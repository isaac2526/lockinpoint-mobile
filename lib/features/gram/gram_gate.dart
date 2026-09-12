import '../../core/json.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api.dart';

/// ===========================================================================
/// THE DOOR TO POINTGRAM
///
/// A LOCKED POINTGRAM WAS IMPASSABLE FROM THE APP. An admin can put the rooms
/// behind a shared code; the website answers that with a PIN box, and the app
/// had nothing — /api/gram/gate had never been called from here, so a student
/// on a phone met an error they could do nothing about and the rooms stayed
/// shut for as long as the lock was on.
///
/// The lobby also used to GUESS at the state of the door: it caught a failure
/// and looked for the word "gate" in the message. This route says it outright
/// — switched off, locked, or open — and says who is here right now, which is
/// the Online tab's whole diet.
///
/// The code is remembered in plain preferences rather than the secure store.
/// It is not a credential: it identifies nobody, grants nothing without a
/// session, and every student in the room has it written on a whiteboard.
/// ===========================================================================
class GramGate {
  const GramGate({
    required this.enabled,
    required this.locked,
    required this.passed,
    required this.online,
    required this.myUid,
    required this.myUsername,
  });

  /// False when an admin has switched Pointgram off entirely. Not a fault —
  /// a door, and it must not be reported as one.
  final bool enabled;

  /// True when the rooms are behind the shared code.
  final bool locked;

  /// True when this client has already presented the right code.
  final bool passed;

  /// Who is alive right now — anyone whose heartbeat landed in the last 45
  /// seconds.
  final List<({String username, bool activated})> online;

  final String myUid;
  final String myUsername;

  bool get open => enabled && (!locked || passed);

  static const closed = GramGate(
    enabled: false,
    locked: false,
    passed: false,
    online: [],
    myUid: '',
    myUsername: '',
  );

  static GramGate fromJson(Map<String, dynamic> j) {
    final me = (j['me'] as Map?)?.cast<String, dynamic>() ?? const {};
    return GramGate(
      enabled: j['enabled'] != false,
      locked: j['locked'] == true,
      passed: j['passed'] == true,
      online: ((j['online'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (m) => (
              username: asText(m['username'], 'student'),
              activated: m['activated'] == true,
            ),
          )
          .toList(),
      myUid: asText(me['uid']),
      myUsername: asText(me['username']),
    );
  }
}

const _pinKey = 'lip.gram_pin';

/// Reads the remembered code off the disk and hands it to the client BEFORE
/// anything asks the gate. Without this the first request after a restart
/// arrives without the code, is refused, and the student is asked to type a
/// code they already gave.
///
/// IT IS BOUNDED, AND THAT IS NOT DEFENSIVE DECORATION. A widget test proved
/// SharedPreferences.getInstance() can never complete at all — in the test
/// binding it hangs forever — and an unbounded await here left the whole
/// Pointgram lobby sitting on a skeleton with no error and no way out. The
/// same shape is reachable on a device whose platform channel is wedged.
///
/// If the read is slow it is NOT abandoned: it still applies the code when it
/// arrives, so at worst one request goes out without it and a pull to refresh
/// puts the student back in the room.
Future<void> restoreGramPin(Api api) async {
  Future<void> apply() async {
    try {
      final pin = (await SharedPreferences.getInstance()).getString(_pinKey);
      if (pin != null && pin.isNotEmpty) api.gramPin = pin;
    } catch (_) {
      // A preferences store that will not open is not worth a failed launch.
    }
  }

  final reading = apply();
  await reading.timeout(
    const Duration(seconds: 2),
    onTimeout: () {
      // Deliberately keeps `reading` alive. See above: late is better than
      // never for a code the student has already given us.
      return;
    },
  );
}

class GramDoor extends AsyncNotifier<GramGate> {
  @override
  Future<GramGate> build() async {
    final api = ref.read(apiProvider);
    await restoreGramPin(api);
    try {
      return GramGate.fromJson(await api.get('/api/gram/gate'));
    } on ApiFailure {
      /* A gate that cannot be read is reported as SHUT rather than as an
         error screen. The rooms may genuinely be off; either way there is
         nothing here for the student to fix, and a red page over a chat room
         reads as "the app is broken". */
      return GramGate.closed;
    }
  }

  /// Knock. Returns null when the door opens, or the server's own sentence
  /// when it does not — never a guess made from a status code.
  Future<String?> knock(String pin) async {
    final api = ref.read(apiProvider);
    final clean = pin.trim();
    if (clean.isEmpty) return 'Type the room code.';
    try {
      final res = await api.post('/api/gram/gate', body: {'pin': clean});
      if (res['ok'] == false) {
        return asText(res['message'], 'That is not the room code.');
      }
      /* The code is set on the client FIRST, then remembered. The refresh
         below is the first request that must carry it, and a write to disk
         that is slow or fails must not cost this student the room they just
         unlocked. */
      api.gramPin = clean;
      try {
        await (await SharedPreferences.getInstance()).setString(_pinKey, clean);
      } catch (_) {
        // Remembered for this run only. Better than refusing to open.
      }
      ref.invalidateSelf();
      await future;
      return null;
    } on ApiFailure catch (e) {
      return e.message;
    }
  }

  /// Forget the code — used when signing out, so the next person on this
  /// phone does not inherit the room.
  Future<void> forget() async {
    ref.read(apiProvider).gramPin = null;
    try {
      await (await SharedPreferences.getInstance()).remove(_pinKey);
    } catch (_) {}
  }
}

final gramGateProvider = AsyncNotifierProvider<GramDoor, GramGate>(
  GramDoor.new,
);
