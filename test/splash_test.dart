import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/splash/splash_screen.dart';

/// ===========================================================================
/// THE FIRST FRAME
///
/// A splash has one honest job: fill the gap between the icon being tapped
/// and the app being usable, and make that gap feel intentional. It must
/// never CREATE the gap.
///
/// So this checks the two things that can be wrong with it: that it actually
/// moves (a still logo reads as a hang), and that the ring keeps turning
/// after the entrance has finished (a spinner that stops reads as a crash).
/// ===========================================================================
void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: LipTheme.light(),
      home: const LipSplash(season: 'WAEC season'),
    ),
  );

  /// What is actually on screen, as numbers.
  ///
  /// A FIRST ATTEMPT COMPARED Transform MATRICES AND ALWAYS PASSED NOTHING:
  /// the only Transforms in the tree were identity ones from the theme, and
  /// the ring is a CustomPainter, which repaints without any widget property
  /// changing. A test that reads the wrong thing reports PASS on a frozen
  /// splash.
  ///
  /// Opacity and Transform.scale ARE rebuilt every frame by the
  /// AnimatedBuilders here, so their values are the honest signal.
  String frameOf(WidgetTester tester) {
    final o = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((w) => w.opacity.toStringAsFixed(3))
        .join(',');
    final s = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((w) => w.transform.storage.map((d) => d.toStringAsFixed(3)).join())
        .join('|');
    return '$o :: $s';
  }

  testWidgets('it animates in rather than appearing all at once', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();
    final early = frameOf(tester);
    expect(early, isNotEmpty, reason: 'nothing on the splash is animated');

    await tester.pump(const Duration(milliseconds: 300));
    final mid = frameOf(tester);

    expect(
      mid,
      isNot(early),
      reason:
          'the splash is a still picture — a logo that does not move for '
          'a second reads as an app that has hung',
    );

    // The season line the app already knew, shown without a network call.
    expect(find.text('WAEC season'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the ring keeps turning after the entrance finishes', (
    tester,
  ) async {
    await pump(tester);

    /* THE RING IS A CustomPainter, SO IT IS INVISIBLE TO EVERY FINDER.
       It repaints without one widget property changing — which means a
       frozen ring looks identical to a turning one in a widget test, and a
       stopped spinner is exactly what a hung app looks like. Reading the
       painter's own sweep is the only honest way to ask. */
    double sweep() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<RingPainter>()
        .first
        .sweep;

    // Well past the 900ms entrance.
    await tester.pump(const Duration(milliseconds: 1200));
    final a = sweep();
    await tester.pump(const Duration(milliseconds: 400));
    final b = sweep();

    expect(b, isNot(a), reason: 'the ring froze once the entrance ended');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a first-ever launch shows no season rather than a guess', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: LipTheme.light(), home: const LipSplash()),
    );
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.textContaining('season'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
