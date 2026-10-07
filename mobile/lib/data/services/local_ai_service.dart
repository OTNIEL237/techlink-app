// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : local_ai_service.dart
// Rôle          : Moteur d'analyse heuristique locale et autonome (fonctionnement 100% hors-ligne).
// Module        : Data / Services
// Dépendances   : Aucune
// Sécurité/RLS  : Traitement purement local sur le smartphone ; zéro envoi de données externes.
// =============================================================================

/// Moteur d'analyse et de diagnostic heuristique embarqué dans l'application.
///
/// Fonctionne sans aucune connexion internet grâce à un système de reconnaissance
/// lexicale, pondération par mots-clés, détection d'urgence et base de connaissances
/// pré-remplie pour formuler des conseils de sécurité immédiats.
class LocalAiService {
  /// Analyse une description de problème et produit un diagnostic complet sans réseau.
  ///
  /// [problem] Texte brut de la panne saisi par le client.
  /// [photoCount] Nombre de photos prises en appui.
  /// Retourne un dictionnaire normalisé contenant catégorie, urgence, étapes de résolution temporaire et consignes de sécurité.
  static Map<String, dynamic> analyze(String problem, {int photoCount = 0}) {
    final text = normalize(problem);
    final category = _detectCategory(text);
    final urgency = _detectUrgency(text);
    final solution = _getSolution(category['slug']!, urgency, text);

    return {
      'category': category['name'],
      'category_slug': category['slug'],
      'urgency': urgency,
      'urgency_label': _urgencyLabel(urgency),
      'temporary_solution': solution['steps'],
      'problem_summary':
          'Problème de ${category['name']} détecté.${photoCount > 0 ? ' $photoCount photo(s) fournie(s).' : ''}',
      'estimated_duration': solution['duration'],
      'safety_warning': solution['warning'],
    };
  }

  /// Normalise une chaîne de caractères en supprimant les accents et en convertissant en minuscules.
  ///
  /// [text] Texte d'origine à nettoyer.
  /// Retourne une chaîne normalisée facilitant les correspondances partielles de mots-clés.
  static String normalize(String text) {
    const accents = {
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'à': 'a', 'â': 'a', 'ä': 'a',
      'ù': 'u', 'û': 'u', 'ü': 'u',
      'î': 'i', 'ï': 'i',
      'ô': 'o', 'ö': 'o',
      'ç': 'c', 'ñ': 'n',
    };
    var result = text.toLowerCase();
    accents.forEach((k, v) => result = result.replaceAll(k, v));
    return result;
  }

  /// Détecte la catégorie de métier la plus adaptée en fonction des mots-clés présents dans le texte.
  ///
  /// Intègre une règle de sécurité prioritaire : si de l'eau et du courant coexistent,
  /// la catégorie électricité l'emporte impérativement sur la plomberie.
  static Map<String, String> _detectCategory(String text) {
    // Cas spécial : eau + électricité/prise/etincelle -> Électricité
    if ((text.contains('eau') || text.contains('inond')) &&
        (text.contains('electr') ||
            text.contains('courant') ||
            text.contains('prise') ||
            text.contains('etincelle') ||
            text.contains('disjonct') ||
            text.contains('court-circuit') ||
            text.contains('court circuit'))) {
      return {'slug': 'electricite', 'name': 'Électricité'};
    }

    final categories = [
      {
        'slug': 'plomberie',
        'name': 'Plomberie',
        'keywords': [
          'eau', 'robinet', 'fuit', 'fuite', 'tuyau', 'wc', 'toilette',
          'evier', 'douche', 'chauffe', 'canalisation', 'plombier',
          'chasse', 'baignoire', 'lavabo', 'egout', 'pompe', 'vanne',
          'coule', 'deborde', 'bouche', 'evacuation', 'goute',
        ],
      },
      {
        'slug': 'electricite',
        'name': 'Électricité',
        'keywords': [
          'electr', 'courant', 'prise', 'disjonct', 'cable', 'lumiere',
          'ampoule', 'court circuit', 'court-circuit', 'fusible', 'tension', 'volt',
          'interrupteur', 'fil', 'eclairage', 'lampe', 'electricien',
          'grille', 'choc', 'etincelle', 'clignote', 'coupure',
          'explos', 'brule', 'crier', 'griller',
        ],
      },
      {
        'slug': 'climatisation',
        'name': 'Climatisation',
        'keywords': [
          'clim', 'climatiseur', 'ventilat', 'air conditionn',
          'chauffage', 'radiateur', 'temperature', 'froid', 'chaud',
          'chaleur', 'refroidir', 'thermostat',
        ],
      },
      {
        'slug': 'informatique',
        'name': 'Informatique',
        'keywords': [
          'ordinateur', 'pc', 'laptop', 'internet', 'reseau', 'wifi', 'wi-fi',
          'ecran', 'virus', 'lent', 'logiciel', 'windows', 'mac',
          'telephone', 'portable', 'tablette', 'imprimante', 'bug',
          'site', 'connexion', 'connecte', 'ligne', 'page', 'navigateur',
        ],
      },
      {
        'slug': 'menuiserie',
        'name': 'Menuiserie',
        'keywords': [
          'porte', 'fenetre', 'serrure', 'meuble', 'bois', 'parquet',
          'placard', 'escalier', 'volet', 'charniere', 'verrou',
          'poignee', 'coince', 'bloque', 'grince', 'claque',
        ],
      },
      {
        'slug': 'peinture',
        'name': 'Peinture',
        'keywords': [
          'peinture', 'tache', 'humidite', 'moisissure', 'papier peint',
          'enduit', 'peindre', 'mur', 'decolore', 'jauni', 'noirci',
        ],
      },
      {
        'slug': 'electromenager',
        'name': 'Électroménager',
        'keywords': [
          'frigo', 'refrigerateur', 'machine', 'four', 'lave',
          'congelateur', 'micro onde', 'cuisiniere', 'hotte',
          'lave vaisselle', 'lave linge', 'seche linge', 'aspirateur',
        ],
      },
      {
        'slug': 'maconnerie',
        'name': 'Maçonnerie',
        'keywords': [
          'beton', 'carrelage', 'fissure', 'dalle', 'ciment', 'macon',
          'plancher', 'fondation', 'lezarde', 'brique', 'parpaing',
        ],
      },
    ];

    String bestSlug = 'general';
    String bestName = 'Service général';
    int maxMatches = 0;

    for (final cat in categories) {
      final keywords = cat['keywords'] as List<String>;
      int matches = 0;
      for (final kw in keywords) {
        if (text.contains(kw)) {
          matches++;
        }
      }
      if (matches > maxMatches) {
        maxMatches = matches;
        bestSlug = cat['slug'] as String? ?? 'general';
        bestName = cat['name'] as String? ?? 'Service général';
      }
    }

    return {'slug': bestSlug, 'name': bestName};
  }

  /// Évalue le niveau d'urgence de la situation ('urgent', 'normal', 'low').
  static String _detectUrgency(String text) {
    const urgentKw = [
      'urgent', 'vite', 'maintenant', 'feu', 'flamme', 'brule', 'brulant',
      'inond', 'danger', 'explos', 'gaz', 'fumee', 'secours',
      'immediatement', 'tout de suite', 'grille', 'court circuit',
      'choc electrique', 'risque', 'bientot', 'va exploser',
    ];
    const lowKw = [
      'pas presse', 'quand vous pouvez', 'non urgent',
      'plus tard', 'pas grave', 'depuis longtemps',
    ];

    if (urgentKw.any((kw) => text.contains(kw))) return 'urgent';
    if (lowKw.any((kw) => text.contains(kw))) return 'low';
    return 'normal';
  }

  /// Traduit l'identifiant d'urgence en étiquette textuelle soignée en français.
  static String _urgencyLabel(String urgency) {
    const labels = {'urgent': 'Urgent', 'normal': 'Normal', 'low': 'Faible'};
    return labels[urgency] ?? 'Normal';
  }

  /// Fournit la recommandation pré-formatée avec étapes numérotées, durée estimée et alertes.
  static Map<String, String> _getSolution(
      String slug, String urgency, String text) {

    // Cas spécial eau + électricité
    if ((text.contains('eau') || text.contains('inond')) &&
        (text.contains('electr') || text.contains('courant') ||
            text.contains('prise'))) {
      return {
        'steps': '1. Coupez IMMÉDIATEMENT le disjoncteur principal.\n'
            '2. Quittez la zone affectée.\n'
            '3. N\'entrez pas dans l\'eau si le courant est actif.\n'
            '4. Appelez les secours si nécessaire.\n'
            '5. Attendez le technicien à l\'extérieur.',
        'duration': 'Urgence immédiate',
        'warning': '⚠️ DANGER EXTRÊME : Eau + Électricité = Risque mortel ! Coupez le courant AVANT tout.',
      };
    }

    final solutions = <String, Map<String, String>>{
      'plomberie': {
        'steps': '1. Fermez le robinet d\'arrêt principal.\n'
            '2. Essuyez l\'eau pour éviter les glissades.\n'
            '3. Placez un seau sous la fuite.\n'
            '4. Évitez d\'utiliser l\'eau jusqu\'à l\'intervention.\n'
            '5. Photographiez la zone pour le technicien.',
        'duration': '1h à 3h',
        'warning': urgency == 'urgent'
            ? 'Évitez tout contact avec des prises si de l\'eau est présente !'
            : '',
      },
      'electricite': {
        'steps': '1. Ne touchez pas les fils ou prises endommagés.\n'
            '2. Coupez le disjoncteur dans le tableau électrique.\n'
            '3. Débranchez les appareils de la zone concernée.\n'
            '4. N\'essayez pas de réparer vous-même.\n'
            '5. Notez l\'emplacement exact du problème.',
        'duration': '1h à 4h',
        'warning': 'Ne touchez jamais un câble sans avoir coupé le courant. Risque d\'électrocution !',
      },
      'climatisation': {
        'steps': '1. Éteignez l\'appareil depuis la télécommande.\n'
            '2. Vérifiez que les filtres ne sont pas bouchés.\n'
            '3. Assurez-vous que rien ne bloque les grilles.\n'
            '4. Notez les messages d\'erreur affichés.\n'
            '5. Ne démontez pas l\'appareil.',
        'duration': '1h à 2h',
        'warning': '',
      },
      'informatique': {
        'steps': '1. Redémarrez l\'appareil.\n'
            '2. Sauvegardez vos données sur une clé USB.\n'
            '3. Notez les messages d\'erreur affichés.\n'
            '4. Débranchez les périphériques non essentiels.\n'
            '5. Ne téléchargez pas de logiciels inconnus.',
        'duration': '30min à 2h',
        'warning': '',
      },
      'menuiserie': {
        'steps': '1. Ne forcez pas la porte ou le meuble bloqué.\n'
            '2. Utilisez de l\'huile sur les charnières si elles grincent.\n'
            '3. Sécurisez la zone si la porte ne ferme plus.\n'
            '4. Photographiez les zones endommagées.\n'
            '5. Notez depuis quand le problème existe.',
        'duration': '1h à 3h',
        'warning': '',
      },
      'peinture': {
        'steps': '1. Identifiez la source d\'humidité si des taches apparaissent.\n'
            '2. Aérez la pièce pour réduire l\'humidité.\n'
            '3. Ne couvrez pas les moisissures sans traitement.\n'
            '4. Protégez les meubles proches de la zone.\n'
            '5. Photographiez l\'étendue des dégâts.',
        'duration': '2h à 1 journée',
        'warning': 'Les moisissures peuvent être dangereuses pour la santé.',
      },
      'electromenager': {
        'steps': '1. Débranchez immédiatement l\'appareil.\n'
            '2. Vérifiez que le disjoncteur n\'a pas sauté.\n'
            '3. Notez le modèle et la marque de l\'appareil.\n'
            '4. Photographiez les panneaux d\'erreur.\n'
            '5. Ne démontez pas l\'appareil vous-même.',
        'duration': '1h à 3h',
        'warning': '',
      },
      'maconnerie': {
        'steps': '1. N\'utilisez pas la zone fissurée.\n'
            '2. Délimitez la zone avec du ruban adhésif.\n'
            '3. Photographiez les fissures avec une règle.\n'
            '4. Notez si la fissure s\'agrandit avec le temps.\n'
            '5. Évitez d\'humidifier la zone.',
        'duration': '2h à plusieurs jours',
        'warning': 'Si la fissure dépasse 5mm ou s\'agrandit, quittez la pièce.',
      },
      'general': {
        'steps': '1. Décrivez précisément le problème au technicien.\n'
            '2. Photographiez la zone concernée.\n'
            '3. Notez depuis quand le problème existe.\n'
            '4. Coupez l\'alimentation si nécessaire.\n'
            '5. Sécurisez la zone pour éviter tout accident.',
        'duration': '1h à 3h',
        'warning': '',
      },
    };

    return solutions[slug] ?? solutions['general']!;
  }
}