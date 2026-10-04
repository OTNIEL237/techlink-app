import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/zego_call_service.dart';
import 'quote_builder_screen.dart';
import 'client_location_map_screen.dart';
import '../shared/responsive_web_wrapper.dart';

// =========================================================================
// ÉCRAN DE DÉTAIL D'UNE DEMANDE DE MISSION
// =========================================================================
// Affiche les détails d'une mission pour le technicien, permet d'accepter, 
// de se mettre en route, de démarrer, d'envoyer un devis, de confirmer 
// le paiement manuel et de finaliser la mission. Gère aussi les litiges.

class MissionRequestScreen extends StatefulWidget {
  final Map<String, dynamic> mission;
  const MissionRequestScreen({super.key, required this.mission});

  @override
  State<MissionRequestScreen> createState() => _MissionRequestScreenState();
}

class _MissionRequestScreenState extends State<MissionRequestScreen> {
  late Map<String, dynamic> _mission;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _mission = widget.mission;
    _startPolling();
  }

  /// Rafraîchit le statut de la mission toutes les 8 secondes
  void _startPolling() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 8));
      if (!mounted) return false;
      await _refreshMission();
      return mounted;
    });
  }

  /// Recharge la mission depuis Supabase pour détecter les changements de statut
  Future<void> _refreshMission() async {
    try {
      final fresh = await Supabase.instance.client
          .from('missions')
          .select('*, users:client_id(id, name, phone), categories(name)')
          .eq('id', _mission['id'])
          .single();
      if (mounted) {
        setState(() => _mission = fresh);
      }
    } catch (_) {}
  }

  Future<void> _confirmManualPaymentReceived() async {
    setState(() => _isUpdating = true);
    try {
      final supabase = Supabase.instance.client;
      final missionId = _mission['id'] as String;

      // 1. Mettre à jour l'enregistrement de paiement en 'success'
      await supabase
          .from('payments')
          .update({'status': 'success'})
          .eq('mission_id', missionId)
          .eq('status', 'pending');

      // 2. Mettre à jour le statut de la mission en 'paid'
      await supabase
          .from('missions')
          .update({'status': 'paid', 'paid_at': DateTime.now().toIso8601String()})
          .eq('id', missionId);

      // 3. Créditer le portefeuille du technicien
      // techUserId = users.id (ID utilisateur auth) — utilisé pour les FK référençant la table users
      // techId = technicians.id (PK table technicians) — utilisé pour mettre à jour la ligne technicians
      final techUserId = supabase.auth.currentUser!.id;
      final techProfile = await supabase
          .from('technicians')
          .select('id, wallet_balance, total_earnings, total_missions')
          .eq('user_id', techUserId)
          .maybeSingle();

      if (techProfile != null) {
        // Trouver le montant du devis
        final quote = await supabase
            .from('quotes')
            .select('subtotal')
            .eq('mission_id', missionId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        final amount = (quote?['subtotal'] as num?)?.toDouble() ?? 0;
        final techId = techProfile['id'] as String; // technicians table PK

        // FK wallet_transactions.technician_id → users.id → utiliser techUserId
        await supabase.from('wallet_transactions').insert({
          'technician_id': techUserId,
          'mission_id': missionId,
          'type': 'payment',
          'amount': amount.toInt(),
          'description': 'Paiement direct reçu pour mission $missionId',
          'reference': 'CONFIRMED_${missionId}_${DateTime.now().millisecondsSinceEpoch}',
        });

        // La mise à jour de la table technicians utilise bien la clé primaire (PK) de technicians
        await supabase.from('technicians').update({
          'wallet_balance': (techProfile['wallet_balance'] as num? ?? 0) + amount,
          'total_earnings': (techProfile['total_earnings'] as num? ?? 0) + amount,
          'total_missions': ((techProfile['total_missions'] as num?)?.toInt() ?? 0) + 1,
        }).eq('id', techId);
      }

      setState(() {
        _mission = {..._mission, 'status': 'paid'};
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Paiement confirmé avec succès !'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: ${e.toString().replaceAll('Exception: ', '')}"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final updates = <String, dynamic>{'status': newStatus};
      if (newStatus == 'technician_enroute') {
        updates['accepted_at'] = DateTime.now().toIso8601String();
      } else if (newStatus == 'in_progress') {
        updates['started_at'] = DateTime.now().toIso8601String();
      }

      await Supabase.instance.client
          .from('missions')
          .update(updates)
          .eq('id', _mission['id']);

      setState(() => _mission = {..._mission, 'status': newStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Statut mis à jour !'),
            backgroundColor: AppColors.success),
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
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _openNavigation() {
    final rawLat = _mission['client_lat'];
    final rawLng = _mission['client_lng'];

    if (rawLat == null || rawLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Localisation du client non disponible.\n'
            'Le client doit autoriser le GPS lors de sa demande.',
          ),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final lat = (rawLat as num).toDouble();
    final lng = (rawLng as num).toDouble();
    final client = _mission['users'] as Map<String, dynamic>?;
    final clientName = client?['name'] as String? ?? 'Client';
    final category =
        (_mission['categories'] as Map<String, dynamic>?)?['name']
            as String? ??
        'Mission';

    // Ouvrir la carte in-app avec la position exacte du client
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientLocationMapScreen(
          clientLat: lat,
          clientLng: lng,
          clientName: clientName,
          missionCategory: category,
        ),
      ),
    );
  }

  void _callClient() {
    final client = _mission['users'] as Map<String, dynamic>?;
    final clientId = _mission['client_id'] as String? ?? '';
    final clientName = client?['name'] as String? ?? 'Client';
    if (clientId.isEmpty) return;
    ZegoCallService().startCall(
      context,
      receiverId: clientId,
      receiverName: clientName,
    );
  }

  void _showDisputeDialog() {
    final descriptionController = TextEditingController();
    String selectedReason = 'Client absent';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Signaler un litige', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sélectionnez le motif :'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Client absent', child: Text('Client absent')),
                    DropdownMenuItem(value: 'Refus de payer', child: Text('Refus de payer')),
                    DropdownMenuItem(value: 'Environnement dangereux', child: Text('Environnement dangereux')),
                    DropdownMenuItem(value: 'Comportement inapproprié', child: Text('Comportement inapproprié')),
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
                  final technicianId = Supabase.instance.client.auth.currentUser!.id;
                  await Supabase.instance.client.from('disputes').insert({
                    'mission_id': _mission['id'],
                    'reporter_id': technicianId,
                    'reason': selectedReason,
                    'description': descriptionController.text.trim(),
                  });
                  // Mettre à jour le statut de la mission en in_dispute
                  await Supabase.instance.client.from('missions').update({
                    'status': 'in_dispute'
                  }).eq('id', _mission['id']);
                  
                  if (context.mounted) {
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signalement envoyé avec succès. Mission gelée.'), backgroundColor: AppColors.success)
                    );
                    _refreshMission();
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
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final status = _mission['status'] as String? ?? 'accepted';
    final client = _mission['users'] as Map<String, dynamic>?;
    final category = _mission['categories'] as Map<String, dynamic>?;
    final description =
        _mission['problem_description'] as String? ?? '';
    final aiSolution = _mission['ai_solution'] as String? ?? '';
    final urgency = _mission['urgency_level'] as String? ?? 'normal';

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        backgroundColor: tc.background,
        title: Text(category?['name'] as String? ?? 'Mission', style: TextStyle(color: tc.textPrimary)),
        iconTheme: IconThemeData(color: tc.textPrimary),
        actions: [
          // Rafraîchir manuellement
          IconButton(
            icon: Icon(Icons.refresh, color: tc.textPrimary),
            onPressed: _refreshMission,
            tooltip: 'Rafraîchir',
          ),
          // Bouton chat
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: tc.textPrimary),
            onPressed: () async {
              final client = _mission['users'] as Map<String, dynamic>?;
              final clientId = _mission['client_id'] as String? ?? '';
              context.push('/chat', extra: {
                  'mission_id': _mission['id'],
                  'current_user_id': Supabase.instance.client
                      .auth.currentUser!.id,
                  'current_user_role': 'technician',
                  'other_user_name':
                      client?['name'] as String? ?? 'Client',
                  'other_user_phone':
                      client?['phone'] as String? ?? '',
                },);
            },
            tooltip: 'Chat',
          ),
          // Appeler le client (déjà présent)
          IconButton(
            icon: Icon(Icons.phone_outlined, color: tc.textPrimary),
            onPressed: _callClient,
            tooltip: 'Appeler le client',
          ),
        ],
      ),
      body: ResponsiveWebWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Statut actuel
            _StatusTimeline(status: status, tc: tc),
            const SizedBox(height: 24),

            // Info client
            _SectionCard(
              title: 'Client',
              icon: Icons.person_outline,
              tc: tc,
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (client?['name'] as String? ?? 'C')[0]
                            .toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client?['name'] as String? ?? 'Client',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: tc.textPrimary)),
                        Text(
                          client?['phone'] as String? ?? '',
                          style: TextStyle(
                            color: tc.textSecondary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _callClient,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone,
                          color: AppColors.success, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Problème
            _SectionCard(
              title: 'Problème signalé',
              icon: Icons.report_problem_outlined,
              tc: tc,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Urgence
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: urgency == 'urgent'
                          ? AppColors.error.withOpacity(0.1)
                          : urgency == 'low'
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      urgency == 'urgent'
                          ? '🔴 Urgent'
                          : urgency == 'low'
                              ? '🟢 Faible'
                              : '🟡 Normal',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(description,
                    style: TextStyle(
                      fontSize: 14, height: 1.5,
                      color: tc.textPrimary)),
                ],
              ),
            ),

            if (aiSolution.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Solution IA proposée',
                icon: Icons.psychology_outlined,
                tc: tc,
                child: Text(aiSolution,
                  style: TextStyle(
                    fontSize: 13, height: 1.6,
                    color: tc.textSecondary)),
              ),
            ],

            const SizedBox(height: 24),

            // BOUTONS D'ACTION selon le statut
            _buildActionButtons(status),

            // BOUTON LITIGE TECHNICIEN
            if (status != 'cancelled') ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showDisputeDialog,
                  icon: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  label: const Text('Signaler un litige', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
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
    ));
  }

  Widget _buildActionButtons(String status) {
    final tc = Theme.of(context).extension<TechLinkColors>() ?? TechLinkColors.light;
    if (_isUpdating) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (status) {
      case 'accepted':
        return Column(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                _updateStatus('technician_enroute');
                _openNavigation();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.technicianColor,
              ),
              icon: const Icon(Icons.directions_car_outlined),
              label: const Text('Je suis en route',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        );

      case 'technician_enroute':
        return Column(
          children: [
            ElevatedButton.icon(
              onPressed: () => _updateStatus('in_progress'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.primary,
              ),
              icon: const Icon(Icons.build_outlined),
              label: const Text('Je suis arrivé — Démarrer',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openNavigation,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Ouvrir la navigation GPS'),
            ),
          ],
        );

      case 'in_progress':
        return Column(
          children: [
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuoteBuilderScreen(mission: _mission),
                ),
              ).then((_) {
                setState(() =>
                    _mission = {..._mission, 'status': 'quote_sent'});
              }),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.success,
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Créer et envoyer le devis',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        );

      case 'quote_sent':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.hourglass_top, color: AppColors.warning),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Devis envoyé. En attente de l\'acceptation du client...',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );

      case 'in_dispute':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.gavel, color: AppColors.error),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'MISSION GELÉE (LITIGE)\nLe support traite actuellement ce dossier. Aucune action possible pour le moment.',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

      case 'quote_accepted':
        return Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isUpdating ? null : _confirmManualPaymentReceived,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text(
                'Confirmer la réception du paiement',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Le client a validé son envoi de fonds. Veuillez vérifier votre compte Mobile Money avant de confirmer la réception.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tc.textSecondary, fontSize: 12, height: 1.4),
            ),
          ],
        );

      case 'paid':
        return ElevatedButton.icon(
          onPressed: () async {
            await _updateStatus('completed');
            if (mounted) context.pop();
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: AppColors.success,
          ),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Confirmer la fin de mission',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        );

      default:
        return const SizedBox();
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final TechLinkColors tc;
  const _SectionCard(
      {required this.title, required this.icon, required this.child, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: tc.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: tc.border),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final String status;
  final TechLinkColors tc;
  const _StatusTimeline({required this.status, required this.tc});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('Acceptée', 'accepted'),
      ('En route', 'technician_enroute'),
      ('En cours', 'in_progress'),
      ('Devis envoyé', 'quote_sent'),
      ('Devis accepté', 'quote_accepted'),
      ('Paiement reçu', 'paid'),
      ('Terminée', 'completed'),
    ];

    final stepMapping = {
      'accepted': 0,
      'technician_enroute': 1,
      'in_progress': 2,
      'quote_sent': 3,
      'quote_accepted': 3,
      'payment_pending': 4,
      'paid': 4,
      'completed': 5,
      'cancelled': -1,
      'in_dispute': -1,
      'cancelled_refunded': -1,
    };
    final currentIndex = stepMapping[status] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progression de la mission',
            style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: tc.textPrimary)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps.asMap().entries.map((entry) {
                final i = entry.key;
                final step = entry.value;
                final isDone = i < currentIndex;
                final isCurrent = i == currentIndex;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppColors.success
                                : isCurrent
                                    ? AppColors.primary
                                    : AppColors.border,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 12)
                                : isCurrent
                                    ? Container(
                                        width: 8, height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle))
                                    : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(step.$1,
                          style: TextStyle(
                            fontSize: 10,
                            color: isCurrent
                                ? AppColors.primary
                                : isDone
                                    ? AppColors.success
                                    : tc.textSecondary,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                          )),
                      ],
                    ),
                    if (i < steps.length - 1)
                      Container(
                        width: 30,
                        height: 2,
                        margin: const EdgeInsets.only(top: 11),
                        color: isDone
                            ? AppColors.success
                            : tc.border,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}