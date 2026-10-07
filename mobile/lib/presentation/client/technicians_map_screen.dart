// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : technicians_map_screen.dart
// Rôle          : Écran de recherche et sélection des techniciens qualifiés
//                 pour une mission, triés par distance géographique (GPS).
// Module        : Présentation Client (Missions & Matching)
// Dépendances   : flutter/material.dart, go_router, supabase_flutter, geolocator,
//                 app_colors.dart
// Sécurité/RLS  : Filtrage des techniciens vérifiés, approuvés et actifs.
//                 Assignation sécurisée de la mission via Supabase.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';

/// Écran affichant les techniciens qualifiés et disponibles pour une mission donnée.
/// Permet la recherche textuelle, le tri par distance GPS et l'assignation directe.
class TechniciansMapScreen extends StatefulWidget {
  /// Identifiant unique de la mission concernée
  final String missionId;

  /// Résultat de l'analyse préliminaire par l'IA (catégorie, description, urgence)
  final Map<String, dynamic> aiResult;

  /// Constructeur de l'écran des techniciens disponibles
  const TechniciansMapScreen({
    super.key,
    required this.missionId,
    required this.aiResult,
  });

  @override
  State<TechniciansMapScreen> createState() => _TechniciansMapScreenState();
}

class _TechniciansMapScreenState extends State<TechniciansMapScreen> {
  /// Liste complète de tous les techniciens chargés depuis la base de données
  List<Map<String, dynamic>> _allTechs = [];

  /// Liste des techniciens après application du filtre de recherche textuel
  List<Map<String, dynamic>> _filteredTechs = [];

  /// Indicateur de chargement initial des données
  bool _isLoading = true;

  /// Coordonnées GPS actuelles de l'utilisateur client
  Position? _clientPosition;

  /// Identifiant textuel de la catégorie requise pour le service
  String _categorySlug = '';

  /// Nom d'affichage de la catégorie du service
  String _categoryName = '';

  /// Contrôleur du champ de saisie de recherche textuelle
  final TextEditingController _searchController = TextEditingController();

  /// Terme de recherche actuellement saisi par l'utilisateur
  String _searchQuery = '';

  /// Contrôleur de défilement pour la pagination infinie
  final ScrollController _scrollController = ScrollController();

  /// Index de décalage pour la pagination Supabase
  int _offset = 0;

  /// Nombre maximal d'enregistrements récupérés par requête
  static const int _limit = 100;

  /// Indique s'il reste d'autres techniciens à charger en pagination
  bool _hasMore = true;

  /// Indicateur de chargement d'une page supplémentaire
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

  /// Détecte lorsque le défilement approche du bas pour déclencher la pagination
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadTechnicians();
    }
  }

  /// Réagit au changement de texte dans la barre de recherche
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _applyFilter();
    });
  }

  /// Filtre les techniciens par nom ou spécialités, en conservant le tri par proximité
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

  /// Message d'erreur éventuel lié à la permission ou géolocalisation GPS
  String? _gpsError;

  /// Charge les techniciens depuis Supabase, calcule les distances GPS et filtre par spécialité.
  /// 
  /// [refresh] : Indique s'il s'agit d'une réinitialisation complète de la liste.
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

  /// Détermine si une spécialité textuelle correspond aux mots-clés du domaine demandé.
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

  /// Ouvre la vue détaillée du profil du technicien sélectionné et attend un retour de confirmation.
  Future<bool?> _navigateToProfile(Map<String, dynamic> technician) async {
    final result = await context.push('/client/technician-profile', extra: {
        'technician': technician,
        'missionId': widget.missionId,
      },);
    return result as bool?;
  }

  /// Assigne le technicien sélectionné à la mission courante après confirmation de l'utilisateur.
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
  /// Construit la vue affichée lorsqu'aucun technicien n'est disponible pour la catégorie.
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

/// En-tête de section avec icône, titre et couleur thématique (ex: Proximité, Éloigné).
class _SectionHeader extends StatelessWidget {
  /// Icône illustrative de la catégorie de distance
  final IconData icon;

  /// Libellé du groupe de distance
  final String title;

  /// Couleur d'accentuation de la section
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

/// Carte interactive présentant un technicien avec ses coordonnées, note, spécialités et distance.
class _TechnicianCard extends StatelessWidget {
  /// Données brutes du technicien et de son utilisateur associé
  final Map<String, dynamic> technician;

  /// Callback déclenché pour ouvrir le profil complet du technicien
  final Future<bool?> Function() onViewProfile;

  /// Action de confirmation et d'assignation du technicien
  final VoidCallback onSelect;

  /// Indique si ce technicien est mis en avant / recommandé par l'algorithme
  final bool isRecommended;

  const _TechnicianCard({
    required this.technician,
    required this.onViewProfile,
    required this.onSelect,
    this.isRecommended = false,
  });

  /// Retourne la couleur représentative du palier de distance
  Color _getDistanceColor(double? dist) {
    if (dist == null) return AppColors.textSecondary;
    if (dist < 3.0) return AppColors.success;
    if (dist < 15.0) return AppColors.warning;
    return AppColors.textSecondary;
  }

  /// Génère le badge visuel indiquant la distance en kilomètres ou mètres
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
