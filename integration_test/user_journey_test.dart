import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lockinpoint/core/config.dart';
import 'package:lockinpoint/main.dart' as app;

/// ===========================================================================
/// THE ACCEPTANCE DRIVE — A STUDENT USING THE REAL APP
///
/// WHY THIS FILE EXISTS.
/// The previous release was declared ready on a clean analyzer, 198 passing
/// unit tests and a successful build. The founder then installed it and found
/// menus that would not open, buttons that did nothing and a JAMB flow that
/// led nowhere. Every one of those defects was invisible to everything that
/// had been run, because none of it TAPPED anything.
///
/// So this drives the real binary: real widgets, real navigation, real HTTP to
/// a stand-in serving the real contracts. Each check asserts a DESTINATION or
/// a STATE CHANGE — what the student ends up looking at — never merely that a
/// widget exists. A widget existing is precisely what was true of every dead
/// button in the shipped build.
/// ===========================================================================
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pump frames for a bounded stretch, then carry on.
  ///
  /// NEVER pumpAndSettle on this app. A CBT paper, a mock and The Climb all
  /// keep a clock ticking once a second, so the widget tree is never
  /// quiescent and pumpAndSettle burns its ten-minute timeout before failing
  /// for a reason that has nothing to do with the app. (Its first argument is
  /// the pump INTERVAL, not a wait, which is the other half of that trap.)
  Future<void> settle(WidgetTester tester, [double seconds = 1]) async {
    final end = DateTime.now().add(
      Duration(milliseconds: (seconds * 1000).round()),
    );
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Pump until [f] matches, or give up.
  ///
  /// This is the honest wait against a live app talking to a real server. A
  /// fixed sleep is wrong in both directions: too short and a slow response
  /// fails a case that works, too long and twelve journeys take an hour.
  Future<bool> waitFor(
    WidgetTester tester,
    Finder f, {
    double seconds = 10,
  }) async {
    final end = DateTime.now().add(
      Duration(milliseconds: (seconds * 1000).round()),
    );
    while (DateTime.now().isBefore(end)) {
      if (f.evaluate().isNotEmpty) return true;
      await tester.pump(const Duration(milliseconds: 60));
    }
    return f.evaluate().isNotEmpty;
  }

  /// Look for [f] on this screen, scrolling if it sits below the fold.
  ///
  /// A ListView only builds what is near the viewport, so a control further
  /// down a long setup screen is genuinely absent from the widget tree until
  /// something scrolls to it — the Start button under the chooser is exactly
  /// that. A student scrolls; so does this.
  Future<bool> findOnScreen(
    WidgetTester tester,
    Finder f, {
    double seconds = 10,
  }) async {
    if (await waitFor(tester, f, seconds: seconds)) return true;
    final lists = find.byType(Scrollable);
    final n = lists.evaluate().length;
    for (var which = 0; which < n; which++) {
      /* BACK TO THE TOP FIRST. This only ever scrolled downwards, so once one
         control had been found near the bottom of a long setup screen, a
         control ABOVE it was unreachable and reported missing — which is a
         test failing for a reason a student would never meet, and the fastest
         way to get a real check deleted. */
      for (var up = 0; up < 12; up++) {
        try {
          await tester.drag(lists.at(which), const Offset(0, 300));
        } catch (_) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 60));
      }
      for (var i = 0; i < 16; i++) {
        if (f.evaluate().isNotEmpty) return true;
        try {
          await tester.drag(lists.at(which), const Offset(0, -220));
        } catch (_) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 150));
      }
    }
    return f.evaluate().isNotEmpty;
  }

  /// Assert the student ends up looking at something — after giving the app
  /// the time a real one gets.
  Future<void> see(
    WidgetTester tester,
    Finder f, {
    String? why,
    double seconds = 10,
  }) async {
    final found = await findOnScreen(tester, f, seconds: seconds);
    /* The reason uses f.description, never "$f": interpolating a Finder
       evaluates it, and .first on an empty match throws StateError while
       building the message — burying the real failure under a stack trace
       about string interpolation. */
    expect(
      found,
      isTrue,
      reason: why ?? 'never appeared: ${f.describeMatch(Plurality.one)}',
    );
  }

  /// Wait for a control, scroll it into view, and tap it.
  ///
  /// The scroll matters: a tap at an off-screen widget's coordinates lands on
  /// whatever is actually painted there, which is one way a "tapped" control
  /// does nothing at all.
  Future<void> tapWhenReady(
    WidgetTester tester,
    Finder f, {
    double seconds = 10,
  }) async {
    await see(
      tester,
      f,
      why: 'nothing to tap: ${f.describeMatch(Plurality.one)}',
      seconds: seconds,
    );
    final one = f.first;
    try {
      await tester.ensureVisible(one);
      /* LET THE SCROLL LAND BEFORE TAPPING.
         ensureVisible starts an animation; tapping 120ms into it aims at
         coordinates the target has already left, and the tap lands on
         whatever is painted there now. On The Climb that meant a tap meant
         for a lifeline chip hit an ANSWER OPTION and ended the rung — a
         failure with every appearance of a product bug and no product bug
         behind it. */
      await settle(tester, 0.6);
    } catch (_) {
      // Not inside a scrollable. Fine — it is already where it is.
    }
    await tester.tap(one);
    await tester.pump(const Duration(milliseconds: 150));
  }

  /// Back out of anything pushed, close any open drawer, and select Home.
  Future<void> toHome(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      /* AN OPEN DRAWER IS A DRAWER, NOT A WORD.
         This detected one by looking for the text "Study plan" — which is
         also the Study plan SCREEN's own app bar title. So after visiting
         that screen the unwind believed a drawer was open, tapped at empty
         coordinates eight times, and left the app exactly where it was; the
         NEXT row then failed with "no hamburger", two steps from its cause.
         Ask for the widget. */
      if (find.byType(Drawer).evaluate().isNotEmpty) {
        await tester.tapAt(const Offset(700, 300));
        await settle(tester);
        continue;
      }
      final back = find.byType(BackButton);
      final close = find.byTooltip('Leave');
      if (close.evaluate().isNotEmpty) {
        await tester.tap(close.first);
        await settle(tester);
        /* THE DIALOG IS NOT THE SAME IN A TIMED SITTING.
           An untimed paper offers "Leave"; a CBT offers "Submit now" and
           "Leave anyway", because walking out of a timed hall is a different
           decision from closing a practice sheet. This looked only for
           "Leave", so a CBT's dialog stayed open, the unwind never reached
           the shell, and the NEXT case failed with no hamburger — a
           failure two cases away from its cause. */
        final anyway = find.widgetWithText(TextButton, 'Leave anyway');
        final leave = find.widgetWithText(FilledButton, 'Leave');
        if (anyway.evaluate().isNotEmpty) {
          await tester.tap(anyway.last);
          await settle(tester, 1.5);
        } else if (leave.evaluate().isNotEmpty) {
          await tester.tap(leave.last);
          await settle(tester, 1.5);
        }
        continue;
      }
      if (back.evaluate().isEmpty) {
        // The practice flow's step arrow is an IconButton with a tooltip, not
        // a BackButton, so the generic unwind walked straight past it.
        final step = find.byTooltip('Back');
        if (step.evaluate().isEmpty) break;
        await tester.tap(step.first);
        await settle(tester);
        continue;
      }
      await tester.tap(back.first);
      await settle(tester);
    }
    final homeTab = find.text('Home');
    if (homeTab.evaluate().isNotEmpty) {
      await tester.tap(homeTab.last);
      await settle(tester);
    }
  }

  /// Boot the app and make sure a student is signed in and standing on the
  /// home tab.
  ///
  /// IDEMPOTENT ON PURPOSE. integration_test runs every case against ONE app
  /// process, and the session survives between them — so this has to cope
  /// with arriving already signed in, and with arriving several screens deep
  /// from the case before. Both are exactly what a real student's app does
  /// between one sitting and the next.
  Future<void> signIn(WidgetTester tester) async {
    app.main();
    await settle(tester, 2);

    // Already in? Walk back to the root and take the home tab.
    if (find.byTooltip('Menu').evaluate().isNotEmpty ||
        find.byType(BottomNavigationBar).evaluate().isNotEmpty ||
        find.byType(NavigationBar).evaluate().isNotEmpty) {
      await toHome(tester);
      return;
    }

    final logIn = find.text('Log in');
    if (logIn.evaluate().isNotEmpty) {
      await tester.tap(logIn.last);
      await settle(tester);
    }
    await tester.enterText(find.byType(TextField).first, 'ada@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in').last);
    await settle(tester, 3);
    await toHome(tester);
  }

  /// The drawer's rows, and only the drawer's: the home grid behind it uses
  /// the same words, so an unscoped finder can pass while the menu is shut.
  Finder inDrawer(String text) =>
      find.descendant(of: find.byType(Drawer), matching: find.text(text));

  Finder drawerList() => find
      .descendant(of: find.byType(Drawer), matching: find.byType(Scrollable))
      .first;

  Future<void> openMenu(WidgetTester tester, [String note = '']) async {
    /* ASSERT THE MENU IS REACHABLE, THEN THAT IT OPENED.
       Both halves matter. A missing hamburger means the walk back to the
       shell did not finish, and an unopened drawer is the founder's original
       blocker — and without these two lines either one surfaces later as
       "Bad state: No element" from a .first on an empty finder, which says
       nothing about what actually went wrong. */
    await see(
      tester,
      find.byTooltip('Menu'),
      why: 'no hamburger — the app is not standing on the shell$note',
      seconds: 8,
    );
    await tester.tap(find.byTooltip('Menu').first);
    await settle(tester);
    await see(
      tester,
      find.byType(Drawer),
      why: 'the hamburger was tapped and no drawer opened$note',
      seconds: 8,
    );
  }

  /// Walk the whole menu with a thumb, looking for one row.
  ///
  /// A ListView only builds what is near the viewport, so a row far down the
  /// drawer is genuinely absent from the widget tree until something scrolls
  /// to it. Asserting on the tree alone would both miss real rows and — worse
  /// — let a deleted row "pass" a findsNothing check for the wrong reason.
  Future<bool> drawerHas(WidgetTester tester, String title) async {
    if (drawerList().evaluate().isEmpty) return false;
    await tester.drag(drawerList(), const Offset(0, 1400));
    await settle(tester);
    for (var i = 0; i < 14; i++) {
      if (inDrawer(title).evaluate().isNotEmpty) return true;
      await tester.drag(drawerList(), const Offset(0, -200));
      await settle(tester);
    }
    return inDrawer(title).evaluate().isNotEmpty;
  }

  /// Tap a drawer row the way a student does — scrolling it into view first.
  /// A tap at a widget's off-screen coordinates lands on whatever is actually
  /// painted there, which is one way a "tapped" row does nothing at all.
  Future<void> tapDrawerRow(WidgetTester tester, String title) async {
    expect(
      await drawerHas(tester, title),
      isTrue,
      reason: 'no drawer row titled "$title" anywhere in the menu',
    );
    final row = inDrawer(title).first;
    await tester.ensureVisible(row);
    await settle(tester);
    await tester.tap(row);
    await settle(tester, 2);
  }

  testWidgets('0 · the app opens and a student can sign in', (tester) async {
    expect(
      AppConfig.apiBase,
      contains('127.0.0.1'),
      reason: 'Run with --dart-define=LIP_API=http://127.0.0.1:<port>',
    );
    await signIn(tester);
    // The shell, not the welcome screen: the student is in.
    await see(tester, find.text('Practice'));
  });

  testWidgets('1 · THE MENU OPENS — the drawer was unreachable', (
    tester,
  ) async {
    await signIn(tester);
    await openMenu(tester);

    /* The exact failure the founder hit: the hamburger called openDrawer on a
       drawerless inner Scaffold and did nothing at all. These rows live ONLY
       in the drawer, so finding them proves it really opened. */
    expect(await drawerHas(tester, 'Study plan'), isTrue);
    expect(await drawerHas(tester, 'Guardian Portal'), isTrue);
    expect(await drawerHas(tester, 'Offline vault'), isTrue);
  });

  testWidgets('2 · the drawer has no rows that apologise for live screens', (
    tester,
  ) async {
    await signIn(tester);
    await openMenu(tester);

    /* Scoped to the DRAWER: the home grid behind it also says "Classroom",
       and the claim here is about the drawer's rows. Two of them used to
       snackbar "arrives in the next build" for screens that shipped long
       ago, and Classroom appeared twice — one live, one dead. */
    expect(await drawerHas(tester, 'Classroom'), isTrue);
    expect(await drawerHas(tester, 'Activation & payment'), isTrue);
    // One screen, one row: "Activate" and "Activation & payment" both opened
    // the same activation screen from the same menu.
    expect(await drawerHas(tester, 'Activate'), isFalse);
  });

  testWidgets('3 · a drawer row NAVIGATES', (tester) async {
    await signIn(tester);
    await openMenu(tester);
    await tapDrawerRow(tester, 'Study plan');

    // Arrived somewhere real, not a closed drawer and a snackbar.
    await see(tester, find.text('Build my plan'));
  });

  /// Open the Practice tab AT THE EXAM LIST.
  ///
  /// The tab keeps its place between visits — which is right for a student
  /// mid-setup, and means a drive arriving from an earlier case can land on
  /// step five rather than step zero. Its back control is a plain IconButton
  /// with a 'Back' tooltip, not a BackButton, so the generic unwind never
  /// touched it.
  Future<void> toExamList(WidgetTester tester) async {
    await tapWhenReady(tester, find.text('Practice').last);
    for (var i = 0; i < 8; i++) {
      if (find.text('Choose your exam').evaluate().isNotEmpty) return;
      final back = find.byTooltip('Back');
      if (back.evaluate().isEmpty) break;
      await tester.tap(back.first);
      await tester.pump(const Duration(milliseconds: 250));
    }
    await see(tester, find.text('Choose your exam'));
  }

  /// Practice tab → JAMB, the road every JAMB case walks first.
  Future<void> toJamb(WidgetTester tester) async {
    await toExamList(tester);
    await tapWhenReady(tester, find.text('JAMB').first);
  }

  /// …and on into the combination step with three subjects chosen.
  Future<void> toCombination(WidgetTester tester) async {
    await toJamb(tester);
    await tapWhenReady(tester, find.text('Full UTME mock - 4 subjects'));
    await see(tester, find.text('Use of English - always in'));
    for (final s in ['Physics', 'Chemistry', 'Biology']) {
      await tapWhenReady(tester, find.text(s));
    }
  }

  testWidgets('4 · JAMB FORKS — it used to jump straight to one subject', (
    tester,
  ) async {
    await signIn(tester);
    await toJamb(tester);

    await see(tester, find.text('Practise one subject'));
    await see(tester, find.text('Full UTME mock - 4 subjects'));
  });

  testWidgets('5 · the combination locks English and demands three more', (
    tester,
  ) async {
    await signIn(tester);
    await toJamb(tester);
    await tapWhenReady(tester, find.text('Full UTME mock - 4 subjects'));

    await see(tester, find.text('Use of English - always in'));
    await see(tester, find.textContaining('Pick 3 more'));

    for (final s in ['Physics', 'Chemistry', 'Biology']) {
      await tapWhenReady(tester, find.text(s));
    }
    // Named, so the student knows exactly what they are about to sit.
    await see(tester, find.textContaining('Start: Use of English + 3'));
  });

  testWidgets('6 · a UTME mock runs, shows its subject rail, scores /400', (
    tester,
  ) async {
    await signIn(tester);
    await toCombination(tester);
    await tapWhenReady(
      tester,
      find.textContaining('Start: Use of English + 3'),
    );

    /* THE RAIL. A four-subject mock used to arrive as one undifferentiated
       stream because the app dropped the subjects list the server sent. */
    await see(tester, find.text('Use of English'), seconds: 15);
    await see(tester, find.text('Physics'));

    // Answer one, then submit the paper.
    await tapWhenReady(tester, find.textContaining('first option').first);
    await tapWhenReady(tester, find.text('Submit'));
    final confirm = find.widgetWithText(FilledButton, 'Submit');
    if (await waitFor(tester, confirm, seconds: 2)) {
      await tapWhenReady(tester, confirm.last);
    }

    /* OUT OF 400, NOT A PERCENTAGE. It printed "265%" in a circle whose
       thresholds painted every mock green. */
    await see(tester, find.text('out of 400'), seconds: 15);
  });

  /// A WAEC Mathematics practice paper, running.
  Future<void> toPractice(WidgetTester tester) async {
    await toExamList(tester);
    await tapWhenReady(tester, find.text('WAEC').first);
    await tapWhenReady(tester, find.text('Mathematics'));
    await tapWhenReady(tester, find.text('Start practising'));
  }

  testWidgets('7 · a sitting can be LEFT — it used to trap the student', (
    tester,
  ) async {
    await signIn(tester);
    await toPractice(tester);

    await tapWhenReady(tester, find.byTooltip('Leave'), seconds: 15);
    await tapWhenReady(tester, find.widgetWithText(FilledButton, 'Leave'));

    /* Starting from the Practice TAB used to REPLACE the shell, so leaving
       popped the last route and left a dead black app to force-close. */
    await see(tester, find.text('Practice'));
  });

  testWidgets('8 · the bookmark exists and saves', (tester) async {
    await signIn(tester);
    await toPractice(tester);

    /* The Saved screen told students to "tap the bookmark on a question while
       you practise" — a button that existed on no screen. */
    await tapWhenReady(
      tester,
      find.byTooltip('Save this question'),
      seconds: 15,
    );
    await see(tester, find.byTooltip('Remove from saved'));
  });

  testWidgets('9 · Lumi acknowledges the question IMMEDIATELY', (tester) async {
    await signIn(tester);
    await openMenu(tester);
    await tapDrawerRow(tester, 'Ask Lumi');

    await see(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField).first, 'What is a mole?');
    await tester.tap(find.byIcon(Icons.send_rounded));
    // ONE frame — not settled, not waited for. The old skeleton appeared
    // 200ms in and looked like an empty box, which reads as a frozen screen.
    await tester.pump();
    expect(
      find.text('thinking'),
      findsOneWidget,
      reason: 'Lumi must say she is thinking on the very next frame',
    );

    await see(tester, find.textContaining('molar mass'), seconds: 20);
  });

  testWidgets('10 · the vault offers a DOWNLOAD where a subject is chosen', (
    tester,
  ) async {
    await signIn(tester);
    await toExamList(tester);
    await tapWhenReady(tester, find.text('WAEC').first);
    await tapWhenReady(tester, find.text('Chemistry'));

    /* The button was fully built, tested at the repository level, promised by
       the vault's empty state — and placed on no screen, so no student could
       ever put a pack on their phone. */
    await see(tester, find.text('Download for offline'));
  });

  testWidgets('11 · logging out really leaves', (tester) async {
    await signIn(tester);
    await openMenu(tester);
    await tapDrawerRow(tester, 'Profile & Product Key');

    /* "Sign out" now, and it ASKS FIRST. It used to be a bare TextButton at
       the foot of a long scroll with nothing behind it — the one action on
       that page a student cannot undo with another tap, and on a shared
       phone the one they most want to find. */
    await tapWhenReady(tester, find.text('Sign out'));
    await see(tester, find.text('Sign out?'));
    await tapWhenReady(tester, find.text('Sign out').last);

    /* Profile is a PUSHED route: signing out rebuilt the gate underneath
       while this screen stayed on top, so the student kept looking at their
       own data and tapping again did nothing. */
    await see(tester, find.text('Create account'), seconds: 15);
  });

  // ==========================================================================
  // THE SECOND ROUND
  //
  // Games and Career were signed off as "route-verified and reachable" — a
  // phrase that means nobody played a game or looked up a course. Route
  // verification is exactly the standard that let a menu ship unopenable, so
  // these play and look up.
  // ==========================================================================

  testWidgets('12 · a QUICK GAME is really played, answered and scored', (
    tester,
  ) async {
    await signIn(tester);
    await openMenu(tester);
    await tapDrawerRow(tester, 'Games arena');
    await see(tester, find.text('The Climb'));

    // Daily Ten: the same plate for everybody, and the shortest to finish.
    await tapWhenReady(tester, find.text('Daily Ten'));
    await see(tester, find.textContaining('1/'), seconds: 15);

    /* PLAY IT OUT. Ten questions, answered by tapping a real option each
       time — not by asserting that an option widget exists. */
    for (var i = 0; i < 12; i++) {
      if (find.text('Back to the arena').evaluate().isNotEmpty) break;
      /* EXACT, NOT CONTAINING. The question itself reads "…which option is
         correct?", so a textContaining('option') finder matched the QUESTION
         first and every tap landed on unclickable text — the game sat on
         question 1 of 10 for a minute looking exactly like a frozen screen.
         A finder that matches the wrong widget is how a test invents a bug. */
      final option = find.text('first option');
      if (option.evaluate().isEmpty) break;
      await tester.tap(option.first);
      // The reveal holds for 850ms before the next question arrives.
      await settle(tester, 1.4);
    }

    // A scoreboard at the end, not a stuck question.
    await see(tester, find.text('Back to the arena'), seconds: 20);
    await tapWhenReady(tester, find.text('Back to the arena'));
    await see(tester, find.text('The Climb'));
  });

  testWidgets('13 · THE CLIMB runs: a rung, a lifeline that pays, an ending', (
    tester,
  ) async {
    await signIn(tester);
    await openMenu(tester);
    await tapDrawerRow(tester, 'Games arena');
    await tapWhenReady(tester, find.text('The Climb'));

    // The setup screen: three lifelines are pre-chosen, so just start.
    await tapWhenReady(tester, find.text('Start climbing'));
    await see(tester, find.textContaining('Climb question'), seconds: 20);

    /* ASK THE CLASS MUST PAY FOR ITSELF. The app read `distribution`, a key
       the route does not send, so the lifeline was consumed and NOTHING
       appeared — the exact shape of "a button that does nothing". */
    await tapWhenReady(tester, find.text('Ask the class'));
    await see(tester, find.textContaining('students answered'), seconds: 15);

    // Answer wrongly on purpose: the climb must END rather than hang.
    await tapWhenReady(tester, find.textContaining('option B'));
    await see(tester, find.textContaining('definition'), seconds: 15);
  });

  testWidgets(
    '14 · CAREER: a course search reaches real schools and cut-offs',
    (tester) async {
      await signIn(tester);
      await openMenu(tester);
      await tapDrawerRow(tester, 'Career & institutions');
      await see(tester, find.text('Which course?'));

      /* The search is debounced by 380ms and needs three letters before it
       asks anything — both are real behaviours a student meets, so type a
       real course name and wait like one. */
      await tester.enterText(find.byType(TextField).first, 'Medicine');
      await settle(tester, 1.2);

      await see(tester, find.text('University of Ibadan'), seconds: 15);
      await see(tester, find.text('Medicine and Surgery'));
      // The cut-off is the whole reason a student opens this screen.
      await see(tester, find.text('78 - 85'));
    },
  );

  testWidgets('15 · CAREER: the other two tabs are not decoration', (
    tester,
  ) async {
    await signIn(tester);
    await openMenu(tester);
    await tapDrawerRow(tester, 'Career & institutions');

    await tapWhenReady(tester, find.text('Careers'));
    await see(tester, find.text('Medicine'), seconds: 15);

    await tapWhenReady(tester, find.text('Schools'));
    await see(tester, find.textContaining('Ibadan'), seconds: 15);
  });

  testWidgets('16 · a MINI MOCK is the size the student asked for', (
    tester,
  ) async {
    await signIn(tester);
    await toCombination(tester);

    await tapWhenReady(tester, find.text('Mini mock'));
    /* THE SIZE WAS A HIDDEN DEFAULT. /api/attempts has read `per` for a
       jamb_mini since the mode existed; the app never sent it, so every mini
       mock was the route's fallback and the student had no say at all. */
    await tapWhenReady(tester, find.text('5'));
    await see(tester, find.textContaining('20 questions'));

    await tapWhenReady(
      tester,
      find.textContaining('Start: Use of English + 3'),
    );
    // Four subjects at five each — the number asked for, honoured.
    await see(tester, find.textContaining('of 20'), seconds: 20);
  });

  testWidgets('17 · the ALL-QUESTIONS grid opens and jumps', (tester) async {
    await signIn(tester);
    await toPractice(tester);

    /* A dropdown-shaped control from the audit: the grid that makes a timed
       paper navigable. A student who skipped question 3 must reach it
       without tapping through two others. */
    await tapWhenReady(tester, find.byTooltip('All questions'), seconds: 15);
    await see(tester, find.text('3'));
    await tapWhenReady(tester, find.text('3'));
    await see(tester, find.textContaining('Question 3 of'), seconds: 15);
  });

  testWidgets('18 · the question COUNT and the room are really choosable', (
    tester,
  ) async {
    await signIn(tester);
    await toExamList(tester);
    await tapWhenReady(tester, find.text('WAEC').first);
    await tapWhenReady(tester, find.text('Mathematics'));

    // The count chips, and the free-form field beside them — three fixed
    // sizes meant a student revising one weak topic could not sit five.
    await tapWhenReady(tester, find.text('20'));
    await tapWhenReady(tester, find.text('By year'));
    await see(tester, find.text('2023'));
    await tapWhenReady(tester, find.text('2023'));

    // CBT turns the clock on, which must reveal the length choice.
    await tapWhenReady(tester, find.text('CBT'));
    await see(tester, find.text('HOW LONG'));
    await tapWhenReady(tester, find.text('Start the clock'), seconds: 15);
    await see(tester, find.textContaining('Question 1 of'), seconds: 20);
  });

  testWidgets('19 · the DRAWER reaches every screen it names', (tester) async {
    await signIn(tester);

    /* THE AUDIT'S MENU LIST, TAPPED — every row, one at a time.
       Each destination is identified by ITS OWN APP BAR TITLE, not by any
       word that happens to be on screen: the home grid behind the drawer uses
       the same vocabulary, and matching that would let a row that never
       navigated pass. "Route-verified" is exactly what was claimed of the
       rows that turned out to do nothing. */
    const rows = <String, String>{
      'Question search': 'Question search',
      'Leaderboard': 'Leaderboard',
      'Classroom': 'Classroom',
      'Saved questions': 'Saved questions',
      'Games arena': 'Games arena',
      'Career & institutions': 'Career & institutions',
      'Ask Lumi': 'Ask Lumi',
      'Result history': 'Result history',
      'Performance analysis': 'Performance analysis',
      'Study plan': 'Study plan',
      'Offline vault': 'Offline vault',
      'Notifications': 'Notifications',
      'Activate': 'Activate',
      /* THE ROOMS THAT WERE MISSING. Every one of these had a working
         backend and no way in — some of them for the life of the app. They
         are in this list so they cannot quietly go back to being absences. */
      'Theory': 'Theory',
      'Practical': 'Practical',
      'Pointgram': 'Pointgram',
      'The Challenge': 'The Challenge',
      'Your activity': 'Your activity',
      'Refer a friend': 'Refer a friend',
    };
    for (final row in rows.keys) {
      await toHome(tester);
      // The row name travels into the failure, so a walk that breaks on the
      // ninth door says which door rather than leaving it to be guessed.
      await openMenu(tester, ' (on the way to "$row")');
      await tapDrawerRow(tester, row);
      await see(
        tester,
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(rows[row]!),
        ),
        why:
            'the drawer row "$row" did not reach a screen titled '
            '"${rows[row]}"',
        seconds: 15,
      );
    }
  });
}
