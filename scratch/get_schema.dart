import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://vaagiltvlgomdmqevayv.supabase.co',
    'sb_publishable_dqMakfvmzbsK8RV6o6GozQ_DqH94lPS',
  );

  try {
    final response = await supabase.rpc('get_table_schema', params: {'table_name': 'technicians'});
    print(response);
  } catch (e) {
    try {
      final res = await supabase.from('technicians').select().limit(1);
      if (res.isNotEmpty) {
        print(res.first.keys);
      } else {
        print("Table empty, cannot infer schema.");
      }
    } catch (e2) {
      print("Error fetching technicians: $e2");
    }
  }
}
