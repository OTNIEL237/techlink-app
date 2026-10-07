// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : ai_solution_screen.dart
// Rôle          : Affichage des solutions et recommandations générées par l'IA
// Module        : Présentation / Client / Diagnostic IA
// Dépendances   : flutter_tts, geolocator, supabase_flutter, go_router
// Sécurité/RLS  : Accès réservé aux clients authentifiés créant une mission
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../shared/responsive_web_wrapper.dart';

/// [AiSolutionScreen] présente les résultats détaillés du diagnostic d'intelligence artificielle :
/// niveau d'urgence, consignes de sécurité, solution de dépannage temporaire,
/// synthèse vocale (TTS) et bouton de recherche d'artisans à proximité.
class AiSolutionScreen extends StatefulWidget {
  /// Description brute du problème renseignée par l'utilisateur.
  final String problem;

  /// Photos justificatives capturées par le client.
  final List<File> photos;

  /// Métadonnées d'analyse structurées renvoyées par le service d'IA (urgence, conseils, etc.).
  final Map<String, dynamic> aiResult;

  const AiSolutionScreen({
    super.key,
    required this.problem,
    required this.photos,
    required this.aiResult,
  });

  @override
  State<AiSolutionScreen> createState() => _AiSolutionScreenState();
}

/// État interne de [AiSolutionScreen] gérant la synthèse vocale (FlutterTts)
/// et la persistance de la nouvelle mission dans la table Supabase `missions`.
class _AiSolutionScreenState extends State<AiSolutionScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  bool _isSavingMission = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    // Lire automatiquement dès l'arrivée sur l'écran
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakResult());
  }

  /// Initialise le moteur Text-to-Speech (voix française, débit et tonalité).
  Future<void> _initTts() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  /// Synthétise vocalement l'ensemble des résultats d'analyse de l'IA (urgence, catégorie, consignes).
  Future<void> _speakResult() async {
    final urgencyLabel = widget.aiResult['urgency_label'] ?? '';
    final category = widget.aiResult['category'] ?? '';
    final summary = widget.aiResult['problem_summary'] ?? '';
    final solution = widget.aiResult['temporary_solution'] ?? '';
    final duration = widget.aiResult['estimated_duration'] ?? '';
    final warning = widget.aiResult['safety_warning'] ?? '';

    final text = '''
      Analyse terminée.
      Catégorie détectée : $category.
      Niveau d'urgence : $urgencyLabel.
      Résumé : $summary.
      Solution temporaire : $solution.
      Durée estimée : $duration.
      ${warning.isNotEmpty ? 'Avertissement de sécurité : $warning.' : ''}
    ''';

    setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  /// Active ou coupe la lecture vocale du diagnostic.
  Future<void> _toggleSpeak() async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
    } else {
      await _speakResult();
    }
  }

  /// Crée un enregistrement de mission dans Supabase avec la géolocalisation actuelle du client
  /// puis redirige vers la carte de recherche des techniciens disponibles.
  Future<void> _createMissionAndNavigate() async {
  setState(() => _isSavingMission = true);

  try {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final categorySlug = widget.aiResult['category_slug'] as String? ?? 'general';

    // Chercher la catégorie
    Map<String, dynamic>? categoryData;
    try {
      categoryData = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .eq('slug', categorySlug)
          .single();
    } catch (_) {}

    // Obtenir la position GPS du client (non bloquant si indisponible)
    double? clientLat;
    double? clientLng;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 6),
        );
        clientLat = pos.latitude;
        clientLng = pos.longitude;
      }
    } catch (_) {}

    // Créer la mission avec coordonnées GPS
    final missionData = await Supabase.instance.client
        .from('missions')
        .insert({
          'client_id': userId,
          'category_id': categoryData?['id'],
          'problem_description': widget.problem,
          'urgency_level': widget.aiResult['urgency'] ?? 'normal',
          'ai_solution': widget.aiResult['temporary_solution'] ?? '',
          'ai_category_detected': widget.aiResult['category'] ?? '',
          'status': 'searching',
          if (clientLat != null) 'client_lat': clientLat,
          if (clientLng != null) 'client_lng': clientLng,
        })
        .select()
        .single();

    if (mounted) {
      context.push('/client/map', extra: {
          'mission_id': missionData['id'],
          'mission': missionData,
          'ai_result': widget.aiResult,
        },);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isSavingMission = false);
  }
}


  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  /// Retourne le code couleur sémantique associé au niveau d'urgence.
  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'urgent':
        return AppColors.error;
      case 'normal':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  /// Retourne l'icône représentative du degré d'urgence de l'intervention.
  IconData _urgencyIcon(String urgency) {
    switch (urgency) {
      case 'urgent':
        return Icons.warning_amber_rounded;
      case 'normal':
        return Icons.info_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final urgency = widget.aiResult['urgency'] as String? ?? 'normal';
    final urgencyLabel = widget.aiResult['urgency_label'] as String? ?? 'Normal';
    final category = widget.aiResult['category'] as String? ?? '';
    final tempSolution = widget.aiResult['temporary_solution'] as String? ?? '';
    final problemSummary = widget.aiResult['problem_summary'] as String? ?? '';
    final estimatedDuration = widget.aiResult['estimated_duration'] as String? ?? '';
    final safetyWarning = widget.aiResult['safety_warning'] as String? ?? '';

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        backgroundColor: tc.background,
        title: Text('Analyse IA', style: TextStyle(color: tc.textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tc.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: ResponsiveWebWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================== BADGE IA ==================
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? tc.primaryLight : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.psychology, color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Analyse complétée par l\'IA',
                      style: TextStyle(
                        color: isDark ? tc.textPrimary : AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ================== LECTURE VOCALE ==================
            Center(
              child: GestureDetector(
                onTap: _toggleSpeak,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isSpeaking
                        ? AppColors.error.withOpacity(0.1)
                        : AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isSpeaking ? AppColors.error : AppColors.success,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isSpeaking
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_outlined,
                        color:
                            _isSpeaking ? AppColors.error : AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isSpeaking ? 'Arrêter la lecture' : 'Écouter la réponse',
                        style: TextStyle(
                          color: _isSpeaking ? AppColors.error : AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ================== URGENCE & CATÉGORIE ==================
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    icon: _urgencyIcon(urgency),
                    label: 'Urgence',
                    value: urgencyLabel,
                    color: _urgencyColor(urgency),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoChip(
                    icon: Icons.category_outlined,
                    label: 'Catégorie',
                    value: category,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),

            if (estimatedDuration.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoChip(
                icon: Icons.access_time,
                label: 'Durée estimée',
                value: estimatedDuration,
                color: AppColors.technicianColor,
              ),
            ],

            // ================== ALERTE DE SÉCURITÉ ==================
            if (safetyWarning.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber,
                        color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        safetyWarning,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ================== RÉSUMÉ ==================
            _SectionCard(
              icon: Icons.description_outlined,
              title: 'Problème détecté',
              content: problemSummary,
              color: AppColors.primary,
            ),

            const SizedBox(height: 16),

            // ================== SOLUTION TEMPORAIRE ==================
            _SectionCard(
              icon: Icons.build_outlined,
              title: 'Solution temporaire',
              content: tempSolution,
              color: AppColors.success,
            ),

            const SizedBox(height: 32),

            // ================== TROUVER UN TECHNICIEN ==================
            ElevatedButton.icon(
              onPressed: _isSavingMission ? null : _createMissionAndNavigate,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isSavingMission
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.location_on_outlined),
              label: Text(
                _isSavingMission
                    ? 'Création de la mission...'
                    : 'Trouver un technicien proche',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 12),

            // ================== MODIFIER DESCRIPTION ==================
            OutlinedButton.icon(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                side: BorderSide(color: tc.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(Icons.edit_outlined,
                  color: tc.textSecondary),
              label: Text(
                'Modifier ma description',
                style: TextStyle(color: tc.textSecondary),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    ));
  }
}

/// Pastille compacte affichant un attribut clé (urgence, catégorie, durée estimée).
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
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

/// Carte de présentation d'une section analytique (ex: Problème détecté, Solution temporaire).
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? tc.card : tc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: tc.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: tc.border),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color: tc.textPrimary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}