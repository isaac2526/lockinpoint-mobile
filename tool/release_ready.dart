// =============================================================================
// WHAT "PRODUCTION READY" MEANS, CHECKED RATHER THAN ASSERTED.
//
//   dart tool/release_ready.dart
//
// A build that compiles is not a build that is fit to publish. Every rule
// below is one of the things that has actually gone wrong in shipped mobile
// apps: a debug base URL left in, a key pasted into a constant, a test account
// still wired up, a version name that drifted from the build number. None of
// them breaks the build, and every one of them is visible to anybody who
// unzips the artifact.
//
// This runs with no Android SDK, no network and no toolchain beyond Dart, so
// it runs in `check` on every push and in the first seconds of the release
// workflow rather than being remembered at the end.
// =============================================================================
import 'dart:io';

int problems = 0;
void fail(String rule, String detail) {
  problems++;
  stdout.writeln('  FAIL  $rule\n        $detail');
}

void pass(String rule) => stdout.writeln('  ok    $rule');

Iterable<File> dartFiles(String dir) sync* {
  final d = Directory(dir);
  if (!d.existsSync()) return;
  for (final e in d.listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) yield e;
  }
}

/// Source lines with comments stripped, so a rule cannot fire on prose that
/// merely EXPLAINS the thing it forbids — vault_open_web.dart documents
/// `dart:ffi` in its header, and an earlier check failed on exactly that.
///
/// IT HAS TO UNDERSTAND STRINGS, AND THE FIRST VERSION DID NOT. It cut every
/// line at the first `//`, and `'http://10.0.2.2:3000'` contains one — so a
/// planted emulator host was trimmed to `'http:` and the development-host rule
/// reported nothing at all. That is the worst possible failure for a guard:
/// not a wrong answer, a confident silence. Proven by planting that exact line
/// and watching the rule stay quiet.
List<String> codeLines(File f) {
  final out = <String>[];
  var inBlock = false;
  for (final raw in f.readAsLinesSync()) {
    final buf = StringBuffer();
    String? quote;
    var i = 0;
    while (i < raw.length) {
      final two = i + 1 < raw.length ? raw.substring(i, i + 2) : '';
      if (inBlock) {
        if (two == '*/') {
          inBlock = false;
          i += 2;
        } else {
          i++;
        }
        continue;
      }
      if (quote != null) {
        // Inside a string: a backslash escapes the next character, and
        // nothing here starts a comment.
        if (raw[i] == r'\' && i + 1 < raw.length) {
          buf.write(raw.substring(i, i + 2));
          i += 2;
          continue;
        }
        if (raw[i] == quote) quote = null;
        buf.write(raw[i]);
        i++;
        continue;
      }
      if (two == '//') break; // rest of the line is a comment
      if (two == '/*') {
        inBlock = true;
        i += 2;
        continue;
      }
      if (raw[i] == "'" || raw[i] == '"') quote = raw[i];
      buf.write(raw[i]);
      i++;
    }
    final line = buf.toString();
    if (line.trim().isNotEmpty) out.add(line);
  }
  return out;
}

void main() {
  stdout.writeln('release-ready · what ships, and what must not\n');

  // ---- 1 · THE ONLY BACKEND IS THE PRODUCTION ONE -------------------------
  final config = File('lib/core/config.dart').readAsStringSync();
  final base = RegExp(r"defaultValue: '([^']+)'").firstMatch(config)?.group(1);
  if (base == 'https://www.lockinpoint.com') {
    pass('apiBase defaults to the production host ($base)');
  } else {
    fail('apiBase', 'the compiled-in default is "$base", not the live site');
  }

  // A debug host anywhere in lib/ ships inside the APK whether it is reached
  // or not, and `10.0.2.2` is the emulator's name for the developer's laptop.
  final devHosts = RegExp(
    r'(localhost|127\.0\.0\.1|10\.0\.2\.2|0\.0\.0\.0|ngrok|\.local\b|:3000|:8080)',
  );
  final hostHits = <String>[];
  for (final f in dartFiles('lib')) {
    for (final line in codeLines(f)) {
      final m = devHosts.firstMatch(line);
      if (m != null) hostHits.add('${f.path}: ${line.trim()}');
    }
  }
  if (hostHits.isEmpty) {
    pass('no development host is compiled into lib/');
  } else {
    fail('development host in lib/', hostHits.join('\n        '));
  }

  // ---- 2 · NO SECRET IS COMPILED IN --------------------------------------
  // The app reaches everything through the API and holds no provider key at
  // all — not Supabase's, not Paystack's, not an AI provider's. These are the
  // shapes those keys take, so a paste is caught the day it happens.
  final secretShapes = <String, RegExp>{
    'a Supabase service-role or anon JWT': RegExp(
      r'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}',
    ),
    'a Paystack secret key': RegExp(r'sk_(live|test)_[A-Za-z0-9]{10,}'),
    'a Google API key': RegExp(r'AIza[A-Za-z0-9_\-]{30,}'),
    'an OpenAI/Anthropic key': RegExp(
      r'\b(sk-ant-|sk-proj-|sk-[A-Za-z0-9]{32,})',
    ),
    'a private key block': RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'),
  };
  final secretHits = <String>[];
  for (final f in dartFiles('lib')) {
    final text = f.readAsStringSync();
    secretShapes.forEach((what, re) {
      if (re.hasMatch(text)) secretHits.add('${f.path}: $what');
    });
  }
  // And the two files a keystore would arrive in, which are git-ignored and
  // must stay that way — a committed key.properties strands every install.
  for (final p in [
    'android/key.properties',
    'android/app/upload-keystore.jks',
    'android/upload-keystore.jks',
  ]) {
    if (File(p).existsSync()) {
      secretHits.add('$p is present in the working tree');
    }
  }
  if (secretHits.isEmpty) {
    pass('no key, token or keystore is in the app source');
  } else {
    fail('a secret is in the source', secretHits.join('\n        '));
  }

  // ---- 3 · NO TEST DATA AND NO BYPASS ------------------------------------
  // A hardcoded account or an `if (kDebugMode) return true` around a gate is
  // the one that reaches a real student.
  final testShapes = <String, RegExp>{
    /* USED AS A VALUE, not merely written down. `_field(_email, 'Email',
       'you@example.com')` passes the address as a HINT — its third positional
       is `String hint` — and a rule that cannot tell the difference fires on
       correct code until somebody switches it off. So this matches an address
       being ASSIGNED: after `=`, or as a named argument that carries data
       (text:, value:, initialValue:, email:, username:, body:). A bare
       positional literal is ambiguous and, like check-columns, this must never
       invent a failure. */
    'a test email address': RegExp(
      r"(=|\b(text|value|initialValue|initialEmail|email|username|user|login|body|defaultValue)\s*:)\s*'[A-Za-z0-9._%+-]+@(example|test|mailinator|yopmail)\.",
    ),
    'a password in a literal': RegExp(
      r"(password|passwd|pwd)\s*[:=]\s*'[^']{4,}'",
      caseSensitive: false,
    ),
    'a debug-mode gate bypass': RegExp(r'kDebugMode\s*(\?|\|\||&&)'),
    'a TODO left in a release path': RegExp(r'\bFIXME\b'),
  };
  /* A PLACEHOLDER IS NOT TEST DATA, AND THE FIRST SPELLING OF THIS RULE SAID
     IT WAS. example.com is the domain RFC 2606 reserves for exactly this, so
     `hintText: 'you@example.com'` in a login field is the correct thing to
     write, not a leftover account. What the rule is looking for is an address
     that is USED — assigned to a controller, held in a constant, posted as a
     default — so the hint and label properties are exempt and nothing else
     is. A rule that fires on good code gets switched off, and then it is not
     protecting anything. */
  final placeholder = RegExp(
    r'\b(hintText|labelText|helperText|placeholder|semanticsLabel)\s*:',
  );
  final testHits = <String>[];
  for (final f in dartFiles('lib')) {
    for (final line in codeLines(f)) {
      testShapes.forEach((what, re) {
        if (!re.hasMatch(line)) return;
        if (what == 'a test email address' && placeholder.hasMatch(line)) {
          return;
        }
        testHits.add('${f.path}: $what · ${line.trim()}');
      });
    }
  }
  if (testHits.isEmpty) {
    pass('no test account, literal password or debug bypass in lib/');
  } else {
    fail('test data or a bypass in lib/', testHits.join('\n        '));
  }

  // ---- 4 · THE IDENTITY THAT CAN NEVER CHANGE ----------------------------
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  if (gradle.contains('applicationId = "com.lockinpoint.app"')) {
    pass('Android applicationId is com.lockinpoint.app');
  } else {
    fail(
      'applicationId',
      'com.lockinpoint.app is not the id this build would publish',
    );
  }
  if (gradle.contains('isMinifyEnabled = true') &&
      gradle.contains('isShrinkResources = true')) {
    pass('the release build shrinks and obfuscates');
  } else {
    fail('release build type', 'minify or shrinkResources is off');
  }
  final ios = File('ios/Runner.xcodeproj/project.pbxproj');
  if (ios.existsSync()) {
    final t = ios.readAsStringSync();
    if (t.contains('PRODUCT_BUNDLE_IDENTIFIER = com.lockinpoint.app;')) {
      pass('iOS bundle identifier is com.lockinpoint.app');
    } else {
      fail(
        'iOS bundle id',
        'com.lockinpoint.app is not set on every configuration',
      );
    }
  }

  // ---- 5 · THE VERSION THE SERVER WILL BE TOLD ---------------------------
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final v = RegExp(
    r'^version:\s*([0-9.]+)\+([0-9]+)',
    multiLine: true,
  ).firstMatch(pubspec);
  final cfgName = RegExp(r"appVersion = '([^']+)'")
      .firstMatch(config)
      ?.group(1);
  final cfgCode = RegExp(r'buildNumber = (\d+)').firstMatch(config)?.group(1);
  if (v != null && v.group(1) == cfgName && v.group(2) == cfgCode) {
    pass('version ${v.group(1)}+${v.group(2)} agrees in pubspec and AppConfig');
  } else {
    fail(
      'version drift',
      'pubspec says ${v?.group(1)}+${v?.group(2)}, AppConfig says $cfgName+$cfgCode · '
          'every request would name a build that does not exist',
    );
  }

  // ---- 6 · THE PERMISSIONS AND THE DECLARATIONS STORES READ --------------
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  for (final key in [
    'NSPhotoLibraryUsageDescription',
    'NSCameraUsageDescription',
    'ITSAppUsesNonExemptEncryption',
  ]) {
    if (plist.contains(key)) {
      pass('Info.plist declares $key');
    } else {
      fail(
        'Info.plist',
        '$key is missing · iOS terminates the app, or review stalls on it',
      );
    }
  }

  // The in-app route to deleting an account. Google Play refuses a listing
  // without one, and refuses it AFTER review rather than at upload.
  final profile = File('lib/features/profile/profile_screen.dart')
      .readAsStringSync();
  if (profile.contains('AppConfig.deleteAccount') &&
      profile.contains('AppConfig.privacyPolicy') &&
      profile.contains('AppConfig.termsOfUse')) {
    pass('the app carries an in-product route to deletion, privacy and terms');
  } else {
    fail(
      'store requirements',
      'the profile screen is missing one of the three links a reviewer looks for',
    );
  }

  stdout.writeln(
    problems == 0
        ? '\nrelease-ready: nothing in this tree blocks a publish.'
        : '\nrelease-ready: $problems problem${problems == 1 ? "" : "s"}. Do not publish.',
  );
  exit(problems == 0 ? 0 : 1);
}
