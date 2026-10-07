// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : mission_history_screen.dart
// Rôle          : Historique et statut en direct des missions du client
// Module        : Présentation / Client / Missions
// Dépendances   : Supabase Flutter, GoRouter, CachedNetworkImage, AppColors
// Sécurité/RLS  : Accès réservé aux interventions créées par le client authentifié
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/neumorphic_styles.dart';

/// [MissionHistoryScreen] présente les demandes d'intervention du client réparties
/// par onglets (En cours, Terminées, Annulées), avec recherche textuelle et suivi temps réel.
class MissionHistoryScreen extends StatefulWidget {
  const MissionHistoryScreen({super.key});

  @override
  State<MissionHistoryScreen> createState() => _MissionHistoryScreenState();
}

/// État interne gérant la pagination et le filtrage des interventions client par statut.
class _MissionHistoryScreenState extends State<MissionHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _allMissions = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 10;

  final List<String> _tabs = ['En cours', 'Terminées', 'Annulées'];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadMissions(refresh: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Déclenche le chargement de la page suivante lorsque l'utilisateur approche du bas de la liste.
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMissions();
    }
  }

  /// Charge les missions associées au client avec pagination et jointure sur les catégories et artisans.
  Future<void> _loadMissions({bool refresh = false}) async {
    if (refresh) {
      _offset = 0;
      _hasMore = true;
      _allMissions.clear();
      if (mounted) setState(() => _isLoading = true);
    } else {
      if (!_hasMore || _isLoadingMore) return;
      if (mounted) setState(() => _isLoadingMore = true);
    }

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('missions')
          .select('*, categories(name, slug), technician:users!missions_technician_id_fkey(name, phone, avatar_url)')
          .eq('client_id', userId)
          .order('created_at', ascending: false)
          .range(_offset, _offset + _limit - 1);

      if (mounted) {
        setState(() {
          if (data.length < _limit) {
            _hasMore = false;
          }
          _allMissions.addAll(List<Map<String, dynamic>>.from(data));
          _offset += data.length;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      // Fallback si la jointure techniciens échoue
      try {
        final userId = Supabase.instance.client.auth.currentUser!.id;
        final data = await Supabase.instance.client
            .from('missions')
            .select('*, categories(name, slug)')
            .eq('client_id', userId)
            .order('created_at', ascending: false)
            .range(_offset, _offset + _limit - 1);

        if (mounted) {
          setState(() {
            if (data.length < _limit) _hasMore = false;
            _allMissions.addAll(List<Map<String, dynamic>>.from(data));
            _offset += data.length;
            _isLoading = false;
            _isLoadingMore = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isLoadingMore = false;
          });
        }
      }
    }
  }

  /// Filtre les missions locales selon l'onglet courant (En cours, Terminées, Annulées) et le mot-clé recherché.
  List<Map<String, dynamic>> _filterMissions(String tab) {
    List<Map<String, dynamic>> list;
    switch (tab) {
      case 'En cours':
        list = _allMissions.where((m) {
          final s = m['status'] as String? ?? '';
          return ['pending', 'searching', 'accepted',
            'technician_enroute', 'in_progress',
            'quote_sent', 'quote_accepted'].contains(s);
        }).toList();
        break;
      case 'Terminées':
        list = _allMissions
            .where((m) => ['completed', 'paid'].contains(m['status']))
            .toList();
        break;
      case 'Annulées':
        list = _allMissions
            .where((m) => m['status'] == 'cancelled')
            .toList();
        break;
      default:
        list = _allMissions;
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((m) {
        final cat = (m['categories']?['name'] as String? ?? '').toLowerCase();
        final prob = (m['problem_description'] as String? ?? '').toLowerCase();
        return cat.contains(query) || prob.contains(query);
      }).toList();
    }
    return list;
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
        centerTitle: false,
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
                    hintText: 'Rechercher une mission...',
                    hintStyle: TextStyle(color: tc.textSecondary, fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              )
            : Row(
                children: [
                  Text(
                    'Mes Missions',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: -0.4,
                      color: tc.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_allMissions.length}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
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
            onPressed: () => _loadMissions(refresh: true),
            tooltip: 'Actualiser',
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252526) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: tc.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) {
                final missions = _filterMissions(tab);
                if (missions.isEmpty) return _buildEmpty(tab, tc, isDark);
                return RefreshIndicator(
                  onRefresh: () => _loadMissions(refresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    itemCount: missions.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == missions.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      return _MissionCard(
                        mission: missions[index],
                        onMissionUpdated: () => _loadMissions(refresh: true),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
    );
  }

  /// Construit la vue d'état vide adaptée selon l'onglet courant (En cours, Terminées, Annulées).
  Widget _buildEmpty(String tab, TechLinkColors tc, bool isDark) {
    String message;
    IconData icon;
    switch (tab) {
      case 'En cours':
        message = 'Vous n\'avez aucune mission active pour l\'instant.';
        icon = Icons.handyman_outlined;
        break;
      case 'Terminées':
        message = 'Aucune intervention clôturée dans votre historique.';
        icon = Icons.task_alt_rounded;
        break;
      default:
        message = 'Aucune mission annulée.';
        icon = Icons.cancel_outlined;
    }

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
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune mission $tab',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tc.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tc.textSecondary, height: 1.4),
            ),
            if (tab == 'En cours') ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.push('/client/problem'),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Créer une mission'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Carte récapitulative d'une mission affichant la catégorie, la date, la description,
/// l'artisan associé et les boutons d'action (Annulation ou Suivi en direct).
class _MissionCard extends StatelessWidget {
  final Map<String, dynamic> mission;
  final VoidCallback onMissionUpdated;

  const _MissionCard({required this.mission, required this.onMissionUpdated});

  /// Affiche une boîte de dialogue de confirmation et procède à l'annulation de la mission dans Supabase.
  Future<void> _cancelMission(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Annuler la mission', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir annuler cette demande ? Cette action informera l\'artisan et mettra fin à l\'intervention.',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Conserver la mission'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('missions')
            .update({'status': 'cancelled'})
            .eq('id', mission['id']);

        onMissionUpdated();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Mission annulée avec succès'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Échec de l\'annulation : $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = mission['status'] as String? ?? 'pending';

    // Configuration des statuts
    Color statusColor;
    Color statusBg;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'searching':
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFEF3C7);
        statusLabel = 'Recherche en cours';
        statusIcon = Icons.search_rounded;
        break;
      case 'accepted':
      case 'technician_enroute':
        statusColor = const Color(0xFF2563EB);
        statusBg = const Color(0xFFDBEAFE);
        statusLabel = 'Artisan en route';
        statusIcon = Icons.directions_car_rounded;
        break;
      case 'in_progress':
        statusColor = const Color(0xFF0D9488);
        statusBg = const Color(0xFFCCFBF1);
        statusLabel = 'Intervention en cours';
        statusIcon = Icons.engineering_rounded;
        break;
      case 'quote_sent':
      case 'quote_accepted':
        statusColor = const Color(0xFF7C3AED);
        statusBg = const Color(0xFFEDE9FE);
        statusLabel = 'Devis disponible';
        statusIcon = Icons.receipt_long_rounded;
        break;
      case 'completed':
      case 'paid':
        statusColor = const Color(0xFF059669);
        statusBg = const Color(0xFFD1FAE5);
        statusLabel = 'Mission terminée';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'cancelled':
        statusColor = const Color(0xFFDC2626);
        statusBg = const Color(0xFFFEE2E2);
        statusLabel = 'Annulée';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = const Color(0xFF2563EB);
        statusBg = const Color(0xFFDBEAFE);
        statusLabel = 'En attente';
        statusIcon = Icons.hourglass_top_rounded;
    }

    final category = mission['categories'] as Map<String, dynamic>?;
    final categoryName = category?['name'] as String? ?? 'Service général';
    final problem = mission['problem_description']?.toString() ?? 'Aucune description spécifiée';
    final technician = mission['technician'] as Map<String, dynamic>?;

    // Formatage de la date
    final createdAt = mission['created_at'];
    String dateStr = 'Date inconnue';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    final isCancellable = !['cancelled', 'completed', 'paid'].contains(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252526) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.30 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la carte : Domaine + Statut badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.build_circle_rounded, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              categoryName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: tc.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: tc.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? statusColor.withOpacity(0.2) : statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),

          // Corps de la carte : Description du problème
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              problem,
              style: TextStyle(
                fontSize: 13,
                color: tc.textPrimary.withOpacity(0.85),
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Mini profil technicien si assigné
          if (technician != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary,
                      backgroundImage: technician['avatar_url'] != null
                          ? CachedNetworkImageProvider(technician['avatar_url'])
                          : null,
                      child: technician['avatar_url'] == null
                          ? Text(
                              (technician['name'] as String? ?? 'T')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Artisan : ${technician['name'] ?? 'Assigné'}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: tc.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Pied de carte : Actions (Anti-overflow complet)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Row(
              children: [
                if (isCancellable) ...[
                  OutlinedButton.icon(
                    onPressed: () => _cancelMission(context),
                    icon: const Icon(Icons.close_rounded, size: 15, color: AppColors.error),
                    label: const Text('Annuler', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/client/tracking', extra: {'mission': mission});
                    },
                    icon: const Icon(Icons.navigation_rounded, size: 16),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        status == 'completed' ? 'Détails de la mission' : 'Suivre l\'intervention',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                        maxLines: 1,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}