// ignore_for_file: avoid_print
import 'dart:io';

/// ===========================================================================
/// EVERY @resource THE ANDROID PROJECT NAMES MUST EXIST.
///
/// `flutter build appbundle` failed to link because ic_launcher.xml drew its
/// background from @color/ic_launcher_background and a change to colors.xml
/// had replaced that colour rather than joined it:
///
///     error: resource color/ic_launcher_background not found
///     error: failed linking file resources
///
/// Nothing in this repository could have caught it. `flutter analyze` does not
/// read Android resources; no test touches them; and the only build that links
/// them is the release bundle, which runs on a hosted runner four minutes into
/// a job. The app compiled, analysed and passed every test while being
/// impossible to ship.
///
/// So: a check that reads the same references aapt2 does, in under a second,
/// with no Android toolchain at all. It runs in CI before the bundle is built,
/// and a developer can run it on a phone-tethered laptop.
///
///     dart tool/check_android_res.dart
///
/// It is deliberately NOT a full aapt2. It resolves the reference forms this
/// project actually uses — @color, @drawable, @mipmap, @style, @string — and
/// ignores the @android/ namespace, which is the platform's, not ours.
/// ===========================================================================

const _root = 'android/app/src/main/res';

/// A reference as it is written in XML: `@color/foo`, `@drawable/bar`.
final _ref = RegExp(r'@(color|drawable|mipmap|style|string|array|dimen)/(\w+)');

/// The `<resources>` value forms — `<color name="x">`, `<style name="y">`.
final _declared = RegExp(
  r'<(color|string|style|integer|dimen|bool|array|string-array|item)\s[^>]*name="([\w.]+)"',
);

void main(List<String> args) {
  final res = Directory(_root);
  if (!res.existsSync()) {
    print('check-android-res: no $_root — nothing to check.');
    exit(0);
  }

  /// What exists, as "type/name". A FILE resource is named by its basename in
  /// any density folder: drawable-hdpi/launch_image.png declares
  /// drawable/launch_image, and one density is enough for the reference to
  /// resolve.
  final have = <String>{};

  /// Where each reference was written, so a failure names the file to open.
  final want = <String, Set<String>>{};

  for (final e in res.listSync(recursive: true).whereType<File>()) {
    final dir = e.parent.path.split(Platform.pathSeparator).last;
    // "drawable-night-v21" -> "drawable"; "values-night" -> "values".
    final kind = dir.split('-').first;
    final name = e.uri.pathSegments.last;
    final stem = name.contains('.')
        ? name.substring(0, name.indexOf('.'))
        : name;

    if (kind == 'values') {
      final body = e.readAsStringSync();
      for (final m in _declared.allMatches(body)) {
        final tag = m.group(1)!;
        final n = m.group(2)!;
        // <item name="android:windowBackground"> inside a style is a property,
        // not a declaration. Only a bare name declares a resource.
        if (n.contains(':')) continue;
        have.add('${tag == 'string-array' ? 'array' : tag}/$n');
      }
    } else {
      have.add('$kind/$stem');
    }

    if (name.endsWith('.xml')) {
      for (final m in _ref.allMatches(e.readAsStringSync())) {
        want.putIfAbsent('${m.group(1)}/${m.group(2)}', () => {}).add(e.path);
      }
    }
  }

  // The manifest names resources too, and is the one that decides the icon.
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (manifest.existsSync()) {
    for (final m in _ref.allMatches(manifest.readAsStringSync())) {
      want
          .putIfAbsent('${m.group(1)}/${m.group(2)}', () => {})
          .add(manifest.path);
    }
  }

  final missing = <String, Set<String>>{};
  want.forEach((ref, where) {
    if (!have.contains(ref)) missing[ref] = where;
  });

  if (missing.isEmpty) {
    print(
      'check-android-res: ${want.length} references, '
      '${have.length} resources — every one resolves.',
    );
    exit(0);
  }

  stderr.writeln('check-android-res: MISSING ANDROID RESOURCES\n');
  missing.forEach((ref, where) {
    stderr.writeln('  @$ref');
    for (final w in where) {
      stderr.writeln('      named by $w');
    }
  });
  stderr.writeln(
    '\naapt2 refuses to link a reference with no resource, so the release '
    'bundle cannot be built until each of these is declared or the reference '
    'is removed.',
  );
  exit(1);
}
