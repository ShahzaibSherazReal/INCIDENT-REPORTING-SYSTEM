class AppConfig {
  static const String supabaseUrl = 'https://ipvvpmacpcvfeabenpay.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlwdnBwbWFjcGN2ZmVhYmVucGF5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzMzAyMDYsImV4cCI6MjA5MzkwNjIwNn0.cptkP-M122Iw1PHfjIA5Vd4dM9nqt3aysMNy-BOrbh4';
  static const String supabasePublishableKey = 'sb_publishable_DB7LpcDb0kDfVOYI9kIDsw_Tq-esHiA';

  /// FastAPI base URL (no trailing slash).
  ///
  /// Default: deployed Railway API. Local backend ke liye:
  /// `flutter run --dart-define=BACKEND_URL=http://localhost:8000`
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
