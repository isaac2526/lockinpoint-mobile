import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/practice/practice_repository.dart';
import 'package:lockinpoint/features/practice/practice_session_screen.dart';
import 'package:lockinpoint/design/rich_text.dart';

/// ===========================================================================
/// THE PRACTICE ROOM, PROVEN
///
/// The maths rewriter is pinned down as pure functions, and the sitting is
/// exercised the way a student uses it: open, answer, get marked instantly,
/// read the why, move on, submit.
/// ===========================================================================

class _FakeRepo extends Fake implements PracticeRepository {
  int saves = 0;
  Map<String, String>? savedAnswers;
  Map<String, String>? submittedAnswers;

  @override
  Future<void> saveProgress({
    required String attemptId,
    required Map<String, String> answers,
    required Map<String, bool> checked,
    required int idx,
    Map<String, bool> flags = const {},
  }) async {
    saves++;
    savedAnswers = {...answers};
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
      corrections: const [
        Correction(
          id: 'q1',
          question: '<p>What is 2 + 2?</p>',
          options: ['3', '4', '5', '22'],
          chosen: 'B',
          right: 'B',
          isRight: true,
          explanation: '<p>Two and two make four.</p>',
        ),
        Correction(
          id: 'q2',
          question: '<p>What is 3 times 3?</p>',
          options: ['6', '9'],
          chosen: 'A',
          right: 'B',
          isRight: false,
          explanation: '<p>Three threes are nine.</p>',
        ),
      ],
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

/// A clock the test owns, so a two minute exam can be lived through in a few
/// milliseconds. Production reads the wall clock; see the widget for why.
class _FakeClock {
  DateTime now = DateTime.utc(2026, 1, 1, 9);
  DateTime call() => now;
}

Future<_FakeRepo> _pumpSession(
  WidgetTester tester, {
  Sitting? sitting,
  _FakeClock? clock,
}) async {
  final repo = _FakeRepo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [practiceRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: LipTheme.light(),
        home: PracticeSessionScreen(
          sitting: sitting ?? _sitting(),
          clock: (clock ?? _FakeClock()).call,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Moves the test's clock and the widget's timers together, one second at a
/// time, the way a real second passes for both.
Future<void> _tickSecond(WidgetTester tester, _FakeClock clock) async {
  clock.now = clock.now.add(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
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
      expect(
        LipHtml.prepare(r'$$\frac{1}{2}$$'),
        r'<tex d="1">\frac{1}{2}</tex>',
      );
    });

    test('angle brackets inside a formula survive the HTML parser', () {
      expect(
        LipHtml.prepare('\\(x < y & y > z\\)'),
        '<tex>x &lt; y &amp; y &gt; z</tex>',
      );
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

    testWidgets('the result leads into the review, missed questions first', (
      tester,
    ) async {
      await _pumpSession(tester);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('See what you missed'));
      await tester.pumpAndSettle();

      // Opens filtered to the one that went wrong, not the whole paper.
      expect(find.text('Review'), findsOneWidget);
      expect(find.textContaining('What is 3 times 3?'), findsOneWidget);
      expect(find.textContaining('What is 2 + 2?'), findsNothing);
      expect(find.textContaining('Three threes are nine'), findsOneWidget);

      // And the whole paper is one tap away.
      await tester.tap(find.textContaining('All 2'));
      await tester.pumpAndSettle();
      expect(find.textContaining('What is 2 + 2?'), findsOneWidget);
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Wrong'), findsOneWidget);
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

    testWidgets('an answer given seconds before leaving is still saved', (
      tester,
    ) async {
      final repo = await _pumpSession(tester);
      await tester.tap(find.textContaining('4').first);
      await tester.pump();
      // Straight out, well inside the two second autosave debounce.
      await tester.tap(find.byTooltip('Leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      // The save was flushed on the way out, not cancelled with the timer.
      expect(repo.saves, greaterThan(0));
      expect(repo.savedAnswers?['q1'], 'B');
    });

    testWidgets('a sitting with no questions lets the student out', (
      tester,
    ) async {
      const empty = Sitting(
        attemptId: 'gone',
        mode: 'practice',
        label: 'Empty',
        questions: [],
        passages: {},
      );
      await _pumpSession(tester, sitting: empty);
      expect(find.text('This sitting has no questions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a question can be flagged and the grid shows it', (
      tester,
    ) async {
      await _pumpSession(tester);
      await tester.tap(find.text('Flag'));
      await tester.pump();
      expect(find.text('Flagged'), findsOneWidget);

      await tester.tap(find.byTooltip('All questions'));
      await tester.pumpAndSettle();
      expect(find.text('All questions'.toUpperCase()), findsOneWidget);
      // Jumping from the grid lands on that question.
      await tester.tap(find.text('2').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('What is 3 times 3?'), findsOneWidget);
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

  group('a CBT is the timed room, with the hall\'s rules', () {
    Sitting timed({int seconds = 120}) => Sitting(
      attemptId: 'attempt-cbt',
      mode: 'cbt',
      label: 'JAMB · Mathematics · CBT',
      duration: seconds,
      questions: _sitting().questions,
      passages: const {},
    );

    testWidgets('the clock is shown and counts down', (tester) async {
      final clock = _FakeClock();
      await _pumpSession(tester, sitting: timed(), clock: clock);
      expect(find.text('02:00'), findsOneWidget);
      await _tickSecond(tester, clock);
      expect(find.text('01:59'), findsOneWidget);
      await _tickSecond(tester, clock);
      expect(find.text('01:58'), findsOneWidget);
    });

    testWidgets('no answer is marked before submit, even with a key', (
      tester,
    ) async {
      // The fixture carries answers, exactly as a practice payload would.
      // A timed sitting must ignore them: marking is the server's at submit.
      await _pumpSession(tester, sitting: timed());
      await tester.tap(find.textContaining('4').first);
      await tester.pump();
      expect(find.textContaining('Two and two make four'), findsNothing);
      expect(find.text('Question 1 of 2 · 1 answered'), findsOneWidget);
    });

    testWidgets('when time runs out the paper goes in by itself', (
      tester,
    ) async {
      final clock = _FakeClock();
      final repo = await _pumpSession(
        tester,
        sitting: timed(seconds: 2),
        clock: clock,
      );
      await _tickSecond(tester, clock);
      expect(find.text('00:01'), findsOneWidget);
      await _tickSecond(tester, clock);
      await tester.pumpAndSettle();
      // No dialog asked, no tap needed: the result is simply there.
      expect(repo.submittedAnswers, isNotNull);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('leaving a timed paper offers the exit that keeps the score', (
      tester,
    ) async {
      await _pumpSession(tester, sitting: timed());
      await tester.tap(find.byTooltip('Leave'));
      await tester.pumpAndSettle();
      expect(find.text('Leave the exam?'), findsOneWidget);
      expect(find.textContaining('The clock keeps running'), findsOneWidget);
      expect(find.text('Submit now'), findsOneWidget);
      expect(find.text('Leave anyway'), findsOneWidget);
    });
  });
}
