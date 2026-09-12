import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/glass.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/design/tokens.dart';

/// ===========================================================================
/// A MENU THAT OPENS UNDERNEATH THE CARD IT CAME FROM
///
/// "Dropdowns appearing under tiles" was the report. This does not test that a
/// dropdown EXISTS — it opens one for real, inside the exact surface the app
/// puts it in, and then asks the questions that matter:
///
///   · is the item actually PAINTED, or clipped away to nothing?
///   · is it HIT-TESTABLE where it is drawn — can a thumb reach it?
///   · does it sit INSIDE the screen, not off the bottom edge?
///
/// GlassSurface wraps every card in a ClipRRect. Anything drawn inside the
/// subtree that overflows is cut off silently, with no error and nothing in
/// the log — which is exactly what "it appears under the tile" looks like.
/// ===========================================================================

/// Does this widget actually reach the student's eye and thumb?
///
/// A FIRST ATTEMPT AT THIS WAS TOO WEAK AND PASSED TWO DELIBERATELY BROKEN
/// LAYOUTS. It walked the render tree all the way to the root looking for any
/// ancestor on the hit path — and the root is on every hit path, so the check
/// could never fail. That is worth writing down, because a test that cannot
/// fail is worse than no test: it reports PASS on a screen nobody can use.
///
/// What it asks now:
///   1 · drawn with real size at all
///   2 · INSIDE every clipping ancestor — the actual "hidden under the card"
///       failure, which produces no error and nothing in the log
///   3 · on the screen, not off the bottom edge
void expectUsable(WidgetTester tester, Finder f, {required String what}) {
  expect(f, findsWidgets, reason: '$what was not drawn at all');
  final box = tester.renderObject<RenderBox>(f.first);
  expect(
    box.size.height > 4 && box.size.width > 4,
    isTrue,
    reason: '$what was drawn with no size — it is being clipped away',
  );

  final rect = tester.getRect(f.first);
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(
    rect.top >= 0 && rect.bottom <= screen.height + 0.5,
    isTrue,
    reason:
        '$what opened off the screen: ${rect.top}–${rect.bottom} '
        'of ${screen.height}',
  );

  /* EVERY CLIP BETWEEN THIS WIDGET AND THE SCREEN.
     GlassSurface wraps every card in a ClipRRect, and a scroll view clips
     too. Something drawn outside one of those is silently cut off — which is
     exactly what "the menu appears under the tile" looks like from the
     outside. A menu that opens in an Overlay route has no card between it
     and the screen, so it passes; one drawn inline inside a card does not. */
  RenderObject? n = box.parent;
  while (n != null) {
    if (n is RenderBox &&
        (n.runtimeType.toString().contains('RenderClip') ||
            n.runtimeType.toString().contains('RenderViewport'))) {
      final clip = Rect.fromPoints(
        n.localToGlobal(Offset.zero),
        n.localToGlobal(n.size.bottomRight(Offset.zero)),
      );
      final visible = rect.intersect(clip);
      expect(
        visible.height >= rect.height - 0.5 &&
            visible.width >= rect.width - 0.5,
        isTrue,
        reason:
            '$what is cut off by a ${n.runtimeType}: it is drawn at $rect '
            'but that surface only shows $clip',
      );
    }
    final p = n.parent;
    n = p is RenderObject ? p : null;
  }
}

Widget _inACard(Widget child) => ProviderScope(
  child: MaterialApp(
    theme: LipTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            children: [
              // A tile ABOVE it, which is what the report says it hides under.
              const GlassSurface(child: SizedBox(height: 90)),
              const SizedBox(height: Gap.md),
              GlassSurface(tier: GlassTier.raised, child: child),
              const SizedBox(height: Gap.md),
              // And a tile BELOW it.
              const GlassSurface(child: SizedBox(height: 400)),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a dropdown inside a glass card opens ON TOP of everything', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      _inACard(
        DropdownButtonFormField<String>(
          initialValue: 'Lagos',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'State'),
          items: const [
            DropdownMenuItem(value: 'Lagos', child: Text('Lagos')),
            DropdownMenuItem(value: 'Oyo', child: Text('Oyo')),
            DropdownMenuItem(value: 'Kano', child: Text('Kano')),
          ],
          onChanged: (v) => picked = v,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lagos').first);
    await tester.pumpAndSettle();

    // Three in the menu, plus the one in the closed field.
    expect(find.text('Kano'), findsWidgets);
    expectUsable(tester, find.text('Kano'), what: 'the Kano option');

    // And choosing it actually works, which is the whole point.
    await tester.tap(find.text('Kano').last);
    await tester.pumpAndSettle();
    expect(picked, 'Kano');
  });

  testWidgets('a popup menu inside a card is reachable, not behind it', (
    tester,
  ) async {
    var chosen = '';
    await tester.pumpWidget(
      _inACard(
        PopupMenuButton<String>(
          position: PopupMenuPosition.under,
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (v) => chosen = v,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'light', child: Text('Light')),
            PopupMenuItem(value: 'dark', child: Text('Dark')),
            PopupMenuItem(value: 'system', child: Text('Follow my phone')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expectUsable(tester, find.text('Follow my phone'), what: 'the System item');
    await tester.tap(find.text('Follow my phone'));
    await tester.pumpAndSettle();
    expect(chosen, 'system');
  });

  testWidgets('a menu near the BOTTOM of the screen still opens on screen', (
    tester,
  ) async {
    /* The nastiest version of this bug: the control is fine in the middle of
       the page and unusable at the bottom, where a long form puts it. */
    var chosen = '';
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: LipTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: GlassSurface(child: SizedBox.expand())),
                GlassSurface(
                  tier: GlassTier.raised,
                  child: PopupMenuButton<String>(
                    position: PopupMenuPosition.under,
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (v) => chosen = v,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'a', child: Text('First')),
                      PopupMenuItem(value: 'b', child: Text('Second')),
                      PopupMenuItem(value: 'c', child: Text('Third')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expectUsable(tester, find.text('Third'), what: 'the last item at the foot');
    await tester.tap(find.text('Third'));
    await tester.pumpAndSettle();
    expect(chosen, 'c');
  });
}
