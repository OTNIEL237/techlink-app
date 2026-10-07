// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : home_screen.dart
// Rôle          : Écran tableau de bord principal du technicien structuré en 4 onglets
//                 (Accueil / KPIs, Missions & devis, Messages et Profil artisan).
// Module        : Présentation Technicien (Tableau de bord & Navigation)
// Dépendances   : flutter/material.dart, go_router, supabase_flutter, cached_network_image,
//                 app_colors.dart, morph_transitions.dart, desktop_sidebar.dart
// Sécurité/RLS  : Accès exclusif aux utilisateurs avec rôle technicien approuvé
//                 et abonnement actif vérifié.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../shared/desktop_sidebar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/animations/morph_transitions.dart';
import 'mission_request_screen.dart';
import 'technician_messages_list_screen.dart';
import '../shared/profile_screen.dart';

/// Tableau de bord central et point d'entrée de l'expérience technicien.
class TechnicianHomeScreen extends StatefulWidget {
  /// Constructeur constant du tableau de bord technicien
  const TechnicianHomeScreen({super.key});

  @override
  State<TechnicianHomeScreen> createState() => _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState extends State<TechnicianHomeScreen> {
  /// Données personnelles de l'utilisateur issues de la table `users`
  Map<String, dynamic>? _userData;

  /// Données professionnelles du technicien issues de la table `technicians`
  Map<String, dynamic>? _technicianData;

  /// Liste des missions actives ou en attente d'intervention
  List<Map<String, dynamic>> _activeMissions = [];

  /// Liste des dernières missions achevées ou annulées
  List<Map<String, dynamic>> _completedMissions = [];

  /// Index du filtre de missions actuellement sélectionné
  int _selectedFilterIndex = 0;

  /// Liste des options de filtrage pour l'onglet Missions
  final List<String> _filters = ['Toutes', 'Nouvelles', 'En cours', 'Terminées'];

  /// Indicateur de chargement initial des données du tableau de bord
  bool _isLoading = true;

  /// Indique si le technicien est actuellement en ligne pour recevoir des clients
  bool _isAvailable = true;

  /// Indique si la mise à jour de disponibilité est en cours de communication réseau
  bool _isUpdatingAvailability = false;

  /// Index de l'onglet actif affiché (0: Accueil, 1: Missions, 2: Messages, 3: Profil)
  int _currentIndex = 0;

  /// Contrôleur de défilement horizontal entre les onglets
  late final PageController _pageController;

  /// Contrôleur de défilement pour la pagination infinie de l'onglet Missions
  final ScrollController _missionsScrollController = ScrollController();

  /// Indicateur de chargement d'une page de missions supplémentaire
  bool _isLoadingMore = false;

  /// Indique s'il reste des missions supplémentaires à charger
  bool _hasMore = true;

  /// Index de la page courante pour la pagination
  int _page = 0;

  /// Nombre d'éléments chargés par lot de pagination
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _loadData();
    _missionsScrollController.addListener(_onMissionsScroll);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _missionsScrollController.dispose();
    super.dispose();
  }

  /// Change l'onglet actif et anime la transition dans le PageController
  void _switchTab(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Détecte lorsque le défilement approche du bas pour charger des missions supplémentaires
  void _onMissionsScroll() {
    if (_missionsScrollController.position.pixels >= _missionsScrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreData();
    }
  }

  /// Charge l'ensemble des données du tableau de bord (profil, statut d'abonnement, missions en cours et archivées)
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _page = 0;
      _hasMore = true;
      _activeMissions = [];
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      final user = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      final technician = await Supabase.instance.client
          .from('technicians')
          .select()
          .eq('user_id', userId)
          .single();

      final subscriptionEndRaw = technician['subscription_end_date'] as String?;
      final subscriptionEnd = subscriptionEndRaw == null
          ? null
          : DateTime.tryParse(subscriptionEndRaw);
      final hasActiveSubscription =
          technician['subscription_status'] == 'active' &&
          subscriptionEnd != null &&
          subscriptionEnd.isAfter(DateTime.now());

      if (!hasActiveSubscription && mounted) {
        context.go('/subscription/select', extra: {
          'technicianId': technician['id'],
          'name': user['name'] ?? '',
          'email': Supabase.instance.client.auth.currentUser?.email ?? '$userId@techlink.cm',
          'phone': user['phone'] ?? '',
        });
        return;
      }

      if (technician['validation_status'] != 'approved' && mounted) {
        context.go('/technician/pending');
        return;
      }

      final missionsData = await Supabase.instance.client
          .from('missions')
          .select('*, categories(name, slug)')
          .or('technician_id.eq.$userId,status.eq.pending')
          .inFilter('status', ['accepted', 'technician_enroute', 'in_progress', 'quote_sent', 'pending'])
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);

      final completedData = await Supabase.instance.client
          .from('missions')
          .select('*, categories(name, slug)')
          .eq('technician_id', userId)
          .inFilter('status', ['completed', 'cancelled'])
          .order('created_at', ascending: false)
          .limit(3);

      final statusStr = technician['status'] as String? ?? 'available';
      final availMap = technician['availability'] is Map
          ? Map<String, dynamic>.from(technician['availability'] as Map)
          : null;
      final isAvail = statusStr != 'offline' && (availMap?['is_available'] != false);

      if (mounted) {
        setState(() {
          _userData = user;
          _technicianData = technician;
          _isAvailable = isAvail;
          _activeMissions = List<Map<String, dynamic>>.from(missionsData);
          _completedMissions = List<Map<String, dynamic>>.from(completedData);
          _hasMore = missionsData.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Charge le lot suivant de missions dans le cadre de la pagination
  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      _page++;
      final missionsData = await Supabase.instance.client
          .from('missions')
          .select('*, categories(name, slug)')
          .or('technician_id.eq.$userId,status.eq.pending')
          .inFilter('status', ['accepted', 'technician_enroute', 'in_progress', 'quote_sent', 'pending'])
          .order('created_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);

      if (mounted) {
        setState(() {
          _activeMissions.addAll(List<Map<String, dynamic>>.from(missionsData));
          _hasMore = missionsData.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Met à jour la disponibilité en ligne du technicien dans Supabase avec confirmation visuelle
  Future<void> _toggleAvailability(bool newValue) async {
    if (_isUpdatingAvailability) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isUpdatingAvailability = true;
      _isAvailable = newValue;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final currentAvail = Map<String, dynamic>.from(_technicianData?['availability'] as Map? ?? {});
      currentAvail['is_available'] = newValue;
      final statusStr = newValue ? 'available' : 'offline';

      await Supabase.instance.client
          .from('technicians')
          .update({
            'status': statusStr,
            'availability': currentAvail,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      if (_technicianData != null) {
        _technicianData!['status'] = statusStr;
        _technicianData!['availability'] = currentAvail;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newValue ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    newValue
                        ? '🟢 Vous êtes DISPONIBLE pour les clients'
                        : '⚪ Vous êtes HORS LIGNE (En pause)',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: newValue ? const Color(0xFF059669) : const Color(0xFF475569),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur toggle availability: $e');
      if (mounted) {
        setState(() => _isAvailable = !newValue);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingAvailability = false);
    }
  }

  // =========================================================================
  // ONGLETS 1 : ACCUEIL DU TECHNICIEN
  // =========================================================================
  Widget _buildAccueilTab(TechLinkColors tc) {
    final userName = _userData?['name'] ?? 'Artisan';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top;
    final safeTop = (topInset > 0 ? topInset : 24.0) + 12.0;

    final pendingMissions = _activeMissions.where((m) => m['status'] == 'pending').toList();
    final myMissions = _activeMissions.where((m) => m['status'] != 'pending').toList();

    // Mission prioritaire en cours s'il y en a une
    final activeOngoingMission = myMissions.isNotEmpty ? myMissions.first : null;

    final earnings = _technicianData?['total_earnings'] ?? 0;
    final rating = (_technicianData?['rating_average'] as num?)?.toDouble() ?? 5.0;
    final totalMissionsCount = _technicianData?['total_missions'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // 1. EN-TÊTE ARTISAN (100% SANS OVERFLOW)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, safeTop, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primary,
                            backgroundImage: _userData?['avatar_url'] != null && _userData!['avatar_url'].toString().isNotEmpty
                                ? CachedNetworkImageProvider(_userData!['avatar_url'])
                                : null,
                            child: (_userData?['avatar_url'] == null || _userData!['avatar_url'].toString().isEmpty)
                                ? Text(
                                    userName.isNotEmpty ? userName[0].toUpperCase() : 'T',
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bonjour 👋', style: TextStyle(color: tc.textSecondary, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(
                                userName,
                                style: TextStyle(color: tc.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: GestureDetector(
                                  onTap: () => _toggleAvailability(!_isAvailable),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: _isAvailable
                                          ? const Color(0xFF059669).withOpacity(isDark ? 0.22 : 0.12)
                                          : const Color(0xFF64748B).withOpacity(isDark ? 0.22 : 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _isAvailable
                                            ? const Color(0xFF059669).withOpacity(0.4)
                                            : const Color(0xFF64748B).withOpacity(0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _isAvailable ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                            boxShadow: _isAvailable
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(0xFF059669).withOpacity(0.6),
                                                      blurRadius: 4,
                                                      spreadRadius: 1,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _isAvailable ? 'Disponible' : 'Hors ligne',
                                          style: TextStyle(
                                            color: _isAvailable ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(
                                          Icons.touch_app_rounded,
                                          size: 11,
                                          color: _isAvailable ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF252526) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
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
                                if (unreadCount == 0 && pendingMissions.isEmpty) return const SizedBox.shrink();
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
            ),
          ),

          // 2. HERO CARD DISPONIBILITÉ (ZERO OVERFLOW GARANTI)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isAvailable
                        ? const Color(0xFF059669).withOpacity(0.4)
                        : const Color(0xFFEF4444).withOpacity(0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isAvailable
                          ? const Color(0xFF059669).withOpacity(isDark ? 0.18 : 0.08)
                          : const Color(0xFFEF4444).withOpacity(isDark ? 0.15 : 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _isAvailable
                            ? const Color(0xFF059669).withOpacity(0.14)
                            : const Color(0xFFEF4444).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isAvailable ? Icons.sensors_rounded : Icons.power_settings_new_rounded,
                        color: _isAvailable ? const Color(0xFF059669) : const Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _isAvailable ? 'DISPONIBLE' : 'HORS LIGNE',
                                  style: TextStyle(
                                    color: _isAvailable ? const Color(0xFF059669) : const Color(0xFFEF4444),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isAvailable ? const Color(0xFF059669) : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isAvailable
                                ? 'Prêt à recevoir des demandes d\'intervention'
                                : 'En pause • Aucune nouvelle demande reçue',
                            style: TextStyle(
                              color: tc.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_isUpdatingAvailability)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    else
                      Transform.scale(
                        scale: 0.85,
                        child: Switch.adaptive(
                          value: _isAvailable,
                          activeColor: const Color(0xFF059669),
                          activeTrackColor: const Color(0xFF059669).withOpacity(0.35),
                          inactiveThumbColor: const Color(0xFFEF4444),
                          inactiveTrackColor: const Color(0xFFEF4444).withOpacity(0.25),
                          onChanged: (val) => _toggleAvailability(val),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          if (!_isAvailable)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2).withOpacity(isDark ? 0.1 : 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF87171).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mode pause activé : Vous êtes invisible aux clients. Réactivez votre statut pour être sollicité.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. SECTION STATISTIQUES (Aperçu épuré & élégant)
          _buildSliverSectionTitle('Aperçu de votre activité', tc),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'DEMANDES',
                          value: '${pendingMissions.length}',
                          subtitle: pendingMissions.isEmpty ? 'À jour' : 'En attente',
                          icon: Icons.flash_on_rounded,
                          accentColor: const Color(0xFFF59E0B),
                          tc: tc,
                          isDark: isDark,
                          onTap: () {
                            setState(() => _selectedFilterIndex = 1);
                            _switchTab(1);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'EN COURS',
                          value: '${myMissions.length}',
                          subtitle: myMissions.isEmpty ? 'Aucune' : 'En intervention',
                          icon: Icons.engineering_rounded,
                          accentColor: AppColors.primary,
                          tc: tc,
                          isDark: isDark,
                          onTap: () {
                            setState(() => _selectedFilterIndex = 2);
                            _switchTab(1);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'REVENUS TOTAL',
                          value: '$earnings F',
                          subtitle: 'Portefeuille pro',
                          icon: Icons.account_balance_wallet_rounded,
                          accentColor: const Color(0xFF10B981),
                          tc: tc,
                          isDark: isDark,
                          onTap: () => context.push('/technician/earnings'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'NOTE GLOBALE',
                          value: '${rating.toStringAsFixed(1)} ★',
                          subtitle: '$totalMissionsCount intervention${totalMissionsCount > 1 ? 's' : ''}',
                          icon: Icons.star_rounded,
                          accentColor: const Color(0xFF8B5CF6),
                          tc: tc,
                          isDark: isDark,
                          onTap: () => _switchTab(3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // 5. INTERVENTION ACTIVE (PRIORITAIRE)
          if (activeOngoingMission != null) ...[
            _buildSliverSectionTitle('Intervention en cours 🚨', tc),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildPremiumMissionCard(activeOngoingMission, tc, isDark),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],

          // 6. NOUVELLES DEMANDES RÉCENTES
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Demandes Récentes',
                    style: TextStyle(
                      color: tc.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedFilterIndex = 1);
                      _switchTab(1);
                    },
                    child: Text(
                      'Voir tout (${pendingMissions.length}) →',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (pendingMissions.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tc.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.done_all_rounded, color: Color(0xFF059669), size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vous êtes à jour !',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: tc.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Aucune nouvelle demande de dépannage en attente de réponse.',
                              style: TextStyle(color: tc.textSecondary, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPremiumMissionCard(pendingMissions[index], tc, isDark),
                  childCount: pendingMissions.take(2).length,
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: SizedBox(height: 36 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ONGLETS 2 : MISSIONS COMPLÈTES (FILTRÉES & PAGINÉES)
  // =========================================================================
  Widget _buildMissionsTab(TechLinkColors tc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top;
    final safeTop = (topInset > 0 ? topInset : 24.0) + 12.0;

    final pendingMissions = _activeMissions.where((m) => m['status'] == 'pending').toList();
    final myMissions = _activeMissions.where((m) => m['status'] != 'pending').toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: CustomScrollView(
        controller: _missionsScrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // 1. En-tête de section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, safeTop, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mes Missions',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: tc.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Gérez vos interventions en direct, devis et historiques',
                    style: TextStyle(fontSize: 12.5, color: tc.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // 2. Filtres interactifs
          SliverToBoxAdapter(
            child: SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                itemBuilder: (context, idx) {
                  final isSelected = _selectedFilterIndex == idx;
                  String label = _filters[idx];
                  if (idx == 0) label = 'Toutes (${_activeMissions.length + _completedMissions.length})';
                  if (idx == 1) label = 'Nouvelles (${pendingMissions.length})';
                  if (idx == 2) label = 'En cours (${myMissions.length})';
                  if (idx == 3) label = 'Terminées (${_completedMissions.length})';

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
                          color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF252526) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // 3. Contenu filtré
          ..._buildFilteredMissionsContent(tc, isDark, pendingMissions, myMissions),

          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 36)),
        ],
      ),
    );
  }

  List<Widget> _buildFilteredMissionsContent(
    TechLinkColors tc,
    bool isDark,
    List<Map<String, dynamic>> pendingMissions,
    List<Map<String, dynamic>> myMissions,
  ) {
    if (_selectedFilterIndex == 1) {
      if (pendingMissions.isEmpty) {
        return [
          SliverToBoxAdapter(
            child: _buildEmptyState(
              'Aucune nouvelle demande',
              'Les demandes de dépannage de vos clients apparaîtront ici dès leur envoi.',
              tc,
              isDark,
            ),
          ),
        ];
      }
      return [
        _buildSliverSectionTitle('Demandes en attente (${pendingMissions.length})', tc),
        _buildMissionListSliver(pendingMissions, tc, isDark),
      ];
    } else if (_selectedFilterIndex == 2) {
      if (myMissions.isEmpty) {
        return [
          SliverToBoxAdapter(
            child: _buildEmptyState(
              'Aucune mission en cours',
              'Acceptez une demande en attente pour débuter une intervention.',
              tc,
              isDark,
            ),
          ),
        ];
      }
      return [
        _buildSliverSectionTitle('Interventions actives (${myMissions.length})', tc),
        _buildMissionListSliver(myMissions, tc, isDark),
      ];
    } else if (_selectedFilterIndex == 3) {
      if (_completedMissions.isEmpty) {
        return [
          SliverToBoxAdapter(
            child: _buildEmptyState(
              'Aucune mission archivée',
              'L\'historique de vos interventions terminées ou annulées apparaîtra ici.',
              tc,
              isDark,
            ),
          ),
        ];
      }
      return [
        _buildSliverSectionTitle('Historique (${_completedMissions.length})', tc),
        _buildCompletedListSliver(_completedMissions, tc, isDark),
      ];
    }

    // _selectedFilterIndex == 0 (Toutes)
    final List<Widget> slivers = [];
    if (pendingMissions.isNotEmpty) {
      slivers.add(_buildSliverSectionTitle('Nouvelles Demandes (${pendingMissions.length})', tc));
      slivers.add(_buildMissionListSliver(pendingMissions, tc, isDark));
    }

    slivers.add(_buildSliverSectionTitle('Vos Interventions Actives (${myMissions.length})', tc));
    if (myMissions.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: _buildEmptyState(
            'Aucune intervention active',
            'Vous n\'avez actuellement aucune mission en cours de traitement.',
            tc,
            isDark,
          ),
        ),
      );
    } else {
      slivers.add(_buildMissionListSliver(myMissions, tc, isDark));
    }

    if (_completedMissions.isNotEmpty) {
      slivers.add(_buildSliverSectionTitle('Historique Récent', tc));
      slivers.add(_buildCompletedListSliver(_completedMissions, tc, isDark));
    }

    return slivers;
  }

  // =========================================================================
  // WIDGETS AUXILIAIRES ET CARTES
  // =========================================================================

  Widget _buildSliverSectionTitle(String title, TechLinkColors tc) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Text(
          title,
          style: TextStyle(
            color: tc.textPrimary,
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required TechLinkColors tc,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: tc.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(isDark ? 0.18 : 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: tc.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: tc.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionListSliver(List<Map<String, dynamic>> list, TechLinkColors tc, bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildPremiumMissionCard(list[index], tc, isDark),
          childCount: list.length,
        ),
      ),
    );
  }

  Widget _buildCompletedListSliver(List<Map<String, dynamic>> list, TechLinkColors tc, bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildCompletedMissionCard(list[index], tc, isDark),
          childCount: list.length,
        ),
      ),
    );
  }

  Widget _buildPremiumMissionCard(Map<String, dynamic> mission, TechLinkColors tc, bool isDark) {
    final status = mission['status'] as String? ?? 'pending';
    final isPending = status == 'pending';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        statusColor = const Color(0xFFD97706);
        statusLabel = 'Nouvelle demande';
        statusIcon = Icons.flash_on_rounded;
        break;
      case 'accepted':
      case 'technician_enroute':
        statusColor = const Color(0xFF2563EB);
        statusLabel = 'En route';
        statusIcon = Icons.directions_car_rounded;
        break;
      case 'in_progress':
        statusColor = const Color(0xFF0D9488);
        statusLabel = 'En intervention';
        statusIcon = Icons.engineering_rounded;
        break;
      case 'quote_sent':
      case 'quote_accepted':
        statusColor = const Color(0xFF7C3AED);
        statusLabel = 'Devis rédigé';
        statusIcon = Icons.receipt_long_rounded;
        break;
      case 'completed':
      case 'paid':
        statusColor = const Color(0xFF059669);
        statusLabel = 'Terminée';
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        statusColor = const Color(0xFF2563EB);
        statusLabel = 'Actif';
        statusIcon = Icons.hourglass_top_rounded;
    }

    final category = mission['categories'] as Map<String, dynamic>?;
    final categoryName = category?['name'] as String? ?? 'Dépannage';
    final problem = mission['problem_description']?.toString() ?? 'Aucune description spécifiée';

    final createdAt = mission['created_at'];
    String dateStr = 'Date inconnue';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252526) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending ? statusColor.withOpacity(0.5) : (isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
          width: isPending ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isPending ? statusColor.withOpacity(isDark ? 0.2 : 0.08) : Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: tc.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(color: tc.textSecondary, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            Text(
              problem,
              style: TextStyle(fontSize: 13, color: tc.textPrimary.withOpacity(0.9), height: 1.35),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    PowerPointMorphRoute(
                      builder: (_) => MissionRequestScreen(mission: mission),
                    ),
                  ).then((_) => _loadData());
                },
                icon: Icon(
                  isPending ? Icons.flash_on_rounded : Icons.engineering_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isPending ? 'Voir & Répondre à la demande' : 'Gérer l\'intervention',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                    maxLines: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPending ? const Color(0xFFD97706) : AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedMissionCard(Map<String, dynamic> m, TechLinkColors tc, bool isDark) {
    final status = m['status'] as String? ?? '';
    final isCompleted = status == 'completed' || status == 'paid';
    final statusColor = isCompleted ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final statusText = isCompleted ? 'Terminée' : 'Annulée';
    final categoryName = m['categories']?['name'] as String? ?? 'Mission';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PowerPointMorphRoute(
            builder: (_) => MissionRequestScreen(mission: m),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252526) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryName,
                    style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m['problem_description'] ?? 'Intervention archivée',
                    style: TextStyle(color: tc.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, TechLinkColors tc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252526) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_turned_in_rounded, size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: tc.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: tc.textSecondary, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // STRUCTURE GLOBALE (BUILD)
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>() ?? TechLinkColors.light;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: tc.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // 4 ONGLETS POUR LE TECHNICIEN
    final screens = [
      KeepAliveTab(child: _buildAccueilTab(tc)),
      KeepAliveTab(child: _buildMissionsTab(tc)),
      const KeepAliveTab(child: TechnicianMessagesListScreen()),
      const KeepAliveTab(child: ProfileScreen()),
    ];

    Widget bodyContent = PinterestFluidBackground(
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: screens,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        if (isDesktop) {
          return Scaffold(
            backgroundColor: const Color(0xFF4A148C),
            body: Row(
              children: [
                CustomDesktopSidebar(
                  tc: tc,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _switchTab,
                  destinations: const [
                    DesktopSidebarItem(icon: Icons.home_outlined, label: 'Accueil'),
                    DesktopSidebarItem(icon: Icons.assignment_outlined, label: 'Missions'),
                    DesktopSidebarItem(icon: Icons.chat_bubble_outline_rounded, label: 'Messages'),
                    DesktopSidebarItem(icon: Icons.person_outline, label: 'Profil'),
                  ],
                ),
                Expanded(
                  child: Container(
                    color: tc.background,
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
          bottomNavigationBar: _buildBottomNav(tc, isDark),
        );
      },
    );
  }

  Widget _buildBottomNav(TechLinkColors tc, bool isDark) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 75 + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? tc.card : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildJumpingNavItem(Icons.home, Icons.home_outlined, 0, tc, isDark),
          _buildJumpingNavItem(Icons.assignment, Icons.assignment_outlined, 1, tc, isDark),
          _buildJumpingNavItem(Icons.chat_bubble, Icons.chat_bubble_outline, 2, tc, isDark),
          _buildJumpingNavItem(Icons.person, Icons.person_outline, 3, tc, isDark),
        ],
      ),
    );
  }

  Widget _buildJumpingNavItem(
    IconData filledIcon,
    IconData outlinedIcon,
    int index,
    TechLinkColors tc,
    bool isDark,
  ) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              top: isSelected ? 5 : 25,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Icon(
                  isSelected ? filledIcon : outlinedIcon,
                  color: isSelected ? Colors.white : tc.textSecondary,
                  size: 24,
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isSelected ? 1.0 : 0.0,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRail(TechLinkColors tc, bool isDark) {
    return NavigationRail(
      extended: MediaQuery.of(context).size.width >= 1000,
      selectedIndex: _currentIndex,
      onDestinationSelected: _switchTab,
      backgroundColor: tc.surface,
      selectedIconTheme: const IconThemeData(color: AppColors.primary),
      unselectedIconTheme: IconThemeData(color: tc.textSecondary),
      selectedLabelTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      unselectedLabelTextStyle: TextStyle(color: tc.textSecondary),
      labelType: MediaQuery.of(context).size.width >= 1000 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: Text('Accueil')),
        NavigationRailDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: Text('Missions')),
        NavigationRailDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded), label: Text('Messages')),
        NavigationRailDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: Text('Profil')),
      ],
    );
  }
}
