import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/home/dashboard_screen.dart';
import 'package:lockinpoint/features/profile/profile_screen.dart';

/// ===========================================================================
/// The profile screen, fed the same payload the dashboard holds.
///
/// No network: the screen's whole contract is "render the student the server
/// already described". These prove the identity is shown, the activation
/// state is told straight, the referral link is copyable, and the doors —
/// WhatsApp, email, appearance, log out — are all present.
/// ===========================================================================
class _FakeDashboard extends DashboardController {
  _FakeDashboard(this._payload);
  final Map<String, dynamic> _payload;

  @override
  Future<Map<String, dynamic>> build() async => _payload;
}

const _student = {
  'ok': true,
  'frozen': false,
  'student': {
    'name': 'Adaeze',
    'surname': 'Okafor',
    'email': 'adaeze@example.com',
    'username': 'ada_the_great',
    'phone': '8012345678',
    'dialCode': '+234',
    'countryCode': 'NG',
    'activated': true,
    'emailVerified': true,
    'streak': 3,
    'referralCode': 'AB2CD',
  },
  'counts': {'questions': 100, 'attempts': 2, 'notes': 5},
  'resume': null,
};

Future<void> _pump(
  WidgetTester tester, {
  Map<String, dynamic> payload = _student,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardProvider.overrideWith(() => _FakeDashboard(payload)),
      ],
      child: MaterialApp(theme: LipTheme.light(), home: const ProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows who the account belongs to', (tester) async {
    await _pump(tester);
    expect(find.text('Adaeze Okafor'), findsOneWidget);
    expect(find.text('adaeze@example.com'), findsOneWidget);
    expect(find.text('ada_the_great'), findsOneWidget);
    expect(find.text('+234 8012345678'), findsOneWidget);
    expect(find.text('NG'), findsOneWidget);
  });

  testWidgets('an activated account is told so, plainly', (tester) async {
    await _pump(tester);
    expect(find.text('Activated'), findsOneWidget);
    expect(find.text('Not activated yet'), findsNothing);
  });

  testWidgets('an unactivated account is not flattered', (tester) async {
    final p = Map<String, dynamic>.from(_student);
    p['student'] = {
      ...(_student['student']! as Map<String, dynamic>),
      'activated': false,
    };
    await _pump(tester, payload: p);
    expect(find.text('Not activated yet'), findsOneWidget);
  });

  testWidgets('tapping the referral banner copies the signup link', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );

    await _pump(tester);
    await tester.tap(find.text('Refer and earn ₦500'));
    await tester.pump();
    expect(copied, contains('/signup?ref=AB2CD'));
  });

  testWidgets('holds every door: WhatsApp, email, appearance, log out', (
    tester,
  ) async {
    await _pump(tester);

    // The test surface is shorter than a phone, and a ListView only builds
    // what is on screen — so walk down to each door before asserting it.
    Future<void> see(String text) async {
      await tester.dragUntilVisible(
        find.text(text),
        find.byType(ListView),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
    }

    await see('System');
    await see('Light');
    await see('Dark');
    await see('Join the WhatsApp channel');
    await see('Email the tutors');
    await see('Log out');
  });

  testWidgets('a student with no referral code sees no banner', (tester) async {
    final p = Map<String, dynamic>.from(_student);
    p['student'] = {
      ...(_student['student']! as Map<String, dynamic>),
      'referralCode': null,
    };
    await _pump(tester, payload: p);
    expect(find.text('Refer and earn ₦500'), findsNothing);
  });

  testWidgets('the dashboard header opens the profile', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(() => _FakeDashboard(_student)),
        ],
        child: MaterialApp(
          theme: LipTheme.light(),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Open your profile'));
    await tester.pumpAndSettle();
    expect(find.text('Adaeze Okafor'), findsOneWidget);
    semantics.dispose();
  });
}
