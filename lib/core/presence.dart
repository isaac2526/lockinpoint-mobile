import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';

/// ===========================================================================
/// PRESENCE · telling the backend the student is here.
///
/// The app never called /api/session. Two things depend on it and neither
/// worked:
///
///   * `profiles.last_seen`, which the leaderboard shows beside every name
///     and the control room uses to answer "is this student active" — for an
///     app-only student it was stamped at signup and never again;
///   * the points law's "+5 every time you enter the app". The only thing
///     that has ever recorded a visit is the login route, and an app holds
///     its session for weeks, so a student who opened LockInPoint every
///     morning for a month scored that term exactly once.
///
/// THE RULES, because a heartbeat is easy to get expensive:
///
///   · on launch, and on every return from the background — that is what
///     "entering the app" means to a student;
///   · never more than once in ten minutes, so flicking between the app and
///     WhatsApp does not become a request per flick;
///   · never while signed out, and never a reason to show an error. A failed
///     ping costs nothing and must interrupt nobody.
/// ===========================================================================
class Presence with WidgetsBindingObserver {
  Presence(this._api);

  final Api _api;

  /// A gap shorter than this is the same visit. Ten minutes is long enough
  /// that switching apps costs nothing and short enough that "last seen" is
  /// still true when a classmate reads it.
  static const quiet = Duration(minutes: 10);

  DateTime? _last;
  bool _inFlight = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(touch());
  }

  void stop() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(touch());
  }

  /// Says "still here" to the backend, at most once per [quiet].
  Future<void> touch({bool force = false}) async {
    if (_inFlight) return;
    final now = DateTime.now();
    if (!force && _last != null && now.difference(_last!) < quiet) return;
    _inFlight = true;
    try {
      await _api.get('/api/session');
      _last = now;
    } on ApiFailure {
      /* A missed heartbeat is not worth a word to the student. The next
         resume tries again, and `_last` is left alone so it will. */
    } finally {
      _inFlight = false;
    }
  }
}

final presenceProvider = Provider<Presence>((ref) {
  final p = Presence(ref.read(apiProvider));
  ref.onDispose(p.stop);
  return p;
});
