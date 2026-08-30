import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/api.dart';
import '../../core/session_store.dart';

/// Where the student stands with the app.
sealed class AuthState {
  const AuthState();
}

/// Still reading the keystore. Shows the splash, never a login form we might
/// have to snatch away a frame later.
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class SignedOut extends AuthState {
  const SignedOut({this.message});

  /// Set when a session ended on its own, so the welcome screen can say why
  /// rather than looking like a bug.
  final String? message;
}

class SignedIn extends AuthState {
  const SignedIn(this.name);
  final String name;
}

/// ===========================================================================
/// IDENTITY
///
/// Login and signup go through the WEBSITE's routes first, because those
/// routes do more than check a password: they heal a missing profile row,
/// record the device, hold the one account per device slot and write the
/// activity log.
///
/// But the app must never be stranded by what one response happened to carry.
/// So the session is established through a chain, and any link is enough:
///
///   1. tokens in the route's JSON body (login and signup both send them)
///   2. a direct sign in against the auth server with the email in hand
///
/// And the name on the dashboard resolves the same way: the API if it answers,
/// the student's own profile row straight from the database if not. The
/// profile read works because Row Level Security explicitly allows a student
/// to read their own row.
/// ===========================================================================
class AuthController extends AsyncNotifier<AuthState> {
  Api get _api => ref.read(apiProvider);
  SessionStore get _store => ref.read(sessionStoreProvider);
  sb.SupabaseClient get _supabase => ref.read(supabaseProvider);

  @override
  Future<AuthState> build() async {
    final refresh = await _store.refreshToken();
    if (refresh == null) return const SignedOut();

    // A stored token is not a session. Ask the server before showing home.
    try {
      final me = await _api.get('/api/me', retainSessionOn401: true);
      return SignedIn((me['name'] as String?) ?? 'Champion');
    } on ApiFailure catch (e) {
      if (e.unauthorised) {
        /* The API said no. That is either a genuinely dead session, or a
           server build that does not yet read bearer tokens. The auth server
           itself is the referee: if it still honours the refresh token, the
           session is real and the student stays in. */
        final revived = await _reviveFromRefreshToken(refresh);
        if (revived != null) return SignedIn(await _resolveName());
        await _store.clear();
        return const SignedOut(
          message: 'Your session has ended. Please log in again.',
        );
      }
      // Offline with a token we cannot verify: let them in. A bus going
      // through a tunnel is not a reason to lock a student out.
      if (e.offline) return const SignedIn('Champion');
      return const SignedOut();
    }
  }

  Future<void> logIn({
    required String identifier,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final res = await _api.post(
        '/api/auth/login',
        body: {'identifier': identifier.trim(), 'password': password},
      );
      await _establishSession(
        res,
        email:
            (res['email'] as String?) ??
            (identifier.contains('@') ? identifier.trim() : null),
        password: password,
      );
      state = AsyncData(
        SignedIn(await _resolveName(hint: res['name'] as String?)),
      );
    } on ApiFailure catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signUp(Map<String, dynamic> form) async {
    state = const AsyncLoading();
    try {
      final res = await _api.post('/api/auth/signup', body: form);
      await _establishSession(
        res,
        email: (res['email'] as String?) ?? form['email'] as String?,
        password: form['password'] as String?,
      );
      state = AsyncData(
        SignedIn(await _resolveName(hint: form['first_name'] as String?)),
      );
    } on ApiFailure catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> logOut() async {
    try {
      await _api.post('/api/auth/logout');
    } on ApiFailure {
      // The server may be unreachable; the phone still forgets the session.
    }
    try {
      await _supabase.auth.signOut(scope: sb.SignOutScope.local);
    } catch (_) {}
    await _store.clear();
    state = const AsyncData(SignedOut());
  }

  // -------------------------------------------------------------------------

  /// Turns a successful login or signup response into a stored session,
  /// through whichever link of the chain works.
  Future<void> _establishSession(
    Map<String, dynamic> res, {
    String? email,
    String? password,
  }) async {
    var access = res['access_token'] as String?;
    var refresh = res['refresh_token'] as String?;

    // The route answered without tokens. Exchange the credentials directly
    // with the auth server instead; it is the same session either way.
    if ((access == null || refresh == null) &&
        email != null &&
        password != null) {
      try {
        final direct = await _supabase.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        access = direct.session?.accessToken;
        refresh = direct.session?.refreshToken;
      } on sb.AuthException catch (e) {
        throw ApiFailure(e.message);
      }
    }

    if (access == null || refresh == null) {
      // Name the missing pieces, so a screenshot of this message is a
      // diagnosis rather than a mystery.
      throw ApiFailure(
        'Signed in, but no session was issued '
        '(response carried: ${res.keys.join(', ')}). '
        'Please try again, and report this if it repeats.',
      );
    }

    await _store.save(access: access, refresh: refresh);

    // Give the Supabase client the same session so profile reads work even
    // when the tokens came from the API rather than a direct sign in.
    try {
      if (_supabase.auth.currentSession?.accessToken != access) {
        await _supabase.auth.setSession(refresh);
        final s = _supabase.auth.currentSession;
        if (s != null) {
          await _store.save(
            access: s.accessToken,
            refresh: s.refreshToken ?? refresh,
          );
        }
      }
    } catch (_) {
      // The API tokens stand on their own; this only helps the fallbacks.
    }
  }

  /// The auth server is asked directly whether a refresh token still lives.
  Future<sb.Session?> _reviveFromRefreshToken(String refresh) async {
    try {
      final res = await _supabase.auth.setSession(refresh);
      final session = res.session;
      if (session != null) {
        await _store.save(
          access: session.accessToken,
          refresh: session.refreshToken ?? refresh,
        );
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  /// The student's first name: API first, own profile row second, a warm
  /// default third. Never a failure — a greeting is not worth an error screen.
  Future<String> _resolveName({String? hint}) async {
    try {
      final me = await _api.get('/api/me', retainSessionOn401: true);
      final n = me['name'] as String?;
      if (n != null && n.isNotEmpty) return n;
    } catch (_) {}
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid != null) {
        final row = await _supabase
            .from('profiles')
            .select('first_name')
            .eq('id', uid)
            .maybeSingle();
        final n = row?['first_name'] as String?;
        if (n != null && n.isNotEmpty) return n;
      }
    } catch (_) {}
    return (hint != null && hint.isNotEmpty) ? hint : 'Champion';
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
