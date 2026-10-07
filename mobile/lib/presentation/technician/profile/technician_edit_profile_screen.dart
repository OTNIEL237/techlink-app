// =============================================================================
// FICHIER : technician_edit_profile_screen.dart
// RÔLE : Gestion et édition du profil professionnel de l'artisan / technicien
// MODULE : Presentation / Technician / Profile
// DÉPENDANCES : flutter/material.dart, go_router, image_picker, supabase_flutter, cached_network_image, app_colors.dart
// SÉCURITÉ / RLS : Authentification technicien requise. Mise à jour de 'users' et 'technicians', upload d'avatar vers Supabase Storage.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';

/// Écran complet d'édition des paramètres professionnels du technicien.
///
/// Permet la gestion de l'avatar photo, du nom, du numéro de contact, de la biographie,
/// des années d'expérience, du tarif horaire indicatif, des spécialités métiers
/// et des numéros de compte Mobile Money (MTN et Orange) pour les encaissements.
class TechnicianEditProfileScreen extends StatefulWidget {
  /// Constructeur constant du widget [TechnicianEditProfileScreen].
  const TechnicianEditProfileScreen({super.key});

  @override
  State<TechnicianEditProfileScreen> createState() => _TechnicianEditProfileScreenState();
}

/// État associé à l'écran d'édition du profil artisan.
///
/// Gère la synchronisation bidirectionnelle des informations de profil
/// entre les tables `users` et `technicians`, ainsi que le téléversement de photos de profil.
class _TechnicianEditProfileScreenState extends State<TechnicianEditProfileScreen> {
  /// Contrôleur du champ de saisie du nom complet de l'artisan.
  final _nameController = TextEditingController();

  /// Contrôleur du champ de saisie du numéro de téléphone principal.
  final _phoneController = TextEditingController();

  /// Contrôleur du champ de saisie de la description / biographie professionnelle.
  final _bioController = TextEditingController();

  /// Contrôleur du champ de saisie des années d'expérience.
  final _experienceController = TextEditingController();

  /// Contrôleur du champ de saisie du taux horaire indicatif en FCFA.
  final _hourlyRateController = TextEditingController();

  /// Contrôleur du numéro MTN Mobile Money pour les versements.
  final _mtnController = TextEditingController();

  /// Contrôleur du numéro Orange Money pour les versements.
  final _orangeController = TextEditingController();

  /// URL publique de la photo de profil hébergée sur Supabase Storage.
  String? _avatarUrl;

  /// Statut de conformité du compte ('pending', 'approved', 'rejected').
  String _validationStatus = 'pending';

  /// Nombre total d'interventions clôturées avec succès.
  int _totalMissions = 0;

  /// Moyenne des évaluations clients obtenues (sur 5 étoiles).
  double _rating = 0.0;

  /// Indicateur de chargement initial des données depuis Supabase.
  bool _isLoading = true;

  /// Indicateur de sauvegarde en cours vers la base de données.
  bool _isSaving = false;

  /// Indicateur d'envoi d'une nouvelle photo vers le bucket Storage avatars.
  bool _isUploadingPhoto = false;

  /// Spécialités actuellement associées au profil du prestataire.
  List<String> _selectedSpecialties = [];

  /// Catalogue exhaustif des spécialités techniques disponibles sur TechLink.
  final List<String> _allSpecialties = [
    'Plomberie',
    'Électricité',
    'Climatisation',
    'Informatique & Réseaux',
    'Menuiserie',
    'Peinture',
    'Électroménager',
    'Maçonnerie',
    'Serrurerie',
    'Froid & Réfrigération',
    'Mécanique Auto',
    'Nettoyage & Entretien',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  /// Libère les ressources des contrôleurs de champs de texte lors du démontage du widget.
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _hourlyRateController.dispose();
    _mtnController.dispose();
    _orangeController.dispose();
    super.dispose();
  }

  /// Nettoie et extrait les chiffres du numéro sans l'indicatif international camerounais '+237' ou '237'.
  String _cleanPhonePrefix(String? raw) {
    if (raw == null) return '';
    var p = raw.trim();
    if (p.startsWith('+237')) p = p.substring(4).trim();
    if (p.startsWith('237')) p = p.substring(3).trim();
    return p;
  }

  /// Charge les données combinées des tables `users` et `technicians` pour pré-remplir le formulaire.
  Future<void> _loadProfileData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final userData = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', user.id)
            .single();

        final techData = await Supabase.instance.client
            .from('technicians')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _nameController.text = userData['name'] ?? '';
            _phoneController.text = _cleanPhonePrefix(userData['phone']);
            _avatarUrl = userData['avatar_url'];

            if (techData != null) {
              _bioController.text = techData['bio'] ?? '';
              _experienceController.text = (techData['experience_years'] ?? '0').toString();
              _hourlyRateController.text = (techData['hourly_rate'] ?? '0').toString();
              _mtnController.text = _cleanPhonePrefix(techData['mtn_number']);
              _orangeController.text = _cleanPhonePrefix(techData['orange_number']);
              _validationStatus = techData['validation_status'] ?? 'pending';
              _totalMissions = (techData['total_missions'] as num?)?.toInt() ?? 0;
              _rating = (techData['rating_average'] as num?)?.toDouble() ?? 5.0;

              if (techData['specialties'] != null) {
                final list = List<String>.from(techData['specialties']);
                _selectedSpecialties = list;
                for (var s in list) {
                  if (!_allSpecialties.contains(s)) {
                    _allSpecialties.add(s);
                  }
                }
              }
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Ouvre la galerie photo, compresse l'image sélectionnée et l'envoie dans le bucket 'avatars'.
  ///
  /// Met à jour de façon synchronisée `users.avatar_url` et `technicians.photo_url`.
  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isUploadingPhoto = true);

      final bytes = await image.readAsBytes();
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final fileExt = image.name.split('.').last.isNotEmpty ? image.name.split('.').last : 'jpg';
      final fileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

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

      await Supabase.instance.client
          .from('technicians')
          .update({'photo_url': newAvatarUrl})
          .eq('user_id', userId);

      if (mounted) {
        setState(() {
          _avatarUrl = newAvatarUrl;
          _isUploadingPhoto = false;
        });
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Photo de profil mise à jour avec succès'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'upload : $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Valide et sauvegarde les modifications du profil dans la base de données Supabase.
  ///
  /// Met à jour les coordonnées dans `users` et les caractéristiques métier dans `technicians`.
  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showToast('Veuillez renseigner votre nom complet');
      return;
    }

    if (_selectedSpecialties.isEmpty) {
      _showToast('Veuillez sélectionner au moins une spécialité professionnelle');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        String phoneFormatted = _phoneController.text.trim();
        if (phoneFormatted.isNotEmpty && !phoneFormatted.startsWith('+237')) {
          phoneFormatted = '+237$phoneFormatted';
        }

        String mtnFormatted = _mtnController.text.trim();
        if (mtnFormatted.isNotEmpty && !mtnFormatted.startsWith('+237')) {
          mtnFormatted = '+237$mtnFormatted';
        }

        String orangeFormatted = _orangeController.text.trim();
        if (orangeFormatted.isNotEmpty && !orangeFormatted.startsWith('+237')) {
          orangeFormatted = '+237$orangeFormatted';
        }

        // 1. Mettre à jour la table users
        await Supabase.instance.client
            .from('users')
            .update({
              'name': name,
              'phone': phoneFormatted,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);

        // 2. Mettre à jour la table technicians
        await Supabase.instance.client
            .from('technicians')
            .update({
              'bio': _bioController.text.trim(),
              'experience_years': int.tryParse(_experienceController.text) ?? 0,
              'hourly_rate': int.tryParse(_hourlyRateController.text) ?? 0,
              'mtn_number': mtnFormatted,
              'orange_number': orangeFormatted,
              'specialties': _selectedSpecialties,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Informations professionnelles enregistrées ✓', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          context.pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showToast('Erreur lors de la sauvegarde : $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Affiche une notification d'erreur stylisée sous forme de SnackBar flottant.
  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Construit l'interface utilisateur d'édition de profil avec sections thématiques.
  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>() ?? TechLinkColors.light;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: tc.background,
        appBar: AppBar(
          title: Text('Modifier mes informations', style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.bold)),
          backgroundColor: tc.background,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isVerified = _validationStatus == 'approved';

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: Text('Profil Professionnel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: tc.textPrimary)),
        centerTitle: true,
        backgroundColor: tc.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: tc.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. CARTE PRO AVATAR + STATUT D'AGRÉMENT
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _avatarUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: tc.surface),
                              errorWidget: (_, __, ___) => const Icon(Icons.person, size: 50),
                            )
                          : Container(
                              color: AppColors.primary.withOpacity(0.15),
                              child: const Icon(Icons.person, size: 52, color: AppColors.primary),
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: _isUploadingPhoto ? null : _pickAndUploadImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.white, width: 2.5),
                        ),
                        child: _isUploadingPhoto
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Badge de statut vérification & notation
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isVerified
                          ? const Color(0xFF059669).withOpacity(0.15)
                          : const Color(0xFFD97706).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isVerified ? const Color(0xFF059669) : const Color(0xFFD97706),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVerified ? Icons.verified_rounded : Icons.pending_actions_rounded,
                          size: 14,
                          color: isVerified ? const Color(0xFF059669) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isVerified ? 'Artisan Certifié' : 'En attente de validation',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isVerified ? const Color(0xFF059669) : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tc.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          '$_rating ($_totalMissions)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tc.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ========================================================
            // SECTION 1 : COORDONNÉES DE CONTACT
            // ========================================================
            _buildSectionTitle('1. Informations & Contact Client', tc),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tc.border),
              ),
              child: Column(
                children: [
                  _buildTextField(
                    label: 'Nom & Prénom professionnel',
                    controller: _nameController,
                    tc: tc,
                    isDark: isDark,
                    icon: Icons.badge_outlined,
                    hint: 'Ex: Jean-Paul Mvondo',
                  ),
                  const SizedBox(height: 16),
                  _buildPhoneField(
                    label: 'Numéro d\'appel direct (Clients)',
                    controller: _phoneController,
                    tc: tc,
                    isDark: isDark,
                    hint: '6XX XX XX XX',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ========================================================
            // SECTION 2 : COMPÉTENCES & TARIFICATION ARTISAN
            // ========================================================
            _buildSectionTitle('2. Métier & Compétences Pro', tc),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tc.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vos Spécialités (Sélectionnez vos domaines d\'expertise) *',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tc.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allSpecialties.map((spec) {
                      final isSelected = _selectedSpecialties.contains(spec);
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (isSelected) {
                              _selectedSpecialties.remove(spec);
                            } else {
                              _selectedSpecialties.add(spec);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : tc.border,
                              width: isSelected ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                size: 14,
                                color: isSelected ? Colors.white : tc.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                spec,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  color: isSelected ? Colors.white : tc.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'Expérience',
                          controller: _experienceController,
                          tc: tc,
                          isDark: isDark,
                          icon: Icons.work_history_outlined,
                          keyboardType: TextInputType.number,
                          suffixText: 'ans',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildTextField(
                          label: 'Tarif indicatif',
                          controller: _hourlyRateController,
                          tc: tc,
                          isDark: isDark,
                          icon: Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                          suffixText: 'FCFA/h',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Description & Bio professionnelle',
                    controller: _bioController,
                    tc: tc,
                    isDark: isDark,
                    maxLines: 3,
                    hint: 'Présentez votre savoir-faire et vos garanties aux clients...',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ========================================================
            // SECTION 3 : COMPTES MOBILE MONEY (VERSEMENTS)
            // ========================================================
            _buildSectionTitle('3. Comptes de Virement (Mobile Money)', tc),
            const SizedBox(height: 6),
            Text(
              'Ces numéros sont utilisés pour vous verser vos gains de dépannage.',
              style: TextStyle(fontSize: 12, color: tc.textSecondary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tc.border),
              ),
              child: Column(
                children: [
                  _buildPhoneField(
                    label: 'Numéro MTN Mobile Money',
                    controller: _mtnController,
                    tc: tc,
                    isDark: isDark,
                    hint: '67X XX XX XX',
                    tag: 'MTN',
                    tagColor: const Color(0xFFEAB308),
                  ),
                  const SizedBox(height: 16),
                  _buildPhoneField(
                    label: 'Numéro Orange Money',
                    controller: _orangeController,
                    tc: tc,
                    isDark: isDark,
                    hint: '69X XX XX XX',
                    tag: 'Orange',
                    tagColor: const Color(0xFFF97316),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ========================================================
            // BOUTON DE SAUVEGARDE
            // ========================================================
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                label: Text(
                  _isSaving ? 'Enregistrement...' : 'Enregistrer les modifications',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Génère un libellé d'en-tête de section typographié.
  Widget _buildSectionTitle(String title, TechLinkColors tc) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
        color: tc.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }

  /// Construit un champ de saisie textuel stylisé avec icône, indicateur et suffixe optionnel.
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required TechLinkColors tc,
    required bool isDark,
    IconData? icon,
    String? hint,
    String? suffixText,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tc.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: maxLines > 1 ? 10 : 3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tc.border),
          ),
          child: Row(
            children: [
              if (icon != null && maxLines == 1) ...[
                Icon(icon, size: 18, color: tc.textSecondary),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: maxLines,
                  keyboardType: keyboardType,
                  style: TextStyle(color: tc.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: tc.textSecondary.withOpacity(0.6), fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (suffixText != null) ...[
                const SizedBox(width: 6),
                Text(suffixText, style: TextStyle(color: tc.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Construit un champ de saisie de numéro téléphonique avec préfixe national (+237) et badge opérateur.
  Widget _buildPhoneField({
    required String label,
    required TextEditingController controller,
    required TechLinkColors tc,
    required bool isDark,
    String? hint,
    String? tag,
    Color? tagColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tc.textPrimary),
            ),
            if (tag != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (tagColor ?? AppColors.primary).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag,
                  style: TextStyle(color: tagColor ?? AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tc.border),
          ),
          child: Row(
            children: [
              Text(
                '🇨🇲 +237',
                style: TextStyle(color: tc.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 18, color: tc.border),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: tc.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: tc.textSecondary.withOpacity(0.6), fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
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
