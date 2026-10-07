// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : edit_profile_screen.dart
// Rôle          : Écran d'édition des données personnelles du profil utilisateur
//                 (nom, numéro de téléphone, avatar photo avec upload Supabase).
// Module        : Présentation Client (Profil / Édition)
// Dépendances   : flutter/material.dart, image_picker, supabase_flutter,
//                 app_colors.dart, go_router
// Sécurité/RLS  : Accès restreint à l'utilisateur authentifié (table `users` et
//                 bucket de stockage `avatars`).
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';

/// Écran permettant à un utilisateur de modifier son profil et sa photo d'avatar.
class EditProfileScreen extends StatefulWidget {
  /// Constructeur constant de l'écran d'édition de profil
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  /// Contrôleur de saisie pour le nom complet
  final _nameController = TextEditingController();

  /// Contrôleur de saisie pour le numéro de téléphone
  final _phoneController = TextEditingController();
  
  /// URL publique de l'image de profil actuelle
  String? _avatarUrl;

  /// Indicateur de chargement initial des informations
  bool _isLoading = true;

  /// Indicateur de sauvegarde en cours dans la base de données
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  /// Récupère les données du profil de l'utilisateur connecté depuis Supabase
  Future<void> _loadProfileData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', user.id)
            .single();

        if (mounted) {
          setState(() {
            _nameController.text = data['name'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _avatarUrl = data['avatar_url'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Permet à l'utilisateur de choisir une image dans la galerie et l'envoie vers Supabase Storage
  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 80,
      );

      if (image == null) return;

      if (mounted) {
        setState(() => _isLoading = true);
      }

      final bytes = await image.readAsBytes();
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final fileExt = image.name.split('.').last.isNotEmpty ? image.name.split('.').last : 'png';
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );

      final newAvatarUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      await Supabase.instance.client
          .from('users')
          .update({'avatar_url': newAvatarUrl})
          .eq('id', userId);

      if (mounted) {
        setState(() {
          _avatarUrl = newAvatarUrl;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo de profil mise à jour')),
        );
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'upload : $e')),
        );
      }
    }
  }

  /// Enregistre les modifications apportées au profil (nom, téléphone) dans Supabase
  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('users')
            .update({
              'name': _nameController.text.trim(),
              'phone': _phoneController.text.trim(),
            })
            .eq('id', user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil mis à jour avec succès')),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la mise à jour : $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: Text('Éditer le profil', style: TextStyle(fontWeight: FontWeight.bold, color: tc.textPrimary)),
        centerTitle: true,
        backgroundColor: tc.background,
        elevation: 0,
        iconTheme: IconThemeData(color: tc.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Photo de profil
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: isDark ? tc.primaryLight : AppColors.primaryLight,
                            shape: BoxShape.circle,
                            image: _avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_avatarUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _avatarUrl == null
                              ? Icon(Icons.person, size: 50, color: isDark ? tc.textPrimary : AppColors.primary)
                              : null,
                        ),
                        GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: tc.background, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  _buildTextField('Nom complet', _nameController, tc, isDark, icon: Icons.person_outline),
                  const SizedBox(height: 20),
                  
                  _buildTextField('Numéro de téléphone', _phoneController, tc, isDark, icon: Icons.phone_outlined, isPhone: true),
                  const SizedBox(height: 40),
                  
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Enregistrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  /// Construit un champ de formulaire textuel ou téléphonique avec mise en forme personnalisée
  Widget _buildTextField(String label, TextEditingController controller, TechLinkColors tc, bool isDark, {IconData? icon, bool isPhone = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: tc.textPrimary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? tc.surface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tc.border),
          ),
          child: Row(
            children: [
              if (isPhone) ...[
                Text('+237', style: TextStyle(fontWeight: FontWeight.bold, color: tc.textPrimary)),
                const SizedBox(width: 8),
                Container(width: 1, height: 24, color: tc.border),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: isPhone ? TextInputType.phone : TextInputType.name,
                  style: TextStyle(fontWeight: FontWeight.bold, color: tc.textPrimary),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: tc.textSecondary),
                    suffixIcon: icon != null ? Icon(icon, color: tc.textSecondary) : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
