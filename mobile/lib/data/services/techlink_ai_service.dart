// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : techlink_ai_service.dart
// Rôle          : Point d'entrée unifié pour l'analyse IA déléguée au backend TechLink.
// Module        : Data / Services
// Dépendances   : api_service.dart, local_ai_service.dart
// Sécurité/RLS  : Fait transiter toutes les requêtes par le backend avec cache et fallback local.
// =============================================================================

import 'api_service.dart';
import 'local_ai_service.dart';

/// Service unifié d'orchestration de l'intelligence artificielle pour TechLink.
///
/// Encapsule l'appel vers le microservice backend (qui arbitre dynamiquement
/// entre Groq, OpenAI et les résultats mis en cache) tout en assurant un basculement
/// automatique vers le moteur heuristique local [LocalAiService] en cas de coupure réseau.
class TechLinkAiService {
  /// Analyse un problème technique soumis par le client.
  ///
  /// Interroge en priorité le serveur backend TechLink. En cas d'erreur de communication
  /// ou d'indisponibilité du serveur, bascule en mode autonome hors-ligne via [LocalAiService].
  ///
  /// [problem] Texte descriptif de la panne.
  /// [photoCount] Nombre de clichés photographiques annexés.
  /// Retourne un dictionnaire normalisé avec catégorie, urgence, solutions temporaires et durée d'intervention.
  static Future<Map<String, dynamic>> analyze(String problem, {int photoCount = 0}) async {
    try {
      final apiService = ApiService();
      // Appel du backend (qui gère l'IA, le Cache, et les clés API)
      final response = await apiService.analyzeProblem(
        problem: problem,
        photosCount: photoCount,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return _normalizeResponse(response['data'], problem, photoCount);
      } else {
        print('TechLink AI Backend error: $response');
        return _fallbackAnalysis(problem, photoCount);
      }
    } catch (e) {
      print('TechLink AI network/service error: $e');
      // Fallback local hors-ligne
      return _fallbackAnalysis(problem, photoCount);
    }
  }

  /// S'assure que la structure de données renvoyée par le backend est complète et sécurisée.
  static Map<String, dynamic> _normalizeResponse(Map<String, dynamic> raw, String problem, int photoCount) {
    final isRelevant = raw['is_relevant'] as bool? ?? true;

    if (!isRelevant) {
      return {
        'is_relevant': false,
        'category': raw['category'] ?? 'Hors sujet',
        'category_slug': 'hors_sujet',
        'urgency': 'low',
        'urgency_label': 'Non applicable',
        'problem_summary': raw['problem_summary'] ??
            'Votre description ne semble pas correspondre à un problème technique domestique.',
        'temporary_solution': '',
        'estimated_duration': '-',
        'safety_warning': '',
      };
    }

    return {
      'is_relevant': true,
      'category': raw['category'] ?? 'Service général',
      'category_slug': raw['category_slug'] ?? 'general',
      'urgency': raw['urgency'] ?? 'normal',
      'urgency_label': raw['urgency_label'] ?? 'Normal',
      'problem_summary': raw['problem_summary'] ?? 'Problème détecté.',
      'temporary_solution': raw['temporary_solution'] ?? '',
      'estimated_duration': raw['estimated_duration'] ?? '1h à 3h',
      'safety_warning': raw['safety_warning'] ?? '',
    };
  }

  /// Analyse locale de secours exécutée si le smartphone n'a pas accès à internet.
  static Map<String, dynamic> _fallbackAnalysis(String problem, int photoCount) {
    final localResult = LocalAiService.analyze(problem, photoCount: photoCount);

    return {
      'is_relevant': true,
      'category': localResult['category'] ?? 'Service général',
      'category_slug': localResult['category_slug'] ?? 'general',
      'urgency': localResult['urgency'] ?? 'normal',
      'urgency_label': localResult['urgency_label'] ?? 'Normal',
      'problem_summary': localResult['problem_summary'] ?? 'Problème détecté.',
      'temporary_solution': localResult['temporary_solution'] ?? '1. Isolez la zone concernée.\n2. Ne touchez à rien en cas de danger.\n3. Attendez le technicien.',
      'estimated_duration': localResult['estimated_duration'] ?? '1h à 3h',
      'safety_warning': localResult['safety_warning'] ?? '',
    };
  }
}
