import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../shared/responsive_web_wrapper.dart';

// =========================================================================
// ÉCRAN DES REVENUS
// =========================================================================
// Affiche les revenus totaux générés par le technicien via la plateforme
// ainsi que l'historique des paiements reçus.

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  List<Map<String, dynamic>> _payments = [];
  double _totalEarnings = 0;
  double _pendingEarnings = 0;
  bool _isLoading = true;
  bool _showAllHistory = false;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final technician = await Supabase.instance.client
          .from('technicians')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      final technicianIds = <String>{
        userId,
        if (technician?['id'] != null) technician!['id'] as String,
      }.toList();

      final payments = await Supabase.instance.client
          .from('payments')
          .select('*, missions(categories(name))')
          .inFilter('technician_id', technicianIds)
          .order('created_at', ascending: false);

      double total = 0;

      for (final p in payments) {
        final amount =
            (p['technician_amount'] as num?)?.toDouble() ?? 0;
        total += amount;
      }

      if (mounted) {
        setState(() {
          _payments = List<Map<String, dynamic>>.from(payments);
          _totalEarnings = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: tc.background,
        elevation: 0,
        title: Text('Mes Revenus', style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveWebWrapper(
              child: CustomScrollView(
                slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CARTE PRINCIPALE DES REVENUS
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            image: DecorationImage(
                              image: const NetworkImage('https://images.unsplash.com/photo-1579621970563-ebec7560ff3e?q=80&w=1000&auto=format&fit=crop'),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Revenus générés via la plateforme', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 8),
                              Text(
                                '${_totalEarnings.toStringAsFixed(0)} F',
                                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // TITRE DE L'HISTORIQUE
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Historique des paiements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary)),
                            if (_payments.length > 3)
                              GestureDetector(
                                onTap: () => setState(() => _showAllHistory = !_showAllHistory),
                                child: Text(_showAllHistory ? 'Voir moins' : 'Voir tout', style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // LISTE DES TRANSACTIONS
                if (_payments.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120, height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: const DecorationImage(
                                image: NetworkImage('https://images.unsplash.com/photo-1620714223084-8fcacc6dfd8d?q=80&w=400&auto=format&fit=crop'),
                                fit: BoxFit.cover,
                              ),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text('Aucun revenu pour le moment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary)),
                          const SizedBox(height: 8),
                          Text('Vos paiements apparaîtront ici une fois vos missions terminées.', textAlign: TextAlign.center, style: TextStyle(color: tc.textSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _PaymentCard(payment: _payments[index], tc: tc, isDark: isDark);
                        },
                        childCount: _showAllHistory ? _payments.length : (_payments.length > 3 ? 3 : _payments.length),
                      ),
                    ),
                  ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final TechLinkColors tc;
  final bool isDark;

  const _PaymentCard({required this.payment, required this.tc, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final amount = (payment['technician_amount'] as num?)?.toDouble() ?? 0;
    final status = payment['payout_status'] as String? ?? 'pending';
    final method = payment['payment_method'] as String? ?? 'mtn_money';
    final mission = payment['missions'] as Map<String, dynamic>?;
    final category = mission?['categories']?['name'] as String? ?? 'Service TechLink';
    
    // Format de la date
    final createdAt = payment['created_at'];
    String dateStr = 'Récemment';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    final isPaid = status == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? tc.card : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tc.border, width: 0.5),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icône
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Détails
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tc.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          // Montant
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+ ${amount.toStringAsFixed(0)} F', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: tc.textPrimary)),
              const SizedBox(height: 4),
              const Text(
                'Généré',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
