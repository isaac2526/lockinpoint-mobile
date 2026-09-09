import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import 'gram_gate.dart';

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
    this.options = const [],
    this.mediaUrl = '',
    this.quiz,
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
    options:
        ((m['meta'] as Map?)?['options'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    mediaUrl: m['media_url'] as String? ?? '',
    quiz: GramQuiz.from(m['meta'] as Map?),
  );

  final String id;
  final String who;
  final String body;
  final bool tutor;
  final bool mine;
  final bool deleted;
  final String type;
  final DateTime? at;

  /// A poll's choices, in the order the tutor wrote them. Empty for every
  /// other kind of message. The website has always sent these inside `meta`
  /// and the app dropped them, so a poll arrived as an empty grey bubble.
  final List<String> options;

  /// Anything with a URL — an image, a voice note. Empty when there is none.
  final String mediaUrl;

  /// A quiz drop's question, straight out of the real bank.
  ///
  /// The app used to render one as a bubble containing the two words "Quiz
  /// drop" — the body the website sends as a fallback — and threw the
  /// question, the options and the answer away with the rest of `meta`.
  final GramQuiz? quiz;
}

/// A question dropped into a room from the real bank.
class GramQuiz {
  const GramQuiz({
    required this.question,
    required this.options,
    required this.letters,
    required this.answer,
  });

  final String question;
  final List<String> options;
  final List<String> letters;

  /// The correct letter. It arrives WITH the drop — the room reveals on tap
  /// rather than asking the server, because a quiz drop is a moment in a
  /// conversation, not a graded sitting.
  final String answer;

  static GramQuiz? from(Map<dynamic, dynamic>? meta) {
    final q = (meta?['q'] as Map?)?.cast<String, dynamic>();
    if (q == null) return null;
    final options = ((q['options'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    if (options.isEmpty) return null;
    return GramQuiz(
      question: q['question'] as String? ?? '',
      options: options,
      letters: ((q['letters'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      answer: (q['answer'] as String? ?? '').toUpperCase(),
    );
  }
}

class GramFeed {
  const GramFeed({
    required this.messages,
    required this.canPost,
    required this.blockedBecause,
    this.reactions = const {},
    this.myReactions = const {},
    this.votes = const {},
    this.myVotes = const {},
    this.typing = const [],
    this.online = 0,
    this.memberCount = 0,
  });

  final List<GramMessage> messages;
  final bool canPost;

  /// The server's own sentence — "Class mode is on. Only the tutors can speak
  /// for now." Never guessed at from a status code.
  final String blockedBecause;

  /// message id -> icon -> how many people chose it.
  final Map<String, Map<String, int>> reactions;

  /// message id -> the icon I chose, so tapping it again takes it back rather
  /// than adding a second.
  final Map<String, String> myReactions;

  /// poll message id -> option index -> how many votes.
  final Map<String, Map<int, int>> votes;

  /// poll message id -> the option I chose.
  final Map<String, int> myVotes;

  /// Who is typing or recording right now, in their own words from the
  /// server: "ada is typing".
  final List<({String username, String state})> typing;

  /// How many are alive in this room, and how many belong to it.
  final int online;
  final int memberCount;
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
  /* THE GATE IS AWAITED FIRST, AND NOT ONLY FOR ITS ANSWER.
     Reading it is what puts the remembered room code onto the client. Asking
     for the rooms before that resolves sends a request with no code, which a
     locked Pointgram refuses — and the student is then asked to type a code
     they gave last week. */
  final gate = await ref.watch(gramGateProvider.future);
  if (!gate.open) {
    return GramLobby(
      rooms: const [],
      dmUnread: 0,
      open: gate.enabled,
      locked: gate.locked,
    );
  }

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
    /* THE OLD GUESS, KEPT AS A BACKSTOP. This used to look for the word
       "gate" inside a failure message to decide whether the rooms were shut —
       a guess that broke the moment the sentence was reworded. The gate above
       now states it outright; this only catches a lock switched on between
       the two requests. */
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
  /* REACTIONS AND VOTES ARRIVE AS FLAT ROWS — one per person per message —
     and are folded here rather than on every rebuild. A room with two hundred
     messages and a thousand reactions would otherwise walk that list once per
     bubble, sixty times a second, on the cheapest phone we sell to. */
  final reactions = <String, Map<String, int>>{};
  final myReactions = <String, String>{};
  for (final r in ((res['reactions'] as List?) ?? const []).whereType<Map>()) {
    final mid = r['message_id'] as String? ?? '';
    final icon = r['icon'] as String? ?? '';
    if (mid.isEmpty || icon.isEmpty) continue;
    reactions.putIfAbsent(mid, () => {});
    reactions[mid]![icon] = (reactions[mid]![icon] ?? 0) + 1;
    if (myId != null && r['user_id'] == myId) myReactions[mid] = icon;
  }

  final votes = <String, Map<int, int>>{};
  final myVotes = <String, int>{};
  for (final v in ((res['votes'] as List?) ?? const []).whereType<Map>()) {
    final mid = v['message_id'] as String? ?? '';
    final idx = (v['option_index'] as num?)?.toInt();
    if (mid.isEmpty || idx == null) continue;
    votes.putIfAbsent(mid, () => {});
    votes[mid]![idx] = (votes[mid]![idx] ?? 0) + 1;
    if (myId != null && v['user_id'] == myId) myVotes[mid] = idx;
  }

  return GramFeed(
    messages: ((res['messages'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => GramMessage.from(m, myId))
        .toList(),
    canPost: res['canPost'] != false,
    blockedBecause: res['postBlock'] as String? ?? '',
    reactions: reactions,
    myReactions: myReactions,
    votes: votes,
    myVotes: myVotes,
    typing: ((res['typing'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (m) => (
            username: m['username'] as String? ?? 'someone',
            state: m['state'] as String? ?? 'typing',
          ),
        )
        .toList(),
    online: (res['online'] as num?)?.toInt() ?? 0,
    memberCount: (res['memberCount'] as num?)?.toInt() ?? 0,
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

/// ===========================================================================
/// THE REST OF WHAT A ROOM DOES
///
/// Three routes the website has used since Pointgram shipped and the app had
/// never called once: the heartbeat that puts a student in everyone else's
/// Online list, the six reactions, and the poll vote. A room where nobody
/// appears online, nothing can be reacted to and a poll cannot be answered is
/// a message list, not a room.
/// ===========================================================================

/// I am here, in this room. Called every few seconds while a room is open.
///
/// Fire and forget in the strongest sense: a heartbeat that fails changes
/// nothing a student can see except a name missing from a list for forty-five
/// seconds, and it must never interrupt reading or typing.
Future<void> gramPing(
  Api api, {
  String? groupId,
  String state = 'online',
}) async {
  try {
    await api.post('/api/gram/ping', body: {'group': ?groupId, 'state': state});
  } catch (_) {
    // See above.
  }
}

/// The six, and only the six. The server refuses anything else, so the app
/// offers nothing else — a picker showing an icon that will be rejected is
/// worse than a shorter picker.
const gramReactionIcons = <String>[
  'fire',
  'star',
  'check',
  'trophy',
  'diamond',
  'robot',
];

/// Tap an icon to add it; tap the same one again to take it back; tap another
/// to switch. One per person per message — the server enforces that, and the
/// app must not pretend otherwise by showing two of mine.
Future<String?> reactToGram(Api api, String messageId, String icon) async {
  try {
    final res = await api.post(
      '/api/gram/messages/$messageId/react',
      body: {'icon': icon},
    );
    return res['ok'] == false
        ? (res['message'] as String? ?? 'Not that one.')
        : null;
  } on ApiFailure catch (e) {
    return e.message;
  }
}

/// One vote per person per poll. Changing your mind moves it rather than
/// adding a second.
Future<String?> voteInGram(Api api, String messageId, int option) async {
  try {
    final res = await api.post(
      '/api/gram/messages/$messageId/vote',
      body: {'option': option},
    );
    return res['ok'] == false ? 'That vote did not go through.' : null;
  } on ApiFailure catch (e) {
    return e.message;
  }
}

/// Sends a picture into a room.
///
/// THE COMPOSER COULD SEND TEXT AND NOTHING ELSE. /api/gram/upload has been
/// there since Pointgram shipped and no client on a phone ever called it, so
/// a student could see that pictures existed — badly, as a grey sentence
/// telling them to open a browser — and could never send one.
///
/// The upload and the message are two steps on purpose: a picture that
/// uploads but whose message fails is recoverable, and one message carrying
/// four megabytes of body is not.
Future<String?> sendGramImage(
  Api api, {
  String? groupId,
  bool dm = false,
  required String filePath,
  String caption = '',
}) async {
  try {
    final up = await api.upload(
      '/api/gram/upload',
      filePath: filePath,
      fieldName: 'file',
    );
    final url = up['url'] as String? ?? '';
    if (up['ok'] == false || url.isEmpty) {
      return up['message'] as String? ?? 'That picture would not upload.';
    }
    await api.post(
      '/api/gram/messages',
      body: {
        'group': ?groupId,
        if (dm) 'dm': true,
        'type': 'image',
        'body': caption,
        'media_url': url,
      },
    );
    return null;
  } on ApiFailure catch (e) {
    return e.message;
  }
}

/// Takes back something you sent.
///
/// The server keeps the row and marks it deleted — a tutor can still see what
/// was said, which is the point of a moderated study room — so this is "take
/// it off the wall", not "make it never have happened".
Future<String?> deleteGram(Api api, String messageId) async {
  try {
    /* PATCH, and the key is `action` — read off the route rather than
       guessed. A POST here creates nothing and would 405. */
    final res = await api.patch(
      '/api/gram/messages/$messageId',
      body: {'action': 'delete'},
    );
    return res['ok'] == false
        ? (res['message'] as String? ?? 'That could not be deleted.')
        : null;
  } on ApiFailure catch (e) {
    return e.message;
  }
}
