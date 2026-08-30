import 'session_store.dart';

/// What the auth server said when asked to honour a refresh token.
sealed class RefreshOutcome {
  const RefreshOutcome();
}

/// The session lives: here is the rotated pair the auth server issued.
class RefreshedSession extends RefreshOutcome {
  const RefreshedSession({required this.access, required this.refresh});
  final String access;
  final String refresh;
}

/// The auth server itself refused the refresh token. This is the ONE outcome
/// that proves a session is genuinely dead.
class RefreshRefused extends RefreshOutcome {
  const RefreshRefused();
}

/// The auth server could not be reached, so nothing was proven either way.
/// A bus going through a tunnel must never be read as a dead session.
class RefreshUnreachable extends RefreshOutcome {
  const RefreshUnreachable();
}

/// Asks the auth server whether a refresh token still lives, returning the
/// rotated pair when it does. The real one wraps supabase's setSession; tests
/// hand in whatever server they need.
typedef RefreshExchange = Future<RefreshOutcome> Function(String refreshToken);

/// ===========================================================================
/// THE ONE PLACE A SESSION IS REVIVED
///
/// Supabase invalidates a refresh token the moment it is used, so two
/// concurrent revive attempts are one success and one "token not found" —
/// and the loser would sign the student out. Every 401 in the app funnels
/// through here, and concurrent callers share one in-flight exchange instead
/// of racing each other for the same single-use token.
/// ===========================================================================
class SessionRefresher {
  SessionRefresher(this._store, this._exchange);

  final SessionStore _store;
  final RefreshExchange _exchange;

  Future<RefreshOutcome>? _inFlight;

  Future<RefreshOutcome> refresh() =>
      _inFlight ??= _run().whenComplete(() => _inFlight = null);

  Future<RefreshOutcome> _run() async {
    String? refresh;
    try {
      refresh = await _store.refreshToken();
    } catch (_) {
      refresh = null;
    }
    if (refresh == null) return const RefreshRefused();

    final outcome = await _exchange(refresh);
    if (outcome is RefreshedSession) {
      // The rotated pair replaces the consumed one before anyone retries, so
      // a crash after this line still leaves the store holding a live key.
      await _store.save(access: outcome.access, refresh: outcome.refresh);
    }
    return outcome;
  }
}
