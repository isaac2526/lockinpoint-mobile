import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/gram/gram_repository.dart';
import 'package:lockinpoint/features/gram/gram_screen.dart';

/// ===========================================================================
/// POINTGRAM.
///
/// A room is not a chat app — it is a study room with a tutor in it. Class
/// mode silences students, slow mode paces them, a frozen account reads but
/// does not speak, and the SERVER decides all of it.
///
/// The rule these hold: the app never invents a reason. "Class mode is on,
/// only the tutors can speak for now" is a different thing to a student than
/// "could not send", and the second is what you get the moment a client
/// starts guessing from status codes.
/// ===========================================================================

class _Rooms extends Fake implements Api {
  _Rooms({this.refusal, this.gate = false});
  final String? refusal;
  final bool gate;
  final List<String> posted = [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (gate) throw ApiFailure('gate');
    if (path == '/api/gram/groups') {
      return {
        'ok': true,
        'dmUnread': 2,
        'groups': [
          {
            'id': 'g1',
            'name': 'The Main Hall',
            'description': 'Everyone',
            'membership': 'approved',
            'unread': 5,
            'locked': false,
            'last': {'who': null, 'body': 'see you tomorrow'},
          },
          {
            'id': 'g2',
            'name': 'Physics Clinic',
            'membership': 'none',
            'unread': 0,
            'locked': true,
          },
        ],
      };
    }
    return {
      'ok': true,
      'canPost': refusal == null,
      'postBlock': refusal ?? '',
      'messages': [
        {
          'id': 'm1',
          'who': 'Tutor Bello',
          'body': 'Read chapter four tonight.',
          'tutor': true,
          'at': DateTime.now().toIso8601String(),
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    if (refusal != null) throw ApiFailure(refusal!);
    posted.add(((body as Map)['body'] ?? '').toString());
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
  testWidgets('the Tutor Line comes first, and carries its own unread', (
    tester,
  ) async {
    await _open(tester, _Rooms());
    expect(find.text('Tutor Line'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('The Main Hall'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('a room switched off reads as a door, not as a fault', (
    tester,
  ) async {
    // "gate" is the server's word for locked-or-off. Told apart from a real
    // failure, because one is a door and the other is a bug, and a student
    // deserves to know which they are looking at.
    await _open(tester, _Rooms(gate: true));
    expect(find.text('The rooms are closed'), findsOneWidget);
  });

  testWidgets("a room you have not joined offers to join, not to type", (
    tester,
  ) async {
    await _open(tester, _Rooms());
    await tester.tap(find.text('Physics Clinic'));
    await tester.pumpAndSettle();
    expect(find.text('Join this room'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('class mode is announced, and shown as the server worded it', (
    tester,
  ) async {
    const said = 'Class mode is on. Only the tutors can speak for now.';
    await _open(
      tester,
      _Rooms(refusal: said),
      home: const GramRoomScreen(
        room: GramRoom(
          id: 'g1',
          name: 'The Main Hall',
          description: '',
          status: 'approved',
          unread: 0,
          last: '',
          locked: true,
          joinMode: 'open',
        ),
      ),
    );
    expect(
      find.text('Class mode · only the tutors are speaking'),
      findsOneWidget,
    );
    // The SERVER's sentence, standing where the placeholder would be, never a
    // guess made from a status code.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.hintText, said);
    expect(field.enabled, isFalse);
  });

  testWidgets("a tutor's line is marked, so it is not read as a classmate's", (
    tester,
  ) async {
    await _open(tester, _Rooms(), home: const GramRoomScreen(dm: true));
    expect(find.text('Tutor Bello'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });

  test('membership is read from the field the server actually sends', () {
    // `membership`, not `status` — and a tutor counts as in.
    expect(GramRoom.from({'membership': 'approved'}).joined, isTrue);
    expect(GramRoom.from({'membership': 'tutor'}).joined, isTrue);
    expect(GramRoom.from({'membership': 'pending'}).waiting, isTrue);
    expect(GramRoom.from({'membership': 'none'}).joined, isFalse);
  });
}
