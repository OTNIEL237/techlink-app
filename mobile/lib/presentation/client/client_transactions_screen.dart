import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';

// =========================================================================
// ÉCRAN MODERNE DES TRANSACTIONS CLIENT (Paiements CamerPay / MoMo / Orange)
// =========================================================================

class ClientTransactionsScreen extends StatefulWidget {
  const ClientTransactionsScreen({super.key});

  @override
  State<ClientTransactionsScreen> createState() => _ClientTransactionsScreenState();
}

class _ClientTransactionsScreenState extends State<ClientTransactionsScreen> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 10;

  List<Map<String, dynamic>> _allTransactions = [];
  final ScrollController _scrollController = ScrollController();

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['Toutes', 'Réussies', 'En attente', 'Échouées'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadTransactions(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadTransactions();
    }
  }

  Future<void> _loadTransactions({bool refresh = false}) async {
    if (refresh) {
      _offset = 0;
      _hasMore = true;
      _allTransactions.clear();
      if (mounted) setState(() => _isLoading = true);
    } else {
      if (!_hasMore || _isLoadingMore) return;
      if (mounted) setState(() => _isLoadingMore = true);
    }

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      final data = await Supabase.instance.client
          .from('payments')
          .select('*, missions(id, problem_description, status)')
          .eq('client_id', userId)
          .order('created_at', ascending: false)
          .range(_offset, _offset + _limit - 1);

      if (mounted) {
        setState(() {
          if (data.length < _limit) {
            _hasMore = false;
          }
          _allTransactions.addAll(List<Map<String, dynamic>>.from(data));
          _offset += data.length;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredTransactions() {
    List<Map<String, dynamic>> list = _allTransactions;

    // Filtre par statut
    if (_selectedFilterIndex == 1) {
      // Réussies
      list = list.where((tx) => ['completed', 'success', 'paid'].contains(tx['status'])).toList();
    } else if (_selectedFilterIndex == 2) {
      // En attente
      list = list.where((tx) => ['pending', 'processing'].contains(tx['status'])).toList();
    } else if (_selectedFilterIndex == 3) {
      // Échouées
      list = list.where((tx) => ['failed', 'cancelled'].contains(tx['status'])).toList();
    }

    // Filtre par recherche
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((tx) {
        final mission = tx['missions'] as Map<String, dynamic>?;
        final problem = (mission?['problem_description'] as String? ?? '').toLowerCase();
        final ref = (tx['camerpay_reference'] as String? ?? '').toLowerCase();
        final method = (tx['method'] as String? ?? '').toLowerCase();
        final id = (tx['id'] as String? ?? '').toLowerCase();
        return problem.contains(query) || ref.contains(query) || method.contains(query) || id.contains(query);
      }).toList();
    }

    return list;
  }

  double get _totalSpent {
    double total = 0;
    for (var tx in _allTransactions) {
      if (['completed', 'success', 'paid'].contains(tx['status'])) {
        final amt = tx['amount'];
        if (amt is num) {
          total += amt.toDouble();
        } else if (amt is String) {
          total += double.tryParse(amt) ?? 0;
        }
      }
    }
    return total;
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0 FCFA';
    final formatter = NumberFormat('#,###', 'fr_FR');
    if (amount is num) {
      return '${formatter.format(amount)} FCFA';
    }
    final parsed = double.tryParse(amount.toString()) ?? 0;
    return '${formatter.format(parsed)} FCFA';
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'Date inconnue';
    try {
      final date = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('dd/MM/yyyy à HH:mm').format(date);
    } catch (_) {
      return dateStr.toString();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'paid':
        return const Color(0xFF059669); // Vert succès
      case 'pending':
      case 'processing':
        return const Color(0xFFD97706); // Ambre
      case 'failed':
      case 'cancelled':
        return const Color(0xFFDC2626); // Rouge
      default:
        return const Color(0xFF2563EB);
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'paid':
        return 'Payé';
      case 'pending':
      case 'processing':
        return 'En attente';
      case 'failed':
      case 'cancelled':
        return 'Échoué';
      default:
        return status;
    }
  }

  IconData _getMethodIcon(String method) {
    final m = method.toLowerCase();
    if (m.contains('mtn') || m.contains('momo')) {
      return Icons.phone_android_rounded;
    } else if (m.contains('orange') || m.contains('om')) {
      return Icons.smartphone_rounded;
    } else if (m.contains('card') || m.contains('carte')) {
      return Icons.credit_card_rounded;
    }
    return Icons.account_balance_wallet_rounded;
  }

  String _getMethodLabel(String method) {
    final m = method.toLowerCase();
    if (m.contains('mtn')) return 'MTN MoMo';
    if (m.contains('orange')) return 'Orange Money';
    if (m.contains('card')) return 'Carte Bancaire';
    return 'CamerPay';
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactionsToDisplay = _getFilteredTransactions();

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: _isSearching
            ? Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252526) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: tc.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une transaction...',
                    hintStyle: TextStyle(color: tc.textSecondary, fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              )
            : Text(
                'Mes Transactions',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.4,
                  color: tc.textPrimary,
                ),
              ),
        backgroundColor: tc.background,
        elevation: 0,
        iconTheme: IconThemeData(color: tc.textPrimary),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: tc.textPrimary),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: tc.textPrimary,
            onPressed: () => _loadTransactions(refresh: true),
            tooltip: 'Actualiser',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadTransactions(refresh: true),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // 1. CARTE RÉSUMÉ FINANCIER VIP
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'DÉPENSES VALIDÉES',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_rounded, color: Colors.white, size: 11),
                                      SizedBox(width: 4),
                                      Text(
                                        'CamerPay Sécurisé',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _formatCurrency(_totalSpent),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.receipt_long_rounded, color: Colors.white.withOpacity(0.8), size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  '${_allTransactions.length} transaction${_allTransactions.length > 1 ? 's' : ''} au total',
                                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. FILTRES RAPIDES (CHIPS)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filters.length,
                        itemBuilder: (context, idx) {
                          final isSelected = _selectedFilterIndex == idx;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedFilterIndex = idx);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark ? const Color(0xFF252526) : Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                                child: Text(
                                  _filters[idx],
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? Colors.white : tc.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // 3. LISTE DES TRANSACTIONS
                  transactionsToDisplay.isEmpty && !_isLoadingMore
                      ? SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState(tc, isDark))
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index == transactionsToDisplay.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final tx = transactionsToDisplay[index];
                                return _buildTransactionCard(tx, tc, isDark);
                              },
                              childCount: transactionsToDisplay.length + (_isLoadingMore ? 1 : 0),
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx, TechLinkColors tc, bool isDark) {
    final mission = tx['missions'] as Map<String, dynamic>?;
    final missionTitle = mission?['problem_description'] ?? 'Mission #${tx['mission_id']?.toString().substring(0, 8) ?? 'Générale'}';
    final amount = tx['amount'];
    final status = tx['status'] as String? ?? 'unknown';
    final method = tx['method'] as String? ?? 'camerpay';
    final ref = tx['camerpay_reference'] ?? tx['id']?.toString().substring(0, 8) ?? 'N/A';
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252526) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne 1 : Titre de la mission & Montant
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getMethodIcon(method), color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      missionTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: tc.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getMethodLabel(method),
                      style: TextStyle(color: tc.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatCurrency(amount),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: statusColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // Ligne 2 : Référence copiable, Statut et Date (Anti-overflow complet)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: ref.toString()));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Référence copiée : $ref'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 12, color: tc.textSecondary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Réf: $ref',
                              style: TextStyle(color: tc.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(tx['created_at']),
                      style: TextStyle(color: tc.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _getStatusText(status),
                      style: TextStyle(color: statusColor, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TechLinkColors tc, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching ? 'Aucun résultat trouvé' : 'Aucune transaction',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tc.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isSearching
                  ? 'Aucun paiement ne correspond à votre recherche.'
                  : 'Vos factures et reçus de paiement apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tc.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
