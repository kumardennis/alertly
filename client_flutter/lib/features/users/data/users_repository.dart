import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/app_user.dart';

class UsersRepository {
  UsersRepository(this._client);

  final SupabaseClient _client;

  PostgrestFilterBuilder<List<Map<String, dynamic>>> queryUsers({
    String columns = '*',
  }) {
    return _client.from('users').select(columns);
  }

  Future<List<AppUser>> getUsers({
    Map<String, dynamic>? filters,
    String columns = '*',
    int? limit,
  }) async {
    dynamic query = _client.from('users').select(columns);

    filters?.forEach((key, value) {
      query = query.eq(key, value);
    });

    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }

    final List<Map<String, dynamic>> data = await query;
    return data.map(AppUser.fromJson).toList();
  }

  Future<AppUser> createUser(Map<String, dynamic> payload) async {
    final data = await _client.from('users').insert(payload).select().single();
    return AppUser.fromJson(data);
  }

  Future<List<AppUser>> updateUsers({
    required Map<String, dynamic> payload,
    required Map<String, Object> filters,
  }) async {
    final data =
        await _client.from('users').update(payload).match(filters).select();
    return data.map(AppUser.fromJson).toList();
  }
}
