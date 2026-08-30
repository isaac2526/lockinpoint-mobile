import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
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
/// timeouts, the retry and the turning of a failure into a sentence all live
/// in one place instead of at forty call sites.
///
/// The token is the SAME Supabase session the website issues. The website's
/// getSession() now reads either a cookie or this Authorization header, so the
/// app and the browser are the same student to the same backend.
/// ===========================================================================
class Api {
  Api(this._store) {
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
  late final Dio _dio;

  /// Tests swap the transport under this Dio for a fake adapter; nothing else
  /// should ever touch it.
  @visibleForTesting
  Dio get dio => _dio;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool retainSessionOn401 = false,
  }) async {
    final token = await _readToken();
    return _send(
      () => _dio.get(
        path,
        queryParameters: query,
        options: Options(headers: _authHeader(token)),
      ),
      hadToken: token != null,
      retainSessionOn401: retainSessionOn401,
    );
  }

  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    final token = await _readToken();
    return _send(
      () => _dio.post(
        path,
        data: body,
        options: Options(headers: _authHeader(token)),
      ),
      hadToken: token != null,
    );
  }

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

  Future<Map<String, dynamic>> _send(
    Future<Response> Function() run, {
    required bool hadToken,
    bool retainSessionOn401 = false,
  }) async {
    Response res;
    try {
      res = await run();
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

    final code = res.statusCode ?? 0;

    /* A 401 means this session is finished — expired, or claimed by another
       device under the one-account-per-device rule. Clearing here is what makes
       the app fall back to the welcome screen rather than sitting on a screen
       that will never load. */
    if (code == 401) {
      /* During a fresh login the caller probes /api/me while HOLDING tokens it
         just received. A 401 there can mean the deployed server build does not
         yet accept bearer tokens, not that the session is bad, so that caller
         asks us not to burn the tokens it is standing on. */
      if (!retainSessionOn401) await _store.clear();
      /* Two very different failures land on 401, and naming the right one is
         what makes a student's screenshot a diagnosis:
           · no token was on the request — this phone lost the saved key
             (secure storage failure), the server never saw a session at all;
           · a token WAS sent and refused — the session genuinely ended or the
             account was signed in on another device. */
      throw ApiFailure(
        hadToken
            ? 'Your session has ended. Please log in again.'
            : 'This phone lost its saved login key. Please log in again.',
        unauthorised: true,
      );
    }

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
final apiProvider = Provider((ref) => Api(ref.watch(sessionStoreProvider)));

/// Supabase is initialised for auth only. Every read of real data goes through
/// the website's API, because RLS deliberately grants no anonymous access to
/// questions, attempts, notes or documents.
final supabaseProvider = Provider((ref) => Supabase.instance.client);
