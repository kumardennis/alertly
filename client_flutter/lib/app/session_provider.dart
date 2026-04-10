import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/notifications/notification_permission_service.dart';
import '../core/supabase/supabase_provider.dart';
import '../core/network/api_client.dart';
import '../core/location/location_provider.dart';
import '../features/alerts/alerts_provider.dart';
import '../features/alerts/users_received_alerts_provider.dart';
import '../features/onboarding/onboarding_provider.dart';
import '../features/profile/profile_alerts_provider.dart';
import '../features/users/data/users_repository.dart';
import '../features/users/data/users_devices_repository.dart';
import '../features/users/profile_provider.dart';

final sessionProvider = NotifierProvider<SessionNotifier, Session?>(
  SessionNotifier.new,
);

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider) != null;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(sessionProvider)?.user;
});

class SessionNotifier extends Notifier<Session?> {
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _activeAuthId;

  void _invalidateUserScopedState() {
    ref.invalidate(profileProvider);
    ref.invalidate(alertsProvider);
    ref.invalidate(usersReceivedAlertsProvider);
    ref.invalidate(profileAlertsProvider);
    ref.invalidate(profileVerificationsCountProvider);
    ref.invalidate(locationProvider);
    ref.invalidate(onboardingProvider);
  }

  Future<void> _syncLoginDataForAuthId(String authId) async {
    final client = ref.read(supabaseClientProvider);
    final usersRepo = UsersRepository(client);
    final users = await usersRepo.getUsers(
      filters: {'auth_id': authId},
      limit: 1,
    );

    if (users.isEmpty) return;
    final userId = users.first.id;

    try {
      await _syncDeviceForUser(userId);
    } catch (_) {
      // Device token sync should not block successful authentication.
    }

    try {
      await ref
          .read(locationProvider.notifier)
          .refreshAndSyncUserLocation(userId);
    } catch (_) {
      // Location sync is best-effort and should never block session state.
    }
  }

  Future<void> _syncDeviceForUser(int userId) async {
    final settings = await NotificationPermissionService.request();
    if (!NotificationPermissionService.isGranted(settings)) {
      return;
    }

    final token = await NotificationPermissionService.getFcmToken();
    if (token == null || token.isEmpty) {
      return;
    }

    final client = ref.read(supabaseClientProvider);
    final devicesRepo = UsersDevicesRepository(client);
    await devicesRepo.upsertDeviceForUser(
      userId: userId,
      fcmToken: token,
      platform: NotificationPermissionService.currentPlatform(),
    );
  }

  Future<void> _syncSpecificTokenForAuthId(String authId, String token) async {
    if (token.isEmpty) return;

    final client = ref.read(supabaseClientProvider);
    final usersRepo = UsersRepository(client);
    final users = await usersRepo.getUsers(
      filters: {'auth_id': authId},
      limit: 1,
    );
    if (users.isEmpty) return;

    final devicesRepo = UsersDevicesRepository(client);
    await devicesRepo.upsertDeviceForUser(
      userId: users.first.id,
      fcmToken: token,
      platform: NotificationPermissionService.currentPlatform(),
    );
  }

  void _startTokenRefreshSync(String authId) {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = NotificationPermissionService.onFcmTokenRefresh().listen(
      (token) {
        unawaited(_syncSpecificTokenForAuthId(authId, token));
      },
    );
  }

  @override
  Session? build() {
    final client = ref.watch(supabaseClientProvider);
    state = client.auth.currentSession;

    final existingAuthId = state?.user.id;
    _activeAuthId = existingAuthId;
    if (existingAuthId != null) {
      unawaited(_syncLoginDataForAuthId(existingAuthId));
      _startTokenRefreshSync(existingAuthId);
    }

    _authSub?.cancel();
    _authSub = client.auth.onAuthStateChange.listen((data) {
      final previousAuthId = _activeAuthId;
      final nextAuthId = data.session?.user.id;
      _activeAuthId = nextAuthId;

      if (previousAuthId != nextAuthId) {
        _invalidateUserScopedState();
      }

      state = data.session;

      if (nextAuthId != null) {
        unawaited(_syncLoginDataForAuthId(nextAuthId));
        _startTokenRefreshSync(nextAuthId);
      } else {
        _tokenRefreshSub?.cancel();
        _tokenRefreshSub = null;
      }
    });

    ref.onDispose(() {
      _authSub?.cancel();
      _tokenRefreshSub?.cancel();
    });

    return state;
  }

  Future<void> signInAnonymously() async {
    final client = ref.read(supabaseClientProvider);
    await client.auth.signInAnonymously();
  }

  /// Sends OTP to [phone] (E.164 format, e.g. +37255512345) via the backend.
  Future<void> register(String phone) async {
    final api = createApiClient();
    await api.post<bool>(
      '/api/auth/register',
      body: {'phone': phone},
      decode: (_) => true,
    );
  }

  /// Verifies [token] for [phone] directly against Supabase.
  /// Returns true if this is a brand-new user (no profile row yet).
  Future<bool> verify(String phone, String token) async {
    final client = ref.read(supabaseClientProvider);

    await client.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);

    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Verification succeeded but no authenticated user found');
    }

    final rows = await client
        .from('users')
        .select('id')
        .eq('auth_id', userId)
        .limit(1);

    return rows.isEmpty;
  }

  Future<void> signOut() async {
    final client = ref.read(supabaseClientProvider);
    await client.auth.signOut();
  }
}
