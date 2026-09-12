import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'json.dart';

/// ===========================================================================
/// THE LAST GOOD ANSWER, AND HOW OLD IT IS
///
/// "No connection" is not an answer to a question the phone already knows the
/// answer to. A student on a bus asking where they are on the leaderboard
/// should be shown where they were this morning — clearly labelled as this
/// morning — rather than an error card, because the error card helps nobody
/// and this morning's position is very nearly right.
///
/// TWO RULES THAT MAKE THE DIFFERENCE BETWEEN A CACHE AND A LIE:
///
///   1 · IT SAYS HOW OLD IT IS. A stale number shown as if it were live is
///       worse than no number: a student who thinks they have dropped ten
///       places, because the board is from Tuesday, has been told something
///       false about their own work.
///
///   2 · IT CATCHES UP BY ITSELF. The old caching in this app served the
///       stored copy and then quietly fetched a fresh one — into nothing.
///       The provider had already returned, so the screen went on showing
///       the old figures until the app was killed and reopened. A refresh
///       nobody sees is not a refresh.
/// ===========================================================================

/// Something read from the network, with the one piece of context the screen
/// needs in order to be honest about it.
class Cached<T> {
  const Cached({required this.value, this.savedAt, this.live = true});

  final T value;

  /// When this was fetched. Null for something never cached.
  final DateTime? savedAt;

  /// True when this came off the wire just now.
  final bool live;

  bool get isStale => !live;

  /// "just now", "8 minutes ago", "yesterday" — how a person says it.
  String get age {
    final at = savedAt;
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inSeconds < 90) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} minutes ago';
    if (d.inHours < 24) {
      return '${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
    }
    if (d.inDays == 1) return 'yesterday';
    if (d.inDays < 7) return '${d.inDays} days ago';
    return 'a while ago';
  }

  /// The sentence a screen puts above stale content.
  String get staleLine =>
      isStale ? 'Showing what we had ${age.isEmpty ? 'before' : age}.' : '';
}

/// Reads JSON from [path], keeping the last good copy under [key].
///
/// Returns the fresh answer when there is one. When the network refuses, it
/// returns the stored copy MARKED STALE rather than throwing — but only if
/// there is one. A first-ever launch with no network still fails honestly,
/// because inventing an empty board would be worse than saying so.
Future<Cached<Map<String, dynamic>>> readCached(
  Ref ref, {
  required String key,
  required String path,
  Map<String, dynamic>? query,
}) async {
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    /* A phone whose preferences will not open still gets live data; it just
       gets no cache. Never a reason to fail the read. */
  }

  try {
    final res = await ref.read(apiProvider).get(path, query: query);
    if (res['ok'] != false) {
      final now = DateTime.now();
      await prefs?.setString(
        key,
        jsonEncode({'at': now.millisecondsSinceEpoch, 'body': res}),
      );
      return Cached(value: res, savedAt: now);
    }
    /* ok:false is the SERVER answering, not the network failing — "you are
       not in any school yet" is a real answer and must not be replaced with
       a week-old board. */
    return Cached(value: res, savedAt: DateTime.now());
  } catch (e) {
    final stored = prefs?.getString(key);
    if (stored == null) rethrow;
    try {
      final wrapper = asMap(jsonDecode(stored));
      final body = asMap(wrapper['body']);
      if (body.isEmpty) rethrow;
      return Cached(value: body, savedAt: asTime(wrapper['at']), live: false);
    } catch (_) {
      // A corrupt cache is thrown away, not fought with.
      rethrow;
    }
  }
}
