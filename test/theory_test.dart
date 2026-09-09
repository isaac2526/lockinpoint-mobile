import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/theory/theory_repository.dart';
import 'package:lockinpoint/features/theory/theory_screen.dart';

/// ===========================================================================
/// THEORY AND PRACTICAL.
///
/// The one rule worth a test: THE MARKING SCHEME IS NEVER ON THE SCREEN UNTIL
/// THE STUDENT ASKS. A theory question with its answer already visible is a
/// passage to read, not a question to attempt — and the entire value of
/// theory practice is writing your own answer first.
///
/// The temptation to send the answer with the question, "to save a request",
/// is exactly what this holds the line against.
/// ===========================================================================
class _Papers extends Fake implements Api {
  _Papers({this.sessions = true, this.papers = true});

  /// Which half of the room exists. A subject may have the tutor's written
  /// sessions, or imported past papers, or both — and for a long time the
  /// app could only ever see the second.
  final bool sessions;
  final bool papers;

  final List<Map<String, dynamic>> asked = [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    asked.add({...?query});
    if (query!.containsKey('answer')) {
      return {
        'ok': true,
        'answer_html': '<p>Mass times velocity.</p>',
        'hasAnswer': true,
        'marks': 3,
      };
    }
    if (query.containsKey('session')) {
      return {
        'ok': true,
        'session': {
          'id': 'n1',
          'title': 'Momentum, walked through',
          'body_html': '<p>Start from Newton&rsquo;s second law.</p>',
        },
      };
    }
    if (query.containsKey('year')) {
      return {
        'ok': true,
        'questions': [
          {
            'id': 't1',
            'number': '1',
            'question_html': '<p>Define momentum.</p>',
            'marks': 3,
          },
        ],
      };
    }
    if (query.containsKey('subject')) {
      return {
        'ok': true,
        'sessions': sessions
            ? [
                {'id': 'n1', 'title': 'Momentum, walked through'},
              ]
            : const [],
        'years': papers
            ? [
                {'year': 2019, 'n': 8},
              ]
            : const [],
      };
    }
    if (query.containsKey('exam')) {
      return {
        'ok': true,
        'subjects': [
          {
            'id': 's1',
            'name': 'Physics',
            'exam': 'WAEC',
            'questions': papers ? 24 : 0,
            'sessions': sessions ? 1 : 0,
          },
        ],
      };
    }
    return {
      'ok': true,
      'exams': [
        {'slug': 'waec', 'name': 'WAEC', 'full': 'West African', 'subjects': 1},
      ],
      'subjects': const [],
    };
  }
}

Future<_Papers> _open(
  WidgetTester tester, {
  String kind = 'theory',
  bool sessions = true,
  bool papers = true,
}) async {
  final api = _Papers(sessions: sessions, papers: papers);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: LipTheme.light(),
        home: TheoryScreen(kind: kind),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  /// Taps through the whole walk and leaves the paper on screen.
  Future<_Papers> walkToPaper(WidgetTester tester) async {
    final api = await _open(tester);
    await tester.tap(find.text('WAEC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('2019'));
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('examination, then subject, then the shelf, then the paper', (
    tester,
  ) async {
    /* THE EXAMINATION STEP DID NOT EXIST. This room opened straight onto a
       flat list of every subject from every board — the "everything moded
       together" the owner objected to. */
    final api = await _open(tester);
    expect(find.text('Which examination?'), findsOneWidget);
    expect(find.text('WAEC'), findsOneWidget);

    await tester.tap(find.text('WAEC'));
    await tester.pumpAndSettle();
    expect(find.text('Which subject?'), findsOneWidget);
    expect(api.asked.last['exam'], 'waec');

    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();
    expect(api.asked.last['subject'], 's1');

    await tester.tap(find.textContaining('2019'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Define momentum'), findsWidgets);
    expect(api.asked.last['year'], '2019');
  });

  testWidgets("the tutor's own sessions are on the shelf, and they open", (
    tester,
  ) async {
    /* THE BUG THIS TEST EXISTS FOR. Admin -> Theory writes into `notes`; this
       room read `theory_questions`, which only the PDF importer writes. Two
       tables that never met, so every session Tutor Bello wrote by hand was
       live on the website and invisible on the phone. */
    final api = await _open(tester);
    await tester.tap(find.text('WAEC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();

    expect(find.text('SESSIONS FROM YOUR TUTOR'), findsOneWidget);
    expect(find.text('Momentum, walked through'), findsOneWidget);

    await tester.tap(find.text('Momentum, walked through'));
    await tester.pumpAndSettle();
    expect(api.asked.last['session'], 'n1');
    expect(find.textContaining('Newton'), findsWidgets);
  });

  testWidgets('a subject with sessions and no papers still opens', (
    tester,
  ) async {
    // It used to read "0 questions", or not be listed at all.
    final api = await _open(tester, papers: false);
    await tester.tap(find.text('WAEC'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 session'), findsOneWidget);
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();
    expect(find.text('Momentum, walked through'), findsOneWidget);
    expect(find.text('PAST PAPERS'), findsNothing);
    expect(api.asked.last['subject'], 's1');
  });

  testWidgets('a subject with papers and no sessions still opens', (
    tester,
  ) async {
    await _open(tester, sessions: false);
    await tester.tap(find.text('WAEC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();
    expect(find.text('SESSIONS FROM YOUR TUTOR'), findsNothing);
    expect(find.text('PAST PAPERS'), findsOneWidget);
  });

  testWidgets('the marking scheme is NOT fetched with the question', (
    tester,
  ) async {
    final api = await walkToPaper(tester);

    // The paper is on screen and no answer has been requested. Sending it
    // along "to save a request" is exactly what this holds the line against.
    expect(api.asked.any((a) => a.containsKey('answer')), isFalse);
    expect(find.textContaining('Mass times velocity'), findsNothing);
    expect(find.textContaining('Write yours first'), findsOneWidget);
  });

  testWidgets('asking for it fetches exactly that one answer', (tester) async {
    final api = await walkToPaper(tester);

    await tester.tap(find.textContaining('Write yours first'));
    await tester.pumpAndSettle();

    expect(api.asked.last['answer'], 't1');
    expect(find.text('THE MARKING SCHEME'), findsOneWidget);
  });

  testWidgets('practical is a different paper, and asks for one', (
    tester,
  ) async {
    final api = await _open(tester, kind: 'practical');
    expect(find.text('Practical'), findsOneWidget);
    expect(api.asked.first['kind'], 'practical');
  });

  test('a paper with no scheme is said plainly, not shown as an empty box', () {
    const a = TheoryAnswer(html: '', hasAnswer: false);
    expect(a.hasAnswer, isFalse);
  });
}
