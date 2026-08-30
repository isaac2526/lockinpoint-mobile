import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
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

  void enqueue(int status, Object body) => _queue.add(
    ResponseBody.fromString(
      body is String ? body : jsonEncode(body),
      status,
      headers: {
        // A real 404 from the host is an HTML page, not JSON; label each
        // fake honestly so Dio parses it the way it would in production.
        Headers.contentTypeHeader: [
          body is String ? 'text/plain' : 'application/json',
        ],
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

    setUp(() {
      store = SessionStore(secure: FakeSecureStorage());
      api = Api(store);
      net = FakeAdapter();
      api.dio.httpClientAdapter = net;
    });

    test('the saved token rides on every request', () async {
      await store.save(access: 'tok-123', refresh: 'r');
      net.enqueue(200, {'ok': true});
      await api.get('/api/me');
      expect(net.requests.single.headers['Authorization'], 'Bearer tok-123');
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

    test('a 401 with a key attached is a genuinely ended session', () async {
      await store.save(access: 'tok-123', refresh: 'r');
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
      // The dead session is gone; nothing will retry it in a loop.
      expect(await store.accessToken(), isNull);
    });

    test(
      'retainSessionOn401 keeps the tokens a fresh login stands on',
      () async {
        await store.save(access: 'tok-123', refresh: 'r');
        net.enqueue(401, {'ok': false});
        await expectLater(
          api.get('/api/me', retainSessionOn401: true),
          throwsA(isA<ApiFailure>()),
        );
        expect(await store.accessToken(), 'tok-123');
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

    test(
      'a 404 is called a deployment in progress, not a dead session',
      () async {
        net.enqueue(404, 'page not found');
        await expectLater(
          api.get('/api/mobile/dashboard'),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.unauthorised, 'unauthorised', isFalse)
                .having(
                  (e) => e.message,
                  'message',
                  contains('still updating'),
                ),
          ),
        );
      },
    );

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
  });
}
