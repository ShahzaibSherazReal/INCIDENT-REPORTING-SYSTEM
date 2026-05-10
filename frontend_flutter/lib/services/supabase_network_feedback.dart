/// Turn low-level HTTP/socket failures into actionable hints for login/signup.
String readableSupabaseNetworkFailure(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();
  if (lower.contains('failed to fetch') ||
      lower.contains('authretryablefetchexception') ||
      lower.contains('clientexception') ||
      lower.contains('socketexception') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('timed out') ||
      lower.contains('handshake')) {
    return         'Could not reach Supabase (network).\n\n'
        '• Logs jo localhost:3000 referer ke saath hain wo aksar browser walī hit hai — Flutter APK ki signup POST '
        'alag dikhti hai. Same Wi‑Fi par mobile/browser dono try kar ke tasdee kar lain.\n\n'
        '• Wi‑Fi / mobile data on kar ke dubārah try karein.\n'
        '• Supabase Dashboard → project paused ho to Restore / Resume karein.\n'
        '• VPN, Private DNS, ya firewall band kar ke dekhein.\n'
        '• Galat URL/key ho to build:\n'
        '  flutter run --dart-define=SUPABASE_URL=https://YOUR.supabase.co '
        '--dart-define=SUPABASE_ANON_KEY=eyJ...\n\n'
        'Technical: $raw';
  }
  return raw;
}
