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

  /// Set when a session ended on its own — expired, or taken by another
  /// device — so the welcome screen can say why rather than looking like a bug.
  final String? message;
}

class SignedIn extends AuthState {
  const SignedIn(this.name);
  final String name;
}

/// ===========================================================================
/// IDENTITY
///
/// Login and signup go through the WEBSITE's routes, not straight to Supabase,
/// because those routes do more than check a password: they heal a missing
/// profile row, record the device, keep the one-account-per-device slot, and
/// write the activity log. Signing in directly against Supabase would skip all
/// of it and quietly produce a student the website does not fully know about.
///
/// The tokens come back in the JSON body — the website has always returned
/// them — and go into the platform keystore.
/// ===========================================================================
class AuthController extends AsyncNotifier<AuthState> {
  Api get _api => ref.read(apiProvider);
  SessionStore get _store => ref.read(sessionStoreProvider);

  @override
  Future<AuthState> build() async {
    final token = await _store.accessToken();
    if (token == null) return const SignedOut();
    // A stored token is not a session — it may have expired, or another device
    // may have taken the slot. Ask the server before showing the dashboard.
    try {
      final me = await _api.get('/api/me');
      return SignedIn((me['name'] as String?) ?? 'Champion');
    } on ApiFailure catch (e) {
      if (e.unauthorised) {
        return const SignedOut(
          message: 'Your session has ended. Please log in again.',
        );
      }
      // Offline with a token we cannot verify: let them in and let the screens
      // deal with it. Locking a student out because a bus went through a
      // tunnel would be the wrong call.
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
      await _persist(res);
      final me = await _api.get('/api/me');
      state = AsyncData(SignedIn((me['name'] as String?) ?? 'Champion'));
    } on ApiFailure catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Creates the account and then signs in with the same credentials.
  ///
  /// The signup route does not return tokens — it sets cookies, which a native
  /// app has no jar for — so the app logs in immediately afterwards with the
  /// details it already has. One extra round trip, no backend change, and no
  /// half-created account left behind if the second call fails.
  Future<void> signUp(Map<String, dynamic> form) async {
    state = const AsyncLoading();
    try {
      await _api.post('/api/auth/signup', body: form);
      await logIn(
        identifier: form['email'] as String,
        password: form['password'] as String,
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

  Future<void> _persist(Map<String, dynamic> res) async {
    final access = res['access_token'] as String?;
    final refresh = res['refresh_token'] as String?;
    if (access == null || refresh == null) {
      throw ApiFailure(
        'Signed in, but no session came back. Please try again.',
      );
    }
    await _store.save(access: access, refresh: refresh);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
