import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/auth/ui/login_screen.dart';
import 'package:lockinpoint/features/auth/ui/signup_screen.dart';
import 'package:lockinpoint/features/onboarding/welcome_screen.dart';

/// ===========================================================================
/// The real screens a student meets, tested as a student meets them.
///
/// No network here — these prove the screens themselves behave: that the
/// welcome page says what LockInPoint is, that the forms refuse bad input
/// before wasting a round trip, and that a student can walk from the welcome
/// screen to either door.
/// ===========================================================================
Future<void> pump(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LipTheme.light(),
        darkTheme: LipTheme.dark(),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls a control into view before tapping it. The 800x600 test surface is
/// shorter than a real phone, so a button below the fold is off-screen here
/// while being perfectly reachable on a device.
Future<void> tapScrolled(WidgetTester tester, Finder target) async {
  /* Fixed pumps, never pumpAndSettle: the live username check shows a spinner
     while it waits, and a spinner animates for ever, so pumpAndSettle would
     wait for ever with it. Advancing fake time fires the debounce and lets
     its result land before the tap. */
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
}

void main() {
  group('the welcome screen introduces LockInPoint', () {
    testWidgets('opens on the product, not a form', (tester) async {
      await pump(tester, const WelcomeScreen());
      expect(find.text('Pass JAMB, WAEC, NECO and more'), findsOneWidget);
      expect(find.textContaining('Noesis Innovations'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
    });

    testWidgets('carries a notice when a session ended on its own', (
      tester,
    ) async {
      await pump(
        tester,
        const WelcomeScreen(notice: 'Your session has ended.'),
      );
      expect(find.text('Your session has ended.'), findsOneWidget);
    });

    testWidgets('both doors open', (tester) async {
      await pump(tester, const WelcomeScreen());

      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.byType(SignupScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('renders in dark mode without throwing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: LipTheme.light(),
            darkTheme: LipTheme.dark(),
            themeMode: ThemeMode.dark,
            home: const WelcomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('login refuses bad input before spending a round trip', () {
    testWidgets('empty fields are caught on the phone', (tester) async {
      await pump(tester, const LoginScreen());
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email or username.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('the password can be revealed', (tester) async {
      await pump(tester, const LoginScreen());
      expect(find.byTooltip('Show password'), findsOneWidget);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide password'), findsOneWidget);
    });
  });

  group('signup mirrors the website’s rules', () {
    testWidgets('starts on step one of two', (tester) async {
      await pump(tester, const SignupScreen());
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.text('Create your account'), findsOneWidget);
    });

    testWidgets('rejects a password under 8 characters, as the server does', (
      tester,
    ) async {
      await pump(tester, const SignupScreen());
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kweku'),
        'Kweku',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Adeola'),
        'Adeola',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. sharpshooter01'),
        'sharp01',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'you@example.com'),
        'me@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'At least 8 characters'),
        'short',
      );

      await tapScrolled(tester, find.text('Continue'));

      expect(
        find.text('Choose a password of at least 8 characters.'),
        findsOneWidget,
      );
      // Still on step one — a rejected form must not advance.
      expect(find.text('Step 1 of 2'), findsOneWidget);
    });

    testWidgets('rejects an address that is not an email', (tester) async {
      await pump(tester, const SignupScreen());
      await tester.enterText(
        find.widgetWithText(TextFormField, 'you@example.com'),
        'not-an-email',
      );
      await tapScrolled(tester, find.text('Continue'));
      expect(
        find.text('That does not look like an email address.'),
        findsOneWidget,
      );
    });

    testWidgets('a complete step one advances to step two', (tester) async {
      await pump(tester, const SignupScreen());
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kweku'),
        'Kweku',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Adeola'),
        'Adeola',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. sharpshooter01'),
        'sharp01',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'you@example.com'),
        'me@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'At least 8 characters'),
        'longenough',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Type it once more'),
        'longenough',
      );

      await tapScrolled(tester, find.text('Continue'));

      expect(find.text('Step 2 of 2'), findsOneWidget);
      // The five nations LockInPoint actually serves.
      expect(find.textContaining('Nigeria'), findsOneWidget);
      expect(find.textContaining('The Gambia'), findsOneWidget);
      expect(find.text('Create my account'), findsOneWidget);
    });
  });

  group('the copy stays professional', () {
    testWidgets('no dashes anywhere on the welcome screen', (tester) async {
      await pump(tester, const WelcomeScreen());
      for (final el in find.byType(Text).evaluate()) {
        final t = (el.widget as Text).data ?? '';
        expect(t.contains('—'), isFalse, reason: 'em dash in: "$t"');
        expect(t.contains(' - '), isFalse, reason: 'spaced hyphen in: "$t"');
      }
    });
  });

  group('signup guards the password properly', () {
    testWidgets('a mismatched confirmation is refused on the phone', (
      tester,
    ) async {
      await pump(tester, const SignupScreen());
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kweku'),
        'Kweku',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Adeola'),
        'Adeola',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. sharpshooter01'),
        'sharp01',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'you@example.com'),
        'me@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'At least 8 characters'),
        'longenough',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Type it once more'),
        'different1',
      );
      await tapScrolled(tester, find.text('Continue'));
      expect(find.text('The two passwords do not match.'), findsOneWidget);
      expect(find.text('Step 1 of 2'), findsOneWidget);
    });

    testWidgets('typing a password shows its strength', (tester) async {
      await pump(tester, const SignupScreen());
      await tester.enterText(
        find.widgetWithText(TextFormField, 'At least 8 characters'),
        'longenough',
      );
      await tester.pump();
      expect(find.text('Weak'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'At least 8 characters'),
        'MuchStronger#2024!',
      );
      await tester.pump();
      expect(find.text('Strong'), findsOneWidget);
    });
  });
}
