import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../models/alert.dart';
import '../users/profile_provider.dart';

final usersReceivedAlertsProvider =
    AsyncNotifierProvider<UsersReceivedAlertsNotifier, List<Alert>>(
      UsersReceivedAlertsNotifier.new,
    );

/// Alerts delivered to the current user via users_received_alerts.
class UsersReceivedAlertsNotifier extends AsyncNotifier<List<Alert>> {
  @override
  Future<List<Alert>> build() {
    return _fetchAlerts();
  }

  Future<List<Alert>> _fetchAlerts() async {
    final profile = await ref.read(profileProvider.future);
    if (profile == null) return [];

    final client = ref.read(supabaseClientProvider);
    final rows = await client
        .from('users_received_alerts')
        .select(
          'created_at, alert:alerts(*, tierInfo:tiers(*), verifications:alerts_verifications(*, users!inner(*)))',
        )
        .eq('receiver_id', profile.id)
        .match({'alert.status': 'published'})
        .order('created_at', ascending: false);

    final alerts = <Alert>[];
    for (final row in rows) {
      final alertJson = row['alert'];
      if (alertJson != null) {
        alerts.add(Alert.fromJson(alertJson));
      }
    }

    return alerts;
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchAlerts);
  }
}
