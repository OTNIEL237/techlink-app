import 'dart:convert';
import 'local_ai_service.dart';
import 'api_service.dart';

class GroqAiService {
  // =========================================================================
  // SERVICE D'INTELLIGENCE ARTIFICIELLE (GROQ / OPENAI)
  // =========================================================================
  // Similaire à Gemini, ce service utilise Groq (qui est très rapide) ou OpenAI 
  // en cas de secours pour analyser le problème du client et catégoriser la panne.
  
  /// Analyse un problème technique avec l'IA via le backend
  static Future<Map<String, dynamic>> analyze(String problem, {int photoCount = 0, String? forcedCategorySlug}) async {
    try {
      final apiService = ApiService();
      final response = await apiService.analyzeProblem(
        problem: problem,
        photosCount: photoCount,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return _normalizeResponse(response['data'], problem, photoCount, forcedCategorySlug: forcedCategorySlug);
      } else {
        print('AI Backend error: ${response}');
        return _fallbackAnalysis(problem, photoCount, forcedCategorySlug: forcedCategorySlug);
      }
    } catch (e) {
      print('AI service error: $e');
      // Fallback si pas de connexion ou autre erreur
      return _fallbackAnalysis(problem, photoCount, forcedCategorySlug: forcedCategorySlug);
    }
  }

  static const String _systemPrompt = '''
Tu es l'assistant IA expert en diagnostic de pannes de TechLink, une application camerounaise de mise en relation pour des réparations domestiques et techniques.
Ton rôle est d'analyser la description utilisateur (qui peut contenir des fautes d'orthographe, du langage familier ou des détails imprécis) et de retourner un objet JSON structuré contenant le diagnostic et les conseils.

### RÈGLES DE PERTINENCE :
- DOIT être un problème technique, une panne, un dysfonctionnement matériel, une fuite, une anomalie électrique, un besoin de réparation ou d'installation d'équipements de la maison ou personnels (plomberie, électricité, électroménager, climatisation, informatique, réseau, menuiserie, maçonnerie, serrurerie, peinture, téléphonie, motorisation, gaz, etc.).
- Les requêtes insolites mais décrivant des symptômes physiques réels (bruits suspects dans le plafond, sensation de vibration, animaux apeurés près des murs, mur chaud, ampoules qui grillent sans cesse, etc.) sont TOTALEMENT PERTINENTES et révèlent souvent des pannes cachées.
- Hors-sujet (is_relevant = false) : Si le message ne décrit aucun problème technique, aucune panne ou demande de dépannage (ex: "j'ai dansé toute la nuit", "j'ai faim", "bonjour", "aide-moi pour mes devoirs", "comment tu t'appelles", "je m'ennuie").
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

### RÈGLES DE CLASSIFICATION CATÉGORIELLE (Intelligence & Causalité) :
Analyse la CAUSE ou l'ORGANE PRINCIPAL en panne, évite les fausses corrélations (ex: "téléphone ne charge plus depuis coupure d'eau" -> Réparation téléphone).
- **electricite** (Électricité) : Prises, éclairage, tableaux, disjoncteurs, courts-circuits, étincelles.
  - Inclut les pannes complexes : picotements/décharges au robinet/frigo/sol (défaut de terre), odeur de brûlé/plastique chaud, crépitements dans le mur, disjoncteur qui saute (lave-linge/clim/douche qui fait sauter le courant), lampes qui clignotent avec le vent ou le micro-ondes (problème de neutre/surtension).
- **plomberie** (Plomberie) : Fuites d'eau, canalisations, WC, robinets, bruit d'eau dans les cloisons, facture d'eau qui double sans explication (fuite cachée), manque de pression d'eau.
- **electromenager** (Électroménager) : Frigo qui ne refroidit plus (même s'il fait du bruit), lave-linge (linge ressort trempé), lave-vaisselle, four, micro-ondes.
- **climatisation** (Climatisation) : Climatiseurs, splits, ventilateur de plafond.
- **informatique** (Informatique) : Ordinateur lent, bug logiciel, imprimante en panne après mise à jour.
- **reseau** (Réseau) : Coupures internet/Wi-Fi, routeur, box.
- **menuiserie** (Menuiserie) : Fenêtres ou portes en bois gonflées par la pluie, meubles cassés.
- **serrurerie** (Serrurerie) : Clés perdues, verrous bloqués, serrures.
- **peinture** (Peinture) : Peinture qui s'écaille sous la salle de bain (infiltration).
- **maconnerie** (Maçonnerie) : Fissures de murs, carrelage tiède (fuite d'eau chaude sous chape), dalles.
- **gaz** (Gaz) : Odeur de gaz ou d'œuf pourri dans la cuisine (Urgence critique).
- **reparation_telephone** (Réparation téléphone) : Smartphone en surchauffe, écran cassé, ne charge plus.
- **motorisation** (Motorisation) : Portail automatique bloqué par la chaleur.

### GESTION DU MULTI-CATÉGORIES :
Si une panne implique plusieurs domaines, fusionne-les dans `category` (ex: "Électricité + Plomberie" ou "Climatisation + Électricité") mais choisis la catégorie prioritaire en termes de sécurité pour le `category_slug` (généralement `electricite` en cas de présence d'eau ou de court-circuit).

### RÈGLES D'URGENCE (Détection des Dangers Cachés) :
- **urgent** ("Urgent") : Risque d'incendie ou d'électrocution (odeur de brûlé, étincelles, crépitements/bruits suspects dans les murs, décharges/picotements électriques, eau sur circuit électrique, pompe d'aquarium qui fait disjoncter), fuite de gaz (œuf pourri), inondation majeure menaçant des équipements électriques, porte principale impossible à verrouiller la nuit.
- **normal** ("Normal") : Panne totale d'un équipement majeur sans danger immédiat (frigo en panne, plus d'eau chaude, WC bouchés, serrure coincée porte ouverte).
- **low** ("Faible") : Confort ou esthétique (Wi-Fi lent le soir, charnière qui grince, peinture décollée).

### STRUCTURE DE RÉPONSE OBLIGATOIRE (JSON strict uniquement) :
{
  "is_relevant": true,
  "category": "Nom complet de la catégorie (ex: Électricité, Plomberie, Électricité + Plomberie, Gaz)",
  "category_slug": "slug_exact_parmi_ceux_ci (electricite, plomberie, electromenager, climatisation, informatique, reseau, menuiserie, peinture, maconnerie, gaz, reparation_telephone, motorisation, serrurerie, general)",
  "urgency": "urgent" | "normal" | "low",
  "urgency_label": "Urgent" | "Normal" | "Faible",
  "problem_summary": "Résumé clair et pro du problème en français",
  "temporary_solution": "Instructions claires et sécurisées sous forme d'étapes numérotées (1. ... 2. ... 3. ...). Max 5 étapes. Donne des étapes réelles et de sécurité absolue (ex: couper le disjoncteur principal si eau + électricité).",
  "estimated_duration": "Durée estimée de l'intervention (ex: 1h à 2h)",
  "safety_warning": "Consigne de sécurité cruciale si danger (ex: Ne touchez pas aux robinets si vous ressentez des décharges), sinon chaîne vide."
}
''';


  /// Normalise et valide la réponse de l'IA
  static Map<String, dynamic> _normalizeResponse(
      Map<String, dynamic> raw, String problem, int photoCount, {String? forcedCategorySlug}) {
    
    // Si l'utilisateur a forcé une catégorie, on considère que c'est toujours pertinent
    bool isRelevant = (forcedCategorySlug != null) ? true : (raw['is_relevant'] as bool? ?? true);

    final Map<String, String> slugToName = {
      'electricite': 'Électricité',
      'plomberie': 'Plomberie',
      'electromenager': 'Électroménager',
      'climatisation': 'Climatisation',
      'informatique': 'Informatique',
      'reseau': 'Réseau',
      'menuiserie': 'Menuiserie',
      'serrurerie': 'Serrurerie',
      'peinture': 'Peinture',
      'maconnerie': 'Maçonnerie',
      'gaz': 'Gaz',
    };

    // Si le problème n'est pas pertinent (et qu'aucune catégorie n'a été forcée)
    if (!isRelevant) {
      return {
        'is_relevant': false,
        'category': raw['category'] ?? 'Hors sujet',
        'category_slug': 'hors_sujet',
        'urgency': 'low',
        'urgency_label': 'Non applicable',
        'problem_summary': raw['problem_summary'] ??
            'Votre description ne semble pas correspondre à un problème technique domestique. Veuillez décrire un problème de plomberie, électricité, climatisation ou autre pour que nous puissions vous aider.',
        'temporary_solution': '',
        'estimated_duration': '-',
        'safety_warning': '',
      };
    }

    // Réponse normale avec ou sans forçage
    String finalSlug = forcedCategorySlug ?? raw['category_slug'] ?? 'general';
    String finalName = forcedCategorySlug != null 
        ? (slugToName[forcedCategorySlug] ?? 'Service') 
        : (raw['category'] ?? 'Service général');

    return {
      'is_relevant': true,
      'category': finalName,
      'category_slug': finalSlug,
      'urgency': raw['urgency'] ?? 'normal',
      'urgency_label': raw['urgency_label'] ?? 'Normal',
      'problem_summary': raw['problem_summary'] ??
          'Problème détecté.${photoCount > 0 ? ' $photoCount photo(s) fournie(s).' : ''}',
      'temporary_solution': raw['temporary_solution'] ?? '',
      'estimated_duration': raw['estimated_duration'] ?? '1h à 3h',
      'safety_warning': raw['safety_warning'] ?? '',
    };
  }

  /// Analyse de secours (sans API) — version améliorée du LocalAiService
  static Map<String, dynamic> _fallbackAnalysis(String problem, int photoCount, {String? forcedCategorySlug}) {
    final text = LocalAiService.normalize(problem);

    // Mots-clés indiquant un problème hors-sujet
    final nonTechKeywords = [
      'faim', 'soif', 'manger', 'boire', 'dormir', 'sommeil',
      'bonjour', 'salut', 'coucou', 'ça va', 'comment vas',
      'amour', 'copine', 'copain', 'musique', 'film', 'jeu',
      'école', 'travail', 'argent', 'test', 'essai', 'danser',
      'danse', 'chante', 'nuit', 'reve', 'reveil',
    ];

    // Mots-clés techniques ou de panne
    final techKeywords = [
      'fuit', 'fuite', 'eau', 'robinet', 'tuyau', 'wc', 'toilette',
      'evier', 'douche', 'chauffe', 'canalisation', 'plombier',
      'chasse', 'baignoire', 'lavabo', 'egout', 'pompe', 'vanne',
      'coule', 'deborde', 'bouche', 'evacuation', 'goute',
      'electr', 'courant', 'prise', 'disjonct', 'cable', 'lumiere',
      'ampoule', 'court circuit', 'court-circuit', 'fusible', 'tension', 'volt',
      'interrupteur', 'fil', 'eclairage', 'lampe', 'electricien',
      'grille', 'choc', 'etincelle', 'clignote', 'coupure',
      'explos', 'brule', 'crier', 'griller',
      'clim', 'climatiseur', 'ventilat', 'air conditionn',
      'chauffage', 'radiateur', 'temperature', 'froid', 'chaud',
      'chaleur', 'refroidir', 'thermostat',
      'ordinateur', 'pc', 'laptop', 'internet', 'reseau', 'wifi', 'wi-fi',
      'ecran', 'virus', 'lent', 'logiciel', 'windows', 'mac',
      'telephone', 'portable', 'tablette', 'imprimante', 'bug',
      'site', 'connexion', 'connecte', 'ligne', 'page', 'navigateur',
      'porte', 'fenetre', 'serrure', 'meuble', 'bois', 'parquet',
      'placard', 'escalier', 'volet', 'charniere', 'verrou',
      'poignee', 'coince', 'bloque', 'grince', 'claque',
      'peinture', 'tache', 'humidité', 'moisissure', 'papier peint',
      'enduit', 'peindre', 'mur', 'decolore', 'jauni', 'noirci',
      'frigo', 'refrigerateur', 'machine', 'four', 'lave',
      'congelateur', 'micro onde', 'cuisiniere', 'hotte',
      'lave vaisselle', 'lave linge', 'seche linge', 'aspirateur',
      'beton', 'carrelage', 'fissure', 'dalle', 'ciment', 'macon',
      'plancher', 'fondation', 'lezarde', 'brique', 'parpaing',
      'panne', 'cassé', 'bloqué', 'marche pas', 'ne fonctionne',
    ];

    final hasNonTech = nonTechKeywords.any((kw) => text.contains(kw));
    final hasTech = techKeywords.any((kw) => text.contains(kw));

    // Si le message contient des termes non techniques, ou ne contient aucun terme technique du tout
    if (forcedCategorySlug == null && ((hasNonTech && !hasTech) || (!hasTech && text.split(' ').length < 15))) {
      return {
        'is_relevant': false,
        'category': 'Hors sujet',
        'category_slug': 'hors_sujet',
        'urgency': 'low',
        'urgency_label': 'Non applicable',
        'problem_summary':
            'Votre description ne semble pas correspondre à un problème technique domestique. '
            'Veuillez décrire un problème de plomberie, électricité, climatisation, informatique ou autre pour que notre IA puisse vous aider.',
        'temporary_solution': '',
        'estimated_duration': '-',
        'safety_warning': '',
      };
    }

    final localResult = LocalAiService.analyze(problem, photoCount: photoCount);

    final Map<String, String> slugToName = {
      'electricite': 'Électricité',
      'plomberie': 'Plomberie',
      'electromenager': 'Électroménager',
      'climatisation': 'Climatisation',
      'informatique': 'Informatique',
      'reseau': 'Réseau',
      'menuiserie': 'Menuiserie',
      'serrurerie': 'Serrurerie',
      'peinture': 'Peinture',
      'maconnerie': 'Maçonnerie',
      'gaz': 'Gaz',
    };

    String finalSlug = forcedCategorySlug ?? localResult['category_slug'] ?? 'general';
    String finalName = forcedCategorySlug != null 
        ? (slugToName[forcedCategorySlug] ?? 'Service') 
        : (localResult['category'] ?? 'Service général');

    return {
      'is_relevant': true,
      'category': finalName,
      'category_slug': finalSlug,
      'urgency': localResult['urgency'] ?? 'normal',
      'urgency_label': localResult['urgency_label'] ?? 'Normal',
      'problem_summary': localResult['problem_summary'] ?? 'Problème détecté.',
      'temporary_solution': localResult['temporary_solution'] ?? '',
      'estimated_duration': localResult['estimated_duration'] ?? '1h à 3h',
      'safety_warning': localResult['safety_warning'] ?? '',
    };
  }
}
