/// Runtime configuration for public Supabase settings. Values come from a
/// committed-with-placeholders `.env`; real values are supplied per
/// environment. Never put service-role or secret keys here.
class EnvConfig {
  const EnvConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  final String supabaseUrl;
  final String supabaseAnonKey;

  static const _placeholderUrl = 'https://YOUR-PROJECT.supabase.co';
  static const _placeholderKey = 'YOUR-ANON-KEY';

  bool get isPlaceholder =>
      supabaseUrl.isEmpty ||
      supabaseAnonKey.isEmpty ||
      supabaseUrl == _placeholderUrl ||
      supabaseAnonKey == _placeholderKey;

  static const String placeholderUrl = _placeholderUrl;
  static const String placeholderKey = _placeholderKey;

  /// Global quick-check mirroring the running config; true once real values
  /// are loaded. Used only for an honest note on transitional screens.
  static bool isReal = false;
}
