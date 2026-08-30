import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// Login and signup go through the WEBSITE's routes, and ONLY the website's
/// routes: they check the password, heal a missing profile row, record the
/// device, hold the one-account-per-device slot, write the activity log —
/// and hand back the session pair in their JSON body.
///
/// The app deliberately holds no other road to a session. An earlier build
/// also signed in directly against a Supabase project compiled into the APK,
/// as a fallback — and that address quietly drifted from the project the
/// server actually uses, so the app ended up carrying tokens one auth server
/// had issued while another rejected them on every request. One backend, one
/// door, nothing compiled in that can drift.
/// ===========================================================================
class AuthController extends AsyncNotifier<AuthState> {
  Api get _api => ref.read(apiProvider);
  SessionStore get _store => ref.read(sessionStoreProvider);

  @override
  Future<AuthState> build() async {
    final refresh = await _store.refreshToken();
    if (refresh == null) return const SignedOut();

    /* A stored token is not a session. Ask the server before showing home.
       The Api enforces the 401 law for us: a 401 comes back `unauthorised`
       ONLY after the backend's refresh route refused the refresh token.
       Every other failure — offline, a mid-deploy backend, an auth hiccup —
       leaves the session standing, and a standing session means the student
       goes to their dashboard, where cached numbers and pull-to-refresh
       live. */
    try {
      final me = await _api.get('/api/me');
      return SignedIn((me['name'] as String?) ?? 'Champion');
    } on ApiFailure catch (e) {
      if (e.unauthorised) {
        return SignedOut(message: e.message);
      }
      // A token we could not verify: let them in. A bus going through a
      // tunnel is not a reason to lock a student out.
      return const SignedIn('Champion');
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
      await _establishSession(res);
      state = AsyncData(SignedIn(_nameFrom(res, hint: null)));
    } on ApiFailure catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signUp(Map<String, dynamic> form) async {
    state = const AsyncLoading();
    try {
      final res = await _api.post('/api/auth/signup', body: form);
      await _establishSession(res);
      state = AsyncData(
        SignedIn(_nameFrom(res, hint: form['first_name'] as String?)),
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
    await _store.clear();
    state = const AsyncData(SignedOut());
  }

  // -------------------------------------------------------------------------

  /// Turns a successful login or signup response into a stored session. The
  /// route's body is the ONLY source of tokens, so a response without them is
  /// a named failure, not a silent detour to some other auth server.
  Future<void> _establishSession(Map<String, dynamic> res) async {
    final access = res['access_token'] as String?;
    final refresh = res['refresh_token'] as String?;
    if (access == null || refresh == null) {
      // Name the missing pieces, so a screenshot of this message is a
      // diagnosis rather than a mystery.
      throw ApiFailure(
        'Signed in, but the server issued no session '
        '(response carried: ${res.keys.join(', ')}). '
        'The website needs its update deployed.',
      );
    }
    await _store.save(access: access, refresh: refresh);
  }

  /// The student's first name, from the route's own response — the same
  /// answer /api/me would give, without a second request. Never a failure:
  /// a greeting is not worth an error screen.
  String _nameFrom(Map<String, dynamic> res, {String? hint}) {
    final n = res['name'] as String?;
    if (n != null && n.isNotEmpty) return n;
    return (hint != null && hint.isNotEmpty) ? hint : 'Champion';
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
