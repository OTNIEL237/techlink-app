// =============================================================================
// FICHIER : admin_clients_screen.dart
// RÔLE : Répertoire paginé et modération de l'ensemble des comptes clients
// MODULE : Presentation / Admin
// DÉPENDANCES : flutter/material.dart, supabase_flutter, app_colors.dart, theme_provider.dart, admin_client_detail_screen.dart
// SÉCURITÉ / RLS : Rôle administrateur requis. Lecture filtrée sur `users` avec rôle `'client'`.
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/neumorphic_styles.dart';
import '../shared/widgets/techlink_button.dart';
import '../shared/widgets/techlink_card.dart';
import 'admin_client_detail_screen.dart';

/// Écran administrateur répertoriant tous les utilisateurs ayant le rôle client.
///
/// Intègre une barre de recherche textuelle avec anti-rebond (debounce),
/// un tri par date d'inscription ou ordre alphabétique, et une pagination progressive infinie.
class AdminClientsScreen extends StatefulWidget {
  /// Indique si l'AppBar standard doit être affichée (true) ou masquée lorsqu'intégré dans un onglet (false).
  final bool showAppBar;

  /// Constructeur constant du widget [AdminClientsScreen].
  const AdminClientsScreen({super.key, this.showAppBar = true});

  @override
  State<AdminClientsScreen> createState() => _AdminClientsScreenState();
}

/// État associé à l'écran du registre des clients.
///
/// Gère la pagination, le déclenchement des recherches temporisées, et la navigation vers les détails.
class _AdminClientsScreenState extends State<AdminClientsScreen> {
  /// Liste accumulée des comptes clients affichés dans l'interface.
  List<Map<String, dynamic>> _clients = [];

  /// Indicateur de requête de chargement en cours.
  bool _isLoading = true;

  /// Chaîne de recherche saisie par l'administrateur.
  String _searchQuery = '';

  /// Colonne de tri active ('created_at' ou 'name').
  String _sortBy = 'created_at';

  /// Sens du tri ordonné (ascendant ou descendant).
  bool _isAscending = false;

  /// Index de la page paginée courante (0-indexée).
  int _currentPage = 0;

  /// Nombre d'éléments demandés par requête de lot.
  final int _itemsPerPage = 10;

  /// Indique s'il reste d'autres éléments à charger côté serveur.
  bool _hasMore = true;

  /// Minuteur d'anti-rebond pour fluidifier les saisies dans la barre de recherche.
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  /// Annule le minuteur actif à la destruction du widget.
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Charge ou recharge les clients depuis Supabase en tenant compte des filtres et de la pagination.
  ///
  /// Si [resetPage] est vrai, remet la pagination à zéro et vide la liste locale.
  Future<void> _loadClients({bool resetPage = false}) async {
    if (resetPage) {
      _currentPage = 0;
      _hasMore = true;
      _clients.clear();
    }
    
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      var query = Supabase.instance.client
          .from('users')
          .select('*')
          .eq('role', 'client');

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$_searchQuery%');
      }

      final from = _currentPage * _itemsPerPage;
      final to = from + _itemsPerPage - 1;
      
      final data = await query.order(_sortBy, ascending: _isAscending).range(from, to);

      if (mounted) {
        setState(() {
          final fetchedData = List<Map<String, dynamic>>.from(data);
          if (resetPage) {
            _clients = fetchedData;
          } else {
            _clients.addAll(fetchedData);
          }
          _hasMore = fetchedData.length == _itemsPerPage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Erreur: $e');
    }
  }

  /// Réceptionne les frappes au clavier et applique un délai de 500ms avant de déclencher la recherche.
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != query) {
        setState(() => _searchQuery = query);
        _loadClients(resetPage: true);
      }
    });
  }

  /// Construit la vue de répertoire client avec barre d'outils et liste défilante.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Clients', style: TextStyle(color: Colors.white)),
              backgroundColor: isDark ? tc.surface : const Color(0xFF1E293B),
              iconTheme: const IconThemeData(color: Colors.white),
            )
          : null,
      body: Column(
        children: [
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
                        hintText: 'Rechercher un client...',
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
                            // Si on trie par nom, on met ascendant par défaut
                            _isAscending = newValue == 'name';
                          });
                          _loadClients(resetPage: true);
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'created_at', child: Text('Récent')),
                        DropdownMenuItem(value: 'name', child: Text('Nom')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading && _clients.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _clients.isEmpty
                    ? const Center(child: Text('Aucun client trouvé.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _clients.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _clients.length) {
                            return _hasMore
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: _isLoading
                                          ? const CircularProgressIndicator()
                                          : TextButton(
                                              onPressed: () {
                                                setState(() => _currentPage++);
                                                _loadClients();
                                              },
                                              child: const Text('Charger plus'),
                                            ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          }
                          
                          final c = _clients[index];
                          final name = c['name'] ?? 'Client sans nom';
                          final phone = c['phone'] ?? 'Pas de numéro';
                          final email = c['email'] ?? '';
                          final avatarUrl = c['avatar_url'] as String?;
                          final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: NeumorphicCard(
                              borderRadius: 18,
                              padding: EdgeInsets.zero,
                              child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminClientDetailScreen(client: c),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      // Circular Avatar
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.12),
                                        backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                                        child: !hasAvatar
                                            ? Text(
                                                name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                                style: const TextStyle(
                                                  color: Color(0xFF1E3A8A),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 14),

                                      // Informations
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
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF1E3A8A).withOpacity(0.10),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'CLIENT',
                                                    style: TextStyle(
                                                      color: Color(0xFF1E3A8A),
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(Icons.phone_rounded, size: 13, color: tc.textSecondary),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    phone,
                                                    style: TextStyle(color: tc.textSecondary, fontSize: 12),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (email.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Icon(Icons.email_outlined, size: 13, color: tc.textSecondary),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      email,
                                                      style: TextStyle(color: tc.textSecondary, fontSize: 12),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Arrow
                                      Icon(Icons.chevron_right_rounded, color: tc.textSecondary),
                                    ],
                                  ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
