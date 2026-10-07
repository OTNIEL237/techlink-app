// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : zego_call_service.dart
// Rôle          : Service de gestion des appels audio/vidéo temps réel (ZegoCloud + Supabase Realtime).
// Module        : Data / Services
// Dépendances   : flutter, go_router, supabase_flutter, app_colors.dart
// Sécurité/RLS  : Écoute et met à jour les sessions d'appel sur la table Supabase 'calls'.
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

/// Service singleton orchestrant la signalisation d'appels voix et vidéo en temps réel.
///
/// Fonctionne en arrière-plan en observant les mutations de la table `calls` dans Supabase :
/// - Détecte les appels entrants (`ringing`) et affiche automatiquement l'écran d'appel entrant.
/// - Lance des appels sortants (`audio` ou `video`) avec détection d'absence de réponse (timeout 40s).
/// - Synchronise les statuts (`ringing`, `accepted`, `declined`, `ended`, `missed`) entre interlocuteurs.
class ZegoCallService {
  /// Instance unique du singleton.
  static final ZegoCallService _instance = ZegoCallService._internal();

  /// Constructeur usine renvoyant l'instance partagée.
  factory ZegoCallService() => _instance;

  /// Constructeur interne privé.
  ZegoCallService._internal();

  /// Clé globale du navigateur permettant d'afficher l'interface d'appel sans BuildContext local.
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Canal Supabase Realtime pour l'écoute des appels entrants.
  RealtimeChannel? _callsChannel;

  /// Souscription au flux d'authentification pour attacher/détacher l'écouteur.
  StreamSubscription<AuthState>? _authSubscription;

  /// Identifiant de la ligne d'appel en cours dans la table `calls`.
  String? _currentCallRowId;

  /// Indicateur d'appel en cours actif.
  bool _isCallActive = false;

  /// Contrôleur de flux notifiant l'écran audio/vidéo des transitions d'état.
  final _callStatusController = StreamController<String>.broadcast();

  /// Flux public des statuts d'appel ('ringing', 'accepted', 'declined', 'ended', 'missed').
  Stream<String> get callStatusStream => _callStatusController.stream;

  /// Initialise le service d'écoute des appels avec la clé de navigation globale.
  ///
  /// [navigatorKey] Clé globale de navigation de l'application.
  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    
    // Écouter les changements d'authentification
    _authSubscription?.cancel();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _subscribeToCalls(session.user.id);
      } else {
        _unsubscribeFromCalls();
      }
    });

    // Si déjà connecté
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _subscribeToCalls(currentUser.id);
    }
  }

  /// Libère les ressources du service et ferme les flux d'événements.
  void dispose() {
    _authSubscription?.cancel();
    _unsubscribeFromCalls();
    _callStatusController.close();
  }

  /// Établit la souscription temps réel pour recevoir les notifications d'appels entrants.
  ///
  /// [userId] Identifiant de l'utilisateur destinataire.
  void _subscribeToCalls(String userId) {
    _unsubscribeFromCalls();

    debugPrint('[ZegoCallService] Écoute des appels pour l\'utilisateur : $userId');

    _callsChannel = Supabase.instance.client
        .channel('calls-listener-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) async {
            final newRecord = payload.newRecord;
            final status = newRecord['status'] as String?;
            
            debugPrint('[ZegoCallService] INSERT reçu: status=$status');

            if (status == 'ringing') {
              final callerId = newRecord['caller_id'] as String;
              final callId = newRecord['call_id'] as String;
              final rowId = newRecord['id'] as String;
              final callType = newRecord['call_type'] as String? ?? 'audio';

              // Charger le nom de l'appelant
              String callerName = 'Correspondant';
              try {
                final user = await Supabase.instance.client
                    .from('users')
                    .select('name')
                    .eq('id', callerId)
                    .single();
                callerName = user['name'] as String? ?? 'Correspondant';
              } catch (_) {}

              _currentCallRowId = rowId;
              _isCallActive = true;

              debugPrint('[ZegoCallService] Appel entrant de $callerName (Type: $callType), navigation vers /call/incoming');

              // Rediriger vers l'écran d'appel entrant
              _navigatorKey?.currentState?.pushNamed(
                '/call/incoming',
                arguments: {
                  'call_row_id': rowId,
                  'call_id': callId,
                  'other_user_name': callerName,
                  'other_user_id': callerId,
                  'call_type': callType,
                },
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final rowId = newRecord['id'] as String?;
            final status = newRecord['status'] as String?;

            debugPrint('[ZegoCallService] UPDATE reçu: rowId=$rowId, status=$status, currentCallRowId=$_currentCallRowId');

            if (rowId == _currentCallRowId && _isCallActive) {
              if (status == 'declined' || status == 'ended' || status == 'missed') {
                _isCallActive = false;
                _currentCallRowId = null;
                // Fermer l'écran d'appel entrant
                _navigatorKey?.currentState?.popUntil((route) => route.settings.name != '/call/incoming');
              }
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ [ZegoCallService] Écoute des appels en temps réel active.');
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('⚠️ [ZegoCallService] Réseau temporairement inaccessible (reconnexion auto en arrière-plan...)');
          }
        });
  }

  /// Désabonne le canal d'appels et réinitialise les états d'appel actif.
  void _unsubscribeFromCalls() {
    _callsChannel?.unsubscribe();
    _callsChannel = null;
    _currentCallRowId = null;
    _isCallActive = false;
  }

  /// Initie un appel sortant (audio ou vidéo) vers un correspondant.
  ///
  /// Effectue les vérifications préalables (auto-appel interdit, compte destinataire existant et non suspendu),
  /// insère l'enregistrement dans la table `calls` avec statut `ringing`, puis navigue vers l'écran d'appel.
  ///
  /// [context] Contexte d'interface pour l'affichage des notifications et navigation.
  /// [receiverId] Identifiant unique du destinataire.
  /// [receiverName] Nom affiché du correspondant.
  /// [callType] Modalité d'appel ('audio' ou 'video').
  Future<void> startCall(BuildContext context, {
    required String receiverId,
    required String receiverName,
    String callType = 'audio',
  }) async {
    final callerId = Supabase.instance.client.auth.currentUser?.id;
    if (callerId == null) return;

    if (callerId == receiverId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Vous ne pouvez pas vous appeler vous-même.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Phase 15 : Sécurité
    try {
      final receiverRes = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', receiverId)
          .maybeSingle();

      if (receiverRes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Ce correspondant n\'existe plus.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Vérifier si le compte est suspendu
      if (receiverRes['is_suspended'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Ce correspondant est temporairement suspendu.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    } catch (_) {}

    final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';

    // Créer la ligne calls
    try {
      final callData = await Supabase.instance.client.from('calls').insert({
        'caller_id': callerId,
        'receiver_id': receiverId,
        'call_id': callId,
        'status': 'ringing',
        'call_type': callType,
      }).select().single();

      final rowId = callData['id'] as String;
      _currentCallRowId = rowId;
      _isCallActive = true;

      final route = callType == 'video' ? '/call/video' : '/call/audio';

      // Naviguer vers l'écran d'appel sortant
      context.push(route, extra: {
          'call_row_id': rowId,
          'call_id': callId,
          'other_user_name': receiverName,
          'is_caller': true,
        },);

      // Écouter le statut pour savoir s'il accepte/refuse/raccroche
      _listenToOutgoingCallStatus(rowId, callId, receiverName, route);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Impossible de démarrer l\'appel : $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Écoute les changements d'état d'un appel sortant (acceptation, refus, raccrochage ou absence de réponse).
  void _listenToOutgoingCallStatus(
    String rowId,
    String callId,
    String receiverName,
    String route,
  ) {
    RealtimeChannel? statusChannel;
    
    // Timeout après 40s
    final timer = Timer(const Duration(seconds: 40), () async {
      statusChannel?.unsubscribe();
      try {
        await Supabase.instance.client
            .from('calls')
            .update({'status': 'missed'})
            .eq('id', rowId);
      } catch (_) {}
      
      if (_currentCallRowId == rowId && _isCallActive) {
        _isCallActive = false;
        _currentCallRowId = null;
        _callStatusController.add('missed');
        _navigatorKey?.currentState?.popUntil((r) => r.settings.name != route);
        _showCallEndedSnackBar('Pas de réponse');
      }
    });

    statusChannel = Supabase.instance.client
        .channel('outgoing-status-$rowId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: rowId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            debugPrint('[ZegoCallService] Outgoing call status update: $status pour call $rowId');
            
            // Notifier l'AudioCallScreen via le stream
            if (status != null) {
              _callStatusController.add(status);
            }

            if (status == 'accepted') {
              timer.cancel();
              statusChannel?.unsubscribe();
              debugPrint('[ZegoCallService] Appel accepté, transition vers ZegoUIKit');
            } else if (status == 'declined') {
              timer.cancel();
              statusChannel?.unsubscribe();
              _isCallActive = false;
              _currentCallRowId = null;
              _navigatorKey?.currentState?.popUntil((r) => r.settings.name != route);
              _showCallEndedSnackBar('Appel refusé');
            } else if (status == 'ended' || status == 'missed') {
              timer.cancel();
              statusChannel?.unsubscribe();
              _isCallActive = false;
              _currentCallRowId = null;
              _navigatorKey?.currentState?.popUntil((r) => r.settings.name != route);
              _showCallEndedSnackBar('Appel terminé');
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ [ZegoCallService] Canal d\'appel sortant connecté.');
          }
        });
  }

  /// Présente un message éphémère informant l'utilisateur de la fin d'un appel.
  void _showCallEndedSnackBar(String message) {
    final context = _navigatorKey?.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📞 $message'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Accepte un appel entrant en passant son statut à 'accepted' dans Supabase.
  ///
  /// [rowId] Identifiant unique de la session d'appel.
  Future<void> acceptCall(String rowId) async {
    try {
      await Supabase.instance.client
          .from('calls')
          .update({'status': 'accepted'})
          .eq('id', rowId);
    } catch (e) {
      debugPrint('ZegoCallService: error accepting call: $e');
    }
  }

  /// Décline un appel entrant en passant son statut à 'declined' dans Supabase.
  ///
  /// [rowId] Identifiant unique de la session d'appel.
  Future<void> declineCall(String rowId) async {
    try {
      await Supabase.instance.client
          .from('calls')
          .update({'status': 'declined'})
          .eq('id', rowId);
      _isCallActive = false;
      _currentCallRowId = null;
    } catch (e) {
      debugPrint('ZegoCallService: error declining call: $e');
    }
  }

  /// Clôture définitivement un appel en cours en passant son statut à 'ended'.
  ///
  /// [rowId] Identifiant unique de la session d'appel.
  Future<void> endCall(String rowId) async {
    try {
      await Supabase.instance.client
          .from('calls')
          .update({'status': 'ended'})
          .eq('id', rowId);
      _isCallActive = false;
      _currentCallRowId = null;
    } catch (e) {
      debugPrint('ZegoCallService: error ending call: $e');
    }
  }
}
