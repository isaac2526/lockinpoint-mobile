import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/core/config.dart';
import 'package:lockinpoint/core/update_check.dart';

/// ===========================================================================
/// IS THERE A NEWER BUILD?
///
/// Most installs are sideloaded from a link, and nothing watches those. The
/// answer has been in /api/public/downloads since the landing page was built
/// and no client had ever read it, so a student stayed on whatever APK they
/// first downloaded and every fix after it went nowhere.
/// ===========================================================================

class _Downloads extends Fake implements Api {
  _Downloads(this.platforms);
  final List<Map<String, dynamic>> platforms;

  /// Set when the request was made at all, so "returns none" can be told
  /// apart from "never asked".
  bool asked = false;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    asked = true;
    return {'ok': true, 'platforms': platforms};
  }
}

class _Dead extends Fake implements Api {
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async => throw ApiFailure('no network');
}

Map<String, dynamic> row({
  String platform = 'android',
  int code = 99,
  String version = '9.9.9',
  bool available = true,
  String url = 'https://example.test/app.apk',
  String notes = 'Faster on cheap phones.',
}) => {
  'platform': platform,
  'version': version,
  'version_code': code,
  'release_notes': notes,
  'url': url,
  'available': available,
};

void main() {
  test(
    'a higher build number is offered, with its notes and its link',
    () async {
      final api = _Downloads([row()]);
      final u = await checkForUpdate(api, platformKey: 'android');
      expect(u.available, isTrue);
      expect(u.version, '9.9.9');
      expect(u.notes, 'Faster on cheap phones.');
      expect(u.url, 'https://example.test/app.apk');
    },
  );

  test('the build this phone is running is not an update', () async {
    final api = _Downloads([row(code: AppConfig.buildNumber)]);
    expect(
      (await checkForUpdate(api, platformKey: 'android')).available,
      isFalse,
    );
  });

  test('an older published build is never offered', () async {
    final api = _Downloads([row(code: AppConfig.buildNumber - 1)]);
    expect(
      (await checkForUpdate(api, platformKey: 'android')).available,
      isFalse,
    );
  });

  test('comparison is on the CODE, not on the name', () async {
    /* "2.0.9" sorts after "2.0.10" as text, which is exactly the trap a
       string comparison walks into. The code is an integer and only ever
       goes up. */
    final api = _Downloads([
      row(version: '2.0.9', code: AppConfig.buildNumber + 1),
    ]);
    final u = await checkForUpdate(api, platformKey: 'android');
    expect(u.available, isTrue);
    expect(u.version, '2.0.9');
  });

  test('another platform’s newer build is not this one’s', () async {
    final api = _Downloads([row(platform: 'windows')]);
    expect(
      (await checkForUpdate(api, platformKey: 'android')).available,
      isFalse,
    );
  });

  test('a download an admin took offline is not offered', () async {
    // Pointing a student at a link that is deliberately down is worse than
    // saying nothing at all.
    final api = _Downloads([row(available: false)]);
    expect(
      (await checkForUpdate(api, platformKey: 'android')).available,
      isFalse,
    );
  });

  test('a row with no URL is not offered', () async {
    final api = _Downloads([row(url: '')]);
    expect(
      (await checkForUpdate(api, platformKey: 'android')).available,
      isFalse,
    );
  });

  test('a failed check costs the student nothing', () async {
    // Silence is the correct failure mode: an update notice must never be
    // the reason a home screen shows an error.
    expect(
      (await checkForUpdate(_Dead(), platformKey: 'android')).available,
      isFalse,
    );
  });
}
