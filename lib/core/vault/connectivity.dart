import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ===========================================================================
/// IS THERE A NETWORK?
///
/// Used ONLY to decide what to attempt, never to decide what a student is
/// allowed to do. A phone that reports "connected" on a hotel wifi with no
/// route to the internet is common enough that this can never be the last
/// word — every request still tries, and the vault still answers when it
/// cannot.
///
/// `connectivity_plus` has been in the pubspec since the beginning with
/// nothing importing it. This is where it finally earns its place.
/// ===========================================================================
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();

  bool up(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);

  yield up(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(up);
});

/// True when the phone believes it has a network. Defaults to TRUE while
/// unknown: assuming offline would make the app behave as though it were
/// disconnected during the first frames of every launch.
final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).value ?? true,
);
