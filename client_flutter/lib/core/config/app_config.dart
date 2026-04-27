import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL']?.trim() ??
      'https://vebbrghiubfssxucqbfq.supabase.co';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY']?.trim() ??
      'sb_publishable_msTXazQTkrFOHg1wLQ-x6w_UKOqP6v4';

  static String get backendBaseUrl =>
      dotenv.env['BACKEND_BASE_URL']?.trim() ??
      'https://alertly-backend-api-server.onrender.com';

  static String get mapboxAccessToken =>
      dotenv.env['MAPBOX_ACCESS_TOKEN']?.trim() ?? '';

  static bool get hasMapboxAccessToken => mapboxAccessToken.trim().isNotEmpty;

  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing Supabase config. Set SUPABASE_URL and SUPABASE_ANON_KEY in .env.',
      );
    }
  }
}
