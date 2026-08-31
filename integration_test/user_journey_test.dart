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
      for (var i = 0; i < 14; i++) {
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
      await tester.pump(const Duration(milliseconds: 120));
    } catch (_) {
      // Not inside a scrollable. Fine — it is already where it is.
    }
    await tester.tap(one);
    await tester.pump(const Duration(milliseconds: 120));
  }

  /// Back out of anything pushed, close any open drawer, and select Home.
  Future<void> toHome(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      // A drawer left open by the previous case swallows every later tap.
      if (find.text('Study plan').evaluate().isNotEmpty) {
        await tester.tapAt(const Offset(700, 300));
        await settle(tester);
        continue;
      }
      final back = find.byType(BackButton);
      final close = find.byTooltip('Leave');
      if (close.evaluate().isNotEmpty) {
        await tester.tap(close.first);
        await settle(tester);
        final leave = find.widgetWithText(FilledButton, 'Leave');
        if (leave.evaluate().isNotEmpty) {
          await tester.tap(leave.last);
          await settle(tester);
        }
        continue;
      }
      if (back.evaluate().isEmpty) break;
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

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Menu').first);
    await settle(tester);
  }

  /// Walk the whole menu with a thumb, looking for one row.
  ///
  /// A ListView only builds what is near the viewport, so a row far down the
  /// drawer is genuinely absent from the widget tree until something scrolls
  /// to it. Asserting on the tree alone would both miss real rows and — worse
  /// — let a deleted row "pass" a findsNothing check for the wrong reason.
  Future<bool> drawerHas(WidgetTester tester, String title) async {
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

    await tapWhenReady(tester, find.text('Log out'));

    /* Profile is a PUSHED route: signing out rebuilt the gate underneath
       while this screen stayed on top, so the student kept looking at their
       own data and tapping again did nothing. */
    await see(tester, find.text('Create account'), seconds: 15);
  });
}
