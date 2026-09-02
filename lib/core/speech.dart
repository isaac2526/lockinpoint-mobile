import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// ===========================================================================
/// READING A QUESTION ALOUD
///
/// The website has had browser speech since the beginning. The app had
/// nothing — so a student who reads slowly, or who is revising while walking,
/// was better served by the website than by the product built for them.
///
/// THE PLATFORM'S OWN ENGINE, NOT A CLOUD VOICE. Android, iOS, macOS, Windows
/// and every browser ship a speech synthesiser. Using it means reading a
/// question aloud costs nothing, needs no key, and — the reason that matters —
/// WORKS IN THE OFFLINE VAULT. A cloud voice would turn "practise with no
/// signal" back into "practise with no signal, silently".
///
/// It also means the voice is whatever the student has already chosen in
/// their phone's own accessibility settings, which is nearly always better
/// than one this app would pick for them.
/// ===========================================================================

/// Speech is a device capability, so it is asked for rather than assumed.
/// Linux desktop has no engine wired into flutter_tts, and a button that
/// silently does nothing is worse than an absent one.
bool get speechSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows;

class Speech {
  Speech() {
    if (!speechSupported) return;
    _tts = FlutterTts();
    // Slower than the default. A question is not a paragraph of prose: every
    // number and every option matters, and the default rate reads a chemical
    // formula like a barcode.
    _tts!.setSpeechRate(0.45);
    _tts!.setPitch(1.0);
    _tts!.setCompletionHandler(() => _speaking.value = false);
    _tts!.setCancelHandler(() => _speaking.value = false);
    _tts!.setErrorHandler((_) => _speaking.value = false);
  }

  FlutterTts? _tts;

  /// Watched by the button, so it can show stop while a question is playing.
  final ValueNotifier<bool> _speaking = ValueNotifier(false);
  ValueListenable<bool> get speaking => _speaking;

  /// Speak a question and its options as one passage, so the reading does not
  /// stop between the stem and option A.
  Future<void> question(
    String stem,
    List<String> options, [
    List<String>? letters,
  ]) {
    final buffer = StringBuffer(_readable(stem));
    for (var i = 0; i < options.length; i++) {
      final letter = (letters != null && letters.length > i)
          ? letters[i]
          : String.fromCharCode(65 + i);
      // The pause matters: without it the engine runs the stem straight into
      // "A" and a student cannot tell where the question ended.
      buffer.write('. Option $letter. ${_readable(options[i])}');
    }
    return speak(buffer.toString());
  }

  Future<void> speak(String text) async {
    final tts = _tts;
    if (tts == null) return;
    final clean = _readable(text);
    if (clean.isEmpty) return;
    await tts.stop();
    _speaking.value = true;
    await tts.speak(clean);
  }

  Future<void> stop() async {
    _speaking.value = false;
    await _tts?.stop();
  }

  void dispose() {
    _tts?.stop();
    _speaking.dispose();
  }
}

/// Questions carry markup from the importers and LaTeX from the maths ones.
/// An engine reads `<sub>2</sub>` as "less than sub two greater than", which
/// is worse than silence.
String _readable(String raw) => raw
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '. ')
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', ' and ')
    .replaceAll('&lt;', ' less than ')
    .replaceAll('&gt;', ' greater than ')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    // Bare LaTeX delimiters read as "dollar", which is nonsense in a
    // chemistry question. The content between them is left to be read.
    .replaceAll(RegExp(r'\$+'), ' ')
    .replaceAll(RegExp(r'\\[a-zA-Z]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

final speechProvider = Provider<Speech>((ref) {
  final s = Speech();
  ref.onDispose(s.dispose);
  return s;
});
