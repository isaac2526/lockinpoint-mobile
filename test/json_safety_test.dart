import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/json.dart';

/// ===========================================================================
/// READING JSON MUST NEVER TAKE DOWN A SCREEN.
///
/// The owner hit this as a student would, in My Activities:
///
///     Type int is not a subtype of type string in type cast
///
/// One hard cast — `m['id'] as String?` — meeting an id the server sent as a
/// number. There were roughly three hundred such casts across this app.
///
/// Every test here is a shape that really reaches this client: PostgREST
/// sends a bigint as a STRING; a column added by a migration that silently
/// skipped an existing table comes back as an INT where a uuid was expected;
/// a nullable join returns null where an object was expected; a list has one
/// malformed row in two hundred.
/// ===========================================================================
void main() {
  group('asText', () {
    test('the exact value that crashed My Activities', () {
      // activity_log.id as a number, because `create table if not exists`
      // skipped a table that already had a bigserial id.
      expect(asText(12), '12');
      expect(() => asText(12), returnsNormally);
    });

    test('a real string passes through untouched', () {
      expect(asText('9f1c-4a2b'), '9f1c-4a2b');
    });

    test('null and absent give the fallback', () {
      expect(asText(null), '');
      expect(asText(null, 'Activity'), 'Activity');
    });

    test('a map or list never becomes a UI label', () {
      // "{a: 1}" on a card is worse than an empty one.
      expect(asText({'a': 1}), '');
      expect(asText([1, 2]), '');
    });
  });

  group('asTextOrNull', () {
    test('empty and absent are both nothing, so layout can tell', () {
      expect(asTextOrNull(''), isNull);
      expect(asTextOrNull(null), isNull);
      expect(asTextOrNull('x'), 'x');
    });
  });

  group('asInt', () {
    test('PostgREST sends a bigint as a string', () {
      expect(asInt('20394'), 20394);
    });

    test('a whole number written the long way', () {
      expect(asInt('12.0'), 12);
      expect(asInt(12.7), 12);
    });

    test('nonsense gives the fallback rather than throwing', () {
      // NaN.toInt() and infinity.toInt() THROW in Dart. A coercion helper
      // that crashes on a number would be the joke this library exists to
      // avoid, and the all-junk test below is what caught it.
      expect(asInt(double.nan), 0);
      expect(asInt(double.infinity, 7), 7);
      expect(asIntOrNull(double.nan), isNull);
      expect(asInt('not a number'), 0);
      expect(asInt(null, -1), -1);
      expect(asInt({'n': 1}), 0);
    });
  });

  group('asDouble', () {
    test('NaN and infinity never escape', () {
      // These propagate silently and surface as a blank percentage three
      // screens away, which is far harder to trace than a zero.
      expect(asDouble(double.nan), 0);
      expect(asDouble(double.infinity), 0);
      expect(asDouble('nan'), 0);
    });

    test('real numbers survive in both shapes', () {
      expect(asDouble('72.5'), 72.5);
      expect(asDouble(72), 72.0);
    });
  });

  group('asBool', () {
    test('every affirmative the backend has ever sent', () {
      for (final v in [true, 1, '1', 'true', 'TRUE', 'yes', 'on']) {
        expect(asBool(v), isTrue, reason: 'for $v');
      }
    });

    test('every negative', () {
      for (final v in [false, 0, '0', 'false', 'no', 'off']) {
        expect(asBool(v), isFalse, reason: 'for $v');
      }
    });

    test('an unreadable flag is FALSE, never true', () {
      // A permission that defaults to ON when it cannot be read is a
      // security bug, not a convenience.
      expect(asBool('maybe'), isFalse);
      expect(asBool(null), isFalse);
      expect(asBool({'x': 1}), isFalse);
    });
  });

  group('asMap', () {
    test('a null join becomes an empty map, not an exception', () {
      expect(asMap(null), isEmpty);
      expect(asMap('a string'), isEmpty);
      expect(asMap([1]), isEmpty);
    });

    test('non-string keys are coerced', () {
      final m = asMap(<dynamic, dynamic>{1: 'a', 'b': 2});
      expect(m['1'], 'a');
      expect(m['b'], 2);
    });
  });

  group('asMapList', () {
    test('one malformed row costs that row, not the page', () {
      final rows = asMapList([
        {'id': 1},
        'garbage',
        null,
        {'id': 2},
      ]);
      expect(rows.length, 2);
      expect(rows.first['id'], 1);
    });

    test('a non-list is empty rather than fatal', () {
      expect(asMapList(null), isEmpty);
      expect(asMapList({'rows': []}), isEmpty);
    });
  });

  group('asTextList', () {
    test('numbers coerce and rubbish is dropped', () {
      expect(
        asTextList([
          'a',
          2,
          null,
          {'x': 1},
        ]),
        ['a', '2'],
      );
    });
  });

  group('asTime', () {
    test('the ISO string the API sends', () {
      expect(asTime('2026-09-12T08:30:00Z')?.toUtc().hour, 8);
    });

    test('epoch milliseconds from a cache', () {
      final t = DateTime.utc(2026, 9, 12);
      expect(asTime(t.millisecondsSinceEpoch)?.toUtc(), t);
    });

    test('epoch SECONDS are told apart from milliseconds', () {
      // 10^11 ms is 1973, and nothing in this product predates it — so a
      // smaller number means somebody sent seconds.
      final t = DateTime.utc(2026, 9, 12);
      expect(asTime(t.millisecondsSinceEpoch ~/ 1000)?.toUtc(), t);
    });

    test('unparseable is null, not an exception', () {
      expect(asTime(double.nan), isNull);
      expect(asTime(double.infinity), isNull);
      expect(asTime('sometime last week'), isNull);
      expect(asTime(null), isNull);
    });
  });

  test('nothing in this library throws, whatever it is handed', () {
    const junk = [
      null,
      0,
      -1,
      1.5,
      double.nan,
      double.infinity,
      '',
      'x',
      true,
      false,
      [],
      {},
      [1, 'a'],
      {'k': 'v'},
    ];
    for (final v in junk) {
      expect(() => asText(v), returnsNormally, reason: 'asText($v)');
      expect(() => asTextOrNull(v), returnsNormally);
      expect(() => asInt(v), returnsNormally);
      expect(() => asIntOrNull(v), returnsNormally);
      expect(() => asDouble(v), returnsNormally);
      expect(() => asBool(v), returnsNormally);
      expect(() => asMap(v), returnsNormally);
      expect(() => asMapList(v), returnsNormally);
      expect(() => asTextList(v), returnsNormally);
      expect(() => asTime(v), returnsNormally);
    }
  });
}
