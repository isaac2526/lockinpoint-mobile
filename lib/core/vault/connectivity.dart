import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';

/// ===========================================================================
/// IS THERE A NETWORK? ASK THE NETWORK, NOT A PLUGIN.
///
/// connectivity_plus reports what the OS believes about its interfaces — and
/// on Linux without NetworkManager, on some Windows setups and on parts of
/// the web it says "none" while requests sail through. The founder's
/// installed build wore a permanent amber "No connection" bar over a working
/// network, and anything gated on that flag was dead on arrival.
///
/// So the plugin's word is now a HINT, verified before it is believed:
///
///   plugin says online   → believed. False positives (hotel wifi) cost
///                          nothing here, because no ACTION is ever gated on
///                          this flag — requests always try, and the vault
///                          answers when they fail. The flag only drives the
///                          reassurance bar and the auto-sync nudge.
///   plugin says offline  → CHECKED, with one cheap ping to our own server.
///                          Only a ping that fails makes the app say offline.
///
/// The ping goes to /api/mobile/ping — the route built for exactly this — on
/// a Dio of its own with tight timeouts and no auth, so a probe can never
/// touch session state or hang behind a slow call.
/// ===========================================================================

final _probe = Dio(
  BaseOptions(
    baseUrl: AppConfig.apiBase,
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
  ),
);

Future<bool> _reachable() async {
  try {
    await _probe.get('/api/mobile/ping');
    return true;
  } catch (_) {
    return false;
  }
}

/// Where connectivity_plus can actually be trusted.
///
/// Its Linux implementation asks NetworkManager over D-Bus and its Windows
/// and web ones are similarly indirect — which is why the installed desktop
/// build wore a permanent "No connection" bar over a working network. Worse,
/// on a machine with no D-Bus socket the plugin's signal listener throws
/// ASYNCHRONOUSLY, escaping every try/catch around the call, so it cannot
/// even be guarded — a fault this drive caught by running the real binary.
///
/// On a phone the plugin is exactly right: it knows about aeroplane mode and
/// a dropped mast the instant they happen, without a request. Everywhere else
/// the only honest answer comes from asking our own server.
bool get _trustPlugin =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

final connectivityProvider = StreamProvider<bool>((ref) async* {
  if (!_trustPlugin) {
    /* DESKTOP AND WEB: ask the server, rarely. This flag drives a
       reassurance bar and a sync nudge — nothing is ever GATED on it, so a
       thirty-second granularity costs nothing and a wrong answer costs
       nothing either. */
    yield await _reachable();
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 30));
      yield await _reachable();
    }
  }

  final c = Connectivity();

  bool up(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);

  /// The plugin's word is a HINT, verified before it is believed. A false
  /// positive (hotel wifi with no route) costs nothing here; a false negative
  /// would tell a student they are offline while their requests succeed, so
  /// only a failed ping to our own server confirms it.
  Future<bool> verdict(List<ConnectivityResult> r) async =>
      up(r) ? true : _reachable();

  try {
    yield await verdict(await c.checkConnectivity());
    await for (final r in c.onConnectivityChanged) {
      yield await verdict(r);
    }
  } catch (_) {
    // Even on a phone, a plugin that dies must not take the flag with it.
    while (true) {
      yield await _reachable();
      await Future<void>.delayed(const Duration(seconds: 30));
    }
  }
});

/// True when the phone believes it has a network. Defaults to TRUE while
/// unknown: assuming offline would make the app behave as though it were
/// disconnected during the first frames of every launch.
final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).value ?? true,
);
