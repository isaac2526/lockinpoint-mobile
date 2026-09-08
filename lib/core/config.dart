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

  /// How the app names itself on every request.
  ///
  /// IT HAD DRIFTED TO 1.0.13 WHILE THE APP WAS 2.0.1. scripts/verify.sh has
  /// always carried a check for exactly this — and no workflow ran that
  /// script, so the guard never fired once. Every request from every phone
  /// named a build that had not existed for months, which makes a server log
  /// worse than useless: it points confidently at the wrong version. The
  /// check now runs in `check` on every push.
  static const appVersion = '2.0.1';

  /// The build number, which is what an update check compares. Names are for
  /// people; only this ever increases, and only this can be ordered.
  static const buildNumber = 16;

  static const userAgent = 'LockInPoint/$appVersion+$buildNumber (Flutter)';

  /* THE APP NO LONGER KNOWS A PHONE NUMBER OR AN ADDRESS.
     A WhatsApp channel and a support email used to live here as constants,
     which meant changing a support line meant shipping an APK. They are rows
     in `support_contacts` now, read through content_repository.dart, and a
     channel is a LIST — the team runs more than one number and the app shows
     all of them. Nothing that Isaac may need to change belongs in this file. */

  /// THE GUARDIAN PORTAL IS A WEBSITE, ON PURPOSE.
  ///
  /// A parent following a candidate is not a second app to install, keep
  /// updated and sign into on a phone they may share. It is one page they
  /// open, so the app simply points at it. The student app stays a student
  /// app: nothing here can hold a guardian session.
  static const guardianPortal = '$apiBase/guardian';
}
