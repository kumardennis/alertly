import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

const double _portraitTabletMaxWidth = 768;

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
String? _initialNotificationAlertId;

void setupForegroundNotificationHandling() {
  FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((message) {
    final title = message.notification?.title ?? 'New neighborhood alert';
    final body = message.notification?.body ?? 'A new alert was posted nearby.';

    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('$title\n$body'),
        duration: const Duration(seconds: 4),
      ),
    );
  });
}

Future<void> setupNotificationTapRouting() async {
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    final alertId = message.data['alertId'];
    if (alertId == null || alertId.isEmpty) {
      return;
    }

    router.go('/?alertId=$alertId');
  });

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  final initialAlertId = initialMessage?.data['alertId'];
  if (initialAlertId != null && initialAlertId.isNotEmpty) {
    _initialNotificationAlertId = initialAlertId;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  setupForegroundNotificationHandling();
  await setupNotificationTapRouting();
  AppConfig.validate();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: MainApp()));

  if (_initialNotificationAlertId != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.go('/?alertId=$_initialNotificationAlertId');
      _initialNotificationAlertId = null;
    });
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'Alertly',
      theme: AppTheme.light(),
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth <= _portraitTabletMaxWidth) {
              return content;
            }

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _portraitTabletMaxWidth,
                ),
                child: content,
              ),
            );
          },
        );
      },
      routerConfig: router,
    );
  }
}
