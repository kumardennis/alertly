import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/app_user_device.dart';

class UsersDevicesRepository {
  UsersDevicesRepository(this._client);

  final SupabaseClient _client;

  PostgrestFilterBuilder<List<Map<String, dynamic>>> queryUserDevices({
    String columns = '*',
  }) {
    return _client.from('users_devices').select(columns);
  }

  Future<List<AppUserDevice>> getUserDevices({
    Map<String, dynamic>? filters,
    String columns = '*',
    int? limit,
  }) async {
    dynamic query = _client.from('users_devices').select(columns);

    filters?.forEach((key, value) {
      query = query.eq(key, value);
    });

    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }

    final List<Map<String, dynamic>> data = await query;
    return data.map(AppUserDevice.fromJson).toList();
  }

  Future<AppUserDevice> createUserDevice(Map<String, dynamic> payload) async {
    final data =
        await _client.from('users_devices').insert(payload).select().single();
    return AppUserDevice.fromJson(data);
  }

  Future<List<AppUserDevice>> updateUserDevices({
    required Map<String, dynamic> payload,
    required Map<String, Object> filters,
  }) async {
    final data =
        await _client
            .from('users_devices')
            .update(payload)
            .match(filters)
            .select();
    return data.map(AppUserDevice.fromJson).toList();
  }

  Future<AppUserDevice> upsertDeviceForUser({
    required int userId,
    required String fcmToken,
    required String platform,
  }) async {
    final existing = await getUserDevices(
      filters: {'user_id': userId},
      limit: 1,
    );

    if (existing.isEmpty) {
      return createUserDevice({
        'user_id': userId,
        'fcm_token': fcmToken,
        'platform': platform,
      });
    }

    final updated = await updateUserDevices(
      payload: {
        'fcm_token': fcmToken,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      filters: {'id': existing.first.id},
    );

    return updated.first;
  }
}
