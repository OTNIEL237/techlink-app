// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : audio_call_screen.dart
// Rôle          : Écran d'appel audio pair-à-pair avec sonnerie et intégration ZegoCloud UIKit.
// Module        : Presentation / Shared
// Dépendances   : flutter, go_router, supabase_flutter, zego_uikit_prebuilt_call, zego_config.dart
// Sécurité/RLS  : Synchronise l'état de l'appel via Supabase Realtime et libère les canaux WebRTC.
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/zego_config.dart';
import '../../data/services/zego_call_service.dart';

/// Écran complet gérant l'expérience d'appel voix (one-on-one audio call).
///
/// Si l'utilisateur est l'appelant ([_isCaller]), affiche d'abord l'écran d'attente
/// avec pulsation et sonnerie sortante. Dès que l'interlocuteur répond (`accepted`),
/// initialise automatiquement le flux audio haute définition [ZegoUIKitPrebuiltCall].
class AudioCallScreen extends StatefulWidget {
  /// Constructeur constant pour [AudioCallScreen].
  const AudioCallScreen({super.key});

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

/// État associé à l'écran [AudioCallScreen] gérant la synchronisation temps réel.
class _AudioCallScreenState extends State<AudioCallScreen> {
  /// Identifiant unique de la ligne dans la table `calls`.
  late String _callRowId;

  /// Identifiant de la salle d'appel ZegoCloud.
  late String _callId;

  /// Nom de l'interlocuteur affiché à l'écran.
  late String _otherUserName;

  /// Indique si l'utilisateur local est l'émetteur de l'appel.
  late bool _isCaller;

  /// Statut de l'appel ('ringing', 'accepted', 'declined', 'ended', 'missed').
  String _status = 'ringing';

  /// Nom de l'utilisateur connecté affiché dans le SDK Zego.
  String _currentUserName = 'Utilisateur';

  /// Empêche la réinitialisation multiple des arguments de route.
  bool _isInitialized = false;

  /// Souscription au flux d'état émis par [ZegoCallService].
  StreamSubscription<String>? _statusSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      Map<String, dynamic>? args;
      try {
        args = GoRouterState.of(context).extra as Map<String, dynamic>?;
      } catch (_) {}
      args ??= ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
        _callRowId = args['call_row_id'] as String? ?? '';
        _callId = args['call_id'] as String? ?? '';
        _otherUserName = args['other_user_name'] as String? ?? 'Inconnu';
        _isCaller = args['is_caller'] as bool? ?? false;
      } else {
        _callRowId = '';
        _callId = '';
        _otherUserName = 'Inconnu';
        _isCaller = false;
      }

      _loadCurrentUserName();
      if (_isCaller) {
        _status = 'ringing';
        _subscribeToCallStatus();
      } else {
        _status = 'accepted';
      }
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUserName() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('name')
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() {
          _currentUserName = data['name'] as String? ?? 'Utilisateur';
        });
      }
    } catch (_) {}
  }

  void _subscribeToCallStatus() {
    // Écouter le stream du ZegoCallService au lieu d'un channel Supabase séparé
    // Cela évite la race condition entre deux channels parallèles
    _statusSubscription = ZegoCallService().callStatusStream.listen((newStatus) {
      debugPrint('[AudioCallScreen] Status reçu via stream: $newStatus pour call $_callRowId');
      if (mounted) {
        setState(() {
          _status = newStatus;
        });
        if (newStatus == 'declined' || newStatus == 'ended' || newStatus == 'missed') {
          context.pop();
        }
      }
    });

    // Fallback : vérifier le statut actuel dans la DB après 3s
    // au cas où le realtime a raté l'évènement
    Future.delayed(const Duration(seconds: 3), () {
      _checkCallStatusFallback();
    });
  }

  Future<void> _checkCallStatusFallback() async {
    if (!mounted || _status != 'ringing') return;
    try {
      final call = await Supabase.instance.client
          .from('calls')
          .select('status')
          .eq('id', _callRowId)
          .maybeSingle();
      if (call != null && mounted) {
        final dbStatus = call['status'] as String?;
        debugPrint('[AudioCallScreen] Fallback check: DB status=$dbStatus, current=$_status');
        if (dbStatus != null && dbStatus != _status) {
          setState(() {
            _status = dbStatus;
          });
          if (dbStatus == 'declined' || dbStatus == 'ended' || dbStatus == 'missed') {
            context.pop();
          }
        }
      }
    } catch (e) {
      debugPrint('[AudioCallScreen] Fallback check error: $e');
    }

    // Continuer à vérifier toutes les 5s tant que l'appel sonne
    if (mounted && _status == 'ringing') {
      Future.delayed(const Duration(seconds: 5), () {
        _checkCallStatusFallback();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCaller && _status == 'ringing') {
      return _buildOutgoingRingingScreen();
    }

    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'user';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await ZegoCallService().endCall(_callRowId);
          if (mounted) {
            context.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E293B),
        body: SafeArea(
          child: ZegoUIKitPrebuiltCall(
            appID: ZegoConfig.appId,
            appSign: ZegoConfig.appSign,
            userID: userId,
            userName: _currentUserName,
            callID: _callId,
            config: ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
            events: ZegoUIKitPrebuiltCallEvents(
              onCallEnd: (event, defaultAction) {
                ZegoCallService().endCall(_callRowId);
                defaultAction.call();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutgoingRingingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                        _otherUserName.isNotEmpty ? _otherUserName[0].toUpperCase() : '?',
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
                    _otherUserName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Appel en cours...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () async {
                  await ZegoCallService().endCall(_callRowId);
                  if (mounted) {
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
                      'Annuler',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
