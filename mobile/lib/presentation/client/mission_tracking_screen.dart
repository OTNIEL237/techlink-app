// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : mission_tracking_screen.dart
// Rôle          : Suivi en temps réel de l'avancement d'une intervention client
// Module        : Présentation / Client / Suivi de Mission
// Dépendances   : Supabase Flutter, GoRouter, ZegoCallService, UrlLauncher
// Sécurité/RLS  : Accès réservé au client propriétaire de la mission en cours
// =============================================================================

import 'package:flutter/material.dart';
import 'package:techlink/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/zego_call_service.dart';
import '../shared/responsive_web_wrapper.dart';

import 'widgets/tracking_status_card.dart';
import 'widgets/tracking_technician_card.dart';
import 'widgets/tracking_quote_card.dart';
import 'widgets/tracking_info_card.dart';
import 'widgets/tracking_review_card.dart';

/// [MissionTrackingScreen] est l'écran central de suivi d'intervention pour le client :
/// progression des étapes (recherche, artisan en route, diagnostic, devis, paiement),
/// appels audio/vidéo Zego, validation/rejet de devis, notation et signalement de litiges.
class MissionTrackingScreen extends StatefulWidget {
  /// Données de la mission courante (identifiant, statut, description, coordonnées).
  final Map<String, dynamic> mission;

  const MissionTrackingScreen({super.key, required this.mission});

  @override
  State<MissionTrackingScreen> createState() => _MissionTrackingScreenState();
}

/// État interne orchestrant le polling de rafraîchissement périodique (10s),
/// la gestion du devis et les interactions multimédia avec l'artisan.
class _MissionTrackingScreenState extends State<MissionTrackingScreen> {
  late Map<String, dynamic> _mission;
  Map<String, dynamic>? _technicianData;
  Map<String, dynamic>? _quoteData;
  bool _isLoading = true;
  bool _isAcceptingQuote = false;
  bool _hasRated = false;

  @override
  void initState() {
    super.initState();
    _mission = widget.mission;
    _loadDetails();
    // Rafraîchir toutes les 10 secondes
    _startPolling();
  }

  /// Lance une boucle de rafraîchissement d'état toutes les 10 secondes tant que l'écran est affiché.
  void _startPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 10));
      if (!mounted) return false;
      await _loadDetails();
      return mounted;
    });
  }

  /// Récupère l'état à jour de la mission, du profil technicien, du devis et de l'évaluation éventuelle.
  Future<void> _loadDetails() async {
    try {
      // Recharger la mission
      final mission = await Supabase.instance.client
          .from('missions')
          .select('*, categories(name, slug)')
          .eq('id', _mission['id'])
          .single();

      // Charger le technicien
      Map<String, dynamic>? techData;
      final techId = mission['technician_id'];
      if (techId != null) {
        try {
          final techUser = await Supabase.instance.client
              .from('users')
              .select('id, name, phone')
              .eq('id', techId)
              .single();

          final techProfile = await Supabase.instance.client
              .from('technicians')
              .select('specialties, rating_average, total_missions')
              .eq('user_id', techId)
              .maybeSingle();

          techData = {...techUser, ...?techProfile};
        } catch (_) {}
      }

      // Charger le devis s'il existe (sans condition de statut)
      Map<String, dynamic>? quote;
      try {
        quote = await Supabase.instance.client
            .from('quotes')
            .select('*')
            .eq('mission_id', _mission['id'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      } catch (_) {}

      // Vérifier si un avis a déjà été laissé
      bool hasRated = false;
      try {
        final rating = await Supabase.instance.client
            .from('ratings')
            .select('id')
            .eq('mission_id', _mission['id'])
            .maybeSingle();
        hasRated = rating != null;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _mission = mission;
          _technicianData = techData;
          _quoteData = quote;
          _hasRated = hasRated;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Démarre un appel audio ou vidéo ZegoCloud avec l'artisan en charge de la mission.
  void _callTechnician(String callType) {
    final techId = _technicianData?['id'] as String?;
    final name = _technicianData?['name'] as String? ?? 'Technicien';
    if (techId == null) return;
    ZegoCallService().startCall(
      context,
      receiverId: techId,
      receiverName: name,
      callType: callType,
    );
  }

  /// Valide et accepte le devis proposé par l'artisan, passant la mission au statut 'quote_accepted'.
  Future<void> _acceptQuote() async {
    if (_quoteData == null) return;
    setState(() => _isAcceptingQuote = true);
    try {
      await Supabase.instance.client
          .from('quotes')
          .update({'status': 'accepted'})
          .eq('id', _quoteData!['id']);

      await Supabase.instance.client
          .from('missions')
          .update({'status': 'quote_accepted'})
          .eq('id', _mission['id']);

      await _loadDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Devis accepté ! Le technicien va procéder.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isAcceptingQuote = false);
    }
  }

  /// Refuse le devis proposé et replace la mission en cours pour ajustement éventuel.
  Future<void> _rejectQuote() async {
    if (_quoteData == null) return;
    try {
      await Supabase.instance.client
          .from('quotes')
          .update({'status': 'rejected'})
          .eq('id', _quoteData!['id']);

      await Supabase.instance.client
          .from('missions')
          .update({'status': 'in_progress'})
          .eq('id', _mission['id']);

      await _loadDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Devis refusé. Le technicien sera informé.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (_) {}
  }

  /// Ouvre le formulaire de réclamation pour déclarer un litige (technicien absent, surfacturation, etc.).
  void _showDisputeDialog() {
    final descriptionController = TextEditingController();
    String selectedReason = 'Travail mal fait';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Signaler un problème', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sélectionnez le motif de votre réclamation :'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Le technicien est absent', child: Text('Le technicien est absent')),
                    DropdownMenuItem(value: 'Travail mal fait', child: Text('Travail mal fait')),
                    DropdownMenuItem(value: 'Comportement inapproprié', child: Text('Comportement inapproprié')),
                    DropdownMenuItem(value: 'Surfacturation', child: Text('Surfacturation')),
                    DropdownMenuItem(value: 'Autre', child: Text('Autre')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedReason = val);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Décrivez le problème :'),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Détails du problème...'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                if (descriptionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez décrire le problème')));
                  return;
                }
                setDialogState(() => isSubmitting = true);
                try {
                  final clientId = Supabase.instance.client.auth.currentUser!.id;
                  await Supabase.instance.client.from('disputes').insert({
                    'mission_id': _mission['id'],
                    'reporter_id': clientId,
                    'reason': selectedReason,
                    'description': descriptionController.text.trim(),
                  });
                  // Update mission status to in_dispute
                  await Supabase.instance.client.from('missions').update({
                    'status': 'in_dispute'
                  }).eq('id', _mission['id']);
                  
                  if (context.mounted) {
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signalement envoyé avec succès. Mission gelée.'), backgroundColor: AppColors.success)
                    );
                    _loadDetails();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error));
                  setDialogState(() => isSubmitting = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _mission['status'] as String? ?? '';
    final category = _mission['categories']?['name'] as String? ?? 'Mission';
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: Text(category, style: TextStyle(color: tc.textPrimary)),
        backgroundColor: tc.background,
        iconTheme: IconThemeData(color: tc.textPrimary),
        actions: [
          // Bouton chat
          if (_technicianData != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => context.push('/chat', extra: {
                  'mission_id': _mission['id'],
                  'current_user_id': Supabase.instance.client
                      .auth.currentUser!.id,
                  'current_user_role': 'client',
                  'other_user_name':
                      _technicianData!['name'] as String? ?? 'Technicien',
                  'other_user_phone':
                      _technicianData!['phone'] as String? ?? '',
                },),
              tooltip: 'Chat',
            ),
          // Bouton appel audio
          if (_technicianData?['phone'] != null)
            IconButton(
              icon: const Icon(Icons.phone_outlined),
              onPressed: () => _callTechnician('audio'),
              tooltip: 'Appel Audio',
            ),
          // Bouton appel vidéo
          if (_technicianData?['phone'] != null)
            IconButton(
              icon: const Icon(Icons.videocam_outlined),
              onPressed: () => _callTechnician('video'),
              tooltip: 'Appel Vidéo',
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: tc.textPrimary),
            onPressed: _loadDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDetails,
              child: ResponsiveWebWrapper(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================== STATUT ==================
                    TrackingStatusCard(status: status),
                    const SizedBox(height: 20),

                    // ================== RECHERCHER UN TECHNICIEN ==================
                    if (status == 'searching') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF9D63F3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.radar, color: Colors.white, size: 48),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n?.findExpert ?? 'Trouvez le meilleur expert',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n?.mapDescription ?? 'Visualisez les techniciens disponibles autour de vous sur la carte.',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  context.push('/client/map', extra: {
                                      'mission_id': _mission['id'],
                                      'ai_result': {
                                        'category': _mission['categories']?['name'] ?? 'Mission',
                                        'category_slug': _mission['categories']?['slug'] ?? '',
                                      }
                                    },);
                                },
                                icon: const Icon(Icons.map, color: AppColors.primary),
                                label: Text(l10n?.openMap ?? 'Ouvrir la carte', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ALERTE NOUVEAU DEVIS
                    if (_quoteData != null && status == 'quote_sent') ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.warning.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active,
                                color: AppColors.warning),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n?.newQuoteAlert ?? '📋 Nouveau devis reçu ! Consultez et acceptez ci-dessous.',
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ================== TECHNICIEN ==================
                    if (_technicianData != null) ...[
                      TrackingTechnicianCard(
                        technician: _technicianData!,
                        onCall: () => _callTechnician('audio'),
                        onVideoCall: () => _callTechnician('video'),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ================== ÉVALUATION (SI TERMINÉE) ==================
                    if ((status == 'completed' || status == 'paid') && _technicianData != null) ...[
                      if (!_hasRated)
                        TrackingReviewCard(
                          missionId: _mission['id'],
                          technicianId: _technicianData!['id'],
                          technicianName: _technicianData!['name'],
                          onRated: () {
                            setState(() => _hasRated = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Merci pour votre avis ! ⭐'), backgroundColor: AppColors.success),
                            );
                            _loadDetails();
                          },
                        )
                      else
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.success.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star, color: Colors.amber),
                              SizedBox(width: 8),
                              Text('Vous avez évalué ce technicien.',
                                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],

                    // ================== PROBLÈME ==================
                    TrackingInfoCard(
                      title: l10n?.yourProblem ?? 'Votre problème',
                      icon: Icons.report_problem_outlined,
                      child: Text(
                        _mission['problem_description']?.toString() ?? '',
                        style: TextStyle(fontSize: 14, height: 1.5, color: tc.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ================== DEVIS ==================
                    if (_quoteData != null) ...[
                      TrackingQuoteCard(
                        mission: _mission,
                        quote: _quoteData!,
                        status: status,
                        onAccept: _acceptQuote,
                        onReject: _rejectQuote,
                        onPay: () => context.push('/client/payment', extra: {
                            'mission': _mission,
                            'quote': _quoteData!,
                          },),
                        isLoading: _isAcceptingQuote,
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ================== BOUTON LITIGE ==================
                    if (status != 'cancelled') ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showDisputeDialog,
                          icon: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                          label: Text(l10n?.reportProblem ?? 'Signaler un problème', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            backgroundColor: AppColors.error.withOpacity(0.05),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
