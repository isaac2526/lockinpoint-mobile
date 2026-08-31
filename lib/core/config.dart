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
  /// THE `www` MATTERS. A host on Vercel has one name primary and the other
  /// redirecting to it. A browser follows that hop invisibly — which is why
  /// the website looks perfectly healthy — but a native app meets it head on,
  /// and Dart's own redirect following drops a POST body on the way, turning
  /// a login into an empty request.
  ///
  /// The Belloxdydx app, which worked on its first build, posts to
  /// `https://www.belloxdydx.org`. This app was pointed at the bare apex.
  /// It now uses the same shape — and Api._followSameSite re-issues the whole
  /// request if the hop turns out to run the other way, so either name works.
  static const apiBase = String.fromEnvironment(
    'LIP_API',
    defaultValue: 'https://www.lockinpoint.com',
  );

  /// How the app names itself on every request. Kept in step with the
  /// pubspec version by `scripts/verify.sh`, which fails if the two drift.
  static const appVersion = '1.0.13';

  static const userAgent = 'LockInPoint/$appVersion (Android; Flutter)';

  static const whatsappChannel =
      'https://whatsapp.com/channel/0029Vb7NwWk9hXFD6TSas40m';

  static const supportEmail = 'info@lockinpoint.com';

  /// THE GUARDIAN PORTAL IS A WEBSITE, ON PURPOSE.
  ///
  /// A parent following a candidate is not a second app to install, keep
  /// updated and sign into on a phone they may share. It is one page they
  /// open, so the app simply points at it. The student app stays a student
  /// app: nothing here can hold a guardian session.
  static const guardianPortal = '$apiBase/guardian';
}
