import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/supabase/supabase_provider.dart';
import '../../models/alert.dart';
import '../alerts/data/alerts_repository.dart';
import '../users/profile_provider.dart';

/// Fetches all alerts submitted by the currently logged-in user (no status
/// filter so we show everything they've contributed).
final profileAlertsProvider = FutureProvider<List<Alert>>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final repo = AlertsRepository(client, createApiClient());

  return repo.getAlerts(
    filters: {'user_id': profile.id},
    orderBy: 'created_at',
    ascending: false,
  );
});

/// Fetches verification count for alerts created by the current user.
final profileVerificationsCountProvider = FutureProvider<int>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return 0;

  final client = ref.watch(supabaseClientProvider);
  final repo = AlertsRepository(client, createApiClient());

  final verifications = await repo.getAlertVerificationsByAlertOwner(
    userId: profile.id,
  );

  return verifications.where((v) => v.verified != false).length;
});
