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
        'years': [
          {'year': 2019, 'n': 8},
        ],
      };
    }
    return {
      'ok': true,
      'subjects': [
        {'id': 's1', 'name': 'Physics', 'exam': 'WAEC', 'questions': 24},
      ],
    };
  }
}

Future<_Papers> _open(WidgetTester tester, {String kind = 'theory'}) async {
  final api = _Papers();
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
  testWidgets('subject, then year, then the paper', (tester) async {
    final api = await _open(tester);
    expect(find.text('Which subject?'), findsOneWidget);
    expect(find.text('Physics'), findsOneWidget);

    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();
    expect(find.text('Which year?'), findsOneWidget);
    expect(api.asked.last['subject'], 's1');

    await tester.tap(find.textContaining('2019'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Define momentum'), findsWidgets);
    expect(api.asked.last['year'], '2019');
  });

  testWidgets('the marking scheme is NOT fetched with the question', (
    tester,
  ) async {
    final api = await _open(tester);
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('2019'));
    await tester.pumpAndSettle();

    // The paper is on screen and no answer has been requested. Sending it
    // along "to save a request" is exactly what this holds the line against.
    expect(api.asked.any((a) => a.containsKey('answer')), isFalse);
    expect(find.textContaining('Mass times velocity'), findsNothing);
    expect(find.textContaining('Write yours first'), findsOneWidget);
  });

  testWidgets('asking for it fetches exactly that one answer', (tester) async {
    final api = await _open(tester);
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('2019'));
    await tester.pumpAndSettle();

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
