class AppConfig {
  static const String supabaseUrl = 'https://ipvvpmacpcvfeabenpay.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlwdnBwbWFjcGN2ZmVhYmVucGF5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzMzAyMDYsImV4cCI6MjA5MzkwNjIwNn0.cptkP-M122Iw1PHfjIA5Vd4dM9nqt3aysMNy-BOrbh4';
  static const String supabasePublishableKey = 'sb_publishable_DB7LpcDb0kDfVOYI9kIDsw_Tq-esHiA';

  /// FastAPI base URL (no trailing slash).
  ///
  /// Default [http://localhost:8000] — Chrome/web ke liye localhost theek hai.
  ///
  /// **Phone / release APK:** deploy backend (Railway, Fly.io, VPS, etc.) aur build ke waqt:
  /// `flutter build apk --release --dart-define=BACKEND_URL=https://your-api.example.com`
  ///
  /// Same Wi‑Fi par PC backend test: `--dart-define=BACKEND_URL=http://192.168.x.x:8000`
  /// (phone aur PC same network; backend `--host 0.0.0.0` se chalao).
  static String get backendBaseUrl {
    const raw = String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'http://localhost:8000',
    );
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }
}
