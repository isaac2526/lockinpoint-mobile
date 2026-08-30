import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'session_refresher.dart';
import 'session_store.dart';

/// A failure the student can be shown. Never a stack trace, never a status
/// code in the headline — a sentence saying what happened and, where
/// possible, what to do. The exact request lives in [detail], for the small
/// print, so a screenshot is a diagnosis and never a mystery.
class ApiFailure implements Exception {
  ApiFailure(
    this.message, {
    this.detail,
    this.offline = false,
    this.unauthorised = false,
  });

  final String message;

  /// `GET /api/mobile/dashboard → 401 · Not signed in.` — which request,
  /// which status, the server's own words. No tokens, ever.
  final String? detail;

  final bool offline;
  final bool unauthorised;

  @override
  String toString() => message;
}

/// ===========================================================================
/// THE ONE DOOR TO THE BACKEND
///
/// Every request the app makes goes through here, so the bearer token, the
/// timeouts, the refresh-and-retry and the turning of a failure into a
/// sentence all live in one place instead of at forty call sites.
///
/// The token is the SAME session the website issues; its login route hands
/// the pair over in its JSON body and getSession() on the server reads either
/// a cookie or this Authorization header. Which auth project stands behind
/// those tokens is the SERVER'S business alone — the app carries no auth
/// address of its own, so it can never refresh at one project while being
/// verified against another.
///
/// THE 401 LAW. A student is signed out for exactly one reason: the backend's
/// own refresh route refused their refresh token. An access token quietly
/// expiring an hour after login, a deploy mid-rollout, an auth hiccup — none
/// of those may cost a session. So a 401 here is never final on its own: the
/// refresh token goes to POST /api/auth/refresh, and if it is honoured the
/// request is retried once with the fresh key. Only a refusal clears the
/// store.
/// ===========================================================================
class Api {
  Api(this._store, this._refresher) {
    _dio = Dio(baseOptions());
  }

  /// One options recipe for every Dio this app creates, the refresh
  /// exchange's included, so a timeout tuned here is tuned everywhere.
  static BaseOptions baseOptions() => BaseOptions(
    baseUrl: AppConfig.apiBase,
    // Generous, because this is Nigeria on mobile data, not a datacentre.
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
    // We read the status ourselves so a 401 is a typed failure, not a throw.
    validateStatus: (_) => true,
    /* A 3xx is NEVER followed. Dart's HttpClient follows redirects on POST by
       default and drops the request body on the way, so a domain-level hop
       (an apex sending the app to www, say) would deliver a body-less login
       to another origin and the failure would look like anything except what
       it is. Seeing the hop beats silently taking it. */
    followRedirects: false,
  );

  final SessionStore _store;
  final SessionRefresher _refresher;
  late final Dio _dio;

  /// Tests swap the transport under this Dio for a fake adapter; nothing else
  /// should ever touch it.
  @visibleForTesting
  Dio get dio => _dio;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _request(
    'GET',
    path,
    (token) => _dio.get(
      path,
      queryParameters: query,
      options: Options(headers: _authHeader(token)),
    ),
  );

  Future<Map<String, dynamic>> post(String path, {Object? body}) => _request(
    'POST',
    path,
    (token) => _dio.post(
      path,
      data: body,
      options: Options(headers: _authHeader(token)),
    ),
  );

  /// The token read itself must never sink a request: a phone whose secure
  /// storage throws should send the request signed out, not crash the screen.
  Future<String?> _readToken() async {
    try {
      return await _store.accessToken();
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _authHeader(String? token) =>
      token == null ? {} : {'Authorization': 'Bearer $token'};

  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    Future<Response<dynamic>> Function(String? token) run,
  ) async {
    final where = '$method $path';
    final token = await _readToken();
    var res = await _guard(where, () => run(token));
    _refuseGate(where, res);

    if (res.statusCode == 401) {
      if (token == null) {
        /* The server never saw a session at all: this phone lost its saved
           key (secure storage failure). Naming that is what makes a student's
           screenshot a diagnosis rather than a mystery. */
        throw ApiFailure(
          'This phone lost its saved login key. Please log in again.',
          detail: '$where → 401, sent with no key attached',
          unauthorised: true,
        );
      }

      /* A token WAS sent and refused. The backend's refresh route is the
         referee: present the refresh token and let IT say whether this
         session lives. */
      switch (await _refresher.refresh()) {
        case RefreshedSession(:final access):
          res = await _guard(where, () => run(access));
          _refuseGate(where, res);
          if (res.statusCode == 401) {
            /* The refresh route honoured this session seconds ago, yet the
               same server still refuses the fresh key. Signing the student
               out cannot fix a server, so the session stays — and the small
               print carries the whole story. */
            throw ApiFailure(
              'The server could not verify this login right now. '
              'Please try again shortly.',
              detail:
                  '$where → 401 twice, yet POST /api/auth/refresh '
                  'accepted this session · ${_serverWords(res)}',
            );
          }
        case RefreshRefused(:final why):
          // The one genuine sign-out: the session is dead at the source.
          await _store.clear();
          throw ApiFailure(
            'Your session has ended. Please log in again.',
            detail: '$where → 401 · POST /api/auth/refresh said: $why',
            unauthorised: true,
          );
        case RefreshUnreachable(:final why):
          throw ApiFailure(
            'Could not confirm your login. Check your connection and try again.',
            detail: '$where → 401 · refresh attempt: $why',
            offline: true,
          );
      }
    }

    return _read(where, res);
  }

  /// Runs one attempt, turning transport failures into sentences.
  Future<Response<dynamic>> _guard(
    String where,
    Future<Response<dynamic>> Function() run,
  ) async {
    try {
      return await run();
    } on DioException catch (e) {
      final isTimeout =
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;
      if (isTimeout) {
        throw ApiFailure(
          'That took too long. Check your connection and try again.',
          detail: '$where → no answer within the time limit',
          offline: true,
        );
      }
      throw ApiFailure(
        'No connection. Check your data and try again.',
        detail: '$where → ${e.type.name}',
        offline: true,
      );
    }
  }

  /* ==========================================================================
     SOMETHING IN FRONT OF THE SERVER

     WHAT WAS OBSERVED, exactly: a login POST to production came back as JSON
     whose keys were precisely `redirect` and `status` — no `ok`, no tokens.
     Two things follow with certainty. No version of the LockInPoint backend
     has ever emitted that body, so it was written by something standing in
     FRONT of the app's code. And the reply was not a 401: at a login screen
     no token is stored, and a 401 without a token takes an earlier branch
     that never reaches the message the key list was printed by.

     WHAT IS SUSPECTED, honestly: a hosting gate — Vercel's Deployment
     Protection is the obvious candidate, since a browser carrying its cookie
     passes while an app carrying nothing cannot. But Vercel's own documented
     JSON refusal is shaped {error, protection}, not this, so the attribution
     is a strong hypothesis and NOT a proven fact. The code must therefore
     describe the shape it sees and name whoever actually answered, rather
     than assert a culprit — an earlier version of this comment asserted one,
     and a guess written down as fact is how three builds were spent hunting
     a session bug that was never in the app.

     So: the gatekeeper's own redirect target is carried into the failure,
     because that single string names the real culprit whatever it turns out
     to be, and one screenshot then closes the question for good.
     ========================================================================== */

  /// The gatekeeper, if this body was written by something other than
  /// LockInPoint: its host and the raw address it points at. Null otherwise.
  @visibleForTesting
  static ({String host, String target})? platformGate(dynamic data) {
    if (data is! Map) return null;
    /* Every LockInPoint route that could be mistaken for this answers with
       `ok`. (/api/search answers {rows,total} with no `ok` — hence the two
       keys below are required, never `ok`'s absence alone.) */
    if (data.containsKey('ok')) return null;
    if (!data.containsKey('redirect') || !data.containsKey('status')) {
      return null;
    }
    final target = data['redirect'];
    if (target is String && target.isNotEmpty) {
      final host = Uri.tryParse(target)?.host;
      if (host != null && host.isNotEmpty) {
        return (host: host, target: target);
      }
      return (host: 'an unnamed gate', target: target);
    }
    return (host: 'an unnamed gate', target: '$target');
  }

  static void _refuseGate(String where, Response<dynamic> res) {
    final gate = platformGate(res.data);
    if (gate == null) return;
    throw ApiFailure(
      'LockInPoint is not letting the app in. Something in front of the '
      'website is answering the app instead of LockInPoint, and only a '
      'signed-in browser can pass it.',
      detail:
          '$where → ${res.statusCode ?? 0} · answered by ${gate.host}, '
          'which points at ${gate.target}',
    );
  }

  /// The server's own words out of a response body, for the small print.
  static String _serverWords(Response<dynamic> res) {
    final data = res.data;
    if (data is Map && data['message'] is String) {
      return 'server said: ${data['message']}';
    }
    return 'no message in the body';
  }

  Map<String, dynamic> _read(String where, Response<dynamic> res) {
    final code = res.statusCode ?? 0;
    final data = res.data;

    // Nothing follows a redirect for us, so name it — including where it led.
    if (code >= 300 && code < 400) {
      throw ApiFailure(
        'LockInPoint sent the app somewhere else instead of answering.',
        detail:
            '$where → $code · redirected to '
            '${res.headers.value('location') ?? 'an address it did not name'}',
      );
    }
    if (data is Map<String, dynamic>) {
      // The website answers every route as { ok, message?, ...payload }.
      if (data['ok'] == false) {
        throw ApiFailure(
          (data['message'] as String?)?.trim().isNotEmpty == true
              ? data['message'] as String
              : 'That did not work. Please try again.',
          detail: '$where → $code',
        );
      }
      return data;
    }

    if (code == 404) {
      /* Every path the app calls exists in the current backend, so a 404 can
         only mean the server is running an older build — a deployment behind
         this app, not just one mid-rollout. */
      throw ApiFailure(
        'The server does not have this feature yet. '
        'The website needs its update deployed.',
        detail: '$where → 404, the route is missing on the server',
      );
    }
    if (code >= 500) {
      throw ApiFailure(
        'LockInPoint is having a moment. Try again shortly.',
        detail: '$where → $code',
      );
    }
    throw ApiFailure(
      'Something unexpected came back. Please try again.',
      detail: '$where → $code, body was not JSON',
    );
  }
}

final sessionStoreProvider = Provider((ref) => SessionStore());

/// The real exchange: POST /api/auth/refresh on the SAME backend the app
/// reads data from. The server refreshes against whichever auth project IT is
/// configured with, so issuing, refreshing and verifying can never belong to
/// different projects — the exact drift that once had this app refreshing
/// tokens one server while another rejected them.
RefreshExchange backendRefreshExchange(Dio dio) => (refreshToken) async {
  Response<dynamic> res;
  try {
    res = await dio.post(
      '/api/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
  } on DioException catch (e) {
    return RefreshUnreachable(
      'the refresh route did not answer '
      '(${e.type.name})',
    );
  }

  final code = res.statusCode ?? 0;
  final data = res.data;

  /* A platform gate answers 401 to everything, this route included. Reading
     that as a refusal would clear a perfectly good session and tell the
     student it had ended — the exact lie this whole chain exists to stop. */
  final gate = Api.platformGate(data);
  if (gate != null) {
    return RefreshUnreachable(
      'POST /api/auth/refresh → $code, answered by ${gate.host} '
      'before it reached LockInPoint',
    );
  }

  if (code == 200 && data is Map<String, dynamic>) {
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access != null && refresh != null) {
      return RefreshedSession(access: access, refresh: refresh);
    }
  }
  if (code == 401) {
    final why = (data is Map && data['message'] is String)
        ? data['message'] as String
        : 'the session has ended';
    return RefreshRefused(why);
  }
  if (code == 404) {
    /* The deployed backend does not have the refresh route yet. That proves
       nothing about the session — and naming it is what turns the next
       screenshot into the deployment conversation it needs to be. */
    return RefreshUnreachable(
      'POST /api/auth/refresh → 404, the server needs its update deployed',
    );
  }
  return RefreshUnreachable('POST /api/auth/refresh → $code');
};

final sessionRefresherProvider = Provider(
  (ref) => SessionRefresher(
    ref.watch(sessionStoreProvider),
    backendRefreshExchange(Dio(Api.baseOptions())),
  ),
);

final apiProvider = Provider(
  (ref) =>
      Api(ref.watch(sessionStoreProvider), ref.watch(sessionRefresherProvider)),
);
