import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';

// =========================================================================
// ÉCRAN DE LA CARTE DES TECHNICIENS
// =========================================================================
// Affiche la liste des techniciens qualifiés pour la mission demandée,
// triés par distance depuis la position GPS du client.

class TechniciansMapScreen extends StatefulWidget {
  final String missionId;
  final Map<String, dynamic> aiResult;

  const TechniciansMapScreen({
    super.key,
    required this.missionId,
    required this.aiResult,
  });

  @override
  State<TechniciansMapScreen> createState() => _TechniciansMapScreenState();
}

class _TechniciansMapScreenState extends State<TechniciansMapScreen> {
  List<Map<String, dynamic>> _allTechs = [];          // tous les techniciens chargés
  List<Map<String, dynamic>> _filteredTechs = [];     // après filtre texte
  bool _isLoading = true;
  Position? _clientPosition;
  String _categorySlug = '';
  String _categoryName = '';

  // Contrôleur pour la recherche
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final ScrollController _scrollController = ScrollController();
  int _offset = 0;
  static const int _limit = 100;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _categorySlug = widget.aiResult['category_slug'] as String? ?? '';
    _categoryName = widget.aiResult['category'] as String? ?? 'votre service';
    _scrollController.addListener(_onScroll);
    _loadTechnicians(refresh: true);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadTechnicians();
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredTechs = List.from(_allTechs);
    } else {
      _filteredTechs = _allTechs.where((t) {
        final user = t['users'] as Map<String, dynamic>?;
        final name = (user?['name'] as String? ?? '').toLowerCase();
        final specs = (t['specialties'] as List? ?? [])
            .map((s) => s.toString().toLowerCase())
            .join(' ');
        return name.contains(_searchQuery) || specs.contains(_searchQuery);
      }).toList();
    }
    // On garde le tri par distance
    _filteredTechs.sort((a, b) {
      final da = (a['distance_km'] as num?)?.toDouble() ?? 9999;
      final db = (b['distance_km'] as num?)?.toDouble() ?? 9999;
      return da.compareTo(db);
    });
  }

  String? _gpsError;

  Future<void> _loadTechnicians({bool refresh = false}) async {
    if (refresh) {
      _offset = 0;
      _hasMore = true;
      _allTechs.clear();
      if (mounted) setState(() => _isLoading = true);
    } else {
      if (!_hasMore || _isLoadingMore) return;
      if (mounted) setState(() => _isLoadingMore = true);
    }

    try {
      // Position GPS (seulement à l'initialisation)
      if (refresh && _clientPosition == null) {
        try {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
            _clientPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 15),
            );
            _gpsError = null;
          } else {
            _gpsError = 'Permission $permission';
          }
        } catch (e) {
          print('Erreur GPS : $e');
          _gpsError = e.toString();
        }
      }

      // Charger les techniciens approuvés par lot de 20
      final data = await Supabase.instance.client
          .from('technicians')
          .select('*, users(id, name, phone, avatar_url)')
          .eq('validation_status', 'approved')
          .eq('is_verified', true)
          .eq('subscription_status', 'active')
          .gte('subscription_end_date', DateTime.now().toIso8601String())
          .range(_offset, _offset + _limit - 1);

      List<Map<String, dynamic>> newTechs =
          List<Map<String, dynamic>>.from(data);

      if (newTechs.length < _limit) {
        _hasMore = false;
      }

      // Calculer distance si GPS disponible
      for (var t in newTechs) {
        final lat = (t['current_lat'] as num?)?.toDouble();
        final lng = (t['current_lng'] as num?)?.toDouble();

        if (_clientPosition != null && lat != null && lng != null) {
          final dist = Geolocator.distanceBetween(
            _clientPosition!.latitude,
            _clientPosition!.longitude,
            lat, lng,
          );
          t['distance_km'] = dist / 1000;
        } else {
          t['distance_km'] = null;
        }
      }

      // Marquer ceux qui correspondent à la catégorie
      for (var t in newTechs) {
        final specs = List<String>.from(t['specialties'] as List? ?? []);
        final matches = _categorySlug.isEmpty || _categorySlug == 'general' ||
            specs.any((s) {
              final cleanS = s.trim().toLowerCase();
              if (cleanS.isEmpty) return false;
              if (cleanS == _categorySlug) return true;
              return _slugMatchesSpec(cleanS);
            });
        t['matches_category'] = matches;
      }

      // EXCLURE les techniciens qui ne correspondent pas à la catégorie demandée
      newTechs.removeWhere((t) => !(t['matches_category'] as bool));

      if (mounted) {
        setState(() {
          _allTechs.addAll(newTechs);
          _offset += newTechs.length;
          _applyFilter();
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

  bool _slugMatchesSpec(String spec) {
    // spec est déjà en minuscules et trim()
    final slug = _categorySlug.toLowerCase();
    const mapping = {
      'electricite': ['electr', 'electric', 'courant'],
      'plomberie': ['plomb', 'eau', 'tuyau'],
      'climatisation': ['clim', 'ventil', 'froid'],
      'informatique': ['info', 'pc', 'reseau', 'wifi'],
      'menuiserie': ['menuis', 'bois', 'porte'],
      'peinture': ['peint', 'decor'],
      'electromenager': ['electrom', 'appareil'],
      'maconnerie': ['macon', 'beton', 'carrel'],
    };
    final keys = mapping[slug] ?? [slug];
    // On vérifie si la spécialité contient un des mots-clés forts
    return keys.any((k) => spec.contains(k));
  }

  // Méthode pour ouvrir le profil et attendre le résultat
  Future<bool?> _navigateToProfile(Map<String, dynamic> technician) async {
    final result = await context.push('/client/technician-profile', extra: {
        'technician': technician,
        'missionId': widget.missionId,
      },);
    return result as bool?;
  }

  // Méthode pour sélectionner le technicien (identique à celle du profil)
  Future<void> _selectTechnician(Map<String, dynamic> technician) async {
  final user = technician['users'] as Map<String, dynamic>?;
  final name = user?['name'] as String? ?? 'Technicien';

  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Confirmer le technicien'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: AppColors.technicianColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold,
                  color: AppColors.technicianColor)),
            ),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Voulez-vous envoyer votre demande à ce technicien ?',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Confirmer')),
      ],
    ),
  );

  if (confirm != true || !mounted) return;

  // Afficher loader
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    // Récupérer les bons IDs
    final technicianUserId = user?['id'] as String?;
    final technicianTableId = technician['id'] as String?;

    print('DEBUG — missionId: ${widget.missionId}');
    print('DEBUG — technicianUserId: $technicianUserId');
    print('DEBUG — technicianTableId: $technicianTableId');

    if (widget.missionId.isEmpty) {
      throw Exception('Mission ID manquant');
    }
    if (technicianUserId == null) {
      throw Exception('ID technicien manquant');
    }

    // Mettre à jour la mission avec le user_id du technicien
    final result = await Supabase.instance.client
        .from('missions')
        .update({
          'technician_id': technicianUserId,
          'status': 'accepted',
          'accepted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', widget.missionId)
        .select()
        .single();

    print('DEBUG — Mission mise à jour: $result');

    // Créer la mission_request
    try {
      await Supabase.instance.client
          .from('mission_requests')
          .insert({
            'mission_id': widget.missionId,
            'technician_id': technicianTableId ?? technicianUserId,
            'status': 'accepted',
            'responded_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('DEBUG — mission_requests ignoré: $e');
    }

    if (mounted) {
      context.pop(); // ferme loader
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Technicien assigné !'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(
          context, '/client/home', (r) => false);
    }
  } catch (e) {
    if (mounted) {
      context.pop(); // ferme loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Trouver le premier technicien qui correspond à la catégorie
    final firstMatchingTechId = _filteredTechs.firstWhere(
      (t) => t['matches_category'] == true,
      orElse: () => <String, dynamic>{},
    )['id'];

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        backgroundColor: tc.background,
        title: Text('Trouver un technicien', style: TextStyle(color: tc.textPrimary)),
        iconTheme: IconThemeData(color: tc.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTechnicians,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: tc.textPrimary),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou spécialité...',
                hintStyle: TextStyle(color: tc.textSecondary),
                prefixIcon: Icon(Icons.search, color: tc.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? tc.surface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredTechs.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadTechnicians,
                  child: CustomScrollView(
                    slivers: [
                      // Bannière GPS
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _clientPosition != null
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _clientPosition != null
                                    ? AppColors.success.withOpacity(0.3)
                                    : AppColors.warning.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _clientPosition != null
                                      ? Icons.gps_fixed
                                      : Icons.gps_off,
                                  color: _clientPosition != null
                                      ? AppColors.success
                                      : AppColors.warning,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _clientPosition != null
                                        ? '📍 Techniciens triés par distance de votre position'
                                        : '⚠️ Localisation GPS indisponible. ${_gpsError ?? "Tri standard par défaut."}',
                                    style: TextStyle(
                                      color: _clientPosition != null
                                          ? AppColors.success
                                          : AppColors.warning,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // En-tête : infos catégorie
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? tc.primaryLight : AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.filter_list,
                                  color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Catégorie : $_categoryName • ${_filteredTechs.length} résultat(s)',
                                  style: TextStyle(
                                    color: isDark ? tc.textPrimary : AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Section : À proximité (distance < 5 km)
                      if (_filteredTechs.any((t) => ((t['distance_km'] as num?)?.toDouble()) != null && ((t['distance_km'] as num?)!.toDouble()) < 5))
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            icon: Icons.near_me,
                            title: 'À proximité (moins de 5 km)',
                            color: AppColors.success,
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final tech = _filteredTechs[i];
                              final dist = (tech['distance_km'] as num?)?.toDouble();
                              if (dist == null || dist >= 5) return const SizedBox.shrink();
                              return _TechnicianCard(
                                technician: tech,
                                isRecommended: tech['id'] == firstMatchingTechId,
                                onViewProfile: () => _navigateToProfile(tech),
                                onSelect: () => _selectTechnician(tech),
                              );
                            },
                            childCount: _filteredTechs.length,
                          ),
                        ),
                      ),

                      // Section : Proche (5 - 15 km)
                      if (_filteredTechs.any((t) => ((t['distance_km'] as num?)?.toDouble()) != null && ((t['distance_km'] as num?)!.toDouble()) >= 5 && ((t['distance_km'] as num?)!.toDouble()) < 15))
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            icon: Icons.directions_car,
                            title: 'Proche (5 - 15 km)',
                            color: AppColors.warning,
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final tech = _filteredTechs[i];
                              final dist = (tech['distance_km'] as num?)?.toDouble();
                              if (dist == null || dist < 5 || dist >= 15) return const SizedBox.shrink();
                              return _TechnicianCard(
                                technician: tech,
                                isRecommended: tech['id'] == firstMatchingTechId,
                                onViewProfile: () => _navigateToProfile(tech),
                                onSelect: () => _selectTechnician(tech),
                              );
                            },
                            childCount: _filteredTechs.length,
                          ),
                        ),
                      ),

                      // Section : Éloignés ou sans GPS
                      if (_filteredTechs.any((t) {
                        final dist = (t['distance_km'] as num?)?.toDouble();
                        return dist == null || dist >= 15;
                      }))
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            icon: Icons.people_outline,
                            title: 'Éloigné (plus de 15 km) ou sans GPS',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final tech = _filteredTechs[i];
                              final dist = (tech['distance_km'] as num?)?.toDouble();
                              if (dist != null && dist < 15) return const SizedBox.shrink();
                              return _TechnicianCard(
                                technician: tech,
                                isRecommended: tech['id'] == firstMatchingTechId,
                                onViewProfile: () => _navigateToProfile(tech),
                                onSelect: () => _selectTechnician(tech),
                              );
                            },
                            childCount: _filteredTechs.length,
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
                ),
    );
  }
  Widget _buildEmpty() {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.engineering_outlined,
                size: 56,
                color: AppColors.warning.withOpacity(0.8)),
            ),
            const SizedBox(height: 24),
            Text('Aucun technicien disponible',
              style: TextStyle(
                color: tc.textPrimary,
                fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Votre mission a été enregistrée ✓\nVous pourrez chercher un technicien depuis l\'onglet Missions dès qu\'un technicien sera disponible.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tc.textSecondary,
                fontSize: 14, height: 1.6)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, '/client/home', (r) => false),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Voir mes missions'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadTechnicians,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SECTION HEADER (réutilisé) ──
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color)),
        ],
      ),
    );
  }
}

// ── CARTE TECHNICIEN (avec onViewProfile et onSelect) ──
class _TechnicianCard extends StatelessWidget {
  final Map<String, dynamic> technician;
  final Future<bool?> Function() onViewProfile;
  final VoidCallback onSelect;
  final bool isRecommended;

  const _TechnicianCard({
    required this.technician,
    required this.onViewProfile,
    required this.onSelect,
    this.isRecommended = false,
  });

  Color _getDistanceColor(double? dist) {
    if (dist == null) return AppColors.textSecondary;
    if (dist < 3.0) return AppColors.success;
    if (dist < 15.0) return AppColors.warning;
    return AppColors.textSecondary;
  }

  Widget _buildDistanceBadge(double? dist) {
    if (dist == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.textSecondary.withOpacity(0.2), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, color: AppColors.textSecondary, size: 12),
            SizedBox(width: 4),
            Text(
              'Non localisé',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    final color = _getDistanceColor(dist);
    final text = dist < 1.0
        ? '${(dist * 1000).toStringAsFixed(0)} m'
        : '${dist.toStringAsFixed(1)} km';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = technician['users'] as Map<String, dynamic>?;
    final name = user?['name'] as String? ?? 'Technicien';
    final specialties =
        List<String>.from(technician['specialties'] as List? ?? []);
    final rating =
        (technician['rating_average'] as num?)?.toDouble() ?? 0.0;
    final totalMissions = (technician['total_missions'] as num?)?.toInt() ?? 0;
    final distanceKm = (technician['distance_km'] as num?)?.toDouble();
    final avail = technician['availability'] is Map ? technician['availability'] as Map : null;
    final isAvailable = technician['status'] != 'offline' && (avail?['is_available'] != false);

    return GestureDetector(
      onTap: () async {
        final confirmed = await onViewProfile();
        if (confirmed == true) {
          onSelect();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 130,
        decoration: BoxDecoration(
          color: isDark ? tc.card : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tc.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ================== CÔTÉ GAUCHE (PHOTO DE PROFIL PLEINE HAUTEUR) ==================
            Container(
              width: 110,
              decoration: BoxDecoration(
                color: AppColors.technicianColor.withOpacity(0.15),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                image: (user?['avatar_url'] != null && user!['avatar_url'].toString().isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(user['avatar_url']),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (user?['avatar_url'] == null || user!['avatar_url'].toString().isEmpty)
                  ? Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'T',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.technicianColor),
                      ),
                    )
                  : null,
            ),
            
            // ================== CÔTÉ DROIT (DÉTAILS) ==================
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: tc.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? const Color(0xFF059669).withOpacity(0.12)
                                : const Color(0xFFEF4444).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 6, color: isAvailable ? const Color(0xFF059669) : const Color(0xFFEF4444)),
                              const SizedBox(width: 4),
                              Text(
                                isAvailable ? 'En ligne' : 'Occupé',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isAvailable ? const Color(0xFF059669) : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🥇 ', style: TextStyle(fontSize: 10)),
                                Text(
                                  'Recommandé',
                                  style: TextStyle(color: Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    // Spécialités (max 2)
                    if (specialties.isNotEmpty)
                      Wrap(
                        spacing: 4, runSpacing: 4,
                        children: specialties.take(2).map((s) =>
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? tc.primaryLight : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(s,
                              style: TextStyle(
                                color: isDark ? tc.textPrimary : AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                          )
                        ).toList(),
                      ),
                      
                    // Bio ou description
                    const SizedBox(height: 6),
                    Text(
                      technician['bio']?.toString().isNotEmpty == true 
                          ? technician['bio'].toString() 
                          : 'Technicien vérifié prêt à intervenir rapidement.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tc.textSecondary, fontSize: 11, height: 1.3),
                    ),
                    
                    const Spacer(),
                    
                    // Stats & Distance
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (rating > 0) ...[
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Color(0xFFFBBF24), size: 14),
                                  const SizedBox(width: 2),
                                  Text(rating.toStringAsFixed(1), style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text('$totalMissions missions', style: TextStyle(color: tc.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const Spacer(),
                        _buildDistanceBadge(distanceKm),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
