import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';

/// ===========================================================================
/// WHAT THIS STUDENT HAS ACTUALLY READ, WATCHED AND OPENED
///
/// The per-subject progress rings had nothing to measure. `/api/mobile/
/// progress-mark` was written to record a note read, a video watched and a
/// document opened — and no client had ever called it, so every ring on
/// every screen was drawn from an empty table.
///
/// Marking is FIRE AND FORGET. A student who opens a note on a bad train
/// connection must still get the note; a progress row that fails to save is
/// not worth an error, a retry queue, or a single frame of delay. The reward
/// for the request succeeding is a ring that moves — the reward for it
/// failing must be nothing at all.
///
/// The server upserts on (user, kind, item), so opening the same note twice
/// does not make two rows, and a video's furthest position only ever moves
/// forward.
/// ===========================================================================
class ProgressMarker {
  ProgressMarker(this._api);
  final Api _api;

  /// Everything already marked in this session, so scrolling a shelf back
  /// and forth does not fire the same request twenty times. Cleared only by
  /// the process ending — the server is idempotent, so a duplicate after a
  /// restart costs one request and changes nothing.
  final Set<String> _sent = {};

  void note(String id) => _mark('note', id);

  void document(String id) => _mark('document', id);

  /// Videos carry how far the student got. `seconds` is the furthest point
  /// reached, not the current one — the server never moves it backwards.
  void video(String id, {int percent = 100, int seconds = 0}) =>
      _mark('video', id, percent: percent, seconds: seconds, once: false);

  void _mark(
    String kind,
    String id, {
    int percent = 100,
    int seconds = 0,
    bool once = true,
  }) {
    if (id.trim().isEmpty) return;
    final key = '$kind:$id';
    if (once && !_sent.add(key)) return;

    /* THE try/catch IS AROUND THE CALL, NOT ONLY THE FUTURE.
       Attaching .catchError to the returned Future catches an ASYNCHRONOUS
       failure — a timeout, a 500 — and nothing else. A client that throws
       BEFORE returning a Future, which is what a malformed base URL or a
       missing session does, throws straight out of this method instead. This
       is called from a post-frame callback, so that exception surfaces as a
       framework error over the note the student is trying to read: the whole
       screen replaced because a progress row could not be written. */
    try {
      _api
          .post(
            '/api/mobile/progress-mark',
            body: {
              'kind': kind,
              'itemId': id,
              'percent': percent,
              if (seconds > 0) 'seconds': seconds,
            },
          )
          .catchError((_) => <String, dynamic>{});
    } catch (_) {
      // See above. There is no failure here worth a single pixel.
    }
  }
}

final progressMarkerProvider = Provider(
  (ref) => ProgressMarker(ref.watch(apiProvider)),
);
