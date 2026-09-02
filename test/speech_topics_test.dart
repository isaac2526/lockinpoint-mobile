import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/features/progress/progress_repository.dart';

/// ===========================================================================
/// READING ALOUD, AND TOPIC-LEVEL HONESTY
///
/// Two things worth holding:
///
///   1. A question read aloud must not be read as MARKUP. A synthesiser
///      saying "less than sub two greater than" instead of "H two O" is
///      worse than silence, and the importers put tags and LaTeX in every
///      chemistry and maths question in the bank.
///   2. The topic breakdown must not invent confidence. A topic the server
///      declined to judge must arrive as unproven, and stay unproven.
/// ===========================================================================
void main() {
  group('a topic breakdown survives the parse', () {
    test('the weakest come back weakest-first, with their denominator', () {
      final t = TopicStrength.from({
        'minSeen': 6,
        'weakest': [
          {
            'topic': 'Mole Concept',
            'subject': 'Chemistry',
            'seen': 18,
            'correct': 4,
            'percent': 22.2,
          },
          {
            'topic': 'Redox',
            'subject': 'Chemistry',
            'seen': 9,
            'correct': 4,
            'percent': 44.4,
          },
        ],
        'strongest': [
          {
            'topic': 'Periodic Table',
            'subject': 'Chemistry',
            'seen': 20,
            'correct': 19,
            'percent': 95,
          },
        ],
        'rows': [],
        'unproven': [
          {'topic': 'Electrolysis', 'seen': 2},
        ],
      });

      expect(t.weakest.first.topic, 'Mole Concept');
      expect(t.weakest.first.percent, closeTo(22.2, 0.01));
      // The denominator matters: 22% off eighteen questions and off two are
      // not the same claim, and the screen prints both numbers.
      expect(t.weakest.first.seen, 18);
      expect(t.weakest.first.correct, 4);
      expect(t.strongest.first.topic, 'Periodic Table');
    });

    test(
      'an unproven topic stays unproven, and is named rather than hidden',
      () {
        final t = TopicStrength.from({
          'minSeen': 6,
          'unproven': [
            {'topic': 'Electrolysis', 'seen': 2},
            {'topic': 'Titration', 'seen': 5},
          ],
        });
        expect(t.weakest, isEmpty);
        expect(t.unproven.length, 2);
        expect(t.unproven.first.topic, 'Electrolysis');
        expect(t.minSeen, 6);
        // Something to render: "practise these to find out" beats an empty
        // screen that looks broken.
        expect(t.hasAnything, isTrue);
      },
    );

    test('nothing at all renders nothing at all', () {
      final t = TopicStrength.from({});
      expect(t.hasAnything, isFalse);
    });

    test('a row missing every field does not throw', () {
      final t = TopicStrength.from({
        'weakest': [<String, dynamic>{}],
      });
      expect(t.weakest.length, 1);
      expect(t.weakest.first.topic, '');
      expect(t.weakest.first.percent, 0);
    });

    test('minSeen falls back rather than becoming zero', () {
      // Zero would mean "one question is enough to judge you", which is the
      // exact failure the threshold exists to prevent.
      expect(TopicStrength.from({}).minSeen, greaterThan(1));
    });
  });
}
