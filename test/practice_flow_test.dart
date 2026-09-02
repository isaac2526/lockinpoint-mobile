import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/practice/practice_flow_screen.dart';
import 'package:lockinpoint/features/practice/practice_repository.dart';

/// The chooser, walked as a student walks it: exam, subject, then the way in.
class _FakeRepo extends Fake implements PracticeRepository {
  @override
  Future<List<ExamOption>> exams() async => const [
    ExamOption(
      id: 'e-jamb',
      slug: 'jamb',
      shortName: 'JAMB',
      fullName: 'Joint Admissions and Matriculation Board',
    ),
    ExamOption(
      id: 'e-waec',
      slug: 'waec',
      shortName: 'WAEC',
      fullName: 'West African Examinations Council',
    ),
  ];

  @override
  Future<List<SubjectOption>> subjects(String examSlug) async => const [
    SubjectOption(id: 'sub-math', name: 'Mathematics', compulsory: false),
    SubjectOption(id: 'sub-eng', name: 'Use of English', compulsory: true),
  ];

  @override
  Future<ChooserData> chooser(String subjectId) async => const ChooserData(
    subjectName: 'Mathematics',
    examSlug: 'jamb',
    examShort: 'JAMB',
    years: [YearCount(2021, 40), YearCount(2020, 38)],
    topics: [TopicCount('t-alg', 'Algebra', 25, 0)],
    past: 78,
    tutorial: 0,
  );
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [practiceRepositoryProvider.overrideWithValue(_FakeRepo())],
      child: MaterialApp(
        theme: LipTheme.light(),
        home: const PracticeFlowScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every exam is a door — no exam is assumed', (tester) async {
    await _pump(tester);
    expect(find.text('Choose your exam'), findsOneWidget);
    expect(find.text('JAMB'), findsOneWidget);
    expect(find.text('WAEC'), findsOneWidget);
  });

  testWidgets('JAMB forks FIRST: one subject, or the full UTME mock', (
    tester,
  ) async {
    /* The old flow dropped a JAMB candidate straight into single-subject
       practice - the wrong flow for the one exam this product is named for.
       The fork is now the contract: tapping JAMB must offer both roads. */
    await _pump(tester);
    await tester.tap(find.text('JAMB'));
    await tester.pumpAndSettle();
    expect(find.text('Practise one subject'), findsOneWidget);
    expect(find.text('Full UTME mock - 4 subjects'), findsOneWidget);
  });

  testWidgets('the combination locks English and demands exactly three', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('JAMB'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full UTME mock - 4 subjects'));
    await tester.pumpAndSettle();

    // English is not a choice - it is the constant of every UTME paper.
    expect(find.text('Use of English - always in'), findsOneWidget);
    // With nothing picked, the start button says what is missing instead of
    // sitting there enabled and doing nothing when tapped.
    expect(find.textContaining('Pick 3 more'), findsOneWidget);

    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pick 2 more'), findsOneWidget);
  });

  testWidgets('exam leads to subjects, subject leads to the ways in', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('JAMB'));
    await tester.pumpAndSettle();
    // Through the fork's single-subject road.
    await tester.tap(find.text('Practise one subject'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Use of English'), findsOneWidget);

    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('Random mix'), findsOneWidget);
    expect(find.text('By year'), findsOneWidget);
    expect(find.text('By topic'), findsOneWidget);
    // No tutorial questions in this subject, so that door does not appear.
    expect(find.text('Tutorial questions'), findsNothing);
  });

  testWidgets('choosing by year demands a year before starting', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('JAMB'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practise one subject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('By year'));
    await tester.pumpAndSettle();

    // The step is a lazy ListView, so the action at its foot has to be
    // scrolled into existence before it can be inspected at all.
    final startButton = find.widgetWithText(FilledButton, 'Start practising');
    await tester.dragUntilVisible(
      startButton,
      find.byType(ListView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(startButton).onPressed, isNull);

    await tester.dragUntilVisible(
      find.text('2021'),
      find.byType(ListView),
      const Offset(0, 220),
    );
    await tester.tap(find.text('2021'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      startButton,
      find.byType(ListView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(startButton).onPressed, isNotNull);
    // The session label carries the whole choice.
    expect(find.text('JAMB · Mathematics · 2021'), findsOneWidget);
  });

  testWidgets('going back re-walks the steps without losing the screen', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('JAMB'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your exam'), findsOneWidget);
  });
}
