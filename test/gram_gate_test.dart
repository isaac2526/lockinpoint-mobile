import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/gram/gram_repository.dart';
import 'package:lockinpoint/features/gram/gram_screen.dart';

/// ===========================================================================
/// THE DOOR, THE HEARTBEAT, THE REACTIONS AND THE POLL.
///
/// Four routes the website has used since Pointgram shipped and no client on
/// a phone had ever called once. The consequences were not cosmetic: a locked
/// Pointgram was impassable from the app, a student sitting in a room was
/// invisible to everyone else in it, and a poll arrived as an empty grey
/// bubble with nothing in it to answer.
/// ===========================================================================

/// The code the tutors set. Fixed rather than a parameter: every test that
/// cares about it wants the same one, and a knob nothing turns is a knob that
/// goes stale.
const _rightPin = '3513';

class _Gram extends Fake implements Api {
  _Gram({
    this.locked = false,
    this.enabled = true,
    this.poll = false,
    this.quiz = false,
    this.image = false,
  });

  final bool locked;
  final bool enabled;
  final bool poll;
  final bool quiz;
  final bool image;

  /// Every path this fake was asked for, so a test can hold that the app
  /// SENT the request rather than merely rendering as if it had.
  final List<String> got = [];
  final List<String> posted = [];

  /// Set once the right code has been presented — the server's own state,
  /// mirrored here so the second GET answers differently to the first.
  bool _passed = false;

  @override
  String? gramPin;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    got.add(path);
    if (path == '/api/gram/gate') {
      return {
        'ok': true,
        'enabled': enabled,
        'locked': locked,
        'passed': _passed,
        'online': [
          {'username': 'ada', 'activated': true},
        ],
        'me': {'kind': 'student', 'uid': 'u1', 'username': 'me'},
      };
    }
    if (path == '/api/gram/groups') {
      return {
        'ok': true,
        'dmUnread': 0,
        'groups': [
          {
            'id': 'g1',
            'name': 'The Main Hall',
            'membership': 'approved',
            'unread': 0,
            'locked': false,
          },
        ],
      };
    }
    return {
      'ok': true,
      'canPost': true,
      'online': 4,
      'memberCount': 11,
      'typing': const [],
      'messages': [
        {
          'id': 'm1',
          'user_id': 'u1',
          'who': 'me',
          'body': quiz
              ? 'Quiz drop'
              : poll
              ? ''
              : 'Read chapter four.',
          'type': quiz
              ? 'quiz'
              : image
              ? 'image'
              : poll
              ? 'poll'
              : 'text',
          'media_url': image ? 'https://example.test/p.jpg' : null,
          'meta': quiz
              ? {
                  'q': {
                    'question': 'What is the SI unit of force?',
                    'options': ['Newton', 'Joule'],
                    'letters': ['A', 'B'],
                    'answer': 'A',
                  },
                }
              : poll
              ? {
                  'options': ['Yes', 'No'],
                }
              : null,
          'at': DateTime.now().toIso8601String(),
        },
      ],
      'reactions': [
        {'message_id': 'm1', 'user_id': 'u1', 'icon': 'fire'},
        {'message_id': 'm1', 'user_id': 'u2', 'icon': 'fire'},
        {'message_id': 'm1', 'user_id': 'u3', 'icon': 'star'},
      ],
      'votes': poll
          ? [
              {'message_id': 'm1', 'user_id': 'u2', 'option_index': 0},
            ]
          : const [],
    };
  }

  @override
  Future<Map<String, dynamic>> patch(String path, {Object? body}) async {
    posted.add('PATCH $path');
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    posted.add(path);
    if (path == '/api/gram/gate') {
      final pin = (body as Map)['pin'];
      if (pin != _rightPin) {
        return {'ok': false, 'message': 'That is not the room code.'};
      }
      _passed = true;
      return {'ok': true};
    }
    return {'ok': true};
  }
}

Future<void> _open(WidgetTester tester, Api api, {Widget? home}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: LipTheme.light(),
        home: home ?? const GramScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  /* A FRESH PHONE FOR EACH TEST. The mock preference store is shared across
     every test in a file, so the room code remembered by the test above was
     still on disk for the test below — and "a wrong code remembers nothing"
     passed or failed depending on which order the tests ran in. */
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a locked Pointgram offers a way in, not a dead end', (
    tester,
  ) async {
    await _open(tester, _Gram(locked: true));
    expect(find.text('The rooms are locked'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('the right code opens the door and the rooms load', (
    tester,
  ) async {
    final api = _Gram(locked: true);
    await _open(tester, api);
    await tester.enterText(find.byType(TextField), '3513');
    await tester.tap(find.text('Go in'));
    await tester.pumpAndSettle();

    // The code is on the CLIENT, which is how every later request carries it.
    expect(api.gramPin, '3513');
    expect(find.text('The Main Hall'), findsOneWidget);
  });

  testWidgets('a wrong code says the server’s words and keeps the door shut', (
    tester,
  ) async {
    final api = _Gram(locked: true);
    await _open(tester, api);
    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Go in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not the room code'), findsOneWidget);
    // Nothing is remembered, and nothing behind the door was asked for.
    expect(api.gramPin, isNull);
    expect(api.got, isNot(contains('/api/gram/groups')));
  });

  testWidgets('Pointgram switched off entirely is a door, not a code box', (
    tester,
  ) async {
    await _open(tester, _Gram(enabled: false));
    expect(find.text('The rooms are locked'), findsNothing);
    expect(find.text('The rooms are closed'), findsOneWidget);
  });

  testWidgets('opening a room says I am here', (tester) async {
    final api = _Gram();
    await _open(
      tester,
      api,
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
    );
    // Without this the student is invisible in a room they are sitting in.
    expect(api.posted, contains('/api/gram/ping'));
  });

  testWidgets('who is here is shown, because the room has always sent it', (
    tester,
  ) async {
    await _open(
      tester,
      _Gram(),
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
    );
    expect(find.text('4 here now · 11 in this room'), findsOneWidget);
  });

  testWidgets('reactions are counted, and my own is marked', (tester) async {
    final api = _Gram();
    await _open(
      tester,
      api,
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
    );
    // Two people chose fire, one chose star.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(api.posted, contains('/api/gram/messages/m1/react'));
  });

  testWidgets('a quiz drop is a question, not the words "Quiz drop"', (
    tester,
  ) async {
    /* It arrived as a bubble containing the two words the website sends as a
       fallback body. The stem, the options and the answer all ride in `meta`,
       and the app discarded `meta` entirely. */
    await _open(
      tester,
      _Gram(quiz: true),
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
    );
    /* The stem and the options are drawn as HTML, so they are TextSpans
       rather than Text widgets and find.text cannot see them — which is why
       this asserts on the widget and on the option letters, both of which
       are real. */
    expect(find.byType(GramQuizDrop), findsOneWidget);
    expect(find.text('A. '), findsOneWidget);
    expect(find.text('B. '), findsOneWidget);

    await tester.tap(find.text('A. '));
    await tester.pumpAndSettle();
    // The answer comes down with the drop; nothing is asked of the server and
    // nothing is scored. It is a moment in a conversation.
    expect(find.text('Correct.'), findsOneWidget);
  });

  testWidgets('a picture is a picture, not a sentence about a browser', (
    tester,
  ) async {
    /* pumpAndSettle would never return here: CachedNetworkImage starts a
       real HTTP fetch that never resolves in a test binding, so the frame
       scheduler never goes quiet. Fixed pumps instead — this test is about
       what is BUILT, not about a picture arriving. */
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(_Gram(image: true))],
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
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.textContaining('open in the browser'), findsNothing);
  });

  testWidgets('you can take back a message you sent', (tester) async {
    final api = _Gram();
    await _open(
      tester,
      api,
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
    );
    // A button, not a long-press: a long-press on the bubble is eaten by the
    // SelectableText inside it, so the student gets the copy menu instead.
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Delete this message?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    // PATCH, not POST: the route creates nothing and a POST would 405.
    expect(api.posted, contains('PATCH /api/gram/messages/m1'));
  });

  testWidgets('a poll can be answered', (tester) async {
    final api = _Gram(poll: true);
    await _open(
      tester,
      api,
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
    );
    // The options ride inside meta and the app used to drop them entirely.
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    expect(find.text('One vote'), findsOneWidget);

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(api.posted, contains('/api/gram/messages/m1/vote'));
  });
}
