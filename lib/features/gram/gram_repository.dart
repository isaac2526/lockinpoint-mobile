import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// POINTGRAM · the rooms, on the phone.
///
/// Twelve endpoints, and the app called none of them — because it could not.
/// gramIdentity() read a COOKIE and the app carries a bearer token, so every
/// one of them answered 401. That is fixed on the server; this is the client.
///
/// A ROOM IS NOT A CHAT APP. It is a study room with a tutor in it: class
/// mode silences students, slow mode paces them, and the server is the
/// bouncer for all of it. Nothing here decides what may be posted — it asks,
/// and says whatever the server says back.
/// ===========================================================================

class GramRoom {
  const GramRoom({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.unread,
    required this.last,
    required this.locked,
    required this.joinMode,
  });

  factory GramRoom.from(Map<dynamic, dynamic> m) => GramRoom(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? 'Room',
    description: m['description'] as String? ?? '',
    /* The server calls it `membership`: 'none' before joining, 'pending'
       while a tutor decides, 'approved' once in, 'tutor' for staff. */
    status: m['membership'] as String? ?? 'none',
    unread: (m['unread'] as int?) ?? 0,
    last: m['last'] is Map
        ? [
            (m['last'] as Map)['who'] as String?,
            (m['last'] as Map)['body'] as String?,
          ].where((s) => s != null && s.isNotEmpty).join(': ')
        : '',
    locked: m['locked'] == true,
    joinMode: m['join_mode'] as String? ?? m['joinMode'] as String? ?? 'open',
  );

  final String id;
  final String name;
  final String description;
  final String status;
  final int unread;
  final String last;

  /// Class mode: only the tutors may speak.
  final bool locked;
  final String joinMode;

  bool get joined => status == 'approved' || status == 'tutor';
  bool get waiting => status == 'pending';
}

class GramMessage {
  const GramMessage({
    required this.id,
    required this.who,
    required this.body,
    required this.tutor,
    required this.mine,
    required this.deleted,
    required this.at,
    this.type = 'text',
  });

  factory GramMessage.from(
    Map<dynamic, dynamic> m,
    String? myId,
  ) => GramMessage(
    id: m['id'] as String? ?? '',
    who: m['who'] as String? ?? 'student',
    body: m['body'] as String? ?? '',
    // The orange tick. A tutor's word in a study room carries weight and has
    // to be distinguishable from a confident classmate's.
    tutor: m['tutor'] == true,
    mine: myId != null && m['user_id'] == myId,
    deleted: m['deleted'] == true,
    type: m['type'] as String? ?? 'text',
    at: DateTime.tryParse('${m['at'] ?? ''}'),
  );

  final String id;
  final String who;
  final String body;
  final bool tutor;
  final bool mine;
  final bool deleted;
  final String type;
  final DateTime? at;
}

class GramFeed {
  const GramFeed({
    required this.messages,
    required this.canPost,
    required this.blockedBecause,
  });

  final List<GramMessage> messages;
  final bool canPost;

  /// The server's own sentence — "Class mode is on. Only the tutors can speak
  /// for now." Never guessed at from a status code.
  final String blockedBecause;
}

class GramLobby {
  const GramLobby({
    required this.rooms,
    required this.dmUnread,
    required this.open,
    required this.locked,
  });

  final List<GramRoom> rooms;
  final int dmUnread;

  /// False when an admin has switched Pointgram off entirely.
  final bool open;

  /// True when the rooms are behind the shared code.
  final bool locked;
}

final gramLobbyProvider = FutureProvider<GramLobby>((ref) async {
  final api = ref.read(apiProvider);
  try {
    final res = await api.get('/api/gram/groups');
    return GramLobby(
      rooms: ((res['groups'] as List?) ?? const [])
          .whereType<Map>()
          .map(GramRoom.from)
          .toList(),
      dmUnread: (res['dmUnread'] as int?) ?? 0,
      open: true,
      locked: false,
    );
  } on ApiFailure catch (e) {
    /* "gate" is the server's word for "the rooms are locked or switched off".
       Told apart from a real failure, because one is a door and the other is
       a fault, and a student deserves to know which. */
    if (e.message.contains('gate')) {
      return const GramLobby(rooms: [], dmUnread: 0, open: false, locked: true);
    }
    rethrow;
  }
});

Future<GramFeed> loadRoom(
  Api api, {
  String? groupId,
  bool dm = false,
  String? myId,
}) async {
  final res = await api.get(
    '/api/gram/messages',
    query: {'group': ?groupId, if (dm) 'dm': '1'},
  );
  return GramFeed(
    messages: ((res['messages'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => GramMessage.from(m, myId))
        .toList(),
    canPost: res['canPost'] != false,
    blockedBecause: res['postBlock'] as String? ?? '',
  );
}

/// Sends one line. The server is the bouncer — freeze, class mode, slow mode
/// and the twenty-a-minute ceiling all live there — so a refusal comes back
/// as a sentence to show, never as something the app has to interpret.
Future<String?> sendGram(
  Api api, {
  String? groupId,
  bool dm = false,
  required String body,
}) async {
  try {
    await api.post(
      '/api/gram/messages',
      body: {
        'group': ?groupId,
        if (dm) 'dm': true,
        'type': 'text',
        'body': body,
      },
    );
    return null;
  } on ApiFailure catch (e) {
    return e.message;
  }
}

Future<String?> joinRoom(Api api, String groupId) async {
  try {
    final res = await api.post(
      '/api/gram/groups/$groupId',
      body: {'op': 'join'},
    );
    return res['message'] as String?;
  } on ApiFailure catch (e) {
    return e.message;
  }
}
