import 'package:client_flutter/features/users/profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/alert.dart';
import '../../core/network/api_client.dart';
import '../../core/supabase/supabase_provider.dart';
import 'data/alerts_repository.dart';

final alertsProvider = AsyncNotifierProvider<AlertsNotifier, List<Alert>>(
  AlertsNotifier.new,
);

class AlertsNotifier extends AsyncNotifier<List<Alert>> {
  late AlertsRepository _repo;

  @override
  Future<List<Alert>> build() async {
    final client = ref.watch(supabaseClientProvider);
    _repo = AlertsRepository(client, createApiClient());
    return _fetchAlerts();
  }

  Future<List<Alert>> _fetchAlerts() {
    return _repo.getAlerts(
      filters: {'status': 'published'},
      orderBy: 'created_at',
      ascending: false,
    );
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchAlerts);
  }

  Future<void> createAlert(Map<String, dynamic> payload) async {
    await _repo.createAlert(payload);
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchAlerts);
  }

  Future<void> updateAlert({
    required int id,
    required Map<String, dynamic> payload,
  }) async {
    final updated = await _repo.updateAlert(id: id, payload: payload);
    state.whenData(
      (alerts) =>
          state = AsyncData([
            for (final a in alerts)
              if (a.id == id) updated else a,
          ]),
    );
  }

  Future<void> deleteAlert(int id) async {
    await _repo.deleteAlert(id);
    state.whenData(
      (alerts) => state = AsyncData(alerts.where((a) => a.id != id).toList()),
    );
  }

  Future<void> verifyAlert(int id) async {
    final userId = ref.read(profileProvider).valueOrNull?.id;
    if (userId == null) return;

    await _repo.createAlertVerification(
      alertId: id,
      userId: userId,
    );
    await reload();
  }
}
