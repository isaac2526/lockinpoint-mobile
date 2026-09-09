import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/features/career/career_repository.dart';
import 'package:lockinpoint/features/games/games_repository.dart';
import 'package:lockinpoint/features/home/feature_catalogue.dart';

/// ===========================================================================
/// THE ARENA, THE LADDER, AND THE COURSE SHELF
///
/// Three things these tests exist to stop:
///
///   1. A game marking an answer against the wrong option. The pool serves
///      `letters` alongside `options` precisely because a question can carry
///      A, B, D and no C — indexing by position rather than by letter would
///      silently mark the wrong answer correct.
///   2. The app computing anything about The Climb. Its state comes from the
///      server; if a field is dropped in parsing the game shows a wrong score
///      and nobody notices because it still looks like a game.
///   3. A tile with no destination. Every key in the catalogue must open
///      something now.
/// ===========================================================================
void main() {
  group('a game question knows its own answer', () {
    test('the answer letter maps to the option at that letter', () {
      final q = GameQuestion.from({
        'id': 'q1',
        'question': 'Which is a noble gas?',
        'options': ['Oxygen', 'Argon', 'Nitrogen', 'Chlorine'],
        'letters': ['A', 'B', 'C', 'D'],
        'answer': 'B',
      });
      expect(q.answerIndex, 1);
      expect(q.options[q.answerIndex], 'Argon');
    });

    test('a gap in the letters does NOT shift the answer', () {
      // The bank has these: a question with A, B and D and no C. Indexing by
      // position would mark 'D' as the third option and be wrong.
      final q = GameQuestion.from({
        'id': 'q2',
        'options': ['first', 'second', 'fourth'],
        'letters': ['A', 'B', 'D'],
        'answer': 'D',
      });
      expect(q.answerIndex, 2);
      expect(q.options[q.answerIndex], 'fourth');
    });

    test('an answer letter that is not among the options points nowhere', () {
      final q = GameQuestion.from({
        'options': ['a', 'b'],
        'letters': ['A', 'B'],
        'answer': 'E',
      });
      expect(q.answerIndex, -1);
    });

    test('a lowercase answer from the bank still resolves', () {
      final q = GameQuestion.from({
        'options': ['a', 'b'],
        'letters': ['A', 'B'],
        'answer': 'b',
      });
      expect(q.answerIndex, 1);
    });
  });

  group('The Climb is read from the server, never computed', () {
    Map<String, dynamic> state({
      String status = 'playing',
      int rung = 3,
      int? secondNet,
    }) => {
      'id': 'game-1',
      'rung': rung,
      'total': 15,
      'ladder': [
        10,
        20,
        30,
        40,
        50,
        60,
        70,
        80,
        90,
        100,
        110,
        120,
        130,
        140,
        150,
      ],
      'firstNet': 5,
      'secondNet': secondNet,
      'banked': 0,
      'status': status,
      'score': 30,
      'lifelines': {'fifty': true, 'class': false, 'lumi': true},
      'seconds': null,
      'question': {
        'question': 'Which rung is this?',
        'options': [
          {'letter': 'A', 'text': 'one'},
          {'letter': 'B', 'text': 'two'},
        ],
      },
    };

    test('the whole rung survives the parse', () {
      final s = ClimbState.from(state());
      expect(s.id, 'game-1');
      expect(s.rung, 3);
      expect(s.total, 15);
      expect(s.ladder.length, 15);
      expect(s.score, 30);
      expect(s.playing, isTrue);
    });

    test('a spent lifeline reads as unavailable', () {
      final s = ClimbState.from(state());
      expect(s.lifelines['fifty'], isTrue);
      expect(s.lifelines['class'], isFalse);
    });

    test(
      'fifty-fifty is the server sending FEWER options, not a hide flag',
      () {
        // Two options came back. The app renders what it is given; it never
        // decides which to remove.
        final s = ClimbState.from(state());
        expect(s.options.length, 2);
        expect(s.options.first.letter, 'A');
      },
    );

    test('an unplaced second net is null, not zero', () {
      expect(ClimbState.from(state()).secondNet, isNull);
      expect(ClimbState.from(state(secondNet: 9)).secondNet, 9);
    });

    test('a finished game is not playing', () {
      for (final s in ['won', 'lost', 'walked']) {
        expect(ClimbState.from(state(status: s)).playing, isFalse);
      }
    });

    test('a state with no question at all does not throw', () {
      final s = ClimbState.from({'id': 'g', 'status': 'lost', 'score': 50});
      expect(s.question, '');
      expect(s.options, isEmpty);
      expect(s.score, 50);
    });
  });

  group('the course shelf answers the question candidates actually ask', () {
    test('an offer carries the school, the course and the cut-off', () {
      final o = CourseOffer.from({
        'course': 'Medicine and Surgery',
        'institution': 'University of Ibadan',
        'shortName': 'UI',
        'cutoff': '78 – 85',
        'note': 'Merit list drawn strictly from the aggregate.',
        'state': 'Oyo',
        'type': 'university',
      });
      expect(o.institution, 'University of Ibadan');
      expect(o.cutoff, '78 – 85');
      expect(o.state, 'Oyo');
    });

    test('a school that published no cut-off yields an empty string', () {
      final o = CourseOffer.from({'course': 'Law', 'institution': 'X'});
      expect(o.cutoff, '');
      expect(o.note, '');
    });
  });

  group('prose written as HTML is readable, not tagged', () {
    test('paragraphs become blank lines and tags disappear', () {
      final out = readableHtml(
        '<p><strong>UI aggregate:</strong> (UTME ÷ 8) + (Post UTME ÷ 2)</p>'
        '<p>Merit lists come off that figure.</p>',
      );
      expect(out, contains('UI aggregate:'));
      expect(out, contains('Merit lists'));
      expect(out.contains('<'), isFalse);
      expect(out.contains('strong'), isFalse);
    });

    test('list items become bullets', () {
      expect(
        readableHtml('<ul><li>one</li><li>two</li></ul>'),
        contains('• one'),
      );
    });

    test('entities come back as the characters they stand for', () {
      expect(
        readableHtml('a &amp; b &quot;c&quot; &#39;d&#39;'),
        'a & b "c" \'d\'',
      );
    });
  });

  group('every tile opens something', () {
    test('no feature is still marked "not ready"', () {
      // The whole grid used to be six dead tiles apologising when tapped.
      expect(kFeatures.where((f) => !f.ready), isEmpty);
    });

    test('the catalogue still has no duplicate keys', () {
      final keys = kFeatures.map((f) => f.key).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('colour still tells tiles apart, band by band', () {
      /* THE OLD RULE WAS "every tile has a unique hue", and it held while
         there were twelve tiles and twelve hues. There are twenty-two rooms
         now and still twelve hues, so that rule is arithmetically impossible
         — and dropping it would throw away the thing it protected.

         The scanning unit is the BAND: a student looking for Pointgram looks
         under Community, and only needs it to be unmistakable among the tiles
         beside it. So the invariant is uniqueness WITHIN a band, which is
         both achievable and the one that actually does the work. */
      for (final band in FeatureBand.values) {
        final inBand = kFeatures.where((f) => f.band == band).toList();
        final hues = inBand.map((f) => f.hue).toList();
        expect(
          hues.toSet().length,
          hues.length,
          reason:
              'two tiles in ${band.label} share a hue and cannot be told '
              'apart at a glance: '
              '${inBand.map((f) => "${f.title}=${f.hue.name}").join(", ")}',
        );
      }
    });
  });
}
