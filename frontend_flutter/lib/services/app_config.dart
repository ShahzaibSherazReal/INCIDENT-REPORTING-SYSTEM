class AppConfig {
  AppConfig._();

  /// Default Supabase project (override with dart-define for other envs).
  static const String _defaultSupabaseUrl = 'https://ipvppmacpcvfeabenpay.supabase.co';
  static const String _defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlwdnBwbWFjcGN2ZmVhYmVucGF5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzMzAyMDYsImV4cCI6MjA5MzkwNjIwNn0.cptkP-M122Iw1PHfjIA5Vd4dM9nqt3aysMNy-BOrbh4';

  static String get supabasePublicPublishableKey =>
      'sb_publishable_DB7LpcDb0kDfVOYI9kIDsw_Tq-esHiA';

  /// `flutter run --dart-define=SUPABASE_URL=https://xxxxx.supabase.co`
  static String get supabaseUrl {
    const custom = String.fromEnvironment('SUPABASE_URL');
    final trimmed = custom.trim().replaceAll(RegExp(r'\s+'), '');
    if (trimmed.isNotEmpty) {
      return _stripTrailingSlashes(trimmed);
    }
    return _stripTrailingSlashes(_defaultSupabaseUrl);
  }

  /// `flutter run --dart-define=SUPABASE_ANON_KEY=eyJ...`
  static String get supabaseAnonKey {
    const custom = String.fromEnvironment('SUPABASE_ANON_KEY');
    final trimmed = custom.trim().replaceAll(RegExp(r'\s+'), '');
    if (trimmed.isNotEmpty) return trimmed;
    return _defaultSupabaseAnonKey;
  }

  static String _stripTrailingSlashes(String url) {
    var u = url;
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// FastAPI base URL (no trailing slash).
  ///
  /// Local backend: `flutter run --dart-define=BACKEND_URL=http://localhost:8000`
  static String get backendBaseUrl {
    const raw = String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'https://incident-reporting-system-production.up.railway.app',
    );
    var base = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (base.isEmpty) {
      base = 'https://incident-reporting-system-production.up.railway.app';
    }
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  /// Realtime tab: interval between JPEG uploads (server rate-limits with PROCESS_FPS too).
  static const int realtimeFrameIntervalMs = 700;
}
