import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// ===========================================================================
/// WHAT GENUINELY BEHAVES DIFFERENTLY ON EACH PLATFORM
///
/// Not "does it build". A Flutter app compiles perfectly for a platform whose
/// plugins it does not have, and then throws MissingPluginException the first
/// time a student taps the thing that needed one. The compiler is silent about
/// it; the pubspec is not.
///
/// This reads the RESOLVED plugins' own pubspecs and holds the app to what
/// they actually support. It is the check that found the desktop bug: every
/// document, on every desktop build, reported "That file could not be opened"
/// — because open_filex ships android and ios only.
/// ===========================================================================

/// The platforms a resolved plugin really declares.
Set<String> platformsOf(String package) {
  final cache = Directory(
    '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev',
  );
  if (!cache.existsSync()) return {};
  final dirs =
      cache
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.split('/').last.startsWith('$package-'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (dirs.isEmpty) return {};

  final y = loadYaml(File('${dirs.last.path}/pubspec.yaml').readAsStringSync());
  final p = y['flutter']?['plugin']?['platforms'];
  if (p == null) return {'all'}; // pure Dart: everywhere
  return (p as YamlMap).keys.map((k) => '$k').toSet();
}

void main() {
  test('every platform folder that exists is one we mean to ship', () {
    for (final dir in ['android', 'ios', 'web', 'windows', 'macos', 'linux']) {
      expect(
        Directory(dir).existsSync(),
        isTrue,
        reason: '$dir/ is missing — that platform cannot be built at all',
      );
    }
  });

  test('open_filex is phones only, so desktop MUST have another way', () {
    /* THE BUG THIS CAUGHT. DocumentOpener called OpenFilex.open on every
       platform. Its pubspec declares android and ios and nothing else, so on
       macOS, Windows and Linux the call threw MissingPluginException, was
       swallowed by a catch-all, and every document failed identically with
       "That file could not be opened" — no reason, no way forward. */
    final p = platformsOf('open_filex');
    expect(p, isNotEmpty, reason: 'open_filex did not resolve');
    expect(p, isNot(contains('macos')));
    expect(p, isNot(contains('windows')));
    expect(p, isNot(contains('linux')));

    final src = File('lib/core/vault/materials.dart').readAsStringSync();
    expect(
      src.contains('Platform.isAndroid || Platform.isIOS'),
      isTrue,
      reason: 'materials.dart calls OpenFilex on every platform again',
    );
    expect(
      src.contains('launchUrl(f.uri)'),
      isTrue,
      reason: 'desktop has no fallback way to open a downloaded file',
    );
  });

  test('the store is only offered where a store exists', () {
    // in_app_purchase: android, ios, macos. Never Windows, Linux or the web.
    final p = platformsOf('in_app_purchase');
    expect(p, isNot(contains('windows')));
    expect(p, isNot(contains('linux')));
    expect(p, isNot(contains('web')));

    final src = File('lib/features/activation/store_purchase.dart')
        .readAsStringSync();
    expect(
      src.contains('!kIsWeb && (Platform.isAndroid || Platform.isIOS)'),
      isTrue,
      reason:
          'the app would offer a Play/App Store purchase where there is '
          'no store to buy from',
    );
  });

  test('the vault is hidden where there is no database to put it in', () {
    // sqlite3_flutter_libs has every platform EXCEPT the web.
    final p = platformsOf('sqlite3_flutter_libs');
    expect(p, contains('windows'));
    expect(p, contains('macos'));
    expect(p, contains('linux'));
    expect(p, isNot(contains('web')));

    final features = File('lib/features/home/feature_catalogue.dart')
        .readAsStringSync();
    expect(
      features.contains("kIsWeb ? kFeatures.where((f) => f.key != 'vault')"),
      isTrue,
      reason: 'the web build would show a vault tile that cannot open',
    );

    /* AND NOTHING MAY REACH FOR THE DATABASE ON THE WEB EITHER. The
       first-launch check did, inside a `catch (ApiFailure)` that could not
       catch drift's UnsupportedError — so every web launch raised an
       unhandled async error, swallowed by the global handler and invisible. */
    final essential = File('lib/core/vault/essential_download.dart')
        .readAsStringSync();
    expect(
      essential.contains('if (kIsWeb)'),
      isTrue,
      reason: 'the first-launch download still opens the vault on the web',
    );
  });

  test(
    'the web build has a drift backend that refuses rather than crashes',
    () {
      final web = File('lib/core/vault/vault_open_web.dart').readAsStringSync();
      /* The IMPORTS, not the prose: this file EXPLAINS dart:ffi in its own
         doc comment, and a plain substring check fails on the explanation —
         a test that reads the wrong thing is how a good file gets "fixed"
         into a broken one. */
      final imports = web
          .split('\n')
          .where((l) => l.trimLeft().startsWith('import '))
          .join('\n');
      expect(
        imports.contains('ffi') || imports.contains('drift/native'),
        isFalse,
        reason:
            'importing any native drift backend into a web build breaks the '
            'WHOLE application, not just the vault',
      );
      expect(web.contains('UnsupportedError'), isTrue);
    },
  );

  test('nothing in lib/ imports dart:io without a platform guard nearby', () {
    /* dart:io does not exist in a browser. A bare import is a web build that
       fails to compile — or worse, one that compiles and dies at runtime. */
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (!src.contains("import 'dart:io'")) continue;
      final guarded =
          src.contains('kIsWeb') ||
          src.contains('Platform.is') ||
          f.path.contains('vault_open_io');
      if (!guarded) offenders.add(f.path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these reach for dart:io with no idea what platform they are '
          'on:\n${offenders.join('\n')}',
    );
  });

  test('iOS declares every permission the app actually asks for', () {
    /* THE BUG THIS CAUGHT, and it is a hard crash rather than a bug.

       image_picker is used in two places — uploading proof of a bank
       transfer on the activation screen, and sending a photo into a
       Pointgram room. iOS does NOT return an error when an app opens the
       photo library without a usage string: it TERMINATES THE APP, instantly,
       with no dialog and nothing in the log a student could report. App Store
       review rejects the binary as well, so it would never have shipped —
       but a TestFlight build would have died in Tutor Bello's hand. */
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    final usesPicker = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .any((f) => f.readAsStringSync().contains('ImagePicker('));

    if (usesPicker) {
      expect(
        plist,
        contains('NSPhotoLibraryUsageDescription'),
        reason:
            'the app opens the photo library; without this key iOS kills '
            'it the instant a student taps the button',
      );
      expect(plist, contains('NSCameraUsageDescription'));
    }

    // And the sentence must actually say something — an empty string is the
    // same rejection.
    for (final key in const [
      'NSPhotoLibraryUsageDescription',
      'NSCameraUsageDescription',
    ]) {
      final i = plist.indexOf('<key>$key</key>');
      if (i < 0) continue;
      final value = plist.substring(i, plist.indexOf('</string>', i));
      expect(
        value.length,
        greaterThan(key.length + 40),
        reason: '$key has no real sentence in it',
      );
    }
  });

  test('Android can see the apps it needs to hand a file to', () {
    /* Android 11 hid other apps unless you declare a <queries> block.
       Without it, "open this PDF" finds nothing even when a reader is
       installed — which looks exactly like a broken download. */
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('<queries>'));
    expect(manifest, contains('android.permission.INTERNET'));
  });
}
