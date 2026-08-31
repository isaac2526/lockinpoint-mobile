import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/components.dart';
import 'package:lockinpoint/design/glass.dart';
import 'package:lockinpoint/design/motion_widgets.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/design/tokens.dart';

/// ===========================================================================
/// The design system's own tests.
///
/// Not "does it compile" tests. Each one asserts a rule that, if it broke,
/// would produce a bug nobody notices until a student complains:
///
///   · a colour that only works in one theme
///   · glass blurring inside a scrolling list and eating the frame budget
///   · a tap target too small for a thumb
///   · "correct" and "selected" drawn in the same colour
/// ===========================================================================

/// Pumps a widget inside the real app theme, in the theme asked for.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  required bool dark,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LipTheme.light(),
      darkTheme: LipTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

/// WCAG relative luminance. Flutter's Color channels are already 0..1.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio, 1.0 (identical) to 21.0 (black on white).
double contrast(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('the contrast helper itself is trustworthy', () {
    // A broken measuring stick would let every assertion below pass silently.
    test('black on white is 21, white on white is 1', () {
      expect(
        contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.1),
      );
      expect(
        contrast(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)),
        closeTo(1, 0.01),
      );
    });
  });

  group('themes are two deliberate designs, not one inverted', () {
    test('every text tier is readable on its own ground, in BOTH themes', () {
      for (final c in [LipColors.light, LipColors.dark]) {
        final name = c.isDark ? 'dark' : 'light';
        expect(
          contrast(c.text1, c.bgBase),
          greaterThan(7.0),
          reason: 'primary text fails AAA on the $name ground',
        );
        expect(
          contrast(c.text2, c.bgBase),
          greaterThan(4.5),
          reason: 'secondary text fails AA on the $name ground',
        );
        expect(
          contrast(c.text3, c.bgBase),
          greaterThan(3.0),
          reason: 'tertiary text is illegible on the $name ground',
        );
      }
    });

    test(
      'the brand lifts off the ground in dark, it does not sink into it',
      () {
        // #12296b on #040b22 is unreadable — dark mode must use a lighter blue.
        expect(
          contrast(LipColors.dark.brand, LipColors.dark.bgBase),
          greaterThan(4.5),
          reason: 'the dark brand blue disappears into the navy ground',
        );
      },
    );

    test('semantic tone is distinct from the brand in both themes', () {
      for (final c in [LipColors.light, LipColors.dark]) {
        // If "correct" and "selected" render alike, a student cannot tell a
        // chosen answer from a right one.
        expect(c.success, isNot(equals(c.brand)));
        expect(c.danger, isNot(equals(c.brand)));
        expect(c.success, isNot(equals(c.danger)));
      }
    });

    test('the two themes really are different palettes', () {
      expect(LipColors.light.bgBase, isNot(equals(LipColors.dark.bgBase)));
      expect(LipColors.light.text1, isNot(equals(LipColors.dark.text1)));
    });

    test('surfaces are opaque — the page never bleeds through a card', () {
      for (final c in [LipColors.light, LipColors.dark]) {
        for (final fill in [
          c.glassUltra,
          c.glassCard,
          c.glassRaised,
          c.glassDeep,
          c.glassModal,
        ]) {
          expect(
            fill.a,
            1.0,
            reason: 'a solid foundation means solid surfaces on top of it',
          );
        }
      }
    });

    test('the surface ladder rises away from the page', () {
      /* In dark, a card must be LIGHTER than the page — that is what reading
         as "above" means on a black ground. In light it is the reverse: the
         page is the tinted one and the cards are the white cut-outs. If the
         order ever flips, a raised pane sinks into the page. */
      final d = LipColors.dark;
      expect(_lum(d.glassCard), greaterThan(_lum(d.bgBase)));
      expect(_lum(d.glassRaised), greaterThan(_lum(d.glassCard)));

      final l = LipColors.light;
      expect(_lum(l.glassCard), greaterThan(_lum(l.bgBase)));
    });

    test('dark mode stands on NEUTRAL black, not on navy', () {
      /* The whole point of the dark theme: a blue-black ground swallows the
         blues drawn on it. Every foundation colour must be near-grey. */
      for (final ground in [
        LipColors.dark.bgBase,
        LipColors.dark.glassCard,
        LipColors.dark.glassRaised,
      ]) {
        final spread =
            [ground.r, ground.g, ground.b].reduce((a, b) => a > b ? a : b) -
            [ground.r, ground.g, ground.b].reduce((a, b) => a < b ? a : b);
        expect(
          spread,
          lessThan(0.05),
          reason: 'a foundation this colourful is a tint, not a neutral',
        );
      }
    });

    test('light mode stands on white', () {
      expect(_lum(LipColors.light.bgBase), greaterThan(0.85));
      expect(_lum(LipColors.light.glassCard), greaterThan(0.95));
    });

    test('every feature hue is readable on its own tint, in both themes', () {
      for (final c in [LipColors.light, LipColors.dark]) {
        for (final h in c.hues.all) {
          expect(
            _contrast(h.ink, h.tint),
            greaterThanOrEqualTo(4.5),
            reason:
                'ink ${h.ink} on tint ${h.tint} fails WCAG AA — a title a '
                'student cannot read is not a colour scheme',
          );
        }
      }
    });

    test('feature hues are twelve DIFFERENT colours, not one repeated', () {
      for (final c in [LipColors.light, LipColors.dark]) {
        final inks = c.hues.all.map((h) => h.ink.toARGB32()).toSet();
        expect(inks.length, c.hues.all.length);
      }
    });

    test('the brand blue is legible on the page it sits on', () {
      for (final c in [LipColors.light, LipColors.dark]) {
        expect(_contrast(c.brand, c.bgBase), greaterThanOrEqualTo(4.5));
        expect(_contrast(c.text1, c.bgBase), greaterThanOrEqualTo(7));
        expect(_contrast(c.text3, c.glassCard), greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('glass keeps to its budget', () {
    testWidgets('a surface does NOT blur by default', (tester) async {
      await pumpThemed(
        tester,
        const GlassSurface(child: Text('x')),
        dark: false,
      );
      expect(
        find.byType(BackdropFilter),
        findsNothing,
        reason: 'blur must be opt-in — a blurred card in a list drops frames',
      );
    });

    testWidgets('a surface blurs when explicitly asked', (tester) async {
      await pumpThemed(
        tester,
        const GlassSurface(
          blurred: true,
          tier: GlassTier.modal,
          child: Text('x'),
        ),
        dark: false,
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('every tier renders in both themes without throwing', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        for (final tier in GlassTier.values) {
          await pumpThemed(
            tester,
            GlassSurface(
              tier: tier,
              seam: true,
              child: Text('glass ${tier.name}'),
            ),
            dark: dark,
          );
          expect(tester.takeException(), isNull);
          expect(find.text('glass ${tier.name}'), findsOneWidget);
        }
      }
    });
  });

  group('components', () {
    testWidgets('the primary action is at least 48dp tall', (tester) async {
      await pumpThemed(
        tester,
        const LipButton(label: 'Start practice'),
        dark: false,
      );
      final size = tester.getSize(find.byType(FilledButton));
      expect(
        size.height,
        greaterThanOrEqualTo(48),
        reason: 'a tap target below 48dp is one a tired thumb misses',
      );
    });

    testWidgets('a busy button cannot be pressed twice', (tester) async {
      var taps = 0;
      await pumpThemed(
        tester,
        LipButton(label: 'Saving', busy: true, onPressed: () => taps++),
        dark: false,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(
        taps,
        0,
        reason: 'a busy button must not submit the same form again',
      );
    });

    testWidgets('a chip announces itself as selected to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        LipChip('2024', selected: true, onTap: () {}),
        dark: false,
      );
      // matchesSemantics is the stable public API; the flag accessors on
      // SemanticsNode have churned across releases.
      expect(
        tester.getSemantics(find.byType(LipChip)),
        matchesSemantics(
          label: '2024',
          isSelected: true,
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasSelectedState: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('a choice card carries its meaning into semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        LipChoiceCard(
          icon: Icons.schedule_rounded,
          title: 'Timed CBT',
          subtitle: 'A strict clock.',
          selected: false,
          onTap: () {},
        ),
        dark: false,
      );
      expect(
        find.bySemanticsLabel('Timed CBT. A strict clock.'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('an empty state always offers a way forward', (tester) async {
      var acted = false;
      await pumpThemed(
        tester,
        LipEmpty(
          icon: Icons.inbox_rounded,
          title: 'No saved questions',
          message: 'Tap the bookmark on any question.',
          actionLabel: 'Start practising',
          onAction: () => acted = true,
        ),
        dark: false,
      );
      await tester.tap(find.text('Start practising'));
      await tester.pump();
      expect(acted, isTrue);
    });

    testWidgets('the offline bar reassures when a vault exists', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const LipOfflineBar(hasVault: true),
        dark: false,
      );
      expect(
        find.textContaining('downloaded packs still work'),
        findsOneWidget,
      );

      await pumpThemed(tester, const LipOfflineBar(), dark: false);
      expect(find.text('No connection'), findsOneWidget);
    });
  });

  group('the entrance stagger does not follow a long list', () {
    testWidgets('the opening screenful animates, the rest simply appear', (
      tester,
    ) async {
      /* An item built while scrolling would otherwise start its stagger from
         zero and fade in most of a second after arriving, which reads as lag.
         Past the opening screenful the child is rendered directly. */
      expect(
        Entrance.inList(index: 0, child: const Text('a')),
        isA<Entrance>(),
      );
      expect(
        Entrance.inList(
          index: Entrance.staggerLimit - 1,
          child: const Text('a'),
        ),
        isA<Entrance>(),
      );
      expect(
        Entrance.inList(index: Entrance.staggerLimit, child: const Text('a')),
        isA<Text>(),
      );
      expect(Entrance.inList(index: 99, child: const Text('a')), isA<Text>());
    });
  });
}

// ---------------------------------------------------------------------------
// WCAG maths, so "readable" is measured rather than asserted by eye.

double _channel(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _lum(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
