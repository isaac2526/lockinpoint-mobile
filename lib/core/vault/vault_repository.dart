import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api.dart';
import '../../features/practice/practice_repository.dart';
import 'vault_db.dart';

/// ===========================================================================
/// THE VAULT, AS THE APP USES IT
///
/// THE ONE RULE THIS FILE EXISTS TO ENFORCE:
///
///   NO INTERNET IS NOT AN ANSWER FOR A QUESTION THE PHONE IS HOLDING.
///
/// A student who downloaded Chemistry last night must be able to open
/// Chemistry this morning in a place with no signal, answer it, be marked,
/// and see their explanations — with no spinner, no error card, and no
/// "check your connection".
///
/// Only things that GENUINELY need the network say so: downloading a new
/// pack, the leaderboard, live challenges, Lumi, payment, account changes.
/// ===========================================================================

final vaultDbProvider = Provider<VaultDb>((ref) {
  final db = VaultDb();
  ref.onDispose(db.close);
  return db;
});

/// Which subjects are on this phone right now.
final vaultPacksProvider = FutureProvider<List<Pack>>(
  (ref) => ref.watch(vaultDbProvider).allPacks(),
);

/// True when there is at least one downloaded pack. Drives the difference
/// between "offline, but your downloads still work" and "offline".
final hasVaultProvider = FutureProvider<bool>(
  (ref) => ref.watch(vaultDbProvider).hasAnyPack(),
);

class VaultRepository {
  VaultRepository(this._api, this._db);

  final Api _api;
  final VaultDb _db;

  // -------------------------------------------------------- downloading ----

  /// Fetch a subject and keep it. Needs the network, obviously — this is the
  /// one operation in the vault that legitimately cannot work offline.
  Future<Pack> download(String subjectId, {int limit = 200}) async {
    final res = await _api.get(
      '/api/mobile/pack',
      query: {'subject': subjectId, 'limit': '$limit'},
    );

    final pack = (res['pack'] as Map).cast<String, dynamic>();
    final questions = ((res['questions'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    final passages = ((res['passages'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();

    await _db.savePack(pack: pack, questions: questions, passages: passages);
    return (await _db.pack(subjectId))!;
  }

  Future<void> remove(String subjectId) => _db.removePack(subjectId);

  Future<List<Pack>> packs() => _db.allPacks();

  Future<bool> hasPack(String subjectId) async =>
      await _db.pack(subjectId) != null;

  // ---------------------------------------------------- practising offline --

  /// Build a sitting entirely from the phone. Nothing here touches the
  /// network, so it works in a tunnel.
  ///
  /// The questions are shuffled with a seed derived from the clock, so two
  /// sittings of the same pack are not the same paper in the same order.
  Future<OfflineSitting?> openSitting(
    String subjectId, {
    int count = 40,
    int? seed,
  }) async {
    final pack = await _db.pack(subjectId);
    if (pack == null) return null;

    final rows = await _db.questionsFor(subjectId);
    if (rows.isEmpty) return null;

    // A seed makes the same paper reproducible, which is what lets a test
    // assert offline practice deterministically. Without one it is genuinely
    // shuffled, so two sittings of a pack are not the same paper twice.
    final shuffled = [...rows]..shuffle(seed == null ? null : Random(seed));
    final chosen = shuffled.take(count).toList();

    final questions = <ServedQuestion>[];
    final passages = <String, Passage>{};

    for (final r in chosen) {
      questions.add(
        ServedQuestion(
          id: r.id,
          question: r.question,
          options: (jsonDecode(r.optionsJson) as List).cast<String>(),
          letters: (jsonDecode(r.lettersJson) as List).cast<String>(),
          passageId: r.passageId,
          section: r.section,
          year: r.year,
          answer: r.answer,
          explanation: r.explanation,
          media: r.mediaJson == null
              ? null
              : (jsonDecode(r.mediaJson!) as Map).cast<String, dynamic>(),
        ),
      );
      final pid = r.passageId;
      if (pid != null && !passages.containsKey(pid)) {
        final p = await _db.passage(pid);
        if (p != null) passages[pid] = Passage(title: p.title, body: p.body);
      }
    }

    return OfflineSitting(pack: pack, questions: questions, passages: passages);
  }

  /// Mark a sitting on the phone. The answer key came down with the pack, so
  /// this is real marking rather than a promise to mark later.
  OfflineScore score(
    List<ServedQuestion> questions,
    Map<String, String> chosen,
  ) {
    var correct = 0;
    final wrong = <String>[];
    for (final q in questions) {
      final pick = chosen[q.id];
      if (pick == null) continue;
      if (q.answer != null && pick.toUpperCase() == q.answer) {
        correct += 1;
      } else {
        wrong.add(q.id);
      }
    }
    return OfflineScore(
      correct: correct,
      total: questions.length,
      wrongIds: wrong,
    );
  }

  /// Keep a finished offline sitting until the network comes back.
  Future<void> queueResult({
    required String localId,
    required Pack pack,
    required int correct,
    required int total,
    required int durationSeconds,
    required Map<String, String> answers,
  }) => _db.queueResult(
    PendingResult(
      localId: localId,
      subjectId: pack.subjectId,
      examId: pack.examId,
      correct: correct,
      total: total,
      durationSeconds: durationSeconds,
      answersJson: jsonEncode(answers),
      takenAt: DateTime.now(),
      synced: false,
    ),
  );

  // ------------------------------------------------------------- syncing ---

  /// Send everything sat offline, oldest first. Returns how many landed.
  ///
  /// A result that fails to send is LEFT QUEUED rather than dropped: a
  /// student's paper is not something to lose because a request timed out.
  Future<int> syncPending() async {
    final pending = await _db.unsyncedResults();
    var sent = 0;

    for (final r in pending) {
      try {
        await _api.post(
          '/api/mobile/results/offline',
          body: {
            'localId': r.localId,
            'subjectId': r.subjectId,
            'examId': r.examId,
            'correct': r.correct,
            'total': r.total,
            'durationSeconds': r.durationSeconds,
            'answers': jsonDecode(r.answersJson),
            'takenAt': r.takenAt.toIso8601String(),
          },
        );
        await _db.markSynced(r.localId);
        sent += 1;
      } on ApiFailure {
        // Still offline, or the server is unhappy. Try again next time.
        break;
      }
    }
    return sent;
  }

  Future<int> pendingCount() async => (await _db.unsyncedResults()).length;
}

final vaultProvider = Provider<VaultRepository>(
  (ref) => VaultRepository(ref.watch(apiProvider), ref.watch(vaultDbProvider)),
);

/// A sitting assembled entirely from the phone.
class OfflineSitting {
  const OfflineSitting({
    required this.pack,
    required this.questions,
    required this.passages,
  });

  final Pack pack;
  final List<ServedQuestion> questions;
  final Map<String, Passage> passages;
}

class OfflineScore {
  const OfflineScore({
    required this.correct,
    required this.total,
    required this.wrongIds,
  });

  final int correct;
  final int total;
  final List<String> wrongIds;

  double get percent => total == 0 ? 0 : correct / total * 100;
}
