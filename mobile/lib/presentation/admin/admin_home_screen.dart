import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import 'technician_validation_screen.dart';
import 'admin_missions_screen.dart';
import 'admin_users_tab.dart';
import 'admin_settings_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_payouts_screen.dart';
import 'admin_disputes_screen.dart';
import 'admin_broadcast_screen.dart';
import 'admin_support_list_screen.dart';

// =============================================================================
// FICHIER : admin_home_screen.dart
// RÔLE : Tableau de bord principal administrateur (navigation multi-onglets, KPIs, missions, support)
// MODULE : Presentation / Admin
// DÉPENDANCES : flutter/material.dart, flutter_riverpod, go_router, supabase_flutter, cached_network_image, fl_chart, admin tabs & screens
// SÉCURITÉ / RLS : Rôle administrateur requis. Vue globale avec droits d'accès étendus sur toutes les ressources système.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import 'technician_validation_screen.dart';
import 'admin_missions_screen.dart';
import 'admin_users_tab.dart';
import 'admin_settings_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_payouts_screen.dart';
import 'admin_disputes_screen.dart';
import 'admin_broadcast_screen.dart';
import 'admin_support_list_screen.dart';

/// Fournisseur d'état Riverpod récupérant le profil complet de l'administrateur connecté.
final adminUserProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser!.id;
  final res = await Supabase.instance.client
      .from('users')
      .select()
      .eq('id', userId)
      .single();
  return res;
});

/// Modèle interne représentant un item de navigation pour la barre latérale ou la barre inférieure.
class _AdminNavItem {
  /// Icône par défaut inactive.
  final IconData icon;

  /// Icône active mise en surbrillance.
  final IconData activeIcon;

  /// Libellé textuel de l'onglet.
  final String label;

  /// Constructeur constant du descripteur [_AdminNavItem].
  const _AdminNavItem(this.icon, this.activeIcon, this.label);
}

/// Liste ordonnée des destinations principales du portail administrateur.
const List<_AdminNavItem> _adminNavItems = [
  _AdminNavItem(Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Accueil'),
  _AdminNavItem(Icons.assignment_outlined, Icons.assignment_rounded, 'Missions'),
  _AdminNavItem(Icons.people_alt_outlined, Icons.people_alt_rounded, 'Utilisateurs'),
  _AdminNavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Messages'),
  _AdminNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
];

/// Écran conteneur principal du portail administrateur.
///
/// Adapte dynamiquement l'interface selon la largeur d'écran (Sidebar bureau, NavigationRail tablette,
/// ou barre flottante moderne sur mobile) et héberge les 5 onglets majeurs du système.
class AdminHomeScreen extends StatefulWidget {
  /// Constructeur constant du widget [AdminHomeScreen].
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

/// État associé au conteneur principal de navigation administrateur.
///
/// Supervise l'index d'onglet actif et le décompte des dossiers techniciens en attente de validation KYC.
class _AdminHomeScreenState extends State<AdminHomeScreen> {
  /// Index de l'onglet couramment sélectionné (0 à 4).
  int _currentIndex = 0;

  /// Nombre d'artisans en attente de vérification administrative.
  int _pendingTechs = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  /// Interroge Supabase pour compter les prestataires ayant le statut `'pending'`.
  Future<void> _loadPendingCount() async {
    try {
      final res = await Supabase.instance.client
          .from('technicians')
          .select('id')
          .eq('validation_status', 'pending');
      if (mounted) setState(() => _pendingTechs = (res as List).length);
    } catch (_) {}
  }

  /// Change l'onglet actif et rafraîchit le badge de validation si nécessaire.
  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    if (index == 2) _loadPendingCount();
  }

  /// Construit la vue adaptative selon la résolution écran (bureau, tablette, mobile).
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    Widget bodyContent = IndexedStack(
      index: _currentIndex,
      children: [
        AdminDashboardTab(onNavigateTab: _onTabSelected),
        const AdminMissionsScreen(),
        const AdminUsersTab(),
        const AdminSupportListScreen(),
        const AdminProfileTab(),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        if (isDesktop) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Row(
              children: [
                _buildModernDesktopSidebar(tc, isDark),
                Expanded(
                  child: Container(
                    color: isDark ? const Color(0xFF121826) : const Color(0xFFF8FAFC),
                    child: bodyContent,
                  ),
                ),
              ],
            ),
          );
        }
        if (constraints.maxWidth >= 800) {
          return Scaffold(
            backgroundColor: tc.background,
            body: Row(
              children: [
                _buildNavigationRail(tc, isDark),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: bodyContent,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          backgroundColor: tc.background,
          body: bodyContent,
          bottomNavigationBar: _buildModernBottomBar(tc, isDark),
        );
      },
    );
  }

  /// Construit la barre de navigation mobile flottante moderne avec animations et badges d'alerte.
  Widget _buildModernBottomBar(TechLinkColors tc, bool isDark) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? bottomInset : 12),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_adminNavItems.length, (i) {
            final item = _adminNavItems[i];
            final selected = i == _currentIndex;
            final showBadge = i == 2 && _pendingTechs > 0;

            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: item.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  splashColor: AppColors.primary.withOpacity(0.1),
                  highlightColor: Colors.transparent,
                  onTap: () => _onTabSelected(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            width: selected ? 46 : 34,
                            height: 28,
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? LinearGradient(
                                      colors: [
                                        AppColors.primary.withOpacity(0.24),
                                        AppColors.primary.withOpacity(0.08),
                                      ],
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: AnimatedScale(
                              scale: selected ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 220),
                              child: Icon(
                                selected ? item.activeIcon : item.icon,
                                size: 22,
                                color: selected ? AppColors.primary : tc.textSecondary,
                              ),
                            ),
                          ),
                          if (showBadge)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _pendingTechs > 9 ? '9+' : '$_pendingTechs',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                              color: selected ? AppColors.primary : tc.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: selected ? 14 : 0,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Construit la barre latérale pour environnement desktop/web avec logo, menu de navigation et raccourci de déconnexion.
  Widget _buildModernDesktopSidebar(TechLinkColors tc, bool isDark) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(right: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Section
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TechLink',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Console Admin',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _adminNavItems.length,
              itemBuilder: (context, index) {
                final item = _adminNavItems[index];
                final isSelected = _currentIndex == index;
                final showBadge = index == 2 && _pendingTechs > 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _onTabSelected(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: AppColors.primary.withOpacity(0.4))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected ? AppColors.primary : const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (showBadge)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_pendingTechs',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Admin Card
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF3B82F6),
                  child: Icon(Icons.admin_panel_settings, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Administrateur',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Super Admin',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, size: 16, color: Color(0xFFEF4444)),
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construit le rail de navigation vertical compact adapté aux tablettes et écrans intermédiaires.
  Widget _buildNavigationRail(TechLinkColors tc, bool isDark) {
    return NavigationRail(
      extended: MediaQuery.of(context).size.width >= 1000,
      selectedIndex: _currentIndex,
      onDestinationSelected: _onTabSelected,
      backgroundColor: tc.surface,
      indicatorColor: AppColors.primary.withOpacity(0.15),
      selectedIconTheme: const IconThemeData(color: AppColors.primary),
      unselectedIconTheme: IconThemeData(color: tc.textSecondary),
      selectedLabelTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      unselectedLabelTextStyle: TextStyle(color: tc.textSecondary),
      labelType: MediaQuery.of(context).size.width >= 1000 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      destinations: [
        for (final item in _adminNavItems)
          NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon),
            label: Text(item.label),
          ),
      ],
    );
  }
}

/// Onglet principal de pilotage et tableau de bord analytique pour l'administrateur.
///
/// Affiche les indicateurs clés de performance (KPIs), les graphiques d'évolution hebdomadaire
/// des revenus et des missions, ainsi que les raccourcis d'administration rapide.
class AdminDashboardTab extends ConsumerStatefulWidget {
  /// Callback permettant de basculer vers un autre onglet parent via son index ordinal.
  final ValueChanged<int>? onNavigateTab;

  /// Constructeur constant du widget [AdminDashboardTab].
  const AdminDashboardTab({super.key, this.onNavigateTab});

  @override
  ConsumerState<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

/// État associé au tableau de bord administrateur.
///
/// Agrège les métriques des missions, paiements, abonnements et utilisateurs depuis Supabase.
class _AdminDashboardTabState extends ConsumerState<AdminDashboardTab> {
  /// Compteurs quantitatifs par entité ('pending', 'approved', 'clients', 'missions').
  Map<String, int> _stats = {};

  /// Volume d'affaires brut total généré par les paiements.
  double _totalRevenue = 0;

  /// Revenus générés par les abonnements techniciens perçus par la plateforme.
  double _totalCommissions = 0;

  /// Montant total reversé aux techniciens sur les interventions.
  double _totalPaidToTechs = 0;

  /// Indicateur de chargement asynchrone des indicateurs statistiques.
  bool _isLoading = true;

  /// Répartition du chiffre d'affaires sur les 7 derniers jours glissants.
  List<double> _weeklyRevenue = List.filled(7, 0.0);

  /// Volume de missions créées sur les 7 derniers jours glissants.
  List<double> _weeklyMissions = List.filled(7, 0.0);

  /// Libellés des jours de la semaine courante pour les axes des graphiques.
  List<String> _weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// Calcule et synchronise l'ensemble des métriques d'activité et des séries chronologiques.
  Future<void> _loadStats() async {
    try {
      final pending = await Supabase.instance.client
          .from('technicians')
          .select('id')
          .eq('validation_status', 'pending');

      final approved = await Supabase.instance.client
          .from('technicians')
          .select('id')
          .eq('validation_status', 'approved');

      final clients = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('role', 'client');

      final DateTime now = DateTime.now();
      final DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));
      final String sevenDaysAgoStr = sevenDaysAgo.toIso8601String();

      final missionsList = await Supabase.instance.client
          .from('missions')
          .select('id, created_at')
          .gte('created_at', sevenDaysAgoStr);

      final paymentsList = await Supabase.instance.client
          .from('payments')
          .select('amount, platform_fee, technician_amount, created_at')
          .eq('status', 'success')
          .gte('created_at', sevenDaysAgoStr);

      final subscriptions = await Supabase.instance.client
          .from('technician_subscriptions')
          .select('amount_paid, status')
          .inFilter('status', ['active', 'expired', 'cancelled']);

      double totalRevenue = 0;
      double subscriptionRevenue = 0;
      double totalPaid = 0;

      List<double> weekRev = List.filled(7, 0.0);
      List<double> weekMiss = List.filled(7, 0.0);
      List<String> wDays = [];

      List<String> jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        wDays.add(jours[d.weekday - 1]);
      }

      for (final p in paymentsList) {
        final amt = (p['amount'] as num?)?.toDouble() ?? 0;
        final techAmt = (p['technician_amount'] as num?)?.toDouble() ?? 0;
        totalRevenue += amt;
        totalPaid += techAmt;

        final dt = DateTime.parse(p['created_at']);
        final diff = now.difference(dt).inDays;
        if (diff >= 0 && diff < 7) {
          weekRev[6 - diff] += amt;
        }
      }

      for (final s in subscriptions) {
        subscriptionRevenue += (s['amount_paid'] as num?)?.toDouble() ?? 0;
      }

      for (final m in missionsList) {
        final dt = DateTime.parse(m['created_at']);
        final diff = now.difference(dt).inDays;
        if (diff >= 0 && diff < 7) {
          weekMiss[6 - diff] += 1;
        }
      }

      final totalMissions = await Supabase.instance.client.from('missions').select('id');

      if (mounted) {
        setState(() {
          _stats = {
            'pending': (pending as List).length,
            'approved': (approved as List).length,
            'clients': (clients as List).length,
            'missions': (totalMissions as List).length,
          };
          _totalRevenue = totalRevenue;
          _totalCommissions = subscriptionRevenue;
          _totalPaidToTechs = totalPaid;
          _weeklyRevenue = weekRev;
          _weeklyMissions = weekMiss;
          _weekDays = wDays;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Ouvre l'écran de validation KYC [TechnicianValidationScreen] filtré sur les dossiers en attente.
  void _navigateToPending(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TechnicianValidationScreen(filter: 'pending'),
      ),
    ).then((_) => _loadStats());
  }

  /// Construit la vue complète du tableau de bord avec indicateurs financiers et graphiques d'activité.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final adminUserAsync = ref.watch(adminUserProvider);
    final adminData = adminUserAsync.value;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row (Overflow immune)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF3B82F6).withOpacity(0.15),
                            backgroundImage: adminData?['avatar_url'] != null
                                ? CachedNetworkImageProvider(adminData!['avatar_url'])
                                : null,
                            child: adminData?['avatar_url'] == null
                                ? const Icon(Icons.admin_panel_settings, color: Color(0xFF3B82F6), size: 20)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        'Console Admin • En direct',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: tc.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  adminData?['name'] ?? 'Administrateur',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: tc.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        context.push('/notifications');
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.notifications_outlined, color: tc.textPrimary, size: 21),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: StreamBuilder<List<Map<String, dynamic>>>(
                                stream: Supabase.instance.client
                                    .from('notifications')
                                    .stream(primaryKey: ['id'])
                                    .map((events) => events.where((e) => e['is_read'] == false).toList()),
                                builder: (context, snapshot) {
                                  final unreadCount = snapshot.data?.length ?? 0;
                                  if (unreadCount == 0) return const SizedBox.shrink();
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Hero Financial Card (Electric Mesh gradient, Compact & Overflow Safe)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'VOLUME D\'AFFAIRES GLOBAL',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.trending_up, color: Color(0xFF10B981), size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Actif',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_totalRevenue.toStringAsFixed(0)} FCFA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(height: 1, color: Colors.white.withOpacity(0.08)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Commissions',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                ),
                                const SizedBox(height: 1),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${_totalCommissions.toStringAsFixed(0)} F',
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Reversé Techs',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                ),
                                const SizedBox(height: 1),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${_totalPaidToTechs.toStringAsFixed(0)} F',
                                    style: const TextStyle(
                                      color: Color(0xFF4ADE80),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 4 Modern KPI Cards Grid (Compact boxes)
                Row(
                  children: [
                    Expanded(
                      child: _buildModernKpiCard(
                        title: 'En attente',
                        value: '${_stats['pending'] ?? 0}',
                        subtitle: 'Validation requise',
                        icon: Icons.hourglass_top_rounded,
                        color: const Color(0xFFF59E0B),
                        tc: tc,
                        isDark: isDark,
                        onTap: () => _navigateToPending(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildModernKpiCard(
                        title: 'Techniciens',
                        value: '${_stats['approved'] ?? 0}',
                        subtitle: 'Vérifiés & actifs',
                        icon: Icons.verified_rounded,
                        color: const Color(0xFF10B981),
                        tc: tc,
                        isDark: isDark,
                        onTap: () => widget.onNavigateTab?.call(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildModernKpiCard(
                        title: 'Clients',
                        value: '${_stats['clients'] ?? 0}',
                        subtitle: 'Comptes actifs',
                        icon: Icons.people_rounded,
                        color: const Color(0xFF3B82F6),
                        tc: tc,
                        isDark: isDark,
                        onTap: () => widget.onNavigateTab?.call(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildModernKpiCard(
                        title: 'Missions',
                        value: '${_stats['missions'] ?? 0}',
                        subtitle: 'Interventions',
                        icon: Icons.assignment_rounded,
                        color: const Color(0xFF8B5CF6),
                        tc: tc,
                        isDark: isDark,
                        onTap: () => widget.onNavigateTab?.call(1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 7-Day Performance Charts (Compact & Sleek)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? tc.card : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tc.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Activité des 7 derniers jours',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: tc.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Hebdo',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Chart (Compact height: 105)
                      SizedBox(
                        height: 105,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value < 0 || value >= _weekDays.length) return const SizedBox();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        _weekDays[value.toInt()],
                                        style: TextStyle(color: tc.textSecondary, fontSize: 9),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _weeklyRevenue
                                    .asMap()
                                    .entries
                                    .map((e) => FlSpot(e.key.toDouble(), e.value))
                                    .toList(),
                                isCurved: true,
                                color: const Color(0xFF3B82F6),
                                barWidth: 2.5,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Quick Action Shortcuts Section
                Text(
                  'PILOTAGE RAPIDE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: tc.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                _buildModernActionTile(
                  title: 'Valider les techniciens',
                  subtitle: '${_stats['pending'] ?? 0} dossier(s) en attente',
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFFF59E0B),
                  tc: tc,
                  isDark: isDark,
                  onTap: () => _navigateToPending(context),
                ),
                _buildModernActionTile(
                  title: 'Toutes les missions',
                  subtitle: 'Explorer et filtrer les prestations',
                  icon: Icons.assignment_outlined,
                  color: const Color(0xFF8B5CF6),
                  tc: tc,
                  isDark: isDark,
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
                _buildModernActionTile(
                  title: 'Gérer les utilisateurs',
                  subtitle: 'Clients & flotte de techniciens',
                  icon: Icons.people_alt_outlined,
                  color: const Color(0xFF3B82F6),
                  tc: tc,
                  isDark: isDark,
                  onTap: () => widget.onNavigateTab?.call(2),
                ),
                _buildModernActionTile(
                  title: 'Diffuser une notification',
                  subtitle: 'Alerte push à tous les utilisateurs',
                  icon: Icons.campaign_rounded,
                  color: const Color(0xFF10B981),
                  tc: tc,
                  isDark: isDark,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBroadcastScreen())),
                ),
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construit une carte KPI compacte et interactive avec valeur mise en exergue et couleur thématique.
  Widget _buildModernKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required TechLinkColors tc,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? tc.card : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 11, color: tc.textSecondary),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: tc.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tc.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.5, color: tc.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construit une tuile d'action rapide vers une section d'administration (missions, utilisateurs, broadcasts).
  Widget _buildModernActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required TechLinkColors tc,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? tc.card : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tc.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: tc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: tc.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Onglet de profil et réglages du compte super-administrateur.
///
/// Permet l'actualisation de la photo de profil, le basculement instantané clair/sombre,
/// l'accès aux paramètres système globaux, et la déconnexion de la console.
class AdminProfileTab extends ConsumerStatefulWidget {
  /// Constructeur constant du widget [AdminProfileTab].
  const AdminProfileTab({super.key});

  @override
  ConsumerState<AdminProfileTab> createState() => _AdminProfileTabState();
}

/// État associé à l'onglet de profil administrateur.
///
/// Gère la récupération des informations du compte et le téléversement d'un nouvel avatar.
class _AdminProfileTabState extends ConsumerState<AdminProfileTab> {
  /// Données de l'administrateur issues de la table `users`.
  Map<String, dynamic>? _adminData;

  /// Indicateur de chargement asynchrone des informations du profil.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  /// Charge les données du profil de l'administrateur connecté.
  Future<void> _loadAdminData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final user = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _adminData = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Ouvre la galerie, redimensionne l'image et l'envoie dans le bucket 'avatars' de Supabase Storage.
  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 80,
      );

      if (image == null) return;
      if (mounted) setState(() => _isLoading = true);

      final bytes = await image.readAsBytes();
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final fileExt = image.name.split('.').last.isNotEmpty ? image.name.split('.').last : 'png';
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );

      final newAvatarUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);

      await Supabase.instance.client
          .from('users')
          .update({'avatar_url': newAvatarUrl})
          .eq('id', userId);

      ref.invalidate(adminUserProvider);

      if (mounted) {
        setState(() {
          _adminData?['avatar_url'] = newAvatarUrl;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar mis à jour avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  /// Construit la vue de profil administrateur avec carte d'identité, commutateur de thème et déconnexion.
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: tc.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final name = (_adminData?['name'] as String?)?.trim();
    final email = (_adminData?['email'] as String?) ??
        Supabase.instance.client.auth.currentUser?.email ??
        '';
    final avatarUrl = _adminData?['avatar_url'] as String?;

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadAdminData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              // Header
              Text(
                'Mon Profil',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: tc.textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              // Super Admin Identity Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: Colors.white.withOpacity(0.15),
                          backgroundImage: avatarUrl != null
                              ? CachedNetworkImageProvider(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 32)
                              : null,
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: GestureDetector(
                            onTap: _pickAndUploadImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF0F172A), width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (name == null || name.isEmpty) ? 'Administrateur' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_rounded, color: Color(0xFFFBBF24), size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Super Administrateur',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // Pilotage Section
              Text(
                'PILOTAGE DE LA PLATEFORME',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: tc.textSecondary,
                ),
              ),
              const SizedBox(height: 10),

              _buildProfileTile(
                icon: Icons.category_rounded,
                color: const Color(0xFF3B82F6),
                title: 'Catégories de services',
                subtitle: 'Ajouter, éditer les tarifs',
                tc: tc,
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCategoriesScreen())),
              ),
              _buildProfileTile(
                icon: Icons.gavel_rounded,
                color: const Color(0xFFEF4444),
                title: 'Litiges & signalements',
                subtitle: 'Médiation et résolutions',
                tc: tc,
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDisputesScreen())),
              ),
              _buildProfileTile(
                icon: Icons.campaign_rounded,
                color: const Color(0xFFF59E0B),
                title: 'Notifications globales',
                subtitle: 'Diffuser une annonce à tous',
                tc: tc,
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBroadcastScreen())),
              ),
              _buildProfileTile(
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF10B981),
                title: 'Retraits & reversements',
                subtitle: 'Suivre les paiements techniciens',
                tc: tc,
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPayoutsScreen())),
              ),
              const SizedBox(height: 22),

              // Préférences Section
              Text(
                'PRÉFÉRENCES & SYSTÈME',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: tc.textSecondary,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark ? tc.card : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tc.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: const Color(0xFF8B5CF6),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          isDark ? 'Mode Sombre' : 'Mode Clair',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: tc.textPrimary,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        value: isDark,
                        activeColor: AppColors.primary,
                        onChanged: (val) => ref.read(themeModeProvider.notifier).toggleDarkMode(val),
                      ),
                    ],
                  ),
                ),
              ),

              _buildProfileTile(
                icon: Icons.tune_rounded,
                color: const Color(0xFF64748B),
                title: 'Paramètres système',
                subtitle: 'Commissions, tarification…',
                tc: tc,
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsScreen())),
              ),

              const SizedBox(height: 24),

              // Disconnect button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        title: const Text('Déconnexion'),
                        content: const Text('Voulez-vous vraiment vous déconnecter de la console admin ?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annuler'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Se déconnecter'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                  label: const Text(
                    'Se déconnecter',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.error.withOpacity(0.4)),
                    backgroundColor: AppColors.error.withOpacity(0.06),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construit une tuile d'option de menu de profil avec icône, libellé et chevron indicateur.
  Widget _buildProfileTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required TechLinkColors tc,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? tc.card : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: tc.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: tc.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: tc.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
