import '../../core/api.dart';

/// ===========================================================================
/// LUMI
///
/// The same `/api/ai/ask` the website talks to — same rate dial, same
/// activation gate, same model ladder configured in Admin → AI. The app adds
/// nothing to the conversation and takes nothing away.
///
/// HISTORY IS SENT, TRIMMED. The server keeps the last six turns; sending
/// more would be paid-for tokens the server discards anyway.
/// ===========================================================================

class Turn {
  const Turn(this.role, this.text);
  final String role; // 'user' | 'model'
  final String text;

  bool get mine => role == 'user';
  Map<String, String> get wire => {'role': role, 'text': text};
}

/// What came back, and whether the student needs to activate first.
class LumiReply {
  const LumiReply({
    required this.ok,
    required this.text,
    this.needActivation = false,
    this.coolSeconds,
  });

  final bool ok;
  final String text;
  final bool needActivation;

  /// Set when the per-minute dial has been hit. The screen counts it down
  /// rather than letting a student tap into the same refusal.
  final int? coolSeconds;
}

Future<LumiReply> askLumi(
  Api api,
  String question, {
  List<Turn> history = const [],
  String? questionId,
}) async {
  try {
    final res = await api.post(
      '/api/ai/ask',
      body: {
        'question': question,
        'history': history.map((t) => t.wire).toList(),
        // Null-aware entry: the key vanishes when there is no question
        // to attach, rather than sending an explicit null the server
        // would have to defend against.
        'questionId': ?questionId,
      },
    );
    if (res['ok'] == true) {
      return LumiReply(ok: true, text: (res['answer'] as String? ?? '').trim());
    }
    return LumiReply(
      ok: false,
      text: res['message'] as String? ?? 'Lumi could not answer that one.',
      needActivation: res['needActivation'] == true,
      coolSeconds: (res['cool'] as num?)?.toInt(),
    );
  } on ApiFailure catch (e) {
    /* Api turns any `{ ok: false }` into this, which is right — but Lumi's
       refusals say more than "no". The envelope is still attached, so the
       activation flag and the cooldown are read from the SERVER's answer
       rather than guessed by matching on the wording of a sentence. */
    return LumiReply(
      ok: false,
      text: e.message,
      needActivation: e.data?['needActivation'] == true,
      coolSeconds: (e.data?['cool'] as num?)?.toInt(),
    );
  }
}
