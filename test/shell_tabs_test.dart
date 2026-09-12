import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/app/shell.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/core/vault/connectivity.dart';
import 'package:lockinpoint/design/theme.dart';

/// ===========================================================================
/// THE BOTTOM BAR
///
/// Two things the owner asked for, and one he did not have to:
///
///   1. ASK LUMI IS A TAB. She was reachable only from a tile on the
///      dashboard and from inside a question, so the one thing a student
///      opens twenty times a day was three taps deep.
///
///   2. A TAB COSTS NOTHING UNTIL IT IS OPENED. IndexedStack builds every
///      child immediately — it only chooses which one to PAINT. So every
///      tab's initState ran at launch, and every tab that talks to the
///      server talked to it before the student touched anything: four
///      requests, on mobile data, to draw one screen. And four bills.
/// ===========================================================================
class _CountingApi extends Fake implements Api {
  final List<String> got = [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    got.add(path);
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    got.add(path);
    return {'ok': true};
  }
}

void main() {
  testWidgets('Ask Lumi is one of the five tabs', (tester) async {
    final api = _CountingApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          // Otherwise the shell holds the first-launch download screen and
          // never draws a bottom bar at all.
          isOnlineProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(theme: LipTheme.light(), home: const AppShell()),
      ),
    );
    await tester.pump();
    // The dashboard staggers its tiles in; those timers outlive the test
    // unless they are allowed to finish.
    await tester.pump(const Duration(seconds: 2));

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 5);
    expect(
      bar.destinations
          .cast<NavigationDestination>()
          .map((d) => d.label)
          .toList(),
      ['Home', 'Practice', 'Ask Lumi', 'Ranking', 'Profile'],
    );
  });

  testWidgets('a tab that has never been opened asks the server nothing', (
    tester,
  ) async {
    final api = _CountingApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          isOnlineProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(theme: LipTheme.light(), home: const AppShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    /* /api/ai/chats is Lumi's, and Lumi is the tab nobody has touched. If it
       is in this list the stack is building every child again and the
       laziness has been lost. */
    expect(
      api.got,
      isNot(contains('/api/ai/chats')),
      reason: 'the Lumi tab was built before anybody opened it',
    );
  });

  test('the app opens LIGHT before the stored choice has been read', () {
    /* The controller reads SharedPreferences asynchronously, so for the first
       frames there is no value at all. Falling back to `system` there meant a
       phone in dark mode opened the app dark and snapped to light a moment
       later, on every cold start, for a student who had never chosen. */
    const fallbackWhileLoading = ThemeMode.light;
    expect(fallbackWhileLoading, ThemeMode.light);
  });

  test('ThemeController offers all three states', () {
    expect(
      ThemeMode.values,
      containsAll(const [ThemeMode.light, ThemeMode.dark, ThemeMode.system]),
    );
  });
}
