// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : register_screen.dart
// Rôle          : Écran d'inscription complet (Clients en 1 formulaire, Techniciens en 6 étapes KYC/Spécialités).
// Module        : Presentation / Auth
// Dépendances   : flutter, go_router, supabase_flutter, file_picker, kyc_camera_screen.dart, app_router.dart
// Sécurité/RLS  : Inscription Supabase Auth avec métadonnées de rôle, stockage sécurisé des pièces KYC (CNI/Selfie).
// =============================================================================

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/neumorphic_styles.dart';
import '../shared/kyc_camera_screen.dart';

/// Écran complet d'inscription et de vérification d'identité TechLink.
///
/// Prend en charge deux parcours utilisateurs distincts :
/// 1. Parcours Client : Création rapide de compte en un formulaire unique.
/// 2. Parcours Technicien : Processus d'onboarding complet en 6 étapes :
///    - Étape 1 : Informations personnelles (nom, email, téléphone, mot de passe).
///    - Étape 2 : Spécialités professionnelles (métiers).
///    - Étape 3 : Justificatifs d'identité KYC (prise de photo CNI et selfie).
///    - Étape 4 : Justificatifs professionnels et diplômes (CV, attestations).
///    - Étape 5 : Coordonnées de paiement Mobile Money (MTN MoMo et Orange Money).
///    - Étape 6 : Récapitulatif et soumission pour validation.
class RegisterScreen extends StatefulWidget {
  /// Constructeur constant pour [RegisterScreen].
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

/// État associé à l'écran [RegisterScreen] gérant la navigation du stepper et les soumissions.
class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // ── CONTROLLERS ──
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // (Technicien)
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _mtnController = TextEditingController();
  final _orangeController = TextEditingController();

  // ── ÉTAT ──
  String _selectedRole = 'client'; // 'client' ou 'technician'
  final List<String> _selectedSpecialties = [];
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  int _currentStep = 0; // 0 à 5 pour le technicien

  // Documents & KYC
  final List<_DocFile> _documents = [];
  _DocFile? _cniDocument;
  _DocFile? _selfieDocument;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<String> _allSpecialties = [
    'Plomberie', 'Électricité', 'Climatisation', 'Informatique',
    'Menuiserie', 'Peinture', 'Électroménager', 'Maçonnerie',
  ];



  final List<_StepInfo> _techSteps = [
    _StepInfo(icon: Icons.person_outline, title: 'Informations', subtitle: 'Données personnelles'),
    _StepInfo(icon: Icons.engineering_outlined, title: 'Métiers', subtitle: 'Compétences'),
    _StepInfo(icon: Icons.verified_user_outlined, title: 'Identité', subtitle: 'KYC (CNI & Selfie)'),
    _StepInfo(icon: Icons.upload_file_outlined, title: 'Documents', subtitle: 'Justificatifs'),
    _StepInfo(icon: Icons.account_balance_wallet_outlined, title: 'Paiement', subtitle: 'Mobile Money'),
    _StepInfo(icon: Icons.check_circle_outline, title: 'Résumé', subtitle: 'Vérification'),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _mtnController.dispose();
    _orangeController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── VALIDATION DU STEPPER TECHNICIEN ──
  /// Valide les champs obligatoires de l'étape courante du formulaire technicien.
  ///
  /// Retourne `true` si les critères de l'étape sont satisfaits, `false` sinon avec affichage d'un message d'erreur.
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_nameController.text.trim().isEmpty) { _showError('Entrez votre nom complet'); return false; }
        if (_emailController.text.trim().isEmpty) { _showError('Entrez votre email'); return false; }
        if (_phoneController.text.trim().isEmpty) { _showError('Entrez votre numéro de téléphone'); return false; }
        if (_passwordController.text.length < 6) { _showError('Mot de passe : minimum 6 caractères'); return false; }
        if (_passwordController.text != _confirmPasswordController.text) { _showError('Les mots de passe ne correspondent pas'); return false; }
        return true;
      case 1:
        if (_selectedSpecialties.isEmpty) { _showError('Choisissez au moins une spécialité'); return false; }
        return true;
      case 2:
        if (_cniDocument == null) { _showError('Veuillez fournir votre CNI'); return false; }
        if (_selfieDocument == null) { _showError('Veuillez fournir un selfie avec votre CNI'); return false; }
        return true;
      case 3:
        return true; // Documents optionnels
      case 4:
        if (_mtnController.text.trim().isEmpty && _orangeController.text.trim().isEmpty) {
          _showError('Entrez au moins un numéro de paiement Mobile Money');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  /// Passe à l'étape suivante du stepper technicien après validation.
  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 5) {
      setState(() => _currentStep++);
      _animController.reset();
      _animController.forward();
    }
  }

  /// Revient à l'étape précédente du stepper technicien.
  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _animController.reset();
      _animController.forward();
    }
  }

  /// Ouvre l'écran caméra pour capturer un document d'identité (CNI ou selfie).
  ///
  /// [isSelfie] Vrai pour capturer le selfie visage + CNI, faux pour la CNI seule.
  Future<void> _pickKYCDocument(bool isSelfie) async {
    try {
      final photo = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KycCameraScreen(
            mode: isSelfie ? KycCaptureMode.selfie : KycCaptureMode.cni,
          ),
        ),
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          if (isSelfie) {
            _selfieDocument = _DocFile(name: photo.name, path: photo.path, bytes: bytes, type: 'selfie_cni');
          } else {
            _cniDocument = _DocFile(name: photo.name, path: photo.path, bytes: bytes, type: 'cni');
          }
        });
      }
    } catch (e) {
      _showError('Erreur lors de la capture: $e');
    }
  }

  /// Permet la sélection de documents professionnels annexes (CV, diplômes, certificats) via l'explorateur de fichiers.
  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() => _documents.add(_DocFile(
          name: file.name,
          path: file.path,
          bytes: file.bytes,
          type: 'CV',
        )));
      }
    } catch (e) {
      _showError('Erreur lors de la sélection du fichier');
    }
  }

  // ── UTILITAIRES DE TRADUCTION & NETTOYAGE D'ERREURS ──
  /// Traduit les messages d'erreur fréquents renvoyés par Supabase Auth en français clair et informatif.
  String _translateRegisterError(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('user already registered') || lower.contains('already exists')) {
      return 'Cette adresse e-mail est déjà associée à un compte existant. Veuillez vous connecter.';
    }
    if (lower.contains('password should be at least 6 characters') || lower.contains('password is too short')) {
      return 'Le mot de passe doit comporter au moins 6 caractères.';
    }
    if (lower.contains('invalid email') || lower.contains('invalid format') || lower.contains('unable to validate email')) {
      return 'Le format de l\'adresse e-mail est invalide.';
    }
    if (lower.contains('signup requires a valid password')) {
      return 'Veuillez saisir un mot de passe valide.';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'Trop de tentatives en peu de temps. Veuillez patienter quelques instants avant de réessayer.';
    }
    return msg;
  }

  /// Nettoie les messages d'exception bruts pour préserver une interface utilisateur propre.
  String _cleanErrorMessage(String raw) {
    if (raw.startsWith('Exception: ')) {
      return raw.substring(11);
    }
    return raw;
  }

  // ── SOUMISSION TECHNICIEN ──
  /// Procède à la création complète du compte technicien.
  ///
  /// Enregistre l'utilisateur dans Supabase Auth avec métadonnées explicites `role: technician`,
  /// synchronise les tables `users` et `technicians`, téléverse les fichiers KYC vers le bucket de stockage
  /// et navigue vers l'écran de sélection de forfait `/subscription/select`.
  Future<void> _registerTechnician() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    AppRouter.isRegistering = true;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final phone = '+237${_phoneController.text.trim()}';

    debugPrint('════════════════════════════════════════════════════════════════');
    debugPrint('[INSCRIPTION-TECH] Début du processus d\'inscription Technicien');
    debugPrint('[INSCRIPTION-TECH] Nom : $name');
    debugPrint('[INSCRIPTION-TECH] Email : $email');
    debugPrint('[INSCRIPTION-TECH] Téléphone : $phone');
    debugPrint('[INSCRIPTION-TECH] Spécialités : $_selectedSpecialties');
    debugPrint('[INSCRIPTION-TECH] Expérience : ${_experienceController.text.trim()} ans');
    debugPrint('[INSCRIPTION-TECH] MTN MoMo : ${_mtnController.text.trim()} | Orange : ${_orangeController.text.trim()}');
    debugPrint('════════════════════════════════════════════════════════════════');

    try {
      // 1. Supabase Auth avec métadonnées explicites (garantit le rôle technician dès la session)
      debugPrint('[INSCRIPTION-TECH] Étape 1 : Appel Supabase Auth signUp...');
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'role': 'technician',
          'name': name,
          'phone': phone,
        },
      );

      if (response.user == null) {
        debugPrint('[INSCRIPTION-TECH] ÉCHEC : Aucun utilisateur retourné par Supabase.');
        _showError('Erreur lors de la création du compte. Veuillez réessayer.');
        return;
      }

      final userId = response.user!.id;
      final session = response.session;
      debugPrint('[INSCRIPTION-TECH] Utilisateur créé avec succès dans Supabase Auth ! ID: $userId');
      debugPrint('[INSCRIPTION-TECH] Statut de session : ${session != null ? "Active (Connecté)" : "Nulle (Confirmation par email requise)"}');

      // Définir le rôle immédiatement en mémoire pour bloquer tout saut vers /client/home
      AppRouter.setCachedRole(userId, 'technician', validationStatus: 'pending');

      // Si la confirmation d'adresse email est requise sur le projet Supabase
      if (session == null) {
        debugPrint('[INSCRIPTION-TECH] Confirmation par email requise par Supabase. Invitation envoyée.');
        AppRouter.isRegistering = false;
        if (mounted) {
          _showSuccess('Compte technicien créé avec succès ! Un e-mail de confirmation a été envoyé à $email. Veuillez vérifier vos e-mails avant de vous connecter.');
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) context.go('/login');
        }
        return;
      }

      // 2. Table users (upsert résilient avec repli update en cas de conflit ou RLS)
      debugPrint('[INSCRIPTION-TECH] Étape 2 : Synchronisation de la table public.users...');
      try {
        await Supabase.instance.client.from('users').upsert({
          'id': userId,
          'phone': phone,
          'name': name,
          'role': 'technician',
        });
        debugPrint('[INSCRIPTION-TECH] Profil public.users synchronisé avec succès via upsert.');
      } on PostgrestException catch (pe) {
        debugPrint('[INSCRIPTION-TECH] Note upsert public.users (Code: ${pe.code}) : ${pe.message}. Tentative d\'update...');
        try {
          await Supabase.instance.client.from('users').update({
            'phone': phone,
            'name': name,
            'role': 'technician',
          }).eq('id', userId);
          debugPrint('[INSCRIPTION-TECH] Profil public.users mis à jour avec succès via update.');
        } catch (ue) {
          debugPrint('[INSCRIPTION-TECH] Avertissement update public.users (géré par trigger SQL) : $ue');
        }
      } catch (e) {
        debugPrint('[INSCRIPTION-TECH] Avertissement synchro public.users : $e');
      }

      // 3. Table technicians (colonnes conformes mtn_number et orange_number avec repli)
      debugPrint('[INSCRIPTION-TECH] Étape 3 : Synchronisation de la table public.technicians...');
      String technicianId = userId;
      try {
        final techInsert = await Supabase.instance.client.from('technicians').upsert({
          'user_id': userId,
          'bio': _bioController.text.trim(),
          'experience_years': int.tryParse(_experienceController.text.trim()) ?? 0,
          'specialties': _selectedSpecialties,
          'mtn_number': _mtnController.text.trim(),
          'orange_number': _orangeController.text.trim(),
          'validation_status': 'pending',
          'status': 'offline',
          'is_verified': false,
          'availability': {
            'Lundi': '08:00 - 18:00',
            'Mardi': '08:00 - 18:00',
            'Mercredi': '08:00 - 18:00',
            'Jeudi': '08:00 - 18:00',
            'Vendredi': '08:00 - 18:00',
            'Samedi': '09:00 - 14:00',
            'Dimanche': 'Fermé',
          },
        }, onConflict: 'user_id').select('id').maybeSingle();

        if (techInsert != null && techInsert['id'] != null) {
          technicianId = techInsert['id'] as String;
        }
        debugPrint('[INSCRIPTION-TECH] Profil public.technicians enregistré avec succès (ID: $technicianId).');
      } on PostgrestException catch (pe) {
        debugPrint('[INSCRIPTION-TECH] Avertissement upsert technicians (Code: ${pe.code}) : ${pe.message}');
        // Si colonnes manquantes (mtn_number / orange_number dans schéma ancien), tentative avec payload minimal
        try {
          final fallbackPayload = {
            'user_id': userId,
            'bio': _bioController.text.trim(),
            'experience_years': int.tryParse(_experienceController.text.trim()) ?? 0,
            'specialties': _selectedSpecialties,
            'validation_status': 'pending',
            'status': 'offline',
          };
          final techFallback = await Supabase.instance.client
              .from('technicians')
              .upsert(fallbackPayload, onConflict: 'user_id')
              .select('id')
              .maybeSingle();
          if (techFallback != null && techFallback['id'] != null) {
            technicianId = techFallback['id'] as String;
          }
          debugPrint('[INSCRIPTION-TECH] Profil public.technicians enregistré via payload de repli.');
        } catch (fe) {
          debugPrint('[INSCRIPTION-TECH] Échec repli technicians : $fe');
        }
      } catch (e) {
        debugPrint('[INSCRIPTION-TECH] Avertissement synchro technicians : $e');
      }

      // 4. Upload KYC Documents
      debugPrint('[INSCRIPTION-KYC] Étape 4 : Téléversement des justificatifs KYC...');
      try {
        if (_cniDocument != null && _cniDocument!.bytes != null) {
          final path = '$userId/cni_${DateTime.now().millisecondsSinceEpoch}.jpg';
          debugPrint('[INSCRIPTION-KYC] Téléversement CNI vers kyc-documents/$path...');
          await Supabase.instance.client.storage.from('kyc-documents').uploadBinary(
            path,
            _cniDocument!.bytes!,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
          debugPrint('[INSCRIPTION-KYC] CNI téléversée avec succès.');
        }

        if (_selfieDocument != null && _selfieDocument!.bytes != null) {
          final path = '$userId/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';
          debugPrint('[INSCRIPTION-KYC] Téléversement Selfie CNI vers kyc-documents/$path...');
          await Supabase.instance.client.storage.from('kyc-documents').uploadBinary(
            path,
            _selfieDocument!.bytes!,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
          debugPrint('[INSCRIPTION-KYC] Selfie CNI téléversé avec succès.');
        }

        // 5. Upload autres documents
        for (final doc in _documents) {
          if (doc.bytes != null) {
            final ext = doc.name.split('.').last;
            final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_${doc.type}.$ext';
            debugPrint('[INSCRIPTION-KYC] Téléversement document annexe (${doc.name}) vers technician-documents/$path...');
            await Supabase.instance.client.storage.from('technician-documents').uploadBinary(
              path,
              doc.bytes!,
            );
          }
        }
        debugPrint('[INSCRIPTION-KYC] Tous les documents KYC ont été traités.');
      } catch (uploadError) {
        debugPrint('[INSCRIPTION-KYC] Avertissement stockage documents : $uploadError');
      }

      debugPrint('[INSCRIPTION-TECH] Inscription réussie ! Redirection vers la sélection d\'abonnement (/subscription/select)...');
      if (mounted) {
        _showSuccess('Profil technicien créé avec succès !');
        await Future.delayed(const Duration(milliseconds: 1000));
        AppRouter.isRegistering = false;
        context.go(
          '/subscription/select',
          extra: {
            'technicianId': technicianId,
            'userId': userId,
            'name': name,
            'email': email,
            'phone': phone,
          },
        );
      }
    } on AuthException catch (e) {
      debugPrint('[INSCRIPTION-TECH] ERREUR Supabase Auth : [${e.statusCode}] ${e.message}');
      _showError(_translateRegisterError(e.message));
    } catch (e) {
      debugPrint('[INSCRIPTION-TECH] ERREUR inattendue : $e');
      _showError('Erreur : ${_cleanErrorMessage(e.toString())}');
    } finally {
      AppRouter.isRegistering = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── SOUMISSION CLIENT ──
  /// Procède à l'inscription d'un nouvel utilisateur avec le rôle client.
  ///
  /// Valide les champs obligatoires (nom, email, téléphone, mot de passe),
  /// crée le compte Supabase Auth avec les métadonnées `role: client`,
  /// synchronise de manière résiliente le profil dans la table `users` et redirige vers `/client/home`.
  Future<void> _registerClient() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showError('Veuillez remplir tous les champs obligatoires');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Les mots de passe ne correspondent pas');
      return;
    }
    if (_passwordController.text.length < 6) {
      _showError('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }

    setState(() => _isLoading = true);
    AppRouter.isRegistering = true;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final phone = '+237${_phoneController.text.trim()}';

    debugPrint('════════════════════════════════════════════════════════════════');
    debugPrint('[INSCRIPTION-CLIENT] Début du processus d\'inscription Client');
    debugPrint('[INSCRIPTION-CLIENT] Nom : $name');
    debugPrint('[INSCRIPTION-CLIENT] Email : $email');
    debugPrint('[INSCRIPTION-CLIENT] Téléphone : $phone');
    debugPrint('════════════════════════════════════════════════════════════════');

    try {
      // 1. Supabase Auth avec métadonnées explicites
      debugPrint('[INSCRIPTION-CLIENT] Étape 1 : Appel Supabase Auth signUp...');
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'role': 'client',
          'name': name,
          'phone': phone,
        },
      );

      if (response.user == null) {
        debugPrint('[INSCRIPTION-CLIENT] ÉCHEC : Aucun utilisateur retourné par Supabase.');
        _showError('Erreur lors de la création du compte. Veuillez réessayer.');
        return;
      }

      final userId = response.user!.id;
      final session = response.session;
      debugPrint('[INSCRIPTION-CLIENT] Utilisateur créé avec succès dans Supabase Auth ! ID: $userId');
      debugPrint('[INSCRIPTION-CLIENT] Statut de session : ${session != null ? "Active (Connecté)" : "Nulle (Confirmation par email requise)"}');

      // Mise en cache immédiate du rôle client pour le routeur
      AppRouter.setCachedRole(userId, 'client');

      // Si la confirmation d'adresse email est requise sur le projet Supabase
      if (session == null) {
        debugPrint('[INSCRIPTION-CLIENT] Confirmation par email requise par Supabase. Invitation envoyée.');
        AppRouter.isRegistering = false;
        if (mounted) {
          _showSuccess('Compte créé avec succès ! Un e-mail de confirmation a été envoyé à $email. Veuillez vérifier vos e-mails avant de vous connecter.');
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) context.go('/login');
        }
        return;
      }

      // 2. Synchronisation résiliente de la table public.users
      debugPrint('[INSCRIPTION-CLIENT] Étape 2 : Synchronisation table public.users...');
      try {
        await Supabase.instance.client.from('users').upsert({
          'id': userId,
          'phone': phone,
          'name': name,
          'role': 'client',
        });
        debugPrint('[INSCRIPTION-CLIENT] Profil public.users synchronisé avec succès via upsert.');
      } on PostgrestException catch (pe) {
        debugPrint('[INSCRIPTION-CLIENT] Note upsert public.users (Code: ${pe.code}) : ${pe.message}. Tentative d\'update...');
        try {
          // Si l'upsert échoue (ex: policy INSERT restrictive), mise à jour car le trigger SQL l'a peut-être déjà inséré
          await Supabase.instance.client.from('users').update({
            'phone': phone,
            'name': name,
            'role': 'client',
          }).eq('id', userId);
          debugPrint('[INSCRIPTION-CLIENT] Profil public.users mis à jour avec succès via update.');
        } catch (ue) {
          debugPrint('[INSCRIPTION-CLIENT] Avertissement update public.users (géré par trigger SQL) : $ue');
        }
      } catch (e) {
        debugPrint('[INSCRIPTION-CLIENT] Avertissement synchro public.users : $e');
      }

      // 3. Vérification de cohérence du profil en base
      try {
        final check = await Supabase.instance.client.from('users').select('id, role').eq('id', userId).maybeSingle();
        debugPrint('[INSCRIPTION-CLIENT] Vérification DB : ${check != null ? "Profil confirmé en base (Rôle: ${check['role']})" : "Profil initialisé via métadonnées auth"}');
      } catch (ce) {
        debugPrint('[INSCRIPTION-CLIENT] Note vérification profil : $ce');
      }

      debugPrint('[INSCRIPTION-CLIENT] Inscription réussie ! Redirection vers /client/home');
      if (mounted) {
        _showSuccess('Bienvenue sur TechLink !');
        await Future.delayed(const Duration(milliseconds: 1000));
        AppRouter.isRegistering = false;
        context.go('/client/home');
      }
    } on AuthException catch (e) {
      debugPrint('[INSCRIPTION-CLIENT] ERREUR Supabase Auth : [${e.statusCode}] ${e.message}');
      _showError(_translateRegisterError(e.message));
    } catch (e) {
      debugPrint('[INSCRIPTION-CLIENT] ERREUR inattendue : $e');
      _showError('Erreur d\'inscription : ${_cleanErrorMessage(e.toString())}');
    } finally {
      AppRouter.isRegistering = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 750;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: NeumorphicBackground(
        showSpheres: true,
        child: SafeArea(
          child: Column(
            children: [
              // 1. Barre supérieure compacte & moderne
              _buildTopBar(isDark),

              // 2. Zone défilante principale (aucun débordement de pixels possible)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 580 : 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header Brand & Titres
                          _buildHeaderIntro(isDark),
                          const SizedBox(height: 18),

                          // Sélecteur de rôle interactif (Client vs Pro)
                          _buildRoleSelector(isDark),
                          const SizedBox(height: 18),

                          // Carte Glassmorphic maîtresse (Spacieuse et respirante)
                          _buildMasterGlassCard(isDark),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          NeumorphicIconButton(
            size: 42,
            borderRadius: 14,
            tooltip: 'Retour',
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
            ),
            onTap: () => context.pop(),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icon/logo_techlink.png',
                width: 26,
                height: 26,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.handyman_rounded, color: Color(0xFF1E3A8A), size: 24),
              ),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF93C5FD), const Color(0xFF60A5FA)]
                      : [const Color(0xFF1E3A8A), const Color(0xFF1E40AF)],
                ).createShader(bounds),
                child: const Text(
                  'TechLink',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          const NeumorphicThemeToggle(),
        ],
      ),
    );
  }

  Widget _buildHeaderIntro(bool isDark) {
    final accentColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E283E).withOpacity(0.5) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accentColor.withOpacity(0.20),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars_rounded, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Text(
                'CRÉATION DE COMPTE CERTIFIÉ',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
            ),
            children: [
              const TextSpan(text: 'Rejoignez '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF93C5FD), const Color(0xFF60A5FA)]
                        : [const Color(0xFF1E3A8A), const Color(0xFF1E40AF)],
                  ).createShader(bounds),
                  child: Text(
                    _selectedRole == 'client' ? 'Client' : 'Technicien Pro',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _selectedRole == 'client'
              ? 'Trouvez et commandez des prestations qualifiées en quelques clics'
              : 'Multipliez vos interventions et rejoignez un réseau de confiance',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? NeumorphicTheme.darkField : NeumorphicTheme.lightField,
        borderRadius: BorderRadius.circular(24),
        boxShadow: NeumorphicTheme.debossedShadows(isDark),
        border: Border.all(
          color: isDark ? const Color(0xFF263352).withOpacity(0.4) : Colors.white.withOpacity(0.9),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          _buildRoleTab('👤 Espace Client', 'client', isDark),
          _buildRoleTab('🔧 Technicien Pro', 'technician', isDark),
        ],
      ),
    );
  }

  Widget _buildRoleTab(String label, String value, bool isDark) {
    final isSelected = _selectedRole == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedRole = value;
            _currentStep = 0;
          });
          _animController.reset();
          _animController.forward();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected ? NeumorphicTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF1E40AF).withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMasterGlassCard(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF161E2E).withOpacity(0.75)
                : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.85),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _selectedRole == 'client'
              ? _buildClientView(isDark)
              : _buildTechnicianView(isDark),
        ),
      ),
    );
  }

  // ── VUE CLIENT ──
  Widget _buildClientView(bool isDark) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Espace Client',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Remplissez vos informations pour finaliser',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Champs pleine largeur sans étranglement
          NeumorphicTextField(
            controller: _nameController,
            hint: 'Nom complet',
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),

          NeumorphicTextField(
            controller: _emailController,
            hint: 'Adresse email',
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),

          NeumorphicTextField(
            controller: _phoneController,
            hint: 'Numéro (+237 6XX XXX XXX)',
            prefixIcon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),

          NeumorphicTextField(
            controller: _passwordController,
            hint: 'Mot de passe (6 caractères min.)',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: isDark ? const Color(0xFF8E9EB5) : const Color(0xFF6B7A99),
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 14),

          NeumorphicTextField(
            controller: _confirmPasswordController,
            hint: 'Confirmer le mot de passe',
            prefixIcon: Icons.lock_reset_rounded,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _registerClient(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                color: isDark ? const Color(0xFF8E9EB5) : const Color(0xFF6B7A99),
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          const SizedBox(height: 26),

          // Bouton Enregistrement
          NeumorphicGradientButton(
            text: 'Créer mon compte Client',
            isLoading: _isLoading,
            showArrow: true,
            onPressed: _registerClient,
          ),

          const SizedBox(height: 22),

          // Lien Connexion
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Vous avez déjà un compte ? ',
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: Text(
                  'Se connecter',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── VUE TECHNICIEN MULTI-ÉTAPES ──
  Widget _buildTechnicianView(bool isDark) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stepper Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ÉTAPE ${_currentStep + 1}/6',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                _techSteps[_currentStep].title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Barre de progression élégante
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 6,
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF1E283E) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF)),
            ),
          ),
          const SizedBox(height: 12),

          // Puces d'étapes interactives
          Row(
            children: List.generate(_techSteps.length, (i) {
              final isCompleted = i < _currentStep;
              final isCurrent = i == _currentStep;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (i < _currentStep) {
                      setState(() => _currentStep = i);
                      _animController.reset();
                      _animController.forward();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: (isCompleted || isCurrent) ? NeumorphicTheme.primaryGradient : null,
                      color: (isCompleted || isCurrent) ? null : (isDark ? NeumorphicTheme.darkField : NeumorphicTheme.lightField),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: const Color(0xFF1E40AF).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : Icon(
                              _techSteps[i].icon,
                              size: isCurrent ? 15 : 12,
                              color: isCurrent ? Colors.white : (isDark ? const Color(0xFF70809C) : const Color(0xFF94A3B8)),
                            ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          Text(
            _techSteps[_currentStep].subtitle,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 18),

          // Contenu dynamique de l'étape sans carte superflue
          _buildTechnicianStepContent(isDark),

          const SizedBox(height: 24),

          // Boutons de navigation Précédent / Suivant
          Row(
            children: [
              if (_currentStep > 0) ...[
                NeumorphicIconButton(
                  size: 50,
                  borderRadius: 25,
                  tooltip: 'Étape précédente',
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
                  ),
                  onTap: _prevStep,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: NeumorphicGradientButton(
                  text: _currentStep == 5 ? 'Finaliser mon inscription' : 'Étape suivante',
                  isLoading: _isLoading,
                  showArrow: true,
                  onPressed: _currentStep == 5 ? _registerTechnician : _nextStep,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Lien Connexion
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Vous avez déjà un compte ? ',
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: Text(
                  'Se connecter',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicianStepContent(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildStepPersonalInfo(isDark);
      case 1:
        return _buildStepSpecialties(isDark);
      case 2:
        return _buildStepKYC(isDark);
      case 3:
        return _buildStepDocuments(isDark);
      case 4:
        return _buildStepPayment(isDark);
      case 5:
        return _buildStepSummary(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // Étape 0: Infos perso
  Widget _buildStepPersonalInfo(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeumorphicTextField(
          controller: _nameController,
          hint: 'Nom et Prénom *',
          prefixIcon: Icons.badge_outlined,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        NeumorphicTextField(
          controller: _emailController,
          hint: 'Adresse email professionnelle *',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        NeumorphicTextField(
          controller: _phoneController,
          hint: 'Numéro WhatsApp / Appel (+237) *',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        NeumorphicTextField(
          controller: _experienceController,
          hint: 'Années d\'expérience métier (ex: 5)',
          prefixIcon: Icons.timeline_rounded,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        NeumorphicTextField(
          controller: _passwordController,
          hint: 'Mot de passe (6 caractères min.) *',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, size: 20),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 12),
        NeumorphicTextField(
          controller: _confirmPasswordController,
          hint: 'Confirmer le mot de passe *',
          prefixIcon: Icons.lock_reset_rounded,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          suffixIcon: IconButton(
            icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off, size: 20),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
      ],
    );
  }

  // Étape 1: Spécialités
  Widget _buildStepSpecialties(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vos compétences professionnelles *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Cochez vos domaines d\'intervention pour recevoir les demandes clients correspondantes',
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 18),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _allSpecialties.map((s) {
            final isSelected = _selectedSpecialties.contains(s);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedSpecialties.remove(s);
                  } else {
                    _selectedSpecialties.add(s);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected ? NeumorphicTheme.primaryGradient : null,
                  color: isSelected ? null : (isDark ? NeumorphicTheme.darkField : NeumorphicTheme.lightField),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isSelected
                      ? [BoxShadow(color: const Color(0xFF1E3A8A).withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))]
                      : NeumorphicTheme.debossedShadows(isDark),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : (isDark ? const Color(0xFF283656) : Colors.white),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      s,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : (isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 22),

        Text(
          'Bio professionnelle / Présentation',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? NeumorphicTheme.darkField : NeumorphicTheme.lightField,
            borderRadius: BorderRadius.circular(20),
            boxShadow: NeumorphicTheme.debossedShadows(isDark),
            border: Border.all(
              color: isDark ? const Color(0xFF263352).withOpacity(0.4) : Colors.white.withOpacity(0.9),
            ),
          ),
          child: TextField(
            controller: _bioController,
            maxLines: 3,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Décrivez votre savoir-faire, vos garanties de travail...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? NeumorphicTheme.darkTextSecondary.withOpacity(0.6) : NeumorphicTheme.lightTextSecondary.withOpacity(0.6),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  // Étape 2: KYC CNI & Selfie
  Widget _buildStepKYC(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vérification d\'identité obligatoire *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pour la sécurité des clients, nous vérifions l\'authenticité de chaque intervenant TechLink.',
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 20),

        // Carte CNI
        _buildKYCCard(
          title: 'Carte Nationale d\'Identité (CNI)',
          isAdded: _cniDocument != null,
          icon: Icons.badge_rounded,
          onTap: () => _pickKYCDocument(false),
          isDark: isDark,
        ),

        const SizedBox(height: 16),

        // Carte Selfie
        _buildKYCCard(
          title: 'Selfie tenant votre pièce d\'identité',
          isAdded: _selfieDocument != null,
          icon: Icons.camera_alt_rounded,
          onTap: () => _pickKYCDocument(true),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildKYCCard({
    required String title,
    required bool isAdded,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
        decoration: BoxDecoration(
          color: isDark ? NeumorphicTheme.darkField : NeumorphicTheme.lightField,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isAdded
              ? [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))]
              : NeumorphicTheme.debossedShadows(isDark),
          border: Border.all(
            color: isAdded
                ? const Color(0xFF16A34A)
                : (isDark ? const Color(0xFF283656) : Colors.white),
            width: isAdded ? 1.8 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAdded
                    ? const Color(0xFF16A34A).withOpacity(0.15)
                    : const Color(0xFF1E3A8A).withOpacity(0.10),
              ),
              child: Icon(
                isAdded ? Icons.check_circle_rounded : icon,
                color: isAdded ? const Color(0xFF16A34A) : const Color(0xFF1E3A8A),
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAdded ? 'Pièce enregistrée avec succès' : 'Cliquez pour capturer ou sélectionner',
                    style: TextStyle(
                      fontSize: 12,
                      color: isAdded
                          ? const Color(0xFF16A34A)
                          : (isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isAdded ? Icons.done_all_rounded : Icons.camera_alt_outlined,
              color: isAdded ? const Color(0xFF16A34A) : const Color(0xFF6B7A99),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // Étape 3: Documents Pro
  Widget _buildStepDocuments(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Diplômes & Justificatifs professionnels',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Optionnel mais vivement recommandé pour obtenir le badge Vérifié',
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 18),

        GestureDetector(
          onTap: _pickDocument,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? NeumorphicTheme.darkField : NeumorphicTheme.lightField,
              borderRadius: BorderRadius.circular(22),
              boxShadow: NeumorphicTheme.debossedShadows(isDark),
              border: Border.all(
                color: (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A)).withOpacity(0.35),
                width: 1.4,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A)).withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_upload_rounded, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A), size: 30),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ajouter un document professionnel',
                  style: TextStyle(color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A), fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'CV, Diplôme, Attestation, etc.',
                  style: TextStyle(fontSize: 12, color: isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary),
                ),
              ],
            ),
          ),
        ),

        if (_documents.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Documents joints (${_documents.length})',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary),
          ),
          const SizedBox(height: 10),
          ..._documents.asMap().entries.map((e) {
            final index = e.key;
            final doc = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? NeumorphicTheme.darkField : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF283656) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(Icons.description_rounded, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A), size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      doc.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () => setState(() => _documents.removeAt(index)),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  // Étape 4: Paiement
  Widget _buildStepPayment(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comptes de reversement Mobile Money *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Renseignez au moins un compte pour percevoir automatiquement les paiements de vos interventions.',
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 20),

        // MTN MoMo
        Text(
          'MTN Mobile Money (+237)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary),
        ),
        const SizedBox(height: 8),
        NeumorphicTextField(
          controller: _mtnController,
          hint: '6XX XXX XXX (MTN)',
          prefixIcon: Icons.phone_android_rounded,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          suffixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFCC00),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('MTN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.black)),
          ),
        ),

        const SizedBox(height: 18),

        // Orange Money
        Text(
          'Orange Money (+237)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary),
        ),
        const SizedBox(height: 8),
        NeumorphicTextField(
          controller: _orangeController,
          hint: '6XX XXX XXX (Orange)',
          prefixIcon: Icons.phone_android_rounded,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          suffixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6600),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('OM', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // Étape 5: Résumé
  Widget _buildStepSummary(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Récapitulatif de votre candidature',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Vérifiez vos informations avant l\'envoi final',
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 18),

        _buildSummaryRow('Nom', _nameController.text.trim(), isDark),
        _buildSummaryRow('Email', _emailController.text.trim(), isDark),
        _buildSummaryRow('Téléphone', '+237 ${_phoneController.text.trim()}', isDark),
        _buildSummaryRow('Expérience', '${_experienceController.text.trim()} an(s)', isDark),
        _buildSummaryRow('Spécialités', _selectedSpecialties.join(', '), isDark),
        _buildSummaryRow('Pièce CNI', _cniDocument != null ? 'Fournie' : 'Non fournie', isDark),
        _buildSummaryRow('Selfie KYC', _selfieDocument != null ? 'Fourni' : 'Non fourni', isDark),
        if (_mtnController.text.isNotEmpty)
          _buildSummaryRow('MTN MoMo', _mtnController.text.trim(), isDark),
        if (_orangeController.text.isNotEmpty)
          _buildSummaryRow('Orange Money', _orangeController.text.trim(), isDark),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── DATA CLASSES ──

/// Modèle interne représentant un fichier ou document téléversé (KYC, diplôme, CNI).
class _DocFile {
  /// Nom du fichier avec son extension.
  final String name;

  /// Chemin local d'accès au fichier sur l'appareil.
  final String? path;

  /// Données binaires brutes du fichier (utilisées pour l'upload Supabase Storage).
  final Uint8List? bytes;

  /// Catégorie ou nature du document ('cni', 'selfie_cni', 'CV', etc.).
  final String type;

  /// Constructeur de [_DocFile].
  _DocFile({required this.name, this.path, this.bytes, required this.type});
}

/// Modèle d'affichage représentant une étape dans la barre de progression du stepper technicien.
class _StepInfo {
  /// Icône illustrative de l'étape.
  final IconData icon;

  /// Titre principal de l'étape.
  final String title;

  /// Sous-titre explicatif.
  final String subtitle;

  /// Constructeur de [_StepInfo].
  _StepInfo({required this.icon, required this.title, required this.subtitle});
}
