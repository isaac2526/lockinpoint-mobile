import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api.dart';
import '../../core/session_store.dart';
import '../gram/gram_gate.dart';

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
  /// Where the student's first name is kept between launches, so the very
  /// first frame can greet them by name without asking the server first.
  static const _nameKey = 'lip.student-name';

  Api get _api => ref.read(apiProvider);
  SessionStore get _store => ref.read(sessionStoreProvider);

  @override
  Future<AuthState> build() async {
    final refresh = await _store.refreshToken();
    if (refresh == null) return const SignedOut();

    /* STARTUP IS NOT THE PLACE FOR A ROUND TRIP.
       This used to `await /api/me` before deciding anything, which put a
       whole network exchange — on a Nigerian mobile connection, often
       seconds of it — between tapping the icon and seeing the app. And the
       dashboard then made a SECOND request behind it, one after the other.
       Two serial round trips before a student could do anything.

       A stored refresh token is good enough to open the door with, because
       nothing behind that door can actually be used without the server
       agreeing: every request carries the key, and a key the server refuses
       comes back `unauthorised` and ends the session through
       [signOutBecause]. So the app opens on the student's own home
       immediately — from the snapshot the dashboard already keeps — and the
       identity check runs behind it rather than in front of it.

       This is not hiding the wait behind an animation. The request that used
       to block the first frame is the same request; it simply no longer
       stands between the student and their app. */
    _verifyQuietly();

    final prefs = await SharedPreferences.getInstance();
    return SignedIn(prefs.getString(_nameKey) ?? 'Champion');
  }

  /// Confirms with the server that the stored session is real, without ever
  /// holding up the first frame. Only a refused refresh token ends the
  /// session; being offline, or catching the backend mid-deploy, changes
  /// nothing on screen.
  void _verifyQuietly() {
    /* Both dependencies are taken NOW, while this provider is certainly
       alive. Reading them after the await would throw the moment a student
       signs out or the provider rebuilds mid-flight — the request outlives
       the ref, so it must not need it. */
    final api = _api;
    final store = _store;

    var alive = true;
    ref.onDispose(() => alive = false);

    // Invoked immediately rather than scheduled: the request should already
    // be on the wire by the time the first frame is painted.
    () async {
      try {
        final me = await api.get('/api/me');
        final name = me['name'] as String?;
        if (name == null || name.isEmpty) return;
        await _rememberName(name);
        if (alive && state.value is SignedIn) state = AsyncData(SignedIn(name));
      } on ApiFailure catch (e) {
        // A bus going through a tunnel is not a reason to lock a student out.
        if (!e.unauthorised) return;
        await store.clear();
        await _forgetName();
        if (alive) state = AsyncData(SignedOut(message: e.message));
      } catch (_) {
        // Never let a background check take the app down.
      }
    }();
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
      final name = _nameFrom(res, hint: null);
      await _rememberName(name);
      state = AsyncData(SignedIn(name));
    } on ApiFailure catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signUp(Map<String, dynamic> form) async {
    state = const AsyncLoading();
    try {
      final res = await _api.post('/api/auth/signup', body: form);
      await _establishSession(res);
      final name = _nameFrom(res, hint: form['first_name'] as String?);
      await _rememberName(name);
      state = AsyncData(SignedIn(name));
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
    await _forget();
    state = const AsyncData(SignedOut());
  }

  /// Ends a session the SERVER refused. The store is cleared rather than the
  /// provider merely invalidated, because [build] now opens the door on a
  /// stored token alone: leaving a refused token in place would let the next
  /// build walk straight back in, and the 401 would arrive again, for ever.
  /// Clearing makes the next launch deterministically signed out.
  Future<void> signOutBecause(String why) async {
    await _forget();
    state = AsyncData(SignedOut(message: why));
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

  /// Keeps the greeting across launches. Not a secret, and not a session —
  /// losing it costs a student the word "Champion" for one frame.
  Future<void> _rememberName(String name) async =>
      (await SharedPreferences.getInstance()).setString(_nameKey, name);

  /// Forgets everything this phone knew about who was signed in.
  Future<void> _forget() async {
    await _store.clear();
    await _forgetName();
    /* THE POINTGRAM ROOM CODE GOES WITH THE SESSION. It is a shared code
       rather than a credential, but the next person to sign in on this phone
       has not been given it, and inheriting a locked room from whoever used
       the phone before is not how a lock is meant to work. */
    await ref.read(gramGateProvider.notifier).forget();
  }

  Future<void> _forgetName() async =>
      (await SharedPreferences.getInstance()).remove(_nameKey);
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
