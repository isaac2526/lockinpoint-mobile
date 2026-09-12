/// ===========================================================================
/// READING JSON WITHOUT CRASHING THE SCREEN
///
/// The owner hit this, in My Activities, as a student would:
///
///     Type int is not a subtype of type string in type cast
///
/// That is `m['id'] as String?` meeting an id the server sent as a number.
/// It is not a typo — it is a whole CLASS of defect. There were about three
/// hundred hard casts on JSON across thirty-seven files in this app, and
/// every one of them is a red screen waiting for the day a column changes
/// type, a row comes back null, or a table in production turns out to
/// predate the migration that would have made it a uuid.
///
/// A CAST IS A BET THAT THE SERVER WILL NEVER CHANGE. These helpers are
/// total: every one of them accepts anything at all and returns something
/// usable. A field that arrives as the wrong type degrades to a sensible
/// value instead of taking down the page the student was reading.
///
/// They are deliberately NOT clever. No reflection, no code generation, no
/// model framework — just the handful of coercions this app actually needs,
/// in one file, so the next person can read the whole thing in a minute.
/// ===========================================================================
library;

import 'api.dart';

/// Anything -> text.
///
/// A NUMERIC ID BECOMES ITS DIGITS rather than an exception, which is the
/// exact case that broke My Activities: the id is only ever used to identify
/// a row and compare it, and "12" does that as well as a uuid does.
String asText(Object? v, [String fallback = '']) {
  if (v == null) return fallback;
  if (v is String) return v;
  if (v is num || v is bool) return '$v';
  // A map or a list stringified into a UI label is worse than nothing.
  return fallback;
}

/// Anything -> text, or null when there is genuinely nothing there.
///
/// Distinct from [asText] because "no subtitle" and "an empty subtitle" lay
/// out differently, and a screen that cannot tell them apart draws a gap.
String? asTextOrNull(Object? v) {
  if (v == null) return null;
  if (v is String) return v.isEmpty ? null : v;
  if (v is num || v is bool) return '$v';
  return null;
}

/// Anything -> a whole number.
///
/// A count that arrives as the string "12" — which PostgREST does for a
/// bigint, and which JSON does for anything a database driver decided was
/// too large for a double — becomes 12.
int asInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  /* NaN.toInt() and infinity.toInt() THROW — "Unsupported operation:
     Infinity or NaN toInt". A helper written to stop casts from crashing a
     screen, crashing on a number, is the joke this library exists to avoid;
     the test that hands every junk value to every function caught it. */
  if (v is num) return v.isFinite ? v.toInt() : fallback;
  if (v is String) {
    final n = int.tryParse(v.trim());
    if (n != null) return n;
    // "12.0" is a whole number written the long way.
    final d = double.tryParse(v.trim());
    if (d != null && d.isFinite) return d.toInt();
  }
  if (v is bool) return v ? 1 : 0;
  return fallback;
}

int? asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.isFinite ? v.toInt() : null;
  if (v is String) {
    final n = int.tryParse(v.trim());
    if (n != null) return n;
    final d = double.tryParse(v.trim());
    if (d != null && d.isFinite) return d.toInt();
  }
  return null;
}

/// Anything -> a real number. Never NaN and never infinite: those propagate
/// silently through arithmetic and surface as a blank percentage three
/// screens later, which is far harder to trace than a zero.
double asDouble(Object? v, [double fallback = 0]) {
  if (v is double) return v.isFinite ? v : fallback;
  if (v is num) return v.toDouble();
  if (v is String) {
    final d = double.tryParse(v.trim());
    if (d != null && d.isFinite) return d;
  }
  return fallback;
}

/// Anything -> a real number, or null when the field is genuinely absent.
///
/// Needed wherever one amount falls back to another: a withdrawal carries
/// `amount_local` when the student's currency was known at the time and only
/// `amount_ngn` when it was not. [asDouble] would turn the missing one into
/// zero and the fallback would never fire, so the student would be shown a
/// payout of nothing.
double? asDoubleOrNull(Object? v) {
  if (v is double) return v.isFinite ? v : null;
  if (v is num) return v.toDouble();
  if (v is String) {
    final d = double.tryParse(v.trim());
    if (d != null && d.isFinite) return d;
  }
  return null;
}

/// Anything -> true or false.
///
/// A backend may say true, "true", 1, or "1" for the same flag, and has at
/// various times said each of them. Only real affirmatives are true;
/// everything unrecognised is false, because a permission flag that defaults
/// to ON when it cannot be read is a security bug, not a convenience.
bool asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes' || s == 'y' || s == 'on') {
      return true;
    }
    if (s == 'false' || s == '0' || s == 'no' || s == 'n' || s == 'off') {
      return false;
    }
  }
  return fallback;
}

/// Anything -> a string map. A non-map — null, a list, a bare string where an
/// object was expected — becomes an EMPTY map, so the caller's own reads
/// return their own fallbacks and the screen renders empty rather than dying.
Map<String, dynamic> asMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry('$k', val));
  return const {};
}

/// Anything -> a plain list, WITHOUT touching the entries.
///
/// The drop-in replacement for `(x as List?) ?? const []`, which was written
/// about sixty times in this app and throws the moment the server answers
/// with an object or an error string where a list was expected — exactly
/// what an endpoint does when it fails and returns `{"error": ...}`.
List<Object?> asList(Object? v) => v is List ? v : const [];

/// Anything -> a string map, or null when the object genuinely was not sent.
///
/// [asMap] is right when the caller reads fields out of it; this is right
/// when the caller tests the whole thing for null, because an empty map is
/// not the same answer as "no media on this question".
Map<String, dynamic>? asMapOrNull(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry('$k', val));
  return null;
}

/// Anything -> a list of string maps, with non-map entries DROPPED.
///
/// One malformed row in a list of two hundred must cost that one row, not
/// the whole page. This is the single most common shape in this app: every
/// feed, shelf, board and history is a list of objects.
List<Map<String, dynamic>> asMapList(Object? v) {
  if (v is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final e in v) {
    if (e is Map) {
      out.add(
        e is Map<String, dynamic> ? e : e.map((k, val) => MapEntry('$k', val)),
      );
    }
  }
  return out;
}

/// Anything -> a list of strings, coercing numbers and dropping the rest.
List<String> asTextList(Object? v) {
  if (v is! List) return const [];
  final out = <String>[];
  for (final e in v) {
    final s = asTextOrNull(e);
    if (s != null) out.add(s);
  }
  return out;
}

/// Anything -> a moment, or null.
///
/// Accepts the ISO strings the API sends and the epoch milliseconds a cache
/// writes, because both reach this app and a screen should not care which.
DateTime? asTime(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is num) {
    // Same trap as asInt: a non-finite number cannot be turned into one.
    if (!v.isFinite) return null;
    final ms = v.toInt();
    // Below this the number is far more likely to be seconds than
    // milliseconds — 10^11 ms is 1973, and nothing in this product predates
    // it, so a smaller number means somebody sent seconds.
    return DateTime.fromMillisecondsSinceEpoch(
      ms < 100000000000 ? ms * 1000 : ms,
    );
  }
  final s = asTextOrNull(v);
  return s == null ? null : DateTime.tryParse(s);
}

/// ===========================================================================
/// WHAT A STUDENT IS ALLOWED TO SEE WHEN SOMETHING FAILS
///
/// Seventeen screens rendered `message: '$e'` — the raw Dart exception —
/// directly into the error card. That is how the owner came to be reading
///
///     Type int is not a subtype of type string in type cast
///
/// on his own My Activities page. A stack of that sort tells a student
/// nothing they can act on, tells an attacker a little about the internals,
/// and tells the owner that his product is unfinished.
///
/// [ApiFailure] is the one exception in this app whose message was WRITTEN
/// for a person — "No connection. Try again in a moment." — so it passes
/// through untouched. Everything else is a programming fault, and a
/// programming fault gets a sentence about what the student was trying to do.
///
/// The technical text is not discarded. It goes to the debug console through
/// [describeFailure], which is what a developer reads and a student never
/// sees.
/// ===========================================================================

/// A sentence fit for the screen.
///
/// [doing] names the thing that failed in the student's own terms — "loading
/// your activities", "opening this note" — so the message is specific without
/// being technical. Keep it as a gerund phrase; it is dropped into
/// "We couldn't … right now."
String humanError(Object? e, {String doing = 'load this'}) {
  if (e is ApiFailure) return e.message;
  return "We couldn't $doing right now. Please try again.";
}

/// The technical truth, for the console and for a future crash reporter.
/// Never rendered.
String describeFailure(Object? e, [StackTrace? st]) {
  final head = e is ApiFailure ? '${e.message} · ${e.detail ?? ''}' : '$e';
  return st == null ? head : '$head\n$st';
}
