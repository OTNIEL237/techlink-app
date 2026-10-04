import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'mission_provider.g.dart';

@riverpod
class MissionListNotifier extends _$MissionListNotifier {
  @override
  FutureOr<List<Map<String, dynamic>>> build() async {
    return _fetchMissions();
  }

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