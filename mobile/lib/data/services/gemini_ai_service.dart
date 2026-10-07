// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : gemini_ai_service.dart
// Rôle          : Service d'analyse intelligente de pannes via Google Gemini (relais backend).
// Module        : Data / Services
// Dépendances   : api_service.dart, local_ai_service.dart
// Sécurité/RLS  : Ne divulgue aucune clé d'API côté client ; requêtes déléguées au backend.
// =============================================================================

import 'dart:convert';
import 'local_ai_service.dart';
import 'api_service.dart';

/// Service d'assistance et de diagnostic de pannes alimenté par Google Gemini.
///
/// Transmet les descriptions textuelles et pièces jointes des clients au backend
/// pour catégorisation automatique, niveau d'urgence, conseils de sécurité temporaires
/// et estimation du temps d'intervention. Intègre un mode de repli local ([LocalAiService])
/// si le réseau est inaccessible.
class GeminiAiService {
  /// Analyse un problème technique soumis par l'utilisateur via l'API backend.
  ///
  /// En cas d'erreur de communication ou de réponse invalide, bascule automatiquement
  /// sur l'algorithme heuristique hors ligne de [LocalAiService].
  ///
  /// [problem] Description brute rédigée par l'utilisateur.
  /// [photoCount] Nombre de photos fournies pour étayer la panne.
  /// Retourne un dictionnaire normalisé avec catégorie, urgence, conseils et avertissements.
  static Future<Map<String, dynamic>> analyze(String problem, {int photoCount = 0}) async {
    try {
      final apiService = ApiService();
      final response = await apiService.analyzeProblem(
        problem: problem,
        photosCount: photoCount,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return _normalizeResponse(response['data'], problem, photoCount);
      } else {
        print('AI Backend error: ${response}');
        return _fallbackAnalysis(problem, photoCount);
      }
    } catch (e) {
      print('Gemini AI service error: $e');
      return _fallbackAnalysis(problem, photoCount);
    }
  }

  /// Invite système (System Prompt) de référence configurant le comportement de l'IA Gemini.
  static const String _systemPrompt = '''
Tu es l'assistant IA expert en diagnostic de pannes de TechLink, une application camerounaise de mise en relation pour des réparations domestiques et techniques.
Ton rôle est d'analyser la description utilisateur (qui peut contenir des fautes d'orthographe, du langage familier ou des détails imprécis) et de retourner un objet JSON structuré contenant le diagnostic et les conseils.

### RÈGLES DE PERTINENCE :
- DOIT être un problème technique, une panne, un dysfonctionnement matériel, une fuite, une anomalie électrique, un besoin de réparation ou d'installation d'équipements de la maison ou personnels (plomberie, électricité, électroménager, climatisation, informatique, réseau, menuiserie, maçonnerie, serrurerie, peinture, téléphonie, motorisation, gaz, etc.).
- Les requêtes insolites mais décrivant des symptômes physiques réels sont TOTALEMENT PERTINENTES.
- Hors-sujet (is_relevant = false) : Si le message ne décrit aucun problème technique.
  Dans ce cas, retourne obligatoirement :
  - "is_relevant": false
  - "category": "Hors sujet"
  - "category_slug": "hors_sujet"
  - "problem_summary": "Votre description ne correspond pas à un problème technique de dépannage domestique ou matériel."
  - "temporary_solution": ""
  - "urgency": "low"
  - "urgency_label": "Non applicable"
  - "estimated_duration": "-"
  - "safety_warning": ""

### RÈGLES DE CLASSIFICATION CATÉGORIELLE :
Choisis la catégorie la plus pertinente et utilise le slug exact : electricite, plomberie, electromenager, climatisation, informatique, reseau, menuiserie, peinture, maconnerie, gaz, reparation_telephone, motorisation, serrurerie, general.

### RÈGLES D'URGENCE :
- "urgent" ("Urgent") : Risque d'incendie, électrocution, fuite de gaz, inondation majeure.
- "normal" ("Normal") : Panne sans danger immédiat.
- "low" ("Faible") : Confort ou esthétique.

### STRUCTURE DE RÉPONSE OBLIGATOIRE (JSON strict uniquement) :
{
  "is_relevant": true,
  "category": "Nom complet de la catégorie",
  "category_slug": "slug_exact",
  "urgency": "urgent" | "normal" | "low",
  "urgency_label": "Urgent" | "Normal" | "Faible",
  "problem_summary": "Résumé clair du problème en français",
  "temporary_solution": "Instructions claires et sécurisées sous forme d'étapes numérotées (1. ... 2. ... 3. ...). Max 5 étapes.",
  "estimated_duration": "Durée estimée de l'intervention (ex: 1h à 2h)",
  "safety_warning": "Consigne de sécurité cruciale si danger, sinon chaîne vide."
}
''';

  /// Harmonise et assainit la réponse brute renvoyée par le modèle Gemini.
  ///
  /// Garantit la présence de toutes les clés attendues par l'interface utilisateur.
  static Map<String, dynamic> _normalizeResponse(
      Map<String, dynamic> raw, String problem, int photoCount) {
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

  /// Procédure de secours locale (fallback) en cas d'indisponibilité du backend ou d'absence de réseau.
  static Map<String, dynamic> _fallbackAnalysis(String problem, int photoCount) {
    final localResult = LocalAiService.analyze(problem, photoCount: photoCount);

    return {
      'is_relevant': true,
      'category': localResult['category'] ?? 'Service général',
      'category_slug': localResult['category_slug'] ?? 'general',
      'urgency': localResult['urgency'] ?? 'normal',
      'urgency_label': localResult['urgency_label'] ?? 'Normal',
      'problem_summary': localResult['problem_summary'] ?? 'Problème détecté.',
      'temporary_solution': localResult['temporary_solution'] ?? '',
      'estimated_duration': localResult['estimated_duration'] ?? '1h à 3h',
      'safety_warning': localResult['safety_warning'] ?? '',
    };
  }
}
