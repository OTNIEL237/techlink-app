import 'api_service.dart';
import 'local_ai_service.dart';

class TechLinkAiService {
  // =========================================================================
  // SERVICE UNIQUE D'INTELLIGENCE ARTIFICIELLE (VIA BACKEND)
  // =========================================================================
  // Ce service appelle le backend de TechLink qui se charge de contacter
  // le service d'IA le plus rapide disponible (Groq > OpenAI > Cache).
  
  /// Analyse un problème technique via le backend
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

  /// S'assure que la réponse renvoyée par le backend est valide et sécurisée
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

  /// Analyse locale de secours si le téléphone n'a pas internet ou si le backend est HS
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
