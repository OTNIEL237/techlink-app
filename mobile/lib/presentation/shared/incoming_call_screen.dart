// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : incoming_call_screen.dart
// Rôle          : Écran d'alerte d'appel entrant avec boutons d'acceptation et de refus.
// Module        : Presentation / Shared
// Dépendances   : flutter, go_router, app_colors.dart, zego_call_service.dart
// Sécurité/RLS  : Met à jour le statut de l'appel (accepté / refusé) sur Supabase Realtime.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/zego_call_service.dart';

/// Interface présentée à l'utilisateur lors de la réception d'un appel audio ou vidéo.
///
/// Affiche le nom et l'initiale de l'appelant ainsi que la modalité de communication.
/// Propose deux actions immédiates :
/// - Décliner : clôture l'appel côté Supabase et ferme l'écran.
/// - Répondre : valide l'appel et bascule vers l'interface de communication [AudioCallScreen] ou [VideoCallScreen].
class IncomingCallScreen extends StatelessWidget {
  /// Constructeur constant pour [IncomingCallScreen].
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    Map<String, dynamic>? extraArgs;
    try {
      extraArgs = GoRouterState.of(context).extra as Map<String, dynamic>?;
    } catch (_) {}
    final args = routeArgs ?? extraArgs ?? {};
    final callRowId = args['call_row_id'] as String? ?? '';
    final callId = args['call_id'] as String? ?? '';
    final otherUserName = args['other_user_name'] as String? ?? 'Correspondant';
    final callType = args['call_type'] as String? ?? 'audio';
    
    final isVideo = callType == 'video';

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(height: 40),
            
            // Avatar & Info
            Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  otherUserName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVideo ? 'Appel vidéo entrant...' : 'Appel audio entrant...',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),

            // Boutons d'action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Bouton Refuser
                GestureDetector(
                  onTap: () async {
                    await ZegoCallService().declineCall(callRowId);
                    if (context.mounted) {
                      context.pop();
                    }
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Décliner',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                // Bouton Accepter
                GestureDetector(
                  onTap: () async {
                    await ZegoCallService().acceptCall(callRowId);
                    if (context.mounted) {
                      context.go(isVideo ? '/call/video' : '/call/audio', extra: {
                          'call_row_id': callRowId,
                          'call_id': callId,
                          'other_user_name': otherUserName,
                          'is_caller': false,
                        },);
                    }
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Répondre',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
