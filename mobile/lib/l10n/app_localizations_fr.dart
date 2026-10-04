// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'TechLink';

  @override
  String get hello => 'Bonjour';

  @override
  String get searchHint => 'Que recherchez-vous aujourd\'hui ?';

  @override
  String get categoriesTitle => 'Catégories';

  @override
  String get popularServicesTitle => 'Services Populaires';

  @override
  String get missionStatus => 'Statut de la mission';

  @override
  String get findExpert => 'Trouvez le meilleur expert';

  @override
  String get mapDescription =>
      'Visualisez les techniciens disponibles autour de vous sur la carte.';

  @override
  String get openMap => 'Ouvrir la carte';

  @override
  String get newQuoteAlert =>
      '📋 Nouveau devis reçu ! Consultez et acceptez ci-dessous.';

  @override
  String get yourTechnician => 'Votre technicien';

  @override
  String get yourProblem => 'Votre problème';

  @override
  String get reportProblem => 'Signaler un problème';

  @override
  String get quoteAccepted => 'Devis accepté ✓';

  @override
  String get quoteReceived => '📋 Devis reçu — Votre avis';

  @override
  String get totalToPay => 'Total à payer';

  @override
  String get reject => 'Refuser';

  @override
  String get acceptQuote => 'Accepter le devis';

  @override
  String get payNow => '💳 Payer maintenant (MTN / Orange)';

  @override
  String rateTechnician(String name) {
    return 'Évaluez $name';
  }

  @override
  String get howWasIt => 'Comment s\'est passée l\'intervention ?';

  @override
  String get leaveComment => 'Laissez un commentaire (facultatif)...';

  @override
  String get sendReview => 'Envoyer l\'avis';
}
