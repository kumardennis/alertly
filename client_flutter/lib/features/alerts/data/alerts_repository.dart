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

  Future<List<Alert>> getAlertsInMapBounds({
    required double southLat,
    required double westLng,
    required double northLat,
    required double eastLng,
    int limit = 200,
  }) async {
    final data = await _client.rpc(
      'get_alerts_in_map_bounds',
      params: {
        'p_south_lat': southLat,
        'p_west_lng': westLng,
        'p_north_lat': northLat,
        'p_east_lng': eastLng,
        'p_limit': limit,
      },
    );

    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(_mapBoundsRowToAlert)
        .toList();
  }

  Alert _mapBoundsRowToAlert(Map<String, dynamic> row) {
    final id = row['alert_id'] as int?;
    final latitude = (row['latitude'] as num?)?.toDouble();
    final longitude = (row['longitude'] as num?)?.toDouble();
    final tier = row['tier'] as int?;

    return Alert.fromJson({
      'id': id,
      'title': row['title'],
      'body': row['body'],
      'category': row['category'],
      'status': row['status'],
      'flagged': row['flagged'],
      'user_id': row['user_id'],
      'tier': tier,
      'radius_m': row['radius_m'],
      'created_at': row['created_at'],
      'published_at': row['published_at'],
      'location': {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      },
      'tierInfo': _tierInfoFromInt(tier),
    });
  }

  static const _tierPriorities = {
    1: 'low',
    2: 'medium',
    3: 'high',
    4: 'emergency',
  };

  static Map<String, dynamic>? _tierInfoFromInt(int? tier) {
    if (tier == null) return null;
    return {'id': tier, 'priority': _tierPriorities[tier]};
  }
}
