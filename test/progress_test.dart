import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/design/tokens.dart';
import 'package:lockinpoint/features/progress/analysis_screen.dart';
import 'package:lockinpoint/features/progress/progress_repository.dart';
import 'package:lockinpoint/features/progress/results_screen.dart';

/// ===========================================================================
/// RESULTS AND ANALYSIS
///
/// These tests pin down the specific flaws found in the reference app's
/// versions, so we cannot drift back into them:
///
///   · a score's colour must reflect its band — 64% and 1.25% looked alike
///   · duration and date must not share a line — theirs collided mid-string
///   · subjects are sorted weakest first, because that is the actionable end
///   · analysis refuses to draw a trend from one paper
///   · the plain-English insight appears only when the server supplies one
/// ===========================================================================
class _FakeProgress extends ProgressController {
  _FakeProgress(this._p);
  final Progress _p;
  @override
  Future<Progress> build() async => _p;
}

Attempt _attempt({
  required String id,
  required int correct,
  required int total,
  String mode = 'practice',
  int seconds = 5650,
  List<SubjectScore> subjects = const [],
  int daysAgo = 0,
}) => Attempt(
  id: id,
  mode: mode,
  takenAt: DateTime(2026, 2, 28).subtract(Duration(days: daysAgo)),
  durationSeconds: seconds,
  correct: correct,
  total: total,
  percent: total == 0 ? 0 : correct / total * 100,
  overall: null,
  isJamb: false,
  perSubject: subjects,
);

SubjectScore _sub(String name, int c, int t) =>
    SubjectScore(name: name, correct: c, total: t, percent: c / t * 100);

Progress _progress({
  List<Attempt> attempts = const [],
  List<SubjectScore> subjects = const [],
  String? insight,
}) => Progress(
  sittings: attempts.length,
  questions: attempts.fold(0, (n, a) => n + a.total),
  correct: attempts.fold(0, (n, a) => n + a.correct),
  accuracy: 64,
  minutes: 94,
  attempts: attempts,
  subjects: subjects,
  insight: insight,
);

Future<void> _pump(WidgetTester tester, Widget screen, Progress p) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [progressProvider.overrideWith(() => _FakeProgress(p))],
      child: MaterialApp(
        theme: LipTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  group('result history', () {
    testWidgets('a paper shows its score, mode, date and duration apart', (
      tester,
    ) async {
      await _pump(
        tester,
        const ResultsScreen(),
        _progress(attempts: [_attempt(id: 'a', correct: 256, total: 400)]),
      );

      expect(find.text('64%'), findsWidgets);
      expect(find.text('256/400'), findsOneWidget);
      expect(find.text('Practice'), findsOneWidget);
      /* In the reference these two ran into each other as
         "10 se2026/02/28". They are separate Text widgets here. */
      expect(find.text('28 Feb 2026'), findsOneWidget);
      expect(find.text('1 hr 34 min'), findsOneWidget);
    });

    testWidgets('a duration under an hour is said in minutes', (tester) async {
      await _pump(
        tester,
        const ResultsScreen(),
        _progress(
          attempts: [_attempt(id: 'a', correct: 5, total: 400, seconds: 622)],
        ),
      );
      expect(find.text('10 min'), findsOneWidget);
    });

    test('scores of different bands get different colours', () {
      final c = LipColors.light;
      // The reference rendered 64% and 1.25% identically. These must differ.
      expect(bandOf(c, 64), isNot(equals(bandOf(c, 1.25))));
      expect(bandOf(c, 85), c.hues.green);
      expect(bandOf(c, 55), c.hues.amber);
      expect(bandOf(c, 20), c.hues.rose);
    });

    testWidgets('per-subject marks are shown weakest first', (tester) async {
      await _pump(
        tester,
        const ResultsScreen(),
        _progress(
          attempts: [
            _attempt(
              id: 'a',
              correct: 256,
              total: 400,
              subjects: [
                _sub('Biology', 90, 100),
                _sub('Physics', 45, 100),
                _sub('English', 63, 100),
              ],
            ),
          ],
        ),
      );

      final ys = [
        'Physics',
        'English',
        'Biology',
      ].map((n) => tester.getTopLeft(find.text(n)).dy).toList();
      expect(
        ys[0] < ys[1] && ys[1] < ys[2],
        isTrue,
        reason: 'the subject costing marks belongs at the top',
      );
    });

    testWidgets('no papers yet says so, and says what to do', (tester) async {
      await _pump(tester, const ResultsScreen(), _progress());
      expect(find.text('No papers yet'), findsOneWidget);
      expect(find.textContaining('subject by subject'), findsOneWidget);
    });
  });

  group('performance analysis', () {
    testWidgets('refuses to plot a trend from a single paper', (tester) async {
      await _pump(
        tester,
        const AnalysisScreen(),
        _progress(attempts: [_attempt(id: 'a', correct: 50, total: 100)]),
      );
      expect(find.text('Not enough papers yet'), findsOneWidget);
    });

    testWidgets('plots once there are two, on a zero-based scale', (
      tester,
    ) async {
      await _pump(
        tester,
        const AnalysisScreen(),
        _progress(
          attempts: [
            _attempt(id: 'a', correct: 50, total: 100),
            _attempt(id: 'b', correct: 70, total: 100, daysAgo: 3),
          ],
          subjects: [_sub('Chemistry', 40, 100), _sub('Biology', 80, 100)],
        ),
      );
      // LipLabel renders its section headings uppercase.
      expect(find.text('SCORE OVER TIME'), findsOneWidget);
      // The axis promise is stated to the student, not just implemented.
      expect(find.textContaining('cannot go below zero'), findsOneWidget);
    });

    testWidgets('the legend filters the data instead of covering it', (
      tester,
    ) async {
      await _pump(
        tester,
        const AnalysisScreen(),
        _progress(
          attempts: [
            _attempt(id: 'a', correct: 50, total: 100),
            _attempt(id: 'b', correct: 70, total: 100, daysAgo: 3),
          ],
          subjects: [_sub('Chemistry', 40, 100), _sub('Biology', 80, 100)],
        ),
      );

      expect(find.widgetWithText(FilterChip, 'Chemistry'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Chemistry'));
      await tester.pumpAndSettle();
      // Only the chip remains; the bar is gone from the plot.
      expect(find.text('Chemistry'), findsOneWidget);
    });

    testWidgets('an insight is shown when the server supplies one', (
      tester,
    ) async {
      await _pump(
        tester,
        const AnalysisScreen(),
        _progress(
          attempts: [
            _attempt(id: 'a', correct: 50, total: 100),
            _attempt(id: 'b', correct: 70, total: 100, daysAgo: 3),
          ],
          subjects: [_sub('Chemistry', 40, 100)],
          insight:
              'Chemistry has been your weakest subject in your last 4 papers.',
        ),
      );
      expect(
        find.textContaining('weakest subject in your last 4'),
        findsOneWidget,
      );
    });

    testWidgets('and NOTHING is invented when it does not', (tester) async {
      await _pump(
        tester,
        const AnalysisScreen(),
        _progress(
          attempts: [
            _attempt(id: 'a', correct: 50, total: 100),
            _attempt(id: 'b', correct: 70, total: 100, daysAgo: 3),
          ],
          subjects: [_sub('Chemistry', 40, 100)],
        ),
      );
      expect(find.byIcon(Icons.lightbulb_rounded), findsNothing);
    });
  });
}
