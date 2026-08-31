import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/core/session_store.dart';
import 'package:lockinpoint/features/auth/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ===========================================================================
/// STARTUP: THE FIRST FRAME MUST NOT WAIT ON THE NETWORK
///
/// The app used to `await /api/me` before deciding whether a student was
/// signed in, and the dashboard then made a SECOND request behind it. Two
/// serial round trips stood between tapping the icon and using the app —
/// on the connection least able to afford them.
///
/// These tests pin the new law down so it cannot quietly regress:
///
///   · a stored session opens the app WITHOUT any request completing
///   · the greeting is the student's real name, remembered across launches
///   · only a REFUSED session signs anyone out — and when it does, the
///     stored token is cleared, so the next launch cannot walk back in and
///     start the same 401 over again
///   · being offline never locks a student out
/// ===========================================================================

/// A secure store that simply remembers, so these tests are about startup
/// and not about the keystore (which `session_and_api_test.dart` covers).
class _MemoryBox extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => data[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => data.remove(key);
}

/// An Api whose `/api/me` answers only when the test says so.
class _ScriptedApi extends Fake implements Api {
  _ScriptedApi();

  final _gate = Completer<Map<String, dynamic>>();
  int meCalls = 0;

  void answer(Map<String, dynamic> body) => _gate.complete(body);
  void refuse(String why) =>
      _gate.completeError(ApiFailure(why, unauthorised: true));
  void goOffline() =>
      _gate.completeError(ApiFailure('No connection.', offline: true));

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) {
    if (path == '/api/me') {
      meCalls++;
      return _gate.future;
    }
    return Future.value(const {});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryBox box;
  late _ScriptedApi api;
  late SessionStore store;

  ProviderContainer boot({String? name}) {
    SharedPreferences.setMockInitialValues(
      name == null ? const {} : {'lip.student-name': name},
    );
    box = _MemoryBox();
    api = _ScriptedApi();
    store = SessionStore(secure: box);
    final c = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        apiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> haveASession() =>
      store.save(access: 'access-abc', refresh: 'refresh-xyz');

  test(
    'with no stored session the app opens signed out, asking nothing',
    () async {
      final c = boot();
      final state = await c.read(authControllerProvider.future);
      expect(state, isA<SignedOut>());
      expect(
        api.meCalls,
        0,
        reason: 'a signed-out launch must not call the network',
      );
    },
  );

  test('a stored session opens the app without waiting for /api/me', () async {
    final c = boot(name: 'Adaeze');
    await haveASession();

    // /api/me is deliberately left hanging: this is a phone on a bad line.
    final state = await c
        .read(authControllerProvider.future)
        .timeout(const Duration(seconds: 1));

    expect(state, isA<SignedIn>());
    expect((state as SignedIn).name, 'Adaeze');
    expect(
      api.meCalls,
      1,
      reason: 'the check still runs — behind, not in front',
    );
  });

  test(
    'a launch with no remembered name still opens, greeting generically',
    () async {
      final c = boot();
      await haveASession();
      final state = await c.read(authControllerProvider.future);
      expect((state as SignedIn).name, 'Champion');
    },
  );

  test(
    'the quiet check corrects the greeting when the server knows better',
    () async {
      final c = boot(name: 'Champion');
      await haveASession();
      await c.read(authControllerProvider.future);

      api.answer({'name': 'Chinedu'});
      await pumpEventQueue();

      final now = c.read(authControllerProvider).value;
      expect((now as SignedIn).name, 'Chinedu');
      expect(
        (await SharedPreferences.getInstance()).getString('lip.student-name'),
        'Chinedu',
        reason: 'the corrected name must survive to the next launch',
      );
    },
  );

  test('a REFUSED session signs out AND clears the stored token', () async {
    final c = boot(name: 'Adaeze');
    await haveASession();
    await c.read(authControllerProvider.future);

    api.refuse('Your session has ended.');
    await pumpEventQueue();

    final now = c.read(authControllerProvider).value;
    expect(now, isA<SignedOut>());
    expect((now as SignedOut).message, 'Your session has ended.');

    /* The token MUST be gone. The gate now opens on a stored token alone, so
       leaving a refused one behind would let the next launch walk straight
       back in and hit the same 401 for ever. */
    expect(await store.refreshToken(), isNull);
    expect(
      (await SharedPreferences.getInstance()).getString('lip.student-name'),
      isNull,
    );
  });

  test('being offline never locks a student out', () async {
    final c = boot(name: 'Adaeze');
    await haveASession();
    await c.read(authControllerProvider.future);

    api.goOffline();
    await pumpEventQueue();

    expect(c.read(authControllerProvider).value, isA<SignedIn>());
    expect(
      await store.refreshToken(),
      'refresh-xyz',
      reason: 'a tunnel is not a dead session',
    );
  });
}
