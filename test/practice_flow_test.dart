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

  /* ONLY JAMB HAS A COMPULSORY SUBJECT, WHICH IS WHY ONLY JAMB FORKS.
     The fake used to hand every examination a compulsory "Use of English",
     which is not true of WAEC and would have made the fork appear there. The
     fork is driven by that flag rather than by the slug, so the fake has to
     be honest about it or the tests below prove nothing. */
  @override
  Future<List<SubjectOption>> subjects(String examSlug) async =>
      examSlug == 'jamb'
      ? const [
          SubjectOption(
            id: 'sub-eng',
            name: 'Use of English',
            compulsory: true,
          ),
          SubjectOption(id: 'sub-math', name: 'Mathematics', compulsory: false),
          SubjectOption(id: 'sub-phy', name: 'Physics', compulsory: false),
          SubjectOption(id: 'sub-chm', name: 'Chemistry', compulsory: false),
          SubjectOption(id: 'sub-bio', name: 'Biology', compulsory: false),
        ]
      : const [
          SubjectOption(id: 'sub-math', name: 'Mathematics', compulsory: false),
          SubjectOption(
            id: 'sub-eng-w',
            name: 'English Language',
            compulsory: false,
          ),
        ];

  /// What the last startJamb() was asked for. The whole point of the fork is
  /// the request it produces, so the tests read it rather than guessing.
  Map<String, Object?>? lastJamb;

  @override
  Future<Sitting> startJamb({
    required List<String> subjectIds,
    required String label,
    int? perSubject,
  }) async {
    lastJamb = {
      'subjectIds': subjectIds,
      'label': label,
      'perSubject': perSubject,
    };
    return const Sitting(
      attemptId: 'a-1',
      label: 'JAMB Full Mock',
      mode: 'jamb_mock',
      questions: [],
      passages: {},
      // The clock is the SERVER's: two hours for a full mock, computed from
      // the attempt's creation time so closing the app buys no extra minutes.
      duration: 7200,
    );
  }

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

Future<void> _pump(WidgetTester tester, {_FakeRepo? repo}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        practiceRepositoryProvider.overrideWithValue(repo ?? _FakeRepo()),
      ],
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

  testWidgets('exam leads to subjects, subject leads to the ways in', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('JAMB'));
    await tester.pumpAndSettle();
    // JAMB forks first; one subject is the left-hand road.
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

  /* =======================================================================
     THE JAMB PAPER · the flagship the app promised and could not deliver.

     The welcome screen says "a complete JAMB mock of 180 questions scored
     over 400" and prints 180 as a headline figure. /api/attempts has accepted
     `jamb_mock` and `jamb_mini` since it was written — 60 questions for the
     compulsory subject, 40 for each of the other three, a two hour clock,
     scored over 400 — and no screen in this app could start one. Choosing
     JAMB walked straight into a single subject.

     These hold the fork, the combination rules, and the REQUEST, because the
     request is the only thing the server ever sees.
     ======================================================================= */

  /// Walk to the combination screen with a road chosen.
  Future<void> toCombination(WidgetTester tester, String road) async {
    await tester.tap(find.text('JAMB'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(road));
    await tester.pumpAndSettle();
  }

  testWidgets('JAMB FORKS: the paper is offered beside single subjects', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('JAMB'));
    await tester.pumpAndSettle();

    expect(find.text('Practise one subject'), findsOneWidget);
    expect(find.text('Full UTME mock - 4 subjects'), findsOneWidget);
    expect(find.text('Mini mock'), findsOneWidget);
    // The fork is a step of its own and must not pretend to be the subject
    // list — a student who sees "Mathematics" here has not been asked.
    expect(find.text('Mathematics'), findsNothing);
    // Entrance staggers these three cards in; let its timers run out before
    // the tree is torn down.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('an exam with no compulsory subject does NOT fork', (
    tester,
  ) async {
    /* The fork is driven by the compulsory flag, not by the slug. WAEC has no
       compulsory subject, so asking a WAEC student to choose between "one
       subject" and a four-subject UTME paper would be nonsense. */
    await _pump(tester);
    await tester.tap(find.text('WAEC'));
    await tester.pumpAndSettle();

    expect(find.text('Full UTME mock - 4 subjects'), findsNothing);
    expect(find.text('Practise one subject'), findsNothing);
    expect(find.text('Mathematics'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the combination locks English and demands exactly three more', (
    tester,
  ) async {
    await _pump(tester);
    await toCombination(tester, 'Full UTME mock - 4 subjects');

    expect(find.text('Use of English - always in'), findsOneWidget);
    expect(find.textContaining('PICK 3 MORE'), findsOneWidget);
    expect(find.text('Step 2 of 2'), findsOneWidget);

    final start = find.widgetWithText(FilledButton, 'Pick three subjects');
    expect(
      tester.widget<FilledButton>(start).onPressed,
      isNull,
      reason: 'a paper cannot start before three subjects are chosen',
    );

    for (final s in const ['Physics', 'Chemistry', 'Biology']) {
      await tester.tap(find.text(s));
      await tester.pumpAndSettle();
    }
    expect(find.text('3 OF 3 CHOSEN'), findsOneWidget);
    expect(
      find.textContaining('Start: Use of English + 3'),
      findsOneWidget,
      reason: 'the button must name what is about to be sat',
    );
  });

  testWidgets('a FOURTH pick is refused rather than silently swapped', (
    tester,
  ) async {
    /* Quietly dropping the first subject to make room for a fourth loses a
       student the subject they meant to sit and tells them nothing. */
    await _pump(tester);
    await toCombination(tester, 'Full UTME mock - 4 subjects');
    for (final s in const ['Physics', 'Chemistry', 'Biology']) {
      await tester.tap(find.text(s));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();

    expect(find.text('3 OF 3 CHOSEN'), findsOneWidget);
    // Physics is still in: the fourth tap did nothing at all.
    expect(find.textContaining('Physics'), findsWidgets);
  });

  testWidgets('a pick can be UNPICKED and swapped deliberately', (
    tester,
  ) async {
    await _pump(tester);
    await toCombination(tester, 'Full UTME mock - 4 subjects');
    for (final s in const ['Physics', 'Chemistry', 'Biology']) {
      await tester.tap(find.text(s));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PICK 3 MORE'), findsOneWidget);

    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();
    expect(find.text('3 OF 3 CHOSEN'), findsOneWidget);
  });

  testWidgets('the FULL mock asks the server for jamb_mock, English first', (
    tester,
  ) async {
    final repo = _FakeRepo();
    await _pump(tester, repo: repo);
    await toCombination(tester, 'Full UTME mock - 4 subjects');
    for (final s in const ['Physics', 'Chemistry', 'Biology']) {
      await tester.tap(find.text(s));
      await tester.pumpAndSettle();
    }
    await tester.tap(
      find.widgetWithText(FilledButton, 'Start: Use of English + 3 subjects'),
    );
    await tester.pump();

    expect(repo.lastJamb, isNotNull, reason: 'the paper never started');
    expect(repo.lastJamb!['subjectIds'], const [
      'sub-eng',
      'sub-phy',
      'sub-chm',
      'sub-bio',
    ], reason: 'four subjects, the compulsory one first');
    // No per-subject count: the SERVER sets 60 + 40 + 40 + 40. A phone that
    // sent its own would drift from the hall the first time JAMB changed one.
    expect(repo.lastJamb!['perSubject'], isNull);
    expect(repo.lastJamb!['label'], contains('Full Mock'));
  });

  testWidgets('the MINI mock carries the per-subject count the student chose', (
    tester,
  ) async {
    final repo = _FakeRepo();
    await _pump(tester, repo: repo);
    await toCombination(tester, 'Mini mock');
    for (final s in const ['Physics', 'Chemistry', 'Biology']) {
      await tester.tap(find.text(s));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('40'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Start: Use of English + 3 subjects'),
    );
    await tester.pump();

    expect(repo.lastJamb!['perSubject'], 40);
    expect(repo.lastJamb!['label'], contains('Mini Mock'));
  });

  testWidgets('Back inside the fork returns to the fork, not the exam list', (
    tester,
  ) async {
    /* A student who chose JAMB on purpose should not be thrown back to the
       exam list for changing their mind about which JAMB road to take. */
    await _pump(tester);
    await toCombination(tester, 'Full UTME mock - 4 subjects');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Full UTME mock - 4 subjects'), findsOneWidget);
    expect(find.text('Choose your exam'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });
}
