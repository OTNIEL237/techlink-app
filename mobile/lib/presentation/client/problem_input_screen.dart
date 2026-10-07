// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : problem_input_screen.dart
// Rôle          : Formulaire de saisie et description de panne (voix, texte, photos)
// Module        : Présentation / Client / Diagnostic & Déclaration
// Dépendances   : speech_to_text, image_picker, permission_handler, TechLinkAiService
// Sécurité/RLS  : Accessible aux utilisateurs authentifiés souhaitant créer une mission
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import '../../../core/constants/app_colors.dart';
import '../shared/widgets/techlink_button.dart';
import '../shared/widgets/techlink_input.dart';
import '../../../data/services/techlink_ai_service.dart';
import '../shared/responsive_web_wrapper.dart';

/// [ProblemInputScreen] permet au client de consigner sa panne ou son besoin technique :
/// saisie textuelle guidée, dictée vocale temps réel (Speech-to-Text),
/// ajout de photos (caméra/galerie) et soumission au moteur IA TechLink.
class ProblemInputScreen extends StatefulWidget {
  /// Catégorie pré-sélectionnée issue de l'écran d'accueil (ex: 'plomberie').
  final String? preselectedCategory;

  /// Texte initial éventuel pré-rempli.
  final String? initialProblem;

  /// Donne immédiatement le focus au champ de saisie si vrai.
  final bool autofocus;

  /// Lance automatiquement la dictée vocale à l'ouverture de l'écran si vrai.
  final bool startVoice;

  const ProblemInputScreen({
    super.key,
    this.preselectedCategory,
    this.initialProblem,
    this.autofocus = false,
    this.startVoice = false,
  });

  @override
  State<ProblemInputScreen> createState() => _ProblemInputScreenState();
}

/// État interne gérant la reconnaissance vocale, l'animation du micro pulsé
/// et la sélection de fichiers images.
class _ProblemInputScreenState extends State<ProblemInputScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _problemController;
  final _problemFocusNode = FocusNode();
  final _picker = ImagePicker();
  final SpeechToText _speechToText = SpeechToText();

  List<File> _selectedPhotos = [];
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _wordsSpoken = '';
  String? _selectedCategorySlug;

  final List<Map<String, String>> _categories = [
    {'name': '✨ Détection IA automatique', 'slug': 'auto'},
    {'name': '🚰 Plomberie', 'slug': 'plomberie'},
    {'name': '⚡ Électricité', 'slug': 'electricite'},
    {'name': '❄️ Climatisation', 'slug': 'climatisation'},
    {'name': '🧊 Électroménager', 'slug': 'electromenager'},
    {'name': '🪵 Menuiserie', 'slug': 'menuiserie'},
    {'name': '🔑 Serrurerie', 'slug': 'serrurerie'},
    {'name': '🎨 Peinture', 'slug': 'peinture'},
    {'name': '🧱 Maçonnerie', 'slug': 'maconnerie'},
    {'name': '💻 Informatique', 'slug': 'informatique'},
    {'name': '🌐 Réseau', 'slug': 'reseau'},
  ];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _problemController = TextEditingController(text: widget.initialProblem);
    if (widget.preselectedCategory != null &&
        _categories.any((c) => c['slug'] == widget.preselectedCategory)) {
      _selectedCategorySlug = widget.preselectedCategory;
    } else {
      _selectedCategorySlug = 'auto';
    }

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _problemFocusNode.requestFocus();
      });
    }

    if (widget.startVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toggleListening();
      });
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.stop();
  }

  /// Bascule l'état d'écoute du microphone pour transcrire la voix du client en texte.
  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        final available = await _speechToText.initialize(
          onError: (error) => setState(() => _isListening = false),
        );
        setState(() => _speechAvailable = available);
      }
      if (!_speechAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone non disponible ou permission refusée'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    if (_isListening) {
      await _speechToText.stop();
      _pulseController.stop();
      setState(() => _isListening = false);
    } else {
      setState(() {
        _isListening = true;
        _wordsSpoken = '';
      });
      _pulseController.repeat(reverse: true);

      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _wordsSpoken = result.recognizedWords;
            _problemController.text = _wordsSpoken;
            _problemController.selection = TextSelection.fromPosition(
              TextPosition(offset: _problemController.text.length),
            );
          });
        },
        localeId: 'fr_FR',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
        ),
      );
    }
  }

  /// Déclenche la prise ou la sélection d'une photo d'illustration (limite à 3 photos).
  Future<void> _pickPhoto() async {
    if (_selectedPhotos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos')),
      );
      return;
    }

    final source = await _showPhotoSourceDialog();
    if (source == null) return;

    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() => _selectedPhotos.add(File(image.path)));
    }
  }

  /// Ouvre la feuille modale de sélection de la source de l'image (Appareil photo ou Galerie).
  Future<ImageSource?> _showPhotoSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Ajouter une photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: AppColors.primary),
              ),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: AppColors.primary),
              ),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Soumet le texte et le nombre de photos au service IA pour classification et diagnostic.
  Future<void> _analyzeWithAI() async {
    if (_isListening) {
      await _speechToText.stop();
      _pulseController.stop();
      setState(() => _isListening = false);
    }

    final problem = _problemController.text.trim();
    if (problem.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Décrivez votre problème en au moins 10 caractères'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await TechLinkAiService.analyze(
        problem,
        photoCount: _selectedPhotos.length,
      );

      final isRelevant = result['is_relevant'] as bool? ?? true;

      if (!isRelevant && mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Problème non reconnu'),
                ),
              ],
            ),
            content: Text(
              result['problem_summary'] as String? ??
                  'Votre description ne correspond pas à un problème technique. '
                  'Veuillez décrire un problème de plomberie, électricité, climatisation, etc.',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Modifier ma description'),
              ),
            ],
          ),
        );
        return;
      }

      if (mounted) {
        context.push('/client/ai-solution', extra: {
          'problem': problem,
          'photos': _selectedPhotos,
          'ai_result': result,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'analyse: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _problemController.dispose();
    _problemFocusNode.dispose();
    _pulseController.dispose();
    _speechToText.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: Text('Décrire mon problème', style: TextStyle(color: tc.textPrimary)),
        backgroundColor: tc.background,
        iconTheme: IconThemeData(color: tc.textPrimary),
      ),
      body: ResponsiveWebWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primary.withOpacity(0.15) : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Écrivez ou parlez pour décrire votre problème. L\'IA analyse et propose une solution.',
                        style: TextStyle(color: AppColors.primary, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isListening ? _pulseAnimation.value : 1.0,
                          child: GestureDetector(
                            onTap: _toggleListening,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isListening ? AppColors.error : AppColors.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isListening ? AppColors.error : AppColors.primary).withOpacity(0.4),
                                    blurRadius: _isListening ? 20 : 10,
                                    spreadRadius: _isListening ? 4 : 0,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isListening ? Icons.stop : Icons.mic,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _isListening ? '🔴 En écoute... Parlez maintenant' : 'Appuyez pour parler',
                        key: ValueKey(_isListening),
                        style: TextStyle(
                          color: _isListening ? AppColors.error : tc.textSecondary,
                          fontWeight: _isListening ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: tc.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OU ÉCRIVEZ',
                        style: TextStyle(
                          color: tc.textSecondary.withOpacity(0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        )),
                  ),
                  Expanded(child: Divider(color: tc.border)),
                ],
              ),
              const SizedBox(height: 20),
              Text('Catégorie du problème',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: tc.textPrimary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategorySlug,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? tc.card : AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: tc.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: tc.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                dropdownColor: isDark ? tc.card : AppColors.surface,
                icon: Icon(Icons.arrow_drop_down, color: tc.textPrimary),
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category['slug'],
                    child: Text(
                      category['name']!,
                      style: TextStyle(
                        color: category['slug'] == 'auto' ? AppColors.primary : tc.textPrimary,
                        fontWeight: category['slug'] == 'auto' ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategorySlug = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              Text('Votre problème *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: tc.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _problemController,
                focusNode: _problemFocusNode,
                autofocus: widget.autofocus,
                maxLines: 5,
                maxLength: 500,
                style: TextStyle(color: tc.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ex: Ma robinetterie fuit depuis ce matin...',
                  hintStyle: TextStyle(color: tc.textSecondary),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: isDark ? tc.card : AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: tc.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: tc.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _problemController,
                    builder: (context, value, _) {
                      return value.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: tc.textSecondary),
                              onPressed: () => _problemController.clear(),
                            )
                          : const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Photos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: tc.textPrimary)),
                  Text('${_selectedPhotos.length}/3', style: TextStyle(color: tc.textSecondary, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: isDark ? tc.card : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: tc.border),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 26),
                            SizedBox(height: 4),
                            Text('Ajouter', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ..._selectedPhotos.asMap().entries.map((entry) {
                      return Stack(
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(entry.value),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedPhotos.removeAt(entry.key)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _analyzeWithAI,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.psychology_outlined),
                label: Text(
                  _isLoading ? 'Analyse en cours...' : 'Analyser avec l\'IA',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}