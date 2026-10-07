// =============================================================================
// FICHIER : technician_validation_screen.dart
// RÔLE : Modération et validation des dossiers techniciens (en attente, approuvés, rejetés)
// MODULE : Présentation Administrateur (Admin Technician Validation)
// DÉPENDANCES : flutter/material.dart, go_router, supabase_flutter, app_colors.dart, technician_detail_screen.dart
// SÉCURITÉ / RLS : Réservé aux administrateurs (rôle admin requis)
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import 'technician_detail_screen.dart';

/// Écran administrateur dédié à la liste et à la modération rapide des techniciens.
///
/// Permet de filtrer par statut de vérification (`pending`, `approved`, `rejected`, `all`),
/// de rechercher un technicien par son nom, et d'approuver ou rejeter rapidement son inscription.
class TechnicianValidationScreen extends StatefulWidget {
  /// Filtre initial appliqué aux techniciens ('all', 'pending', 'approved', 'rejected').
  final String filter;

  /// Indique si l'AppBar standard doit être affichée (désactivée en mode onglet intégré).
  final bool showAppBar;

  /// Constructeur de [TechnicianValidationScreen].
  const TechnicianValidationScreen({super.key, required this.filter, this.showAppBar = true});

  @override
  State<TechnicianValidationScreen> createState() =>
      _TechnicianValidationScreenState();
}

/// État associé à l'écran de modération des techniciens.
class _TechnicianValidationScreenState
    extends State<TechnicianValidationScreen> {
  /// Liste paginée des techniciens chargés depuis Supabase.
  List<Map<String, dynamic>> _technicians = [];

  /// Indicateur d'état de chargement asynchrone des données.
  bool _isLoading = true;

  /// Filtre actif sélectionné par l'administrateur.
  late String _currentFilter;

  /// Terme de recherche textuelle saisi dans la barre de recherche.
  String _searchQuery = '';

  /// Colonne utilisée pour trier les résultats ('created_at' ou 'experience_years').
  String _sortBy = 'created_at';

  /// Ordre de tri (croissant ou décroissant).
  bool _isAscending = false;

  /// Index de page courant pour la pagination par curseur/offset.
  int _currentPage = 0;

  /// Nombre d'éléments retournés par page.
  final int _itemsPerPage = 10;

  /// Indique si d'autres enregistrements peuvent être chargés.
  bool _hasMore = true;

  /// Minuteur anti-rebond (debounce) pour la recherche instantanée.
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.filter;
    _loadTechnicians();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Charge ou recharge les techniciens depuis Supabase selon les filtres, le tri et la pagination.
  ///
  /// [resetPage] : Si vrai, réinitialise le curseur de page à 0 et vide la liste existante.
  Future<void> _loadTechnicians({bool resetPage = false}) async {
    if (resetPage) {
      _currentPage = 0;
      _hasMore = true;
      _technicians.clear();
    }
    
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      var query = Supabase.instance.client
          .from('technicians')
          .select('*');

      if (_currentFilter != 'all') {
        query = query.eq('validation_status', _currentFilter);
      }

      if (_searchQuery.isNotEmpty) {
        final usersData = await Supabase.instance.client
            .from('users')
            .select('id')
            .ilike('name', '%$_searchQuery%');
        
        final matchedUserIds = usersData.map((u) => u['id']).toList();
        
        if (matchedUserIds.isEmpty) {
          if (mounted) {
            setState(() {
              if (resetPage) _technicians = [];
              _hasMore = false;
              _isLoading = false;
            });
          }
          return;
        }
        
        query = query.inFilter('user_id', matchedUserIds);
      }

      final from = _currentPage * _itemsPerPage;
      final to = from + _itemsPerPage - 1;

      final data = await query.order(_sortBy, ascending: _isAscending).range(from, to);
      List<Map<String, dynamic>> techs = List<Map<String, dynamic>>.from(data);

      final userIds = techs
          .map((t) => t['user_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      Map<String, Map<String, dynamic>> usersMap = {};

      if (userIds.isNotEmpty) {
        final usersData = await Supabase.instance.client
            .from('users')
            .select('id, name, phone, avatar_url, created_at')
            .inFilter('id', userIds);

        for (final u in List<Map<String, dynamic>>.from(usersData)) {
          usersMap[u['id'] as String] = u;
        }
      }

      final merged = techs.map((t) {
        final userId = t['user_id'] as String? ?? '';
        final user = usersMap[userId] ?? {
          'id': userId,
          'name': 'Technicien ${userId.length >= 6 ? userId.substring(0, 6) : userId}',
          'phone': t['mtn_number'] ?? t['orange_number'] ?? '',
          'created_at': t['created_at'],
        };
        return <String, dynamic>{...t, 'users': user};
      }).toList();

      if (mounted) {
        setState(() {
          if (resetPage) {
            _technicians = merged;
          } else {
            _technicians.addAll(merged);
          }
          _hasMore = techs.length == _itemsPerPage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Déclenche la recherche textuelle avec délai de temporisation (500ms).
  ///
  /// [query] : Terme de recherche saisi par l'administrateur.
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != query) {
        setState(() => _searchQuery = query);
        _loadTechnicians(resetPage: true);
      }
    });
  }

  /// Exécute une validation ou un rejet rapide d'un technicien directement depuis la liste.
  ///
  /// [technicianId] : Identifiant unique de l'enregistrement technicien.
  /// [userId] : Identifiant du compte utilisateur associé.
  /// [action] : Action d'approbation ('approve') ou de rejet ('reject').
  Future<void> _quickValidate(
    String technicianId, String userId, String action) async {
  try {
    final status = action == 'approve' ? 'approved' : 'rejected';

    // Ajouter is_verified seulement si la colonne existe
    try {
      await Supabase.instance.client
          .from('technicians')
          .update({
            'validation_status': status,
            'is_verified': action == 'approve',
            'status': 'offline',
          })
          .eq('id', technicianId);
    } catch (_) {
      // Fallback sans is_verified
      await Supabase.instance.client
          .from('technicians')
          .update({'validation_status': status})
          .eq('id', technicianId);
    }

    // Log admin (optionnel, ne pas bloquer si erreur)
    try {
      await Supabase.instance.client.from('admin_logs').insert({
        'admin_id': Supabase.instance.client.auth.currentUser!.id,
        'action': action == 'approve'
            ? 'technician_approved'
            : 'technician_rejected',
        'target_id': technicianId,
        'details': {'user_id': userId},
      });
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'approve'
              ? '✅ Technicien approuvé !'
              : '❌ Technicien rejeté'),
          backgroundColor: action == 'approve'
              ? AppColors.success
              : AppColors.error,
        ),
      );
      await _loadTechnicians();
    }
  } catch (e) {
    if (mounted) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    final titles = {
      'pending': 'En attente de validation',
      'approved': 'Techniciens validés',
      'rejected': 'Techniciens rejetés',
      'all': 'Tous les techniciens',
    };

    return Scaffold(
      backgroundColor: tc.background,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(titles[_currentFilter] ?? 'Techniciens'),
              backgroundColor: isDark ? tc.surface : const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadTechnicians,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: ['all', 'pending', 'approved', 'rejected']
                        .map((f) {
                      final labels = {
                        'all': 'Tous',
                        'pending': 'En attente',
                        'approved': 'Validés',
                        'rejected': 'Rejetés',
                      };
                      final isSelected = _currentFilter == f;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _currentFilter = f);
                          _loadTechnicians(resetPage: true);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            labels[f]!,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          if (!widget.showAppBar) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: isDark ? tc.surface : Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['all', 'pending', 'approved', 'rejected'].map((f) {
                    final labels = {
                      'all': 'Tous',
                      'pending': 'En attente',
                      'approved': 'Validés',
                      'rejected': 'Rejetés',
                    };
                    final isSelected = _currentFilter == f;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _currentFilter = f);
                        _loadTechnicians(resetPage: true);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? tc.border : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          labels[f]!,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : tc.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          // En-tête de recherche et de tri (Compact & Élégant)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(
              color: isDark ? tc.surface : Colors.white,
              border: Border(bottom: BorderSide(color: tc.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? tc.background : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tc.border),
                    ),
                    child: TextField(
                      onChanged: _onSearchChanged,
                      style: TextStyle(color: tc.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un technicien...',
                        hintStyle: TextStyle(color: tc.textSecondary, fontSize: 12),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: tc.textSecondary),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? tc.background : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tc.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      dropdownColor: tc.surface,
                      icon: Icon(Icons.sort_rounded, size: 16, color: tc.textSecondary),
                      style: TextStyle(color: tc.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _sortBy = newValue;
                            _isAscending = newValue == 'experience_years';
                          });
                          _loadTechnicians(resetPage: true);
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'created_at', child: Text('Récent')),
                        DropdownMenuItem(value: 'experience_years', child: Text('Expérience')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading && _technicians.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _technicians.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined,
                              size: 56,
                              color: AppColors.textSecondary
                                  .withOpacity(0.4)),
                            const SizedBox(height: 16),
                            const Text('Aucun technicien',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadTechnicians(resetPage: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _technicians.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _technicians.length) {
                              return _hasMore
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: _isLoading
                                            ? const CircularProgressIndicator()
                                            : TextButton(
                                                onPressed: () {
                                                  setState(() => _currentPage++);
                                                  _loadTechnicians();
                                                },
                                                child: const Text('Charger plus'),
                                              ),
                                      ),
                                    )
                                  : const SizedBox.shrink();
                            }
                            
                            final tech = _technicians[index];
                      return _TechnicianTile(
                        technician: tech,
                        tc: tc,
                        isDark: isDark,
                        onApprove: _currentFilter == 'pending'
                            ? () => _quickValidate(
                                tech['id'],
                                tech['users']?['id'] ?? '',
                                'approve')
                            : null,
                        onReject: _currentFilter == 'pending'
                            ? () => _showRejectDialog(tech)
                            : null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TechnicianDetailScreen(
                                technician: tech),
                          ),
                        ).then((_) => _loadTechnicians()),
                      );
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }

  /// Affiche une boîte de dialogue de confirmation avant de rejeter l'inscription d'un technicien.
  ///
  /// [tech] : Données du technicien concerné.
  void _showRejectDialog(Map<String, dynamic> tech) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Rejeter ce technicien ?'),
        content: const Text(
          'Le technicien sera notifié et pourra soumettre à nouveau après correction.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              context.pop();
              _quickValidate(
                  tech['id'], tech['users']?['id'] ?? '', 'reject');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Rejeter',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Carte représentant un technicien individuel dans la liste de modération.
class _TechnicianTile extends StatelessWidget {
  /// Données brutes du technicien avec profil utilisateur joint.
  final Map<String, dynamic> technician;

  /// Callback déclenché pour valider le technicien immédiatement.
  final VoidCallback? onApprove;

  /// Callback déclenché pour ouvrir la modale de rejet du dossier.
  final VoidCallback? onReject;

  /// Action déclenchée au clic sur la carte pour ouvrir la vue détaillée.
  final VoidCallback onTap;

  /// Palette de couleurs dynamiques TechLink.
  final TechLinkColors tc;

  /// Indique si l'interface est en mode sombre.
  final bool isDark;

  /// Constructeur de [_TechnicianTile].
  const _TechnicianTile({
    required this.technician,
    this.onApprove,
    this.onReject,
    required this.onTap,
    required this.tc,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final user = technician['users'] as Map<String, dynamic>?;
    final name = user?['name'] as String? ?? 'Technicien';
    final phone = user?['phone'] as String? ?? '';
    final specialties = List<String>.from(technician['specialties'] as List? ?? []);
    final status = technician['validation_status'] as String? ?? 'pending';
    final experience = (technician['experience_years'] as num?)?.toInt() ?? 0;
    final avatarUrl = user?['avatar_url'] as String? ?? technician['photo_url'] as String?;

    final statusConfig = {
      'pending': (AppColors.warning, 'EN ATTENTE'),
      'approved': (AppColors.success, 'VALIDÉ'),
      'rejected': (AppColors.error, 'REJETÉ'),
    };
    final config = statusConfig[status] ?? (AppColors.textSecondary, 'INCONNU');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? tc.card : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Name + Status Badge
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF10B981).withOpacity(0.15),
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? const Icon(Icons.engineering_rounded, color: Color(0xFF10B981), size: 22)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: tc.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: config.$1.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: config.$1.withOpacity(0.4)),
                                ),
                                child: Text(
                                  config.$2,
                                  style: TextStyle(
                                    color: config.$1,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone_rounded, size: 12, color: tc.textSecondary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  phone.isNotEmpty ? phone : 'Sans numéro',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: tc.textSecondary, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.workspace_premium_outlined, size: 13, color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(
                                '$experience ans',
                                style: TextStyle(color: tc.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Specialties Tags
                if (specialties.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: specialties.take(3).map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 12),

                // Action Buttons
                if (onApprove != null && onReject != null && status == 'pending') ...[
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Valider', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: onApprove,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                            label: const Text('Rejeter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.error)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: onReject,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Voir le profil complet',
                          style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}