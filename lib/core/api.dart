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
    headers: {
      'Accept': 'application/json',
      /* IDENTIFY OURSELVES. Left unset, Dart sends `Dart/3.x (dart:io)` —
         a string bot-filters and firewall rules routinely block, while every
         browser sails past. That is the shape of the failure being chased
         here: the website works in a browser and the app is refused by
         something standing in front of it. This does NOT prove that is the
         cause, and a rule that allows only known browsers would refuse this
         too — but shipping a real app's name is right regardless, and it
         removes the one signature most likely to be filtered. */
      'User-Agent': AppConfig.userAgent,
    },
    // We read the status ourselves so a 401 is a typed failure, not a throw.
    validateStatus: (_) => true,
    /* Dio must NOT follow redirects itself. Dart's HttpClient follows a 3xx on
       POST and DROPS the request body doing it, so an apex-to-www hop would
       deliver a body-less login and the failure would look like anything
       except what it is. _followSameSite below re-issues the whole request
       instead — method, body and headers intact. */
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
    (token, url) => _dio.get(
      url,
      queryParameters: query,
      options: Options(headers: _authHeader(token)),
    ),
  );

  Future<Map<String, dynamic>> post(String path, {Object? body}) => _request(
    'POST',
    path,
    (token, url) => _dio.post(
      url,
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
    Future<Response<dynamic>> Function(String? token, String url) run,
  ) async {
    final where = '$method $path';
    final token = await _readToken();
    var url = path;
    var res = await _guard(where, () => run(token, url));
    (url, res) = await _followSameSite(where, url, res, (u) => run(token, u));
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
          res = await _guard(where, () => run(access, url));
          (url, res) = await _followSameSite(
            where,
            url,
            res,
            (u) => run(access, u),
          );
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

  /* ==========================================================================
     THE HOP BETWEEN lockinpoint.com AND www.lockinpoint.com

     A host on Vercel is usually configured with one of the two names primary
     and the other redirecting to it. A BROWSER follows that hop invisibly, so
     the website looks perfectly healthy. A native app does not — and Dart
     makes it worse, because its own redirect following DROPS the POST body,
     turning a login into an empty request.

     The Belloxdydx app, which worked first time, posts to
     www.belloxdydx.org — the primary name, so it never meets a hop at all.
     This app was pointed at the bare apex.

     So the request is re-issued here in full: same method, same body, same
     headers. Only to the SAME SITE, and only over https — the bearer token
     must never be handed to another domain because a Location header said so,
     which is exactly the hole a naive redirect follower opens.
     ========================================================================== */

  static const _maxHops = 3;

  Future<(String, Response<dynamic>)> _followSameSite(
    String where,
    String url,
    Response<dynamic> res,
    Future<Response<dynamic>> Function(String url) again,
  ) async {
    var hops = 0;
    while (_isRedirect(res.statusCode) && hops < _maxHops) {
      final next = _sameSiteTarget(url, res);
      if (next == null) break; // a hop we refuse to take; _read will name it.
      url = next;
      hops++;
      res = await _guard(where, () => again(url));
    }
    return (url, res);
  }

  static bool _isRedirect(int? code) =>
      code != null && code >= 300 && code < 400;

  /// Where a redirect points, but only when it is the same site over https.
  static String? _sameSiteTarget(String from, Response<dynamic> res) {
    final location = res.headers.value('location');
    if (location == null || location.trim().isEmpty) return null;
    final here = Uri.parse(AppConfig.apiBase).resolve(from);
    final target = here.resolve(location.trim());
    if (target.scheme != 'https') return null; // never downgrade
    if (!_sameSite(here.host, target.host)) return null;
    return target.toString();
  }

  /// `lockinpoint.com` and `www.lockinpoint.com` are the same site. Anything
  /// else is not, however similar it looks.
  static bool _sameSite(String a, String b) {
    String bare(String h) {
      final l = h.toLowerCase();
      return l.startsWith('www.') ? l.substring(4) : l;
    }

    return bare(a) == bare(b);
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
