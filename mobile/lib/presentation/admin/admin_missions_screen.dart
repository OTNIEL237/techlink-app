// =============================================================================
// FICHIER : admin_missions_screen.dart
// RÔLE : Supervision, filtrage multi-critères et pagination de toutes les missions
// MODULE : Presentation / Admin
// DÉPENDANCES : flutter/material.dart, flutter_riverpod, app_colors.dart, theme_provider.dart, mission_provider.dart, admin_mission_detail_screen.dart
// SÉCURITÉ / RLS : Rôle administrateur requis. Lecture globale paginée de la table `missions`.
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../providers/mission_provider.dart';
import 'admin_mission_detail_screen.dart';

/// Écran administrateur dédié au suivi opérationnel de l'ensemble des missions.
///
/// Intègre une barre de recherche rapide, des filtres par statut d'intervention
/// (toutes, en attente, en cours, terminées, annulées), et une pagination dynamique.
class AdminMissionsScreen extends ConsumerStatefulWidget {
  /// Constructeur constant du widget [AdminMissionsScreen].
  const AdminMissionsScreen({super.key});

  @override
  ConsumerState<AdminMissionsScreen> createState() => _AdminMissionsScreenState();
}

/// État associé à l'écran de supervision des missions administratives.
///
/// Synchronise les requêtes paginées avec [missionListNotifierProvider] et gère l'anti-rebond de recherche.
class _AdminMissionsScreenState extends ConsumerState<AdminMissionsScreen> {
  /// Filtre de statut actif ('all', 'pending', 'in_progress', 'completed', 'cancelled').
  String _statusFilter = 'all';

  /// Chaîne de recherche saisie par l'administrateur.
  String _searchQuery = '';

  /// Colonne de tri actif dans la requête.
  String _sortBy = 'created_at';

  /// Ordre de tri (ascendant ou descendant).
  bool _isAscending = false;

  /// Index de la page courante.
  int _currentPage = 0;

  /// Nombre de missions chargées par page.
  final int _itemsPerPage = 10;

  /// Indique si d'autres missions restent à charger.
  bool _hasMore = true;

  /// Minuteur pour temporiser les requêtes de recherche.
  Timer? _debounce;

  /// Contrôleur du champ de saisie de recherche.
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  /// Libère les ressources du contrôleur et du minuteur.
  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Déclenche la récupération des missions via [missionListNotifierProvider].
  Future<void> _loadMissions({bool resetPage = false}) async {
    if (resetPage) {
      setState(() {
        _currentPage = 0;
        _hasMore = true;
      });
    }

    if (!mounted) return;

    final oldLength = ref.read(missionListNotifierProvider).value?.length ?? 0;

    await ref.read(missionListNotifierProvider.notifier).fetch(
      statusFilter: _statusFilter,
      searchQuery: _searchQuery,
      sortBy: _sortBy,
      isAscending: _isAscending,
      page: _currentPage,
      append: !resetPage,
    );

    final newLength = ref.read(missionListNotifierProvider).value?.length ?? 0;
    if (mounted) {
      setState(() {
        _hasMore = (newLength - oldLength) == _itemsPerPage;
      });
    }
  }

  /// Applique un anti-rebond de 400ms avant de relancer la recherche de missions.
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (_searchQuery != query) {
        setState(() => _searchQuery = query);
        _loadMissions(resetPage: true);
      }
    });
  }

  /// Construit la vue de supervision des missions avec barre de recherche, filtres et cartes détaillées.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: BoxDecoration(
                color: isDark ? tc.surface : Colors.white,
                border: Border(bottom: BorderSide(color: tc.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.assignment_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gestion des Missions',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: tc.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Interventions & prestations sur la plateforme',
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
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Rafraîchir',
                        icon: Icon(Icons.refresh_rounded, color: tc.textSecondary),
                        onPressed: () => _loadMissions(resetPage: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search + Sort Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? tc.background : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tc.border),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            style: TextStyle(color: tc.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Rechercher une mission...',
                              hintStyle: TextStyle(color: tc.textSecondary, fontSize: 13),
                              prefixIcon: Icon(Icons.search_rounded, size: 20, color: tc.textSecondary),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? tc.background : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: tc.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            dropdownColor: isDark ? tc.surface : Colors.white,
                            icon: Icon(Icons.sort_rounded, size: 18, color: tc.textSecondary),
                            style: TextStyle(
                              color: tc.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            onChanged: (String? val) {
                              if (val != null) {
                                setState(() {
                                  _sortBy = val;
                                  _isAscending = val == 'status';
                                });
                                _loadMissions(resetPage: true);
                              }
                            },
                            items: const [
                              DropdownMenuItem(value: 'created_at', child: Text('Récent')),
                              DropdownMenuItem(value: 'status', child: Text('Statut')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Horizontal Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill('Toutes', 'all', tc, isDark),
                        const SizedBox(width: 8),
                        _buildFilterPill('En attente', 'pending', tc, isDark),
                        const SizedBox(width: 8),
                        _buildFilterPill('En cours', 'in_progress', tc, isDark),
                        const SizedBox(width: 8),
                        _buildFilterPill('Devis', 'quote_sent', tc, isDark),
                        const SizedBox(width: 8),
                        _buildFilterPill('Terminées', 'completed', tc, isDark),
                        const SizedBox(width: 8),
                        _buildFilterPill('Annulées', 'cancelled', tc, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Missions List
            Expanded(
              child: ref.watch(missionListNotifierProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text('Erreur: $err', style: TextStyle(color: tc.textSecondary)),
                ),
                data: (missions) {
                  if (missions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_late_outlined, size: 56, color: tc.textSecondary.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'Aucune mission trouvée',
                            style: TextStyle(
                              color: tc.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Modifiez vos filtres ou relancez la recherche.',
                            style: TextStyle(color: tc.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: missions.length + 1,
                    itemBuilder: (context, index) {
                      if (index == missions.length) {
                        return _hasMore
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() => _currentPage++);
                                      _loadMissions();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: AppColors.primary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Charger 10 de plus'),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink();
                      }

                      final m = missions[index];
                      return _buildMissionCard(m, tc, isDark);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit une pastille interactive pour filtrer les interventions par état d'avancement.
  Widget _buildFilterPill(String label, String value, TechLinkColors tc, bool isDark) {
    final isSelected = _statusFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _statusFilter = value);
        _loadMissions(resetPage: true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? tc.background : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
              ? AppColors.primary
              : (isDark ? tc.border : Colors.grey.shade300),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : tc.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Construit la carte synthétique d'une mission avec ses protagonistes, son prix et son statut.
  Widget _buildMissionCard(Map<String, dynamic> m, TechLinkColors tc, bool isDark) {
    final clientName = m['clients']?['name'] ?? 'Client non spécifié';
    final techName = m['technicians']?['name'] ?? 'Non assigné';
    final category = m['categories']?['name'] ?? 'Prestation';
    final description = m['description'] ?? 'Aucune description';
    final price = (m['price'] as num?)?.toDouble() ?? 0.0;
    final status = m['status'] ?? 'pending';

    final (statusColor, statusLabel) = _getStatusConfig(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? tc.card : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tc.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminMissionDetailScreen(mission: m),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag Row: Category + Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.build_circle_outlined, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description Title
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: tc.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Client & Tech Row
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? tc.background : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFF3B82F6).withOpacity(0.2),
                              child: const Icon(Icons.person, size: 14, color: Color(0xFF3B82F6)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                clientName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tc.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 20, width: 1, color: tc.border),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                              child: const Icon(Icons.engineering, size: 14, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                techName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: techName == 'Non assigné' ? tc.textSecondary : tc.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom Row: Price & Details button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Montant',
                          style: TextStyle(fontSize: 10, color: tc.textSecondary),
                        ),
                        Text(
                          price > 0 ? '${price.toStringAsFixed(0)} FCFA' : 'Sur devis',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: price > 0 ? AppColors.primary : tc.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Détails',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Associe une couleur d'alerte et un libellé français lisible au code technique de statut.
  (Color, String) _getStatusConfig(String status) {
    switch (status) {
      case 'pending':
        return (const Color(0xFFF59E0B), 'EN ATTENTE');
      case 'accepted':
      case 'technician_enroute':
      case 'in_progress':
        return (const Color(0xFF3B82F6), 'EN COURS');
      case 'quote_sent':
        return (const Color(0xFF8B5CF6), 'DEVIS ENVOYÉ');
      case 'completed':
      case 'paid':
        return (const Color(0xFF10B981), 'TERMINÉE');
      case 'cancelled':
        return (const Color(0xFFEF4444), 'ANNULÉE');
      default:
        return (Colors.grey, status.toUpperCase());
    }
  }
}
