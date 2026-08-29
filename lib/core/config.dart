/// Where the app points. Overridable at build time so a debug build can run
/// against a laptop and a release build cannot accidentally ship pointing at it:
///   flutter run --dart-define=LIP_API=http://10.0.2.2:3000
class AppConfig {
  static const apiBase = String.fromEnvironment(
    'LIP_API',
    defaultValue: 'https://lockinpoint.com',
  );

  /// The anon key is public by design — it is in the website's JavaScript
  /// bundle too. Row Level Security, not secrecy, is what protects the data.
  static const supabaseUrl = 'https://sfqsugvqnkuiuvtodush.supabase.co';

  static const whatsappChannel =
      'https://whatsapp.com/channel/0029Vb7NwWk9hXFD6TSas40m';

  static const supportEmail = 'info@lockinpoint.com';
}
