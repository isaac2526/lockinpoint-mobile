import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/core/session_refresher.dart';
import 'package:lockinpoint/core/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ===========================================================================
/// THE AUTH CHAIN, PROVEN IN MINIATURE
///
/// These tests exist because a real student on a real phone saw "Your session
/// has ended" seconds after logging in. The server was proven innocent by
/// running the real backend locally; the phone had silently lost its stored
/// key. Everything that failure touched is pinned down here:
///
///   · the token that is saved is the token that is sent, on every request
///   · a phone whose secure storage lies (returns null after a save) falls
///     back rather than signing the student out
///   · a 401 names the RIGHT problem: a key that was never attached is a
///     storage failure, not an expired session
/// ===========================================================================

/// A secure store that behaves — or misbehaves — exactly as told.
class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = {};

  /// When true, writes "succeed" but store nothing: the MIUI failure.
  bool swallowWrites = false;

  /// When true, every call throws: the corrupt-Keystore failure.
  bool explode = false;

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
    if (explode) throw Exception('keystore corrupt');
    if (swallowWrites) return;
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
  }) async {
    if (explode) throw Exception('keystore corrupt');
    return data[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (explode) throw Exception('keystore corrupt');
    data.remove(key);
  }
}

/// A network that returns exactly the responses queued into it and records
/// every request, headers included.
class FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<ResponseBody> _queue = [];

  void enqueue(int status, Object body, {String? location}) => _queue.add(
    ResponseBody.fromString(
      body is String ? body : jsonEncode(body),
      status,
      headers: {
        // A real 404 from the host is an HTML page, not JSON; label each
        // fake honestly so Dio parses it the way it would in production.
        Headers.contentTypeHeader: [
          body is String ? 'text/plain' : 'application/json',
        ],
        if (location != null) 'location': [location],
      },
    ),
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _queue.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

/// An auth server that answers refresh attempts exactly as scripted, and
/// counts how many times it was actually asked.
class FakeAuthServer {
  FakeAuthServer(this.outcome);

  RefreshOutcome outcome;
  int asks = 0;
  final List<String> tokensSeen = [];

  Future<RefreshOutcome> exchange(String refresh) async {
    asks++;
    tokensSeen.add(refresh);
    /* A real auth round-trip is never instant. Resolving on a timer rather
       than a microtask lets every request already in flight reach its 401 —
       which is exactly the window the single-flight rule exists for. */
    await Future<void>.delayed(Duration.zero);
    return outcome;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SessionStore keeps the session through a healthy secure store', () {
    test('what is saved is what is read back', () async {
      final store = SessionStore(secure: FakeSecureStorage());
      await store.save(access: 'a1', refresh: 'r1');
      expect(await store.accessToken(), 'a1');
      expect(await store.refreshToken(), 'r1');
    });

    test('clear forgets everything everywhere', () async {
      final secure = FakeSecureStorage();
      final store = SessionStore(secure: secure);
      await store.save(access: 'a1', refresh: 'r1');
      await store.clear();
      expect(await store.accessToken(), isNull);
      expect(await store.refreshToken(), isNull);
      expect(secure.data, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lip.access_token'), isNull);
    });
  });

  group('SessionStore survives a phone whose secure store is broken', () {
    test(
      'a save the platform swallows still leaves the run logged in',
      () async {
        final secure = FakeSecureStorage()..swallowWrites = true;
        final store = SessionStore(secure: secure);
        await store.save(access: 'a1', refresh: 'r1');
        // The read-back caught the lie; this run still holds its tokens.
        expect(await store.accessToken(), 'a1');
        // And the fallback now holds them, so the NEXT launch does too.
        final again = SessionStore(secure: secure);
        expect(await again.accessToken(), 'a1');
        expect(await again.refreshToken(), 'r1');
      },
    );

    test('a save marks the store broken so later launches skip it', () async {
      final secure = FakeSecureStorage()..swallowWrites = true;
      await SessionStore(secure: secure).save(access: 'a1', refresh: 'r1');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('lip.secure_store_broken'), isTrue);
    });

    test('a secure store that throws does not lose the session', () async {
      final secure = FakeSecureStorage()..explode = true;
      final store = SessionStore(secure: secure);
      await store.save(access: 'a1', refresh: 'r1');
      expect(await store.accessToken(), 'a1');
      final again = SessionStore(secure: FakeSecureStorage()..explode = true);
      expect(await again.refreshToken(), 'r1');
    });
  });

  group('Api attaches the key and names each failure honestly', () {
    late SessionStore store;
    late Api api;
    late FakeAdapter net;
    late FakeAuthServer auth;

    setUp(() {
      store = SessionStore(secure: FakeSecureStorage());
      auth = FakeAuthServer(const RefreshRefused());
      api = Api(store, SessionRefresher(store, auth.exchange));
      net = FakeAdapter();
      api.dio.httpClientAdapter = net;
    });

    test('the saved token rides on every request', () async {
      await store.save(access: 'tok-123', refresh: 'r');
      net.enqueue(200, {'ok': true});
      await api.get('/api/me');
      expect(net.requests.single.headers['Authorization'], 'Bearer tok-123');
    });

    test('every request names the app, never Dart\'s default agent', () async {
      /* Unset, Dart sends `Dart/3.x (dart:io)` — the signature a bot filter
         blocks while every browser passes, which is the exact shape of the
         failure this app hit against production. */
      net.enqueue(200, {'ok': true});
      await api.get('/api/me');
      final ua = net.requests.single.headers['User-Agent'] as String?;
      expect(ua, isNotNull);
      expect(ua, contains('LockInPoint'));
      expect(ua, isNot(contains('Dart/')));
    });

    test('with no token, no Authorization header is sent at all', () async {
      net.enqueue(200, {'ok': true});
      await api.get('/api/public/exam-tree');
      expect(net.requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test(
      'a 401 with no key attached blames the phone, not the session',
      () async {
        net.enqueue(401, {'ok': false, 'message': 'Not signed in.'});
        await expectLater(
          api.get('/api/mobile/dashboard'),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.unauthorised, 'unauthorised', isTrue)
                .having(
                  (e) => e.message,
                  'message',
                  contains('lost its saved login key'),
                ),
          ),
        );
      },
    );

    test(
      'a 401 whose refresh token the auth server REFUSES ends the session',
      () async {
        await store.save(access: 'tok-123', refresh: 'r');
        auth.outcome = const RefreshRefused();
        net.enqueue(401, {'ok': false, 'message': 'Not signed in.'});
        await expectLater(
          api.get('/api/mobile/dashboard'),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.unauthorised, 'unauthorised', isTrue)
                .having(
                  (e) => e.message,
                  'message',
                  contains('session has ended'),
                ),
          ),
        );
        // The refresh token was actually presented before anyone gave up.
        expect(auth.tokensSeen, ['r']);
        // The dead session is gone; nothing will retry it in a loop.
        expect(await store.accessToken(), isNull);
      },
    );

    test(
      'a 401 on an expired key refreshes and retries instead of signing out',
      () async {
        await store.save(access: 'stale', refresh: 'r1');
        auth.outcome = const RefreshedSession(access: 'fresh', refresh: 'r2');
        net.enqueue(401, {'ok': false, 'message': 'Not signed in.'});
        net.enqueue(200, {'ok': true, 'student': 'data'});

        final data = await api.get('/api/mobile/dashboard');
        expect(data['student'], 'data');
        // The retry carried the fresh key, not the stale one.
        expect(net.requests, hasLength(2));
        expect(net.requests.last.headers['Authorization'], 'Bearer fresh');
        // And the rotated pair is what the store now holds.
        expect(await store.accessToken(), 'fresh');
        expect(await store.refreshToken(), 'r2');
      },
    );

    test(
      'a live session the API still refuses is kept, and named honestly',
      () async {
        /* The stale-backend trap: the auth server honours the refresh token,
           yet the API 401s the fresh key too — a deployed build that cannot
           read bearers. Signing the student out cannot fix a server, so the
           session stays and the failure is not called "session ended". */
        await store.save(access: 'stale', refresh: 'r1');
        auth.outcome = const RefreshedSession(access: 'fresh', refresh: 'r2');
        net.enqueue(401, {'ok': false});
        net.enqueue(401, {'ok': false});
        await expectLater(
          api.get('/api/mobile/dashboard'),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.unauthorised, 'unauthorised', isFalse)
                .having(
                  (e) => e.message,
                  'message',
                  contains('could not verify'),
                ),
          ),
        );
        expect(await store.accessToken(), 'fresh');
      },
    );

    test(
      'an unreachable auth server is an offline moment, never a sign-out',
      () async {
        await store.save(access: 'tok', refresh: 'r1');
        auth.outcome = const RefreshUnreachable();
        net.enqueue(401, {'ok': false});
        await expectLater(
          api.get('/api/mobile/dashboard'),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.offline, 'offline', isTrue)
                .having((e) => e.unauthorised, 'unauthorised', isFalse),
          ),
        );
        expect(await store.accessToken(), 'tok');
      },
    );

    test(
      'two requests hitting 401 together share ONE refresh exchange',
      () async {
        /* The auth server burns a refresh token on first use. If two 401s each
           presented it, the second would be refused and sign the student out
           — the race this law exists to prevent. */
        await store.save(access: 'stale', refresh: 'r1');
        auth.outcome = const RefreshedSession(access: 'fresh', refresh: 'r2');
        net.enqueue(401, {'ok': false});
        net.enqueue(401, {'ok': false});
        net.enqueue(200, {'ok': true});
        net.enqueue(200, {'ok': true});
        await Future.wait([api.get('/api/me'), api.get('/api/leaderboard')]);
        expect(auth.asks, 1);
      },
    );

    test('the server\'s own words come through on ok:false', () async {
      net.enqueue(200, {
        'ok': false,
        'message': 'Email or password is not correct.',
      });
      await expectLater(
        api.post('/api/auth/login', body: {}),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            'Email or password is not correct.',
          ),
        ),
      );
    });

    test('a 404 names the missing deployment, never a dead session', () async {
      net.enqueue(404, 'page not found');
      await expectLater(
        api.get('/api/mobile/dashboard'),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.unauthorised, 'unauthorised', isFalse)
              .having(
                (e) => e.message,
                'message',
                contains('needs its update deployed'),
              ),
        ),
      );
    });

    test('a 500 is the server\'s fault, said plainly', () async {
      net.enqueue(500, 'internal error');
      await expectLater(
        api.get('/api/mobile/dashboard'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            contains('having a moment'),
          ),
        ),
      );
    });

    test('every failure names its exact request in the small print', () async {
      await store.save(access: 'tok', refresh: 'r');
      auth.outcome = const RefreshRefused('refresh token not found');
      net.enqueue(401, {'ok': false, 'message': 'Not signed in.'});
      await expectLater(
        api.get('/api/mobile/dashboard'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.detail,
            'detail',
            allOf(
              contains('GET /api/mobile/dashboard'),
              contains('401'),
              contains('refresh token not found'),
            ),
          ),
        ),
      );
    });
  });

  group('a gate in front of the server is named, not mistaken for a login', () {
    /* The body production actually sent: keys exactly `redirect` and
       `status`, no ok, no tokens. The HTTP status here is 200 deliberately —
       it could NOT have been a 401, because at a login screen no token is
       stored and a 401 without a token takes an earlier branch that never
       prints a key list, yet a key list is what the student's screen showed.
       Whoever writes this body is unproven; the app names it from its own
       redirect target rather than assuming. */
    const gateBody = {
      'redirect':
          'https://vercel.com/sso-api?url=https%3A%2F%2Flockinpoint.com',
      'status': '401',
    };

    late SessionStore store;
    late Api api;
    late FakeAdapter net;
    late FakeAuthServer auth;

    setUp(() {
      store = SessionStore(secure: FakeSecureStorage());
      auth = FakeAuthServer(const RefreshRefused());
      api = Api(store, SessionRefresher(store, auth.exchange));
      net = FakeAdapter();
      api.dio.httpClientAdapter = net;
    });

    test('a gate at ANY status is caught, and carries its address', () async {
      // 200 is the status the real observation implies — the catch must not
      // depend on a 401 it never had.
      net.enqueue(200, gateBody);
      await expectLater(
        api.post('/api/auth/login', body: {}),
        throwsA(
          isA<ApiFailure>()
              .having(
                (e) => e.message,
                'message',
                contains('in front of the website'),
              )
              .having(
                (e) => e.detail,
                'detail',
                allOf(
                  contains('POST /api/auth/login'),
                  contains('vercel.com'),
                  // The raw target: the one string that names the real culprit.
                  contains('sso-api'),
                ),
              ),
        ),
      );
    });

    test('a gate NEVER ends a session or burns the refresh token', () async {
      await store.save(access: 'tok', refresh: 'r1');
      net.enqueue(401, gateBody);
      await expectLater(api.get('/api/me'), throwsA(isA<ApiFailure>()));
      // The session stands, and the gate was never mistaken for a refusal.
      expect(await store.accessToken(), 'tok');
      expect(await store.refreshToken(), 'r1');
      expect(auth.asks, 0);
    });

    test('the gatekeeper is named by its own redirect target', () {
      expect(Api.platformGate(gateBody)?.host, 'vercel.com');
      expect(Api.platformGate(gateBody)?.target, contains('sso-api'));
      // A gate that points somewhere unparseable is still caught and reported.
      final odd = Api.platformGate({'redirect': '/relative', 'status': 401});
      expect(odd?.host, 'an unnamed gate');
      expect(odd?.target, '/relative');
    });

    test('an ordinary LockInPoint answer is never called a gate', () {
      expect(
        Api.platformGate({'ok': true, 'redirect': '/x', 'status': 1}),
        isNull,
      );
      expect(Api.platformGate({'ok': false, 'message': 'no'}), isNull);
      expect(Api.platformGate('a plain string'), isNull);
      expect(Api.platformGate({'redirect': '/somewhere'}), isNull);
      // /api/search answers {rows,total} with NO ok — never a gate.
      expect(Api.platformGate({'rows': [], 'total': 0}), isNull);
    });

    test('a redirect is named and never silently followed', () async {
      net.enqueue(308, '', location: 'https://www.lockinpoint.com/api/me');
      await expectLater(
        api.get('/api/me'),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.message, 'message', contains('somewhere else'))
              .having(
                (e) => e.detail,
                'detail',
                allOf(contains('308'), contains('www.lockinpoint.com')),
              ),
        ),
      );
      // One request only: the body-dropping hop was never taken.
      expect(net.requests, hasLength(1));
    });
  });

  group('the backend refresh exchange reads the route honestly', () {
    late Dio dio;
    late FakeAdapter net;
    late RefreshExchange exchange;

    setUp(() {
      dio = Dio(Api.baseOptions());
      net = FakeAdapter();
      dio.httpClientAdapter = net;
      exchange = backendRefreshExchange(dio);
    });

    test('a 200 with the pair is a refreshed session', () async {
      net.enqueue(200, {
        'ok': true,
        'access_token': 'a2',
        'refresh_token': 'r2',
      });
      final out = await exchange('r1');
      expect(out, isA<RefreshedSession>());
      expect((out as RefreshedSession).access, 'a2');
      expect(out.refresh, 'r2');
      // The refresh token travelled in the body, never in a header or URL.
      expect(net.requests.single.path, '/api/auth/refresh');
      expect((net.requests.single.data as Map)['refresh_token'], 'r1');
    });

    test('a 401 is the one true refusal, with the server\'s words', () async {
      net.enqueue(401, {'ok': false, 'message': 'This session has ended.'});
      final out = await exchange('r1');
      expect(out, isA<RefreshRefused>());
      expect((out as RefreshRefused).why, 'This session has ended.');
    });

    test(
      'a 404 means the server needs deploying, NOT a dead session',
      () async {
        net.enqueue(404, 'not found');
        final out = await exchange('r1');
        expect(out, isA<RefreshUnreachable>());
        expect((out as RefreshUnreachable).why, contains('deployed'));
      },
    );

    test('a 500 proves nothing about the session', () async {
      net.enqueue(500, 'oops');
      expect(await exchange('r1'), isA<RefreshUnreachable>());
    });

    test(
      'a gated answer is unreachable, NOT a refusal that signs out',
      () async {
        net.enqueue(200, {
          'redirect': 'https://vercel.com/sso-api?url=x',
          'status': '401',
        });
        final out = await exchange('r1');
        expect(out, isA<RefreshUnreachable>());
        expect((out as RefreshUnreachable).why, contains('vercel.com'));
      },
    );
  });
}
