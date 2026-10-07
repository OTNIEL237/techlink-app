// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : mission_provider.dart
// Rôle          : Fournisseur d'état Riverpod pour le chargement, filtrage et pagination des missions.
// Module        : Providers (Gestion d'état global)
// Dépendances   : flutter_riverpod, riverpod_annotation, supabase_flutter
// Sécurité/RLS  : Requêtes sur la table 'missions' avec jointures clients, technicians, categories.
// =============================================================================

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'mission_provider.g.dart';

/// Contrôleur d'état (Notifier) gérant la liste des missions avec pagination et filtres.
///
/// Permet de récupérer, rechercher et trier les missions attribuées ou disponibles,
/// en prenant en charge le défilement infini via l'argument `append`.
@riverpod
class MissionListNotifier extends _$MissionListNotifier {
  /// Construction initiale de la liste des missions (première page sans filtre).
  @override
  FutureOr<List<Map<String, dynamic>>> build() async {
    return _fetchMissions();
  }

  /// Requête interne interrogeant la table `missions` de Supabase avec jointures relationnelles.
  ///
  /// [statusFilter] Filtre sur l'état de la mission ('all', 'pending', 'in_progress', 'completed', etc.).
  /// [page] Index de la page (commence à 0, pagination par lot de 10 enregistrements).
  /// [searchQuery] Terme de recherche textuelle appliqué à la description du problème.
  /// [sortBy] Colonne SQL utilisée pour le tri (par défaut 'created_at').
  /// [isAscending] Ordre du tri (vrai pour croissant, faux pour décroissant).
  /// Retourne la liste des missions sous forme de dictionnaires JSON.
  Future<List<Map<String, dynamic>>> _fetchMissions({
    String statusFilter = 'all',
    int page = 0,
    String searchQuery = '',
    String sortBy = 'created_at',
    bool isAscending = false,
  }) async {
    var query = Supabase.instance.client
        .from('missions')
        .select('*, clients:client_id(name, phone), technicians:technician_id(name, phone), categories(name)');

    if (statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }

    if (searchQuery.isNotEmpty) {
      query = query.ilike('problem_description', '%$searchQuery%');
    }

    final from = page * 10;
    final to = from + 9;
    
    final response = await query.order(sortBy, ascending: isAscending).range(from, to);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Déclenche le rechargement ou l'extension (pagination infinie) de la liste des missions.
  ///
  /// Met à jour l'état [state] avec les nouvelles données récupérées.
  /// Si [append] est vrai et qu'un état précédent existe, les nouveaux éléments sont concaténés.
  ///
  /// [statusFilter] Filtre de statut optionnel ('all' par défaut).
  /// [page] Numéro de page à charger (par défaut 0).
  /// [searchQuery] Texte recherché dans la description.
  /// [sortBy] Colonne de tri.
  /// [isAscending] Sens du tri.
  /// [append] Si vrai, ajoute à la liste existante ; sinon, remplace l'état complet.
  Future<void> fetch({
    String statusFilter = 'all',
    int page = 0,
    String searchQuery = '',
    String sortBy = 'created_at',
    bool isAscending = false,
    bool append = false,
  }) async {
    if (!append) {
      state = const AsyncValue.loading();
    }
    
    state = await AsyncValue.guard(() async {
      final newData = await _fetchMissions(
        statusFilter: statusFilter,
        page: page,
        searchQuery: searchQuery,
        sortBy: sortBy,
        isAscending: isAscending,
      );
      
      if (append && state.hasValue) {
        return [...state.value!, ...newData];
      }
      return newData;
    });
  }
}