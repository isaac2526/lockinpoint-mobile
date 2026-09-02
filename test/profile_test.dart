import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/content/content_repository.dart';
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
    'productKey': 'LIP-7K4M-92QT',
    'state': 'Ekiti',
  },
  'counts': {'questions': 100, 'attempts': 2, 'notes': 5},
  'resume': null,
};

/// Two support contacts, as the backend would send them. The app carries no
/// phone numbers of its own any more, so a test that wants to see one has to
/// supply it — which is exactly the point.
const _contacts = [
  SupportContact(
    kind: 'whatsapp',
    label: 'WhatsApp support',
    value: '+2348012345678',
    description: 'Fastest reply',
  ),
  SupportContact(
    kind: 'email',
    label: 'Email the tutors',
    value: 'help@example.com',
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  Map<String, dynamic> payload = _student,
  List<SupportContact> contacts = _contacts,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardProvider.overrideWith(() => _FakeDashboard(payload)),
        supportContactsProvider.overrideWith((ref) async => contacts),
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
    /* A COUNTRY, NOT A COLUMN VALUE. The profile printed the stored code —
       "NG" — at a human. It names the country now, so this asserts on what
       the student actually reads. */
    expect(find.text('🇳🇬  Nigeria'), findsOneWidget);
    expect(find.text('NG'), findsNothing);
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

  /// The test surface is shorter than a phone, and a ListView only builds
  /// what is on screen — so walk down to each door before asserting it.
  Future<void> see(WidgetTester tester, String text) async {
    await tester.dragUntilVisible(
      find.text(text),
      find.byType(ListView),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(find.text(text), findsOneWidget);
  }

  testWidgets('holds every door: appearance, guardian, contacts, log out', (
    tester,
  ) async {
    await _pump(tester);
    await see(tester, 'System');
    await see(tester, 'Light');
    await see(tester, 'Dark');
    await see(tester, 'Guardian Portal');
    await see(tester, 'Log out');
  });

  testWidgets('support contacts are the BACKEND\'s, not the app\'s', (
    tester,
  ) async {
    await _pump(tester);
    // Both labels come from the fake backend rows above. Nothing in the app
    // knows a phone number or an address of its own.
    await see(tester, 'WhatsApp support');
    await see(tester, 'Email the tutors');
    await see(tester, 'Fastest reply');
  });

  testWidgets('a channel is a LIST: two numbers show as two rows', (
    tester,
  ) async {
    await _pump(
      tester,
      contacts: const [
        SupportContact(
          kind: 'phone',
          label: 'Support line 1',
          value: '+2348012345678',
        ),
        SupportContact(
          kind: 'phone',
          label: 'Support line 2',
          value: '+2348077778195',
        ),
      ],
    );
    await see(tester, 'Support line 1');
    await see(tester, 'Support line 2');
  });

  testWidgets('no contacts configured yet still leaves the portal reachable', (
    tester,
  ) async {
    await _pump(tester, contacts: const []);
    await see(tester, 'Guardian Portal');
    await see(tester, 'Log out');
  });

  testWidgets('the Product Key is shown, explained and copyable', (
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
    expect(find.text('LIP-7K4M-92QT'), findsOneWidget);
    // It must never be mistaken for a password or a licence.
    expect(find.textContaining('not a password'), findsOneWidget);

    await tester.tap(find.text('LIP-7K4M-92QT'));
    await tester.pump();
    expect(copied, 'LIP-7K4M-92QT');
  });

  testWidgets('a student with no Product Key yet sees no key card', (
    tester,
  ) async {
    final p = Map<String, dynamic>.from(_student);
    p['student'] = {
      ...(_student['student']! as Map<String, dynamic>),
      'productKey': null,
    };
    await _pump(tester, payload: p);
    expect(find.text('YOUR PRODUCT KEY'), findsNothing);
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
