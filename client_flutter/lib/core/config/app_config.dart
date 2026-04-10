class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vebbrghiubfssxucqbfq.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_msTXazQTkrFOHg1wLQ-x6w_UKOqP6v4',
  );

  static const backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://alertly-backend-api-server.onrender.com',
  );

  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing Supabase config. Pass --dart-define=SUPABASE_URL and --dart-define=SUPABASE_ANON_KEY.',
      );
    }
  }
}
