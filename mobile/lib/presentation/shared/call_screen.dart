// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : call_screen.dart
// Rôle          : Écran d'appel obsolète conservé pour rétrocompatibilité (redirige vers /call/audio).
// Module        : Presentation / Shared
// Dépendances   : flutter, go_router
// Sécurité/RLS  : Composant déprécié, bascule automatique vers le moteur ZegoUIKit.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Ancien écran d'appel Agora conservé pour éviter toute rupture de lien.
///
/// Redirige immédiatement l'utilisateur vers l'implémentation active [AudioCallScreen]
/// via la route `/call/audio`.
@Deprecated('Utilisez AudioCallScreen à la place')
class CallScreen extends StatelessWidget {
  /// Constructeur constant pour [CallScreen].
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Redirige vers l'écran audio Zego
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go('/call/audio');
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}