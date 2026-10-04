// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TechLink';

  @override
  String get hello => 'Hello';

  @override
  String get searchHint => 'What are you looking for today?';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get popularServicesTitle => 'Popular Services';

  @override
  String get missionStatus => 'Mission Status';

  @override
  String get findExpert => 'Find the best expert';

  @override
  String get mapDescription =>
      'View available technicians around you on the map.';

  @override
  String get openMap => 'Open Map';

  @override
  String get newQuoteAlert => '📋 New quote received! Review and accept below.';

  @override
  String get yourTechnician => 'Your technician';

  @override
  String get yourProblem => 'Your problem';

  @override
  String get reportProblem => 'Report a problem';

  @override
  String get quoteAccepted => 'Quote accepted ✓';

  @override
  String get quoteReceived => '📋 Quote received — Your review';

  @override
  String get totalToPay => 'Total to pay';

  @override
  String get reject => 'Reject';

  @override
  String get acceptQuote => 'Accept Quote';

  @override
  String get payNow => '💳 Pay Now (MTN / Orange)';

  @override
  String rateTechnician(String name) {
    return 'Rate $name';
  }

  @override
  String get howWasIt => 'How was the service?';

  @override
  String get leaveComment => 'Leave a comment (optional)...';

  @override
  String get sendReview => 'Submit Review';
}
