import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/app/shell.dart';
import 'package:lockinpoint/design/theme.dart';

/// ===========================================================================
/// THE MENU BUTTON OPENS THE MENU.
///
/// It did not, for the life of the app, on the two tabs that had one.
///
/// The drawer belongs to the shell's Scaffold. Every tab builds its OWN
/// Scaffold inside it, and `Scaffold.of(context)` walks UP to the nearest
/// one — the tab's. That Scaffold has no drawer, so `openDrawer()` found a
/// null drawer key and returned. No exception. No log. Nothing on screen.
///
/// THAT IS WHY NO TEST CAUGHT IT: a dead button is indistinguishable from a
/// live one unless you assert on what happens AFTER the tap. Every test here
/// taps and then looks for the drawer.
/// ===========================================================================
void main() {
  testWidgets('openAppMenu opens the shell drawer through an inner Scaffold', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: LipTheme.light(),
          home: Scaffold(
            key: shellDrawerKey,
            drawer: const Drawer(child: Text('THE MENU')),
            // The shape that broke it: a tab with its own drawer-less
            // Scaffold between the button and the shell.
            body: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const Key('by-key'),
                        onPressed: openAppMenu,
                        icon: const Icon(Icons.menu_rounded),
                      ),
                      IconButton(
                        key: const Key('the-old-way'),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        icon: const Icon(Icons.menu_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // The old call is a silent no-op — it throws nothing, which is exactly
    // how it survived for so long.
    await tester.tap(find.byKey(const Key('the-old-way')));
    await tester.pumpAndSettle();
    expect(
      find.text('THE MENU'),
      findsNothing,
      reason:
          'Scaffold.of() resolves to the INNER Scaffold, which has no '
          'drawer. If this ever starts passing, Flutter changed and the '
          'comment above is stale.',
    );

    await tester.tap(find.byKey(const Key('by-key')));
    await tester.pumpAndSettle();
    expect(find.text('THE MENU'), findsOneWidget);
  });

  testWidgets('opening the menu twice does not stack it', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: LipTheme.light(),
          home: Scaffold(
            key: shellDrawerKey,
            drawer: const Drawer(child: Text('THE MENU')),
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    openAppMenu();
    await tester.pumpAndSettle();
    openAppMenu();
    await tester.pumpAndSettle();
    expect(find.text('THE MENU'), findsOneWidget);
  });

  test('opening the menu with no shell on screen is harmless', () {
    // A pushed route, a test, a screen shown before the shell exists: the
    // call must do nothing rather than throw on a null key.
    expect(openAppMenu, returnsNormally);
  });
}
