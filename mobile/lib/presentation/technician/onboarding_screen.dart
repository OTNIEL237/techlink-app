import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../shared/kyc_camera_screen.dart';

// =========================================================================
// ÉCRAN D'INSCRIPTION TECHNICIEN
// =========================================================================
// Gère le processus d'inscription en plusieurs étapes (spécialités, 
// disponibilité, documents, paiement).

class TechnicianOnboardingScreen extends StatefulWidget {
  const TechnicianOnboardingScreen({super.key});

  @override
  State<TechnicianOnboardingScreen> createState() =>
      _TechnicianOnboardingScreenState();
}

class _TechnicianOnboardingScreenState
    extends State<TechnicianOnboardingScreen> {
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _mtnController = TextEditingController();
  final _orangeController = TextEditingController();

  List<String> _selectedSpecialties = [];
  List<File> _documents = [];
  File? _cniDocument;
  File? _selfieDocument;
  bool _isLoading = false;
  int _currentStep = 0;

  Map<String, String> _availability = {
    'Lundi': '08:00 - 18:00',
    'Mardi': '08:00 - 18:00',
    'Mercredi': '08:00 - 18:00',
    'Jeudi': '08:00 - 18:00',
    'Vendredi': '08:00 - 18:00',
    'Samedi': '09:00 - 14:00',
    'Dimanche': 'Fermé',
  };

  final List<String> _allSpecialties = [
    'Plomberie', 'Électricité', 'Climatisation',
    'Informatique', 'Menuiserie', 'Peinture',
    'Électroménager', 'Maçonnerie',
  ];

  Future<void> _pickDocument() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _documents.add(File(file.path)));
    }
  }

  Future<void> _pickKYCDocument(bool isSelfie) async {
    final XFile? photo = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(
        builder: (_) => KycCameraScreen(
          mode: isSelfie ? KycCaptureMode.selfie : KycCaptureMode.cni,
        ),
      ),
    );
    if (photo != null) {
      setState(() {
        if (isSelfie) {
          _selfieDocument = File(photo.path);
        } else {
          _cniDocument = File(photo.path);
        }
      });
    }
  }

  Future<void> _submit() async {
  if (_selectedSpecialties.isEmpty) {
    _showError('Choisissez au moins une spécialité');
    return;
  }
  if (_cniDocument == null) {
    _showError('Veuillez fournir votre CNI');
    return;
  }
  if (_selfieDocument == null) {
    _showError('Veuillez fournir un selfie avec votre CNI');
    return;
  }
  if (_mtnController.text.trim().isEmpty &&
      _orangeController.text.trim().isEmpty) {
    _showError('Entrez au moins un numéro de paiement');
    return;
  }

  setState(() => _isLoading = true);

  try {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    print('👤 User ID: $userId');

    // Vérifier si profil technicien existe déjà
    final existing = await Supabase.instance.client
        .from('technicians')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    
    print('📋 Existing technician: $existing');

    final technicianData = {
      'bio': _bioController.text.trim(),
      'experience_years': int.tryParse(_experienceController.text) ?? 0,
      'specialties': _selectedSpecialties,
      'mtn_number': _mtnController.text.trim(),
      'orange_number': _orangeController.text.trim(),
      'validation_status': 'pending',
      'availability': _availability,
    };

    if (existing != null) {
      print('🔄 Mise à jour technicien existant');
      await Supabase.instance.client
          .from('technicians')
          .update(technicianData)
          .eq('user_id', userId);
    } else {
      print('➕ Création nouveau technicien');
      final insertData = {
        'user_id': userId,
        ...technicianData,
        'status': 'offline',
        'is_verified': false,
      };
      print('📦 Données à insérer: $insertData');
      
      await Supabase.instance.client.from('technicians').insert(insertData);
    }

    // Upload documents si présents (y compris CNI)
    final techResult = await Supabase.instance.client
        .from('technicians')
        .select('id')
        .eq('user_id', userId)
        .single();
    
    final technicianId = techResult['id'];
    print('🔑 Technician ID: $technicianId');

    if (_cniDocument != null) {
      print('📎 Upload de la CNI');
      final bytes = await _cniDocument!.readAsBytes();
      final fileName = '${userId}_cni_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await Supabase.instance.client.storage
          .from('documents')
          .uploadBinary(fileName, bytes);

      final fileUrl = Supabase.instance.client.storage
          .from('documents')
          .getPublicUrl(fileName);

      await Supabase.instance.client
          .from('technician_documents')
          .insert({
        'technician_id': technicianId,
        'document_type': 'cni',
        'file_url': fileUrl,
        'file_name': fileName,
      });
    }

    if (_selfieDocument != null) {
      print('📎 Upload du Selfie');
      final bytes = await _selfieDocument!.readAsBytes();
      final fileName = '${userId}_selfie_cni_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await Supabase.instance.client.storage
          .from('documents')
          .uploadBinary(fileName, bytes);

      final fileUrl = Supabase.instance.client.storage
          .from('documents')
          .getPublicUrl(fileName);

      await Supabase.instance.client
          .from('technician_documents')
          .insert({
        'technician_id': technicianId,
        'document_type': 'selfie_cni',
        'file_url': fileUrl,
        'file_name': fileName,
      });
    }

    if (_documents.isNotEmpty) {
      print('📎 Upload de ${_documents.length} documents');

      for (int i = 0; i < _documents.length; i++) {
        final bytes = await _documents[i].readAsBytes();
        final fileName =
            '${userId}_doc_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        
        print('⬆️ Uploading: $fileName');
        
        await Supabase.instance.client.storage
            .from('documents')
            .uploadBinary(fileName, bytes);

        final fileUrl = Supabase.instance.client.storage
            .from('documents')
            .getPublicUrl(fileName);

        await Supabase.instance.client
            .from('technician_documents')
            .insert({
          'technician_id': technicianId,
          'document_type': 'diplome',
          'file_url': fileUrl,
          'file_name': fileName,
        });
      }
    }

    print('✅ Onboarding réussi!');
    
    if (mounted) {
      context.go('/technician/pending');
    }
  } catch (e) {
    print('❌ ERREUR: $e');
    _showError('Erreur: ${e.toString()}');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _bioController.dispose();
    _experienceController.dispose();
    _mtnController.dispose();
    _orangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        backgroundColor: tc.background,
        title: Text('Créer mon profil technicien', style: TextStyle(color: tc.textPrimary)),
        iconTheme: IconThemeData(color: tc.textPrimary),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 2 && (_cniDocument == null || _selfieDocument == null)) {
            _showError('Veuillez fournir votre CNI et votre selfie');
            return;
          }
          if (_currentStep < 4) {
            setState(() => _currentStep++);
          } else {
            _submit();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep--);
        },
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: _isLoading ? null : details.onStepContinue,
                child: _isLoading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_currentStep == 4 ? 'Soumettre' : 'Suivant'),
              ),
              if (_currentStep > 0) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Retour'),
                ),
              ],
            ],
          ),
        ),
        steps: [
          // ── ÉTAPE 1 : Spécialités ──
          Step(
            title: const Text('Spécialités'),
            subtitle: const Text('Vos domaines d\'expertise'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0
                ? StepState.complete
                : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sélectionnez vos spécialités *',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14, color: tc.textPrimary)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _allSpecialties.map((s) {
                    final selected = _selectedSpecialties.contains(s);
                    return GestureDetector(
                      onTap: () => setState(() => selected
                          ? _selectedSpecialties.remove(s)
                          : _selectedSpecialties.add(s)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : tc.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : tc.border,
                          ),
                        ),
                        child: Text(s,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : tc.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          )),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text('Années d\'expérience',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14, color: tc.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _experienceController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: tc.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'ex: 5',
                    hintStyle: TextStyle(color: tc.textSecondary.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.work_history_outlined,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Biographie',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14, color: tc.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  style: TextStyle(color: tc.textPrimary),
                  decoration: InputDecoration(
                    hintText:
                        'Décrivez votre expérience professionnelle...',
                    hintStyle: TextStyle(color: tc.textSecondary.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ),

          // ── ÉTAPE 2 : Disponibilité ──
          Step(
            title: const Text('Disponibilité'),
            subtitle: const Text('Jours et heures de travail'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ajustez vos horaires par défaut', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: tc.textPrimary)),
                const SizedBox(height: 16),
                ..._availability.keys.map((day) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(width: 90, child: Text(day, style: TextStyle(fontWeight: FontWeight.w500, color: tc.textPrimary))),
                        Expanded(
                          child: TextFormField(
                            initialValue: _availability[day],
                            style: TextStyle(color: tc.textPrimary),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (val) {
                              _availability[day] = val;
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          // ── ÉTAPE 3 : Identité (KYC) ──
          Step(
            title: const Text('Identité'),
            subtitle: const Text('KYC (CNI)'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Fournissez une pièce d\'identité valide (CNI/Passeport) et un selfie avec la pièce pour vérifier votre identité.',
                          style: TextStyle(color: tc.textSecondary, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                Text('Carte Nationale d\'Identité (CNI) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: tc.textPrimary)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _pickKYCDocument(false),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? tc.surface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _cniDocument != null ? AppColors.success : AppColors.primary.withOpacity(0.4), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Icon(_cniDocument != null ? Icons.check_circle : Icons.badge_outlined, color: _cniDocument != null ? AppColors.success : AppColors.primary, size: 30),
                        const SizedBox(height: 8),
                        Text(_cniDocument != null ? 'CNI ajoutée' : 'Ajouter la CNI', style: TextStyle(color: _cniDocument != null ? AppColors.success : AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                Text('Selfie avec la CNI *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: tc.textPrimary)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _pickKYCDocument(true),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? tc.surface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _selfieDocument != null ? AppColors.success : AppColors.primary.withOpacity(0.4), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Icon(_selfieDocument != null ? Icons.check_circle : Icons.camera_alt_outlined, color: _selfieDocument != null ? AppColors.success : AppColors.primary, size: 30),
                        const SizedBox(height: 8),
                        Text(_selfieDocument != null ? 'Selfie ajouté' : 'Prendre un selfie', style: TextStyle(color: _selfieDocument != null ? AppColors.success : AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── ÉTAPE 4 : Documents ──
          Step(
            title: const Text('Documents Pro'),
            subtitle: const Text('Diplômes et certifications'),
            isActive: _currentStep >= 3,
            state: _currentStep > 3
                ? StepState.complete
                : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Vos documents seront vérifiés par notre équipe avant activation.',
                          style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _pickDocument,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: tc.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.4),
                          style: BorderStyle.solid),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.upload_file,
                            color: AppColors.primary, size: 36),
                        const SizedBox(height: 8),
                        Text('Ajouter un document',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          )),
                        const SizedBox(height: 4),
                        Text('Diplôme, certification, CNI...',
                          style: TextStyle(
                            color: tc.textSecondary,
                            fontSize: 12,
                          )),
                      ],
                    ),
                  ),
                ),
                if (_documents.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ..._documents.asMap().entries.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.description,
                            color: AppColors.success, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Document ${e.key + 1}',
                            style: TextStyle(
                                fontWeight: FontWeight.w500, color: tc.textPrimary)),
                        ),
                        GestureDetector(
                          onTap: () => setState(
                              () => _documents.removeAt(e.key)),
                          child: Icon(Icons.close,
                              color: AppColors.error, size: 18),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),

          // ── ÉTAPE 5 : Paiement ──
          Step(
            title: const Text('Paiement'),
            subtitle: const Text('Recevez vos gains'),
            isActive: _currentStep >= 4,
            state: StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entrez au moins un numéro pour recevoir vos paiements après chaque mission.',
                  style: TextStyle(
                      color: tc.textSecondary,
                      fontSize: 13,
                      height: 1.5),
                ),
                const SizedBox(height: 20),
                Text('Numéro MTN Mobile Money',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14, color: tc.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _mtnController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: tc.textPrimary),
                  decoration: InputDecoration(
                    hintText: '6XX XXX XXX',
                    hintStyle: TextStyle(color: tc.textSecondary.withOpacity(0.5)),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.mtnColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('MTN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.black,
                        )),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Numéro Orange Money',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14, color: tc.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _orangeController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: tc.textPrimary),
                  decoration: InputDecoration(
                    hintText: '6XX XXX XXX',
                    hintStyle: TextStyle(color: tc.textSecondary.withOpacity(0.5)),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.orangeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('ORG',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.white,
                        )),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}