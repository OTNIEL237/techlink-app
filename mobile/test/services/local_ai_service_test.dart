import 'package:flutter_test/flutter_test.dart';
import 'package:techlink/data/services/local_ai_service.dart';

void main() {
  group('LocalAiService.normalize', () {
    test('devrait convertir en minuscules', () {
      expect(LocalAiService.normalize('MON ROBINET FUIT'), equals('mon robinet fuit'));
    });

    test('devrait supprimer les accents', () {
      expect(LocalAiService.normalize('électricité'), equals('electricite'));
      expect(LocalAiService.normalize('problème'), equals('probleme'));
      expect(LocalAiService.normalize('à côté'), equals('a cote'));
    });

    test('devrait gérer les chaînes vides', () {
      expect(LocalAiService.normalize(''), equals(''));
    });

    test('devrait gérer les caractères spéciaux (ç, ñ)', () {
      expect(LocalAiService.normalize('ça'), equals('ca'));
    });
  });

  group('LocalAiService.analyze - Détection de catégorie', () {
    test('devrait détecter la plomberie (robinet, fuite, eau)', () {
      final result = LocalAiService.analyze('Mon robinet fuit dans la cuisine');
      expect(result['category_slug'], equals('plomberie'));
      expect(result['category'], equals('Plomberie'));
    });

    test('devrait détecter l\'électricité (prise, courant, disjoncteur)', () {
      final result = LocalAiService.analyze('Le disjoncteur saute à chaque fois');
      expect(result['category_slug'], equals('electricite'));
    });

    test('devrait détecter la climatisation (climatiseur, froid)', () {
      final result = LocalAiService.analyze('Mon climatiseur ne fait plus de froid');
      expect(result['category_slug'], equals('climatisation'));
    });

    test('devrait détecter l\'informatique (ordinateur, wifi)', () {
      final result = LocalAiService.analyze('Mon ordinateur est très lent et le wifi ne marche pas');
      expect(result['category_slug'], equals('informatique'));
    });

    test('devrait détecter la menuiserie (porte, fenêtre, serrure)', () {
      final result = LocalAiService.analyze('La serrure de ma porte est cassée');
      expect(result['category_slug'], equals('menuiserie'));
    });

    test('devrait retourner general si aucun mot-clé ne correspond', () {
      final result = LocalAiService.analyze('J\'ai besoin d\'aide pour un problème');
      expect(result['category_slug'], equals('general'));
    });

    test('devrait prioriser électricité quand eau + courant sont mentionnés', () {
      final result = LocalAiService.analyze('L\'eau a touché la prise électrique et provoque des étincelles');
      expect(result['category_slug'], equals('electricite'));
    });
  });

  group('LocalAiService.analyze - Structure de réponse', () {
    test('devrait retourner tous les champs obligatoires', () {
      final result = LocalAiService.analyze('Mon robinet fuit');
      
      expect(result.containsKey('category'), isTrue);
      expect(result.containsKey('category_slug'), isTrue);
      expect(result.containsKey('urgency'), isTrue);
      expect(result.containsKey('urgency_label'), isTrue);
      expect(result.containsKey('temporary_solution'), isTrue);
      expect(result.containsKey('problem_summary'), isTrue);
      expect(result.containsKey('estimated_duration'), isTrue);
      expect(result.containsKey('safety_warning'), isTrue);
    });

    test('devrait mentionner les photos dans problem_summary si photoCount > 0', () {
      final result = LocalAiService.analyze('Robinet cassé', photoCount: 3);
      expect(result['problem_summary'], contains('photo'));
    });

    test('devrait ne pas mentionner les photos si photoCount = 0', () {
      final result = LocalAiService.analyze('Robinet cassé', photoCount: 0);
      expect(result['problem_summary'], isNot(contains('photo')));
    });

    test('devrait avoir une urgency valide (low, normal, urgent)', () {
      final result = LocalAiService.analyze('Petite fuite sous le robinet');
      expect(['low', 'normal', 'urgent'], contains(result['urgency']));
    });
  });

  group('LocalAiService.analyze - Détection d\'urgence', () {
    test('devrait détecter urgence élevée avec mots-clés danger', () {
      final result = LocalAiService.analyze('Urgence : il y a une fuite de gaz chez moi !');
      expect(result['urgency'], equals('urgent'));
    });

    test('devrait retourner normal pour un problème standard', () {
      final result = LocalAiService.analyze('Le robinet de la salle de bain goutte un peu');
      expect(result['urgency'], equals('normal'));
    });
  });
}
