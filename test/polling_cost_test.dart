import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/gram/gram_repository.dart';
import 'package:lockinpoint/features/gram/gram_screen.dart';

/// ===========================================================================
/// WHAT THE APP ASKS FOR WHEN NOBODY IS LOOKING
///
/// A Pointgram room polls every twelve seconds and heartbeats every fifteen.
/// Both kept firing after the student switched to WhatsApp: NINE REQUESTS A
/// MINUTE from a screen nobody could see — data the student is paying for at
/// one end and invocations the owner is paying for at the other. The OS
/// suspends the process eventually; "eventually" is minutes on Android and
/// never on desktop or web.
///
/// This counts real requests across a real backgrounding, which is the only
/// way to know whether the architecture actually asks for less.
/// ===========================================================================
class _Counting extends Fake implements Api {
  int gets = 0;
  int posts = 0;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    gets++;
    return {
      'ok': true,
      'messages': const [],
      'typing': const [],
      'online': const [],
      'groups': const [],
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    posts++;
    return {'ok': true};
  }
}

Future<void> _openRoom(WidgetTester tester, Api api) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: LipTheme.light(),
        home: const GramRoomScreen(
          room: GramRoom(
            id: 'g1',
            name: 'The Main Hall',
            description: '',
            status: 'approved',
            unread: 0,
            last: '',
            locked: false,
            joinMode: 'open',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('a backgrounded room asks the server for nothing', (
    tester,
  ) async {
    final api = _Counting();
    await _openRoom(tester, api);

    // A minute on screen: the room stays current.
    await tester.pump(const Duration(seconds: 60));
    final whileWatching = api.gets + api.posts;
    expect(
      whileWatching,
      greaterThan(1),
      reason: 'a room on screen should be polling at all',
    );

    // The student switches to WhatsApp.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final atPause = api.gets + api.posts;

    // Five minutes in another app.
    await tester.pump(const Duration(minutes: 5));

    expect(
      api.gets + api.posts,
      atPause,
      reason:
          'the room kept polling while the app was in the background — '
          'that is the student paying for data on a screen they cannot see, '
          'and the owner paying for the invocations',
    );

    // And it is current the instant they come back, rather than up to
    // twelve seconds behind.
    /* The real transition a phone makes, which differs by platform: Android
       goes paused -> resumed, iOS goes hidden -> inactive -> resumed. Driving
       it through the states rather than jumping is what the OS does. */
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      api.gets + api.posts,
      greaterThan(atPause),
      reason: 'coming back should bring the room up to date at once',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
