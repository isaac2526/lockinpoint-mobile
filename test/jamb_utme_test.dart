import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/features/practice/practice_repository.dart';

/// ===========================================================================
/// THE UTME SITTING THE APP COULD NOT START
///
/// The server has supported four-subject jamb_mock sittings since the engine
/// was written; the app only ever sent ONE subject id, so the sitting JAMB
/// candidates actually face could not be started from a phone. These pin the
/// repaired contract: four ids travel, the mode is real, and the subjects
/// list the server returns is finally kept instead of dropped.
/// ===========================================================================

class _Server extends Fake implements Api {
  _Server(this.answer);
  final Map<String, dynamic> answer;
  Object? lastBody;

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    lastBody = body;
    return answer;
  }
}

Map<String, dynamic> _sittingAnswer() => {
  'ok': true,
  'attemptId': 'att-1',
  'mode': 'jamb_mock',
  'duration': 7200,
  'questions': [
    {
      'id': 'q1',
      'question': 'Choose the option nearest in meaning…',
      'options': ['a', 'b', 'c', 'd'],
      'letters': ['A', 'B', 'C', 'D'],
      'subject_id': 'eng',
    },
    {
      'id': 'q2',
      'question': 'A body of mass 2kg…',
      'options': ['a', 'b', 'c', 'd'],
      'letters': ['A', 'B', 'C', 'D'],
      'subject_id': 'phy',
    },
  ],
  'passages': <String, dynamic>{},
  'subjects': [
    {'id': 'eng', 'name': 'Use of English'},
    {'id': 'phy', 'name': 'Physics'},
  ],
};

void main() {
  const combo = [
    (id: 'eng', name: 'Use of English'),
    (id: 'phy', name: 'Physics'),
    (id: 'chm', name: 'Chemistry'),
    (id: 'bio', name: 'Biology'),
  ];

  test('a full mock sends FOUR subject ids and the jamb_mock mode', () async {
    final s = _Server(_sittingAnswer());
    await PracticeRepository(s).startUtme(combination: combo);
    final body = s.lastBody as Map;
    expect(body['mode'], 'jamb_mock');
    expect(body['examSlug'], 'jamb');
    expect(body['subjectIds'], ['eng', 'phy', 'chm', 'bio']);
  });

  test('a mini mock is jamb_mini, same four subjects', () async {
    final s = _Server(_sittingAnswer());
    await PracticeRepository(s).startUtme(combination: combo, mini: true);
    expect((s.lastBody as Map)['mode'], 'jamb_mini');
  });

  test('the subjects list is KEPT, so the session can draw its rail', () async {
    final s = _Server(_sittingAnswer());
    final sitting = await PracticeRepository(s).startUtme(combination: combo);
    expect(sitting.subjects.length, 2);
    expect(sitting.subjects.first.name, 'Use of English');
    // And each question knows its subject, or jumping is impossible.
    expect(sitting.questions.first.subjectId, 'eng');
    expect(sitting.questions.last.subjectId, 'phy');
  });

  test('the label names the whole combination, not one subject', () async {
    final s = _Server(_sittingAnswer());
    final sitting = await PracticeRepository(s).startUtme(combination: combo);
    expect(sitting.label, contains('Use of English'));
    expect(sitting.label, contains('Chemistry'));
  });

  test('an old-shape response with no subjects list still opens', () async {
    // A server one deploy behind must degrade to no rail, never to a crash.
    final ans = _sittingAnswer()..remove('subjects');
    final s = _Server(ans);
    final sitting = await PracticeRepository(s).startUtme(combination: combo);
    expect(sitting.subjects, isEmpty);
    expect(sitting.questions.length, 2);
  });
}
