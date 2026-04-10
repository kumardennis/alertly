import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../models/alert.dart';

class AlertsRepository {
  AlertsRepository(this._client, this._api);

  final SupabaseClient _client;
  final ApiClient _api;

  Future<List<Alert>> getAlerts({
    Map<String, dynamic>? filters,
    String columns =
        '*, creator:users(*), tierInfo:tiers(*), verifications:alerts_verifications(*, user:users(*))',
    int? limit,
    String? orderBy,
    bool ascending = false,
  }) async {
    dynamic query = _client.from('alerts').select(columns);

    filters?.forEach((key, value) {
      query = query.eq(key, value);
    });

    if (orderBy != null) {
      query = query.order(orderBy, ascending: ascending);
    }

    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }

    final List<Map<String, dynamic>> data = await query;
    return data.map(Alert.fromJson).toList();
  }

  Future<Alert> getAlertById(int id) async {
    final data =
        await _client
            .from('alerts')
            .select(
              '*, creator:users(*), tierInfo:tiers(*), verifications:alerts_verifications(*, user:users(*))',
            )
            .eq('id', id)
            .single();
    return Alert.fromJson(data);
  }

  Future<void> createAlert(Map<String, dynamic> payload) async {
    await _api.post<Object?>(
      '/api/alerts/submit',
      body: payload,
      decode: (json) => json,
    );
  }

  Future<Alert> updateAlert({
    required int id,
    required Map<String, dynamic> payload,
  }) async {
    final data =
        await _client
            .from('alerts')
            .update(payload)
            .eq('id', id)
            .select(
              '*, creator:users(*), tierInfo:tiers(*), verifications:alerts_verifications(*, user:users(*))',
            )
            .single();
    return Alert.fromJson(data);
  }

  Future<void> deleteAlert(int id) async {
    await _client.from('alerts').delete().eq('id', id);
  }

  Future<AlertVerification> createAlertVerification({
    required int alertId,
    required int userId,
  }) async {
    final data =
        await _client
            .from('alerts_verifications')
            .insert({'alert_id': alertId, 'user_id': userId})
            .select('*, user:users(*)')
            .single();
    return AlertVerification.fromJson(data);
  }

  Future<List<AlertVerification>> getAlertVerificationsByAlertOwner({
    required int userId,
  }) async {
    final List<Map<String, dynamic>> data = await _client
        .from('alerts_verifications')
        .select('*, user:users(*), alert:alerts!inner(user_id)')
        .eq('alert.user_id', userId)
        .order('created_at', ascending: false);

    return data.map(AlertVerification.fromJson).toList();
  }

  Future<Map<String, double>?> getAlertLocation({required int alertId}) async {
    final data = await _client.rpc(
      'get_alert_location',
      params: {'p_alert_id': alertId},
    );

    if (data is! List || data.isEmpty) {
      return null;
    }

    final row = data.first;
    if (row is! Map) {
      return null;
    }

    final latitude = (row['latitude'] as num?)?.toDouble();
    final longitude = (row['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      return null;
    }

    return {'latitude': latitude, 'longitude': longitude};
  }
}
