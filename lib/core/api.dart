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
