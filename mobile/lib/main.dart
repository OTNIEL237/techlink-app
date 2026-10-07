// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : main.dart
// Rôle          : Point d'entrée principal de l'application mobile TechLink.
//                 Initialise les liaisons Flutter, intercepte les erreurs
//                 globales (UI et asynchrones), charge l'environnement (.env),
//                 configure Supabase et monte le ProviderScope Riverpod.
// Module        : Core / Démarrage
// Dépendances   : Supabase, Riverpod, flutter_dotenv, ZegoCloud, GoRouter
// Sécurité/RLS  : Accès initial public, délègue le contrôle d'accès à AppRouter
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/routing/app_router.dart';
import 'presentation/shared/splash_screen.dart';
import 'presentation/auth/phone_input_screen.dart';
import 'data/services/zego_call_service.dart';
import 'data/services/notification_service.dart';

import 'core/constants/app_colors.dart';

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'core/utils/logger_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:techlink/l10n/app_localizations.dart';

/// Point d'entrée principal de l'application TechLink.
///
/// Exécute l'application dans une zone sécurisée via [runZonedGuarded] afin de
/// capturer toutes les exceptions non interceptées et garantir une haute disponibilité.
void main() {
  runZonedGuarded(() async {
    // ── 1. Initialisation des liaisons du moteur Flutter ──
    WidgetsFlutterBinding.ensureInitialized();

    // Capture les erreurs Flutter (UI, Layout)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      LoggerService.logError(
        'Erreur Flutter (UI): ${details.exception}',
        error: details.exception,
        stackTrace: details.stack,
        tag: 'UI_ERROR',
      );
    };

    // Capture les erreurs asynchrones non gérées (Platform, Isolate)
    PlatformDispatcher.instance.onError = (error, stack) {
      LoggerService.logError(
        'Erreur Asynchrone non gérée: $error',
        error: error,
        stackTrace: stack,
        tag: 'ASYNC_ERROR',
      );
      return true;
    };

    // Chargement des variables d'environnement
    await dotenv.load(fileName: ".env");

    // Initialisation de la connexion à Supabase (Base de données et Auth)
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? 'https://vaagiltvlgomdmqevayv.supabase.co',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? 'sb_publishable_dqMakfvmzbsK8RV6o6GozQ_DqH94lPS',
    );

    // ProviderScope enveloppe l'app pour permettre l'utilisation de Riverpod (gestion d'état)
    runApp(const ProviderScope(child: TechLinkApp()));
  }, (error, stackTrace) {
    LoggerService.logError(
      'Erreur Critique Zone: $error',
      error: error,
      stackTrace: stackTrace,
      tag: 'CRITICAL_ERROR',
    );
  });
}

// navigatorKey n'est plus géré ici, il est géré par AppRouter.rootNavigatorKey
// pour éviter les conflits et permettre à ZegoCloud de se superposer proprement.

/// [TechLinkApp]
///
/// Composant racine de l'application TechLink.
/// Responsabilité : Initialise les thèmes (Light / Dark), configure la
/// localisation multilingue (FR/EN) et branche le routeur [AppRouter.router].
class TechLinkApp extends ConsumerStatefulWidget {
  const TechLinkApp({super.key});

  @override
  ConsumerState<TechLinkApp> createState() => _TechLinkAppState();
}

/// [_TechLinkAppState]
///
/// État du widget racine [TechLinkApp].
/// Gère le cycle de vie des services globaux (appels ZegoCloud et notifications en temps réel).
class _TechLinkAppState extends ConsumerState<TechLinkApp> {
  /// Initialise les écouteurs d'appels entrants et les notifications push.
  @override
  void initState() {
    super.initState();
    // Initialisation du service d'appels ZegoCloud avec le rootNavigatorKey du GoRouter
    ZegoCallService().initialize(rootNavigatorKey);
    // Initialisation du service de notifications et écoute temps réel
    NotificationService().initialize(rootNavigatorKey);
  }

  @override
  void dispose() {
    // Nettoyage des ressources quand l'application se ferme
    ZegoCallService().dispose();
    NotificationService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Écoute les changements de thème (clair/sombre) gérés par Riverpod
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'TechLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: AppRouter.router,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', ''), // French
        Locale('en', ''), // English
      ],
    );
  }
}
