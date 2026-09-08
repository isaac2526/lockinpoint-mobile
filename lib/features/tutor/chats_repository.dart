import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// LUMI'S CONVERSATIONS, ON THE PHONE.
///
/// The same rows the website reads. A student who starts a conversation on
/// their phone opens it in a browser and carries on mid sentence, because
/// neither client holds the history any more — the server does.
///
/// Fifteen is the cap and the SERVER enforces it, so the app never has to
/// guess: it asks for a new chat and is told, in a sentence, when the list is
/// full and which conversation is oldest.
/// ===========================================================================

class LumiChat {
  const LumiChat({required this.id, required this.title});
  final String id;
  final String title;

  static LumiChat from(Map<dynamic, dynamic> m) => LumiChat(
    id: m['id'] as String? ?? '',
    title: (m['title'] as String? ?? '').trim().isEmpty
        ? 'New chat'
        : m['title'] as String,
  );
}

class ChatList {
  const ChatList({required this.chats, required this.max});
  final List<LumiChat> chats;
  final int max;

  bool get isFull => chats.length >= max;
}

final lumiChatsProvider = FutureProvider<ChatList>((ref) async {
  final res = await ref.read(apiProvider).get('/api/ai/chats');
  return ChatList(
    chats: ((res['chats'] as List?) ?? const [])
        .whereType<Map>()
        .map(LumiChat.from)
        .toList(),
    max: (res['max'] as int?) ?? 15,
  );
});

/// One conversation's messages, oldest first.
Future<List<({String role, String text})>> loadChat(Api api, String id) async {
  final res = await api.get('/api/ai/chats', query: {'id': id});
  return ((res['messages'] as List?) ?? const [])
      .whereType<Map>()
      .map(
        (m) => (
          role: m['role'] as String? ?? 'user',
          text: m['text'] as String? ?? '',
        ),
      )
      .toList();
}

/// Starts a conversation. Throws with the server's own sentence when the list
/// is full — which names the oldest chat, so the student knows what to delete.
Future<LumiChat> newChat(Api api) async {
  final res = await api.post('/api/ai/chats', body: {'op': 'new'});
  final c = res['chat'];
  if (c is! Map) {
    throw ApiFailure(
      res['message'] as String? ?? 'Could not start a conversation.',
    );
  }
  return LumiChat.from(c);
}

Future<void> renameChat(Api api, String id, String title) =>
    api.post('/api/ai/chats', body: {'op': 'rename', 'id': id, 'title': title});

Future<void> deleteChat(Api api, String id) =>
    api.post('/api/ai/chats', body: {'op': 'delete', 'id': id});
