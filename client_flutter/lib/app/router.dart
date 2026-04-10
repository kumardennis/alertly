import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/alerts/alerts_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/otp_page.dart';
import '../features/home/home_page.dart';
import '../features/navigation/main_shell_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/profile/profile_page.dart';

/// Notifies GoRouter when Supabase auth state changes so redirect re-runs.
/// This is infrastructure glue only — it holds no app state.
class _AuthBridge extends ChangeNotifier {
  _AuthBridge() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authBridge = _AuthBridge();

Future<bool> _hasProfileForCurrentUser() async {
  final client = Supabase.instance.client;
  final authId = client.auth.currentUser?.id;

  if (authId == null) {
    return false;
  }

  final row =
      await client
          .from('users')
          .select('id')
          .eq('auth_id', authId)
          .maybeSingle();

  return row != null;
}

final router = GoRouter(
  initialLocation: '/login',
  refreshListenable: _authBridge,
  redirect: (context, state) async {
    final client = Supabase.instance.client;
    final isLoggedIn = client.auth.currentSession != null;
    final loc = state.matchedLocation;
    final isPublic = loc == '/login' || loc == '/otp';
    final isOnboarding = loc == '/onboarding';

    if (!isLoggedIn && !isPublic) return '/login';

    if (!isLoggedIn) {
      return null;
    }

    final hasProfile = await _hasProfileForCurrentUser();

    if (!hasProfile && !isOnboarding) {
      return '/onboarding';
    }

    if (hasProfile && isOnboarding) {
      return '/';
    }

    if (loc == '/login' || loc == '/otp') {
      return hasProfile ? '/' : '/onboarding';
    }

    return null;
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return MainShellPage(location: state.uri.path, child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            final alertId = int.tryParse(
              state.uri.queryParameters['alertId'] ?? '',
            );
            return HomePage(deepLinkAlertId: alertId);
          },
        ),
        GoRoute(
          path: '/alerts',
          builder: (context, state) => const AlertsPage(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
      ],
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final phone = state.uri.queryParameters['phone'] ?? '';
        return OtpPage(phone: phone);
      },
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
  ],
);
