import '../core/json.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'config.dart';

/// ===========================================================================
/// IS THERE A NEWER ONE?
///
/// MOST OF THESE INSTALLS ARE SIDELOADED. The APK is handed out by link, and
/// a phone that installs an APK that way is never told a newer one exists —
/// there is no store watching it. So a student stays on whatever build they
/// happened to download, forever, and the fix Isaac shipped last night never
/// reaches them.
///
/// /api/public/downloads has carried the answer since the landing page was
/// built: every platform's current version, version_code, release notes and
/// URL, all of it edited in Admin. No client had ever read it.
///
/// COMPARISON IS ON version_code, NOT ON THE NAME. "2.0.10" sorts before
/// "2.0.9" as text and a name can be anything an admin types; the code is an
/// integer that only ever goes up, which is the whole reason Play requires
/// one.
/// ===========================================================================
class AppUpdate {
  const AppUpdate({
    required this.available,
    required this.version,
    required this.notes,
    required this.url,
    required this.buildNumber,
  });

  final bool available;
  final String version;
  final String notes;
  final String url;
  final int buildNumber;

  static const none = AppUpdate(
    available: false,
    version: '',
    notes: '',
    url: '',
    buildNumber: 0,
  );
}

/// Which row of the downloads table belongs to the machine this is running
/// on. The web build never offers itself an update: it IS the newest one the
/// moment it is served.
String? currentPlatformKey() {
  if (kIsWeb) return null;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.windows => 'windows',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.linux => 'linux',
    _ => null,
  };
}

/// Reads the published downloads and decides whether this install is behind.
///
/// Never throws and never blocks: an update notice that fails to load must
/// cost the student nothing at all, which is why every failure returns
/// [AppUpdate.none] rather than an error a screen would have to render.
Future<AppUpdate> checkForUpdate(Api api, {String? platformKey}) async {
  final want = platformKey ?? currentPlatformKey();
  if (want == null) return AppUpdate.none;

  try {
    final res = await api.get('/api/public/downloads');
    for (final p
        in ((res['platforms'] as List?) ?? const []).whereType<Map>()) {
      if ((asText(p['platform'])).toLowerCase() != want) continue;

      /* AN ADMIN CAN TAKE A DOWNLOAD OFFLINE, and a row that is not
         available must not be offered as an upgrade — pointing a student at
         a link that is deliberately down is worse than saying nothing. */
      if (p['available'] == false) return AppUpdate.none;

      final code = asInt(p['version_code']);
      final url = asText(p['url']);
      if (code <= AppConfig.buildNumber || url.isEmpty) return AppUpdate.none;

      return AppUpdate(
        available: true,
        version: asText(p['version']),
        notes: asText(p['release_notes']),
        url: url,
        buildNumber: code,
      );
    }
  } catch (_) {
    // See above. Silence is the correct failure mode for this one.
  }
  return AppUpdate.none;
}

final updateCheckProvider = FutureProvider<AppUpdate>(
  (ref) => checkForUpdate(ref.read(apiProvider)),
);
