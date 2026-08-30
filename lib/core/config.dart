/// Where the app points. Overridable at build time so a debug build can run
/// against a laptop and a release build cannot accidentally ship pointing at it:
///   flutter run --dart-define=LIP_API=http://10.0.2.2:3000
///
/// This is the app's ONLY backend address. There is deliberately no Supabase
/// URL here any more: the server's auth project is chosen by the server's own
/// configuration, and the app learns everything it needs — login, session
/// refresh, data — through these API routes. An address compiled into an APK
/// cannot drift away from what the deployment actually uses.
class AppConfig {
  static const apiBase = String.fromEnvironment(
    'LIP_API',
    defaultValue: 'https://lockinpoint.com',
  );

  static const whatsappChannel =
      'https://whatsapp.com/channel/0029Vb7NwWk9hXFD6TSas40m';

  static const supportEmail = 'info@lockinpoint.com';
}
