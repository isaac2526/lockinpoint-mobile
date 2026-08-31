import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/features/saved/saved_repository.dart';
import 'package:lockinpoint/features/tutor/tutor_repository.dart';

/// ===========================================================================
/// THREE TILES THAT USED TO SAY "ARRIVES IN THE NEXT BUILD"
///
/// Classroom, Saved questions and Lumi all had working backends and dead
/// tiles. These tests hold the three things that were easiest to get wrong
/// while wiring them:
///
///   1. A saved question's answer LETTER must point at the right option.
///   2. Lumi's refusals must keep their meaning. A 403 saying "activate" and
///      a 429 saying "wait 20 seconds" arrive as the same exception, and a
///      screen that cannot tell them apart shows an anonymous red sentence.
///   3. Nothing may crash on a row the bank left half-filled.
/// ===========================================================================

/// A server that answers with exactly one envelope, then records what it saw.
class _Server extends Fake implements Api {
  _Server(this.answer, {this.throwIt});

  final Map<String, dynamic> answer;
  final ApiFailure? throwIt;
  Object? lastBody;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Duration? receiveTimeout,
  }) async {
    lastBody = body;
    if (throwIt != null) throw throwIt!;
    return answer;
  }
}

void main() {
  group('a saved question knows which option is the answer', () {
    SavedQuestion q(String answer, int options) => SavedQuestion.from({
      'id': 'q1',
      'question': 'What is 2 + 2?',
      'options': List.generate(options, (i) => 'option $i'),
      'answer': answer,
      'explanation': 'Because it is.',
      'subject': 'Mathematics',
      'year': 2019,
    });

    test(
      'A points at the first option',
      () => expect(q('A', 4).answerIndex, 0),
    );
    test('D points at the fourth', () => expect(q('D', 4).answerIndex, 3));

    test('a letter past the end of the list points nowhere', () {
      // A five-option answer on a four-option question is a bank error, not a
      // reason to throw a RangeError inside a student's revision list.
      expect(q('E', 4).answerIndex, isNull);
    });

    test('no answer recorded points nowhere', () {
      expect(q('', 4).answerIndex, isNull);
    });

    test('a lowercase letter from the bank still resolves', () {
      final parsed = SavedQuestion.from({
        'id': 'q',
        'options': ['a', 'b'],
        'answer': 'b',
      });
      expect(parsed.answerIndex, 1);
    });

    test('a row with nothing in it parses to empties, not nulls', () {
      final parsed = SavedQuestion.from({});
      expect(parsed.question, '');
      expect(parsed.options, isEmpty);
      expect(parsed.year, isNull);
      expect(parsed.answerIndex, isNull);
    });
  });

  group("Lumi's refusals keep their meaning", () {
    test('an answer comes back as an answer', () async {
      final r = await askLumi(
        _Server({'ok': true, 'answer': '  Start with the formula.  '}),
        'help',
      );
      expect(r.ok, isTrue);
      expect(r.text, 'Start with the formula.');
      expect(r.needActivation, isFalse);
    });

    test('a 403 offers activation rather than an anonymous refusal', () async {
      final r = await askLumi(
        _Server(
          const {},
          throwIt: ApiFailure(
            'Lumi opens with activation.',
            data: {
              'ok': false,
              'needActivation': true,
              'message': 'Lumi opens with activation.',
            },
          ),
        ),
        'help',
      );
      expect(r.ok, isFalse);
      expect(r.needActivation, isTrue);
      expect(r.text, 'Lumi opens with activation.');
    });

    test('a 429 carries the wait, so the screen can count it down', () async {
      final r = await askLumi(
        _Server(
          const {},
          throwIt: ApiFailure(
            'Easy, scholar.',
            data: {'ok': false, 'cool': 23, 'message': 'Easy, scholar.'},
          ),
        ),
        'help',
      );
      expect(r.coolSeconds, 23);
      expect(r.needActivation, isFalse);
    });

    test('an offline failure is still a sentence, not a crash', () async {
      final r = await askLumi(
        _Server(const {}, throwIt: ApiFailure('No connection.', offline: true)),
        'help',
      );
      expect(r.ok, isFalse);
      expect(r.text, 'No connection.');
      expect(r.coolSeconds, isNull);
    });
  });

  group('what the app actually sends Lumi', () {
    test('history is sent as role/text pairs', () async {
      final s = _Server({'ok': true, 'answer': 'ok'});
      await askLumi(
        s,
        'and then?',
        history: const [
          Turn('user', 'explain moles'),
          Turn('model', 'A mole is…'),
        ],
      );
      final body = s.lastBody as Map;
      expect(body['question'], 'and then?');
      expect((body['history'] as List).length, 2);
      expect((body['history'] as List).first, {
        'role': 'user',
        'text': 'explain moles',
      });
    });

    test('no question id means the key is absent, not null', () async {
      final s = _Server({'ok': true, 'answer': 'ok'});
      await askLumi(s, 'hello');
      expect((s.lastBody as Map).containsKey('questionId'), isFalse);
    });

    test('a question id travels — but never the stem or the answer', () async {
      final s = _Server({'ok': true, 'answer': 'ok'});
      await askLumi(s, 'hint please', questionId: 'q-42');
      final body = s.lastBody as Map;
      expect(body['questionId'], 'q-42');
      // The server looks the question up itself. Anything the app sent could
      // be forged, and the answer key must never leave the server.
      expect(body.containsKey('options'), isFalse);
      expect(body.containsKey('answer'), isFalse);
    });
  });
}
