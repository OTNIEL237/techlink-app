// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : mission_active_screen.dart
// Rôle          : Écran d'affichage des archives de missions pour le technicien
//                 (missions terminées ou annulées) avec pagination infinie.
// Module        : Présentation Technicien (Missions & Historique)
// Dépendances   : flutter/material.dart, supabase_flutter, app_colors.dart
// Sécurité/RLS  : Filtrage par `technician_id` correspondant à l'utilisateur connecté.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

/// Écran listant les missions passées (achevées ou annulées) avec pagination.
class MissionArchiveScreen extends StatefulWidget {
  /// Constructeur constant de l'écran d'archives de missions
  const MissionArchiveScreen({super.key});

  @override
  State<MissionArchiveScreen> createState() => _MissionArchiveScreenState();
}

class _MissionArchiveScreenState extends State<MissionArchiveScreen> {
  /// Liste des enregistrements de missions archivées
  List<Map<String, dynamic>> _missions = [];

  /// Indicateur de chargement initial des archives
  bool _isLoading = true;

  /// Contrôleur de défilement pour la pagination infinie
  final ScrollController _scrollController = ScrollController();

  /// Indicateur de chargement d'une page supplémentaire d'archives
  bool _isLoadingMore = false;

  /// Indique si d'autres archives sont disponibles sur le serveur
  bool _hasMore = true;

  /// Numéro de la page courante
  int _page = 0;

  /// Nombre d'archives chargées par page
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadArchives();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Détecte lorsque le défilement atteint le bas pour charger la page suivante
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreArchives();
    }
  }

  /// Charge le premier lot de missions archivées depuis Supabase
  Future<void> _loadArchives() async {
    setState(() {
      _isLoading = true;
      _page = 0;
      _hasMore = true;
      _missions = [];
    });
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('missions')
          .select('*, categories(name)')
          .eq('technician_id', userId)
          .inFilter('status', ['completed', 'cancelled'])
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);

      if (mounted) {
        setState(() {
          _missions = List<Map<String, dynamic>>.from(data);
          _hasMore = data.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Charge le lot suivant de missions archivées pour la pagination infinie
  Future<void> _loadMoreArchives() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      _page++;
      final data = await Supabase.instance.client
          .from('missions')
          .select('*, categories(name)')
          .eq('technician_id', userId)
          .inFilter('status', ['completed', 'cancelled'])
          .order('created_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);

      if (mounted) {
        setState(() {
          _missions.addAll(List<Map<String, dynamic>>.from(data));
          _hasMore = data.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        backgroundColor: tc.background,
        title: Text('Archives', style: TextStyle(color: tc.textPrimary)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _missions.isEmpty
              ? Center(
                  child: Text('Aucune mission archivée',
                    style: TextStyle(color: tc.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _loadArchives,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _missions.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _missions.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final m = _missions[index];
                      final status = m['status'] as String? ?? '';
                      final isCompleted = status == 'completed';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: tc.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: tc.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? AppColors.success.withOpacity(0.1)
                                    : AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isCompleted
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: isCompleted
                                    ? AppColors.success
                                    : AppColors.error,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m['categories']?['name']
                                            as String? ??
                                        'Mission',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: tc.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    m['problem_description']
                                            as String? ??
                                        '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tc.textSecondary,
                                      fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? AppColors.success.withOpacity(0.1)
                                    : AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isCompleted ? 'Terminée' : 'Annulée',
                                style: TextStyle(
                                  color: isCompleted
                                      ? AppColors.success
                                      : AppColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}