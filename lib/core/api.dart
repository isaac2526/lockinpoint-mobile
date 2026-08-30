import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'session_refresher.dart';
import 'session_store.dart';

/// A failure the student can be shown. Never a stack trace, never a status
/// code — a sentence saying what happened and, where possible, what to do.
class ApiFailure implements Exception {
  ApiFailure(this.message, {this.offline = false, this.unauthorised = false});

  final String message;
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
/// The token is the SAME Supabase session the website issues. The website's
/// getSession() reads either a cookie or this Authorization header, so the
/// app and the browser are the same student to the same backend.
///
/// THE 401 LAW. A student is signed out for exactly one reason: the auth
/// server itself refused their refresh token. An access token quietly expiring
/// an hour after login, a backend deploy that is mid-rollout, an auth hiccup —
/// none of those may cost a session. So a 401 here is never final on its own:
/// the refresh token is presented to the auth server, and if it is honoured
/// the request is retried once with the fresh key. Only a refusal from the
/// auth server clears the store. That law is what stands between a student
/// and the "Your session has ended" screen that used to appear seconds after
/// a perfectly good login.
/// ===========================================================================
class Api {
  Api(this._store, this._refresher) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBase,
        // Generous, because this is Nigeria on mobile data, not a datacentre.
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
        // We read the status ourselves so a 401 is a typed failure, not a throw.
        validateStatus: (_) => true,
      ),
    );
  }

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
    (token) => _dio.get(
      path,
      queryParameters: query,
      options: Options(headers: _authHeader(token)),
    ),
  );

  Future<Map<String, dynamic>> post(String path, {Object? body}) => _request(
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
    Future<Response<dynamic>> Function(String? token) run,
  ) async {
    final token = await _readToken();
    var res = await _guard(() => run(token));

    if (res.statusCode == 401) {
      if (token == null) {
        /* The server never saw a session at all: this phone lost its saved
           key (secure storage failure). Naming that is what makes a student's
           screenshot a diagnosis rather than a mystery. */
        throw ApiFailure(
          'This phone lost its saved login key. Please log in again.',
          unauthorised: true,
        );
      }

      /* A token WAS sent and refused. The auth server is the referee: present
         the refresh token and let IT say whether this session lives. */
      switch (await _refresher.refresh()) {
        case RefreshedSession(:final access):
          res = await _guard(() => run(access));
          if (res.statusCode == 401) {
            /* The auth server honoured this session seconds ago, yet the API
               still refuses the fresh key. That is a server-side problem —
               most likely a backend build that cannot read bearer tokens —
               and signing the student out would not fix it. Keep the session;
               say what is actually wrong. */
            throw ApiFailure(
              'The server could not verify this login right now. '
              'Please try again shortly.',
            );
          }
        case RefreshRefused():
          // The one genuine sign-out: the session is dead at the source.
          await _store.clear();
          throw ApiFailure(
            'Your session has ended. Please log in again.',
            unauthorised: true,
          );
        case RefreshUnreachable():
          throw ApiFailure(
            'Could not confirm your login. Check your connection and try again.',
            offline: true,
          );
      }
    }

    return _read(res);
  }

  /// Runs one attempt, turning transport failures into sentences.
  Future<Response<dynamic>> _guard(
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
          offline: true,
        );
      }
      throw ApiFailure(
        'No connection. Check your data and try again.',
        offline: true,
      );
    }
  }

  Map<String, dynamic> _read(Response<dynamic> res) {
    final code = res.statusCode ?? 0;
    final data = res.data;
    if (data is Map<String, dynamic>) {
      // The website answers every route as { ok, message?, ...payload }.
      if (data['ok'] == false) {
        throw ApiFailure(
          (data['message'] as String?)?.trim().isNotEmpty == true
              ? data['message'] as String
              : 'That did not work. Please try again.',
        );
      }
      return data;
    }

    if (code == 404) {
      /* Every path the app calls exists in the current backend, so a 404 can
         only mean the server is still running an older build, typically for
         the few minutes a deployment takes. */
      throw ApiFailure(
        'The server is still updating. Give it two minutes and pull down to refresh.',
      );
    }
    if (code >= 500) {
      throw ApiFailure('LockInPoint is having a moment. Try again shortly.');
    }
    throw ApiFailure('Something unexpected came back. Please try again.');
  }
}

final sessionStoreProvider = Provider((ref) => SessionStore());

/// The real exchange: supabase's setSession presents the refresh token to the
/// auth server and, on success, leaves the client holding a live session —
/// which also switches its background auto-refresh on for the rest of the run.
final sessionRefresherProvider = Provider(
  (ref) => SessionRefresher(ref.watch(sessionStoreProvider), (refresh) async {
    try {
      final res = await Supabase.instance.client.auth.setSession(refresh);
      final s = res.session;
      if (s == null || s.refreshToken == null) return const RefreshRefused();
      return RefreshedSession(access: s.accessToken, refresh: s.refreshToken!);
    } on AuthRetryableFetchException {
      // The auth server never answered; nothing was proven either way.
      return const RefreshUnreachable();
    } on AuthException {
      // The auth server answered, and the answer was no.
      return const RefreshRefused();
    } catch (_) {
      return const RefreshUnreachable();
    }
  }),
);

final apiProvider = Provider(
  (ref) =>
      Api(ref.watch(sessionStoreProvider), ref.watch(sessionRefresherProvider)),
);

/// Supabase is initialised for auth only. Every read of real data goes through
/// the website's API, because RLS deliberately grants no anonymous access to
/// questions, attempts, notes or documents.
final supabaseProvider = Provider((ref) => Supabase.instance.client);
