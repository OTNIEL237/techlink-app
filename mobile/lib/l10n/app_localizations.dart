import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'TechLink'**
  String get appTitle;

  /// No description provided for @hello.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get hello;

  /// No description provided for @searchHint.
  ///
  /// In fr, this message translates to:
  /// **'Que recherchez-vous aujourd\'hui ?'**
  String get searchHint;

  /// No description provided for @categoriesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get categoriesTitle;

  /// No description provided for @popularServicesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Services Populaires'**
  String get popularServicesTitle;

  /// No description provided for @missionStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut de la mission'**
  String get missionStatus;

  /// No description provided for @findExpert.
  ///
  /// In fr, this message translates to:
  /// **'Trouvez le meilleur expert'**
  String get findExpert;

  /// No description provided for @mapDescription.
  ///
  /// In fr, this message translates to:
  /// **'Visualisez les techniciens disponibles autour de vous sur la carte.'**
  String get mapDescription;

  /// No description provided for @openMap.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir la carte'**
  String get openMap;

  /// No description provided for @newQuoteAlert.
  ///
  /// In fr, this message translates to:
  /// **'📋 Nouveau devis reçu ! Consultez et acceptez ci-dessous.'**
  String get newQuoteAlert;

  /// No description provided for @yourTechnician.
  ///
  /// In fr, this message translates to:
  /// **'Votre technicien'**
  String get yourTechnician;

  /// No description provided for @yourProblem.
  ///
  /// In fr, this message translates to:
  /// **'Votre problème'**
  String get yourProblem;

  /// No description provided for @reportProblem.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un problème'**
  String get reportProblem;

  /// No description provided for @quoteAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Devis accepté ✓'**
  String get quoteAccepted;

  /// No description provided for @quoteReceived.
  ///
  /// In fr, this message translates to:
  /// **'📋 Devis reçu — Votre avis'**
  String get quoteReceived;

  /// No description provided for @totalToPay.
  ///
  /// In fr, this message translates to:
  /// **'Total à payer'**
  String get totalToPay;

  /// No description provided for @reject.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get reject;

  /// No description provided for @acceptQuote.
  ///
  /// In fr, this message translates to:
  /// **'Accepter le devis'**
  String get acceptQuote;

  /// No description provided for @payNow.
  ///
  /// In fr, this message translates to:
  /// **'💳 Payer maintenant (MTN / Orange)'**
  String get payNow;

  /// No description provided for @rateTechnician.
  ///
  /// In fr, this message translates to:
  /// **'Évaluez {name}'**
  String rateTechnician(String name);

  /// No description provided for @howWasIt.
  ///
  /// In fr, this message translates to:
  /// **'Comment s\'est passée l\'intervention ?'**
  String get howWasIt;

  /// No description provided for @leaveComment.
  ///
  /// In fr, this message translates to:
  /// **'Laissez un commentaire (facultatif)...'**
  String get leaveComment;

  /// No description provided for @sendReview.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer l\'avis'**
  String get sendReview;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
