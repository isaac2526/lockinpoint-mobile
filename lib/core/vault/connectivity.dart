import 'package:connectivity_plus/connectivity_plus.dart';
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

final connectivityProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();

  bool up(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);

  Future<bool> verdict(List<ConnectivityResult> r) async =>
      up(r) ? true : _reachable();

  yield await verdict(await c.checkConnectivity());
  await for (final r in c.onConnectivityChanged) {
    yield await verdict(r);
  }
});

/// True when the phone believes it has a network. Defaults to TRUE while
/// unknown: assuming offline would make the app behave as though it were
/// disconnected during the first frames of every launch.
final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).value ?? true,
);
