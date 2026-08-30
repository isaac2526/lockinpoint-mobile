import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/practice/practice_repository.dart';
import 'package:lockinpoint/features/practice/practice_session_screen.dart';
import 'package:lockinpoint/features/practice/question_html.dart';

/// ===========================================================================
/// THE PRACTICE ROOM, PROVEN
///
/// The maths rewriter is pinned down as pure functions, and the sitting is
/// exercised the way a student uses it: open, answer, get marked instantly,
/// read the why, move on, submit.
/// ===========================================================================

class _FakeRepo extends Fake implements PracticeRepository {
  int saves = 0;
  Map<String, String>? submittedAnswers;

  @override
  Future<void> saveProgress({
    required String attemptId,
    required Map<String, String> answers,
    required Map<String, bool> checked,
    required int idx,
  }) async {
    saves++;
  }

  @override
  Future<SubmitResult> submit({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    submittedAnswers = answers;
    return SubmitResult(
      correct: 1,
      total: 2,
      overall: 50,
      perSubject: const [(name: 'Mathematics', correct: 1, total: 2)],
    );
  }
}

Sitting _sitting() => const Sitting(
  attemptId: 'attempt-1',
  mode: 'practice',
  label: 'JAMB · Mathematics · Random mix',
  questions: [
    ServedQuestion(
      id: 'q1',
      question: '<p>What is 2 + 2?</p>',
      options: ['3', '4', '5', '22'],
      letters: ['A', 'B', 'C', 'D'],
      answer: 'B',
      explanation: '<p>Two and two make four.</p>',
    ),
    ServedQuestion(
      id: 'q2',
      question: '<p>What is 3 times 3?</p>',
      options: ['6', '9'],
      letters: ['A', 'B'],
      answer: 'B',
      explanation: '<p>Three threes are nine.</p>',
    ),
  ],
  passages: {},
);

Future<_FakeRepo> _pumpSession(WidgetTester tester, {Sitting? sitting}) async {
  final repo = _FakeRepo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [practiceRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: LipTheme.light(),
        home: PracticeSessionScreen(sitting: sitting ?? _sitting()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('the maths rewriter honours the site delimiters', () {
    test('inline maths becomes an inline tex element', () {
      expect(
        LipHtml.prepare('Solve \\(x^2\\) now'),
        'Solve <tex>x^2</tex> now',
      );
    });

    test('both display forms become display tex elements', () {
      expect(LipHtml.prepare('\\[a+b\\]'), '<tex d="1">a+b</tex>');
      expect(LipHtml.prepare(r'$$\frac{1}{2}$$'), r'<tex d="1">\frac{1}{2}</tex>');
    });

    test('angle brackets inside a formula survive the HTML parser', () {
      expect(LipHtml.prepare('\\(x < y & y > z\\)'),
          '<tex>x &lt; y &amp; y &gt; z</tex>');
    });

    test('text without maths passes through untouched', () {
      const plain = '<p>The <b>capital</b> of Ghana</p>';
      expect(LipHtml.prepare(plain), plain);
    });
  });

  group('a practice sitting behaves like the untimed room it is', () {
    testWidgets('shows the question and its options', (tester) async {
      await _pumpSession(tester);
      expect(find.textContaining('What is 2 + 2?'), findsOneWidget);
      expect(find.text('Question 1 of 2 · 0 answered'), findsOneWidget);
    });

    testWidgets('an answer is marked instantly and explains itself', (
      tester,
    ) async {
      await _pumpSession(tester);
      // The wrong pick.
      await tester.tap(find.textContaining('3').first);
      await tester.pump();
      expect(find.textContaining('Two and two make four'), findsOneWidget);
      // Marked answers are final: tapping again changes nothing.
      await tester.tap(find.textContaining('22').first);
      await tester.pump();
      expect(find.text('Question 1 of 2 · 1 answered'), findsOneWidget);
    });

    testWidgets('next moves on, previous comes back', (tester) async {
      await _pumpSession(tester);
      await tester.tap(find.text('Next question'));
      await tester.pumpAndSettle();
      expect(find.textContaining('What is 3 times 3?'), findsOneWidget);
      expect(find.text('Finish and submit'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous question'));
      await tester.pumpAndSettle();
      expect(find.textContaining('What is 2 + 2?'), findsOneWidget);
    });

    testWidgets('submitting with gaps asks first, then grades', (tester) async {
      final repo = await _pumpSession(tester);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no answer yet'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();
      // The graded end.
      expect(repo.submittedAnswers, isNotNull);
      expect(find.text('50%'), findsOneWidget);
      expect(find.textContaining('1 of 2 correct'), findsOneWidget);
      expect(find.text('Back to the dashboard'), findsOneWidget);
    });

    testWidgets('leaving warns and keeps the sitting alive', (tester) async {
      await _pumpSession(tester);
      await tester.tap(find.byTooltip('Leave'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your progress is saved'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.textContaining('What is 2 + 2?'), findsOneWidget);
    });

    testWidgets('a resumed sitting without the key defers marking', (
      tester,
    ) async {
      const resumed = Sitting(
        attemptId: 'attempt-2',
        mode: 'practice',
        label: 'Resumed',
        questions: [
          ServedQuestion(
            id: 'q1',
            question: '<p>Pick one</p>',
            options: ['Yes', 'No'],
            letters: ['A', 'B'],
            // No answer, no explanation: exactly what resume serves.
          ),
        ],
        passages: {},
      );
      await _pumpSession(tester, sitting: resumed);
      await tester.tap(find.textContaining('Yes').first);
      await tester.pump();
      expect(
        find.textContaining('Marking for this resumed sitting'),
        findsOneWidget,
      );
    });
  });
}
