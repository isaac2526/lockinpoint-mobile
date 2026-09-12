import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/core/vault/exam_download.dart';
import 'package:lockinpoint/core/vault/vault_db.dart';
import 'package:lockinpoint/core/vault/vault_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ===========================================================================
/// THE WHOLE OFFLINE CYCLE, ON A REAL DATABASE
///
/// Download · progress · interruption · resume · completion · opening it with
/// no network · an update arriving · deletion.
///
/// Not the controller in isolation and not the database in isolation: one
/// student, one examination, start to finish, against a real SQLite file in
/// memory. The parts each passed their own tests; what this asks is whether
/// the sequence works, which is the only question a student cares about.
/// ===========================================================================

/// A server that can fail, stall, and grow new questions between visits.
class _Bank extends Fake implements Api {
  _Bank();

  bool online = true;

  /// Subject id -> how many questions it holds RIGHT NOW. Changing this is
  /// how "twelve new questions" happens.
  final Map<String, int> counts = {'chem': 40, 'phys': 30};

  /// Held open to freeze a download mid-flight.
  Completer<void>? gate;

  /// Subject ids whose fetch fails. Deterministic, where racing a timer is
  /// not: a test that sometimes passes is a test that tells you nothing.
  final Set<String> failOn = {};

  final List<String> fetched = [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (!online) throw ApiFailure('No connection. Try again in a moment.');

    if (path.contains('/vault')) {
      return {
        'ok': true,
        'activated': true,
        'text': {
          'packs': [
            for (final e in counts.entries)
              {
                'subjectId': e.key,
                'subject': e.key == 'chem' ? 'Chemistry' : 'Physics',
                'exam': 'WAEC',
                'examSlug': 'waec',
                'questions': e.value,
                'bytes': e.value * 1400,
              },
          ],
        },
      };
    }

    final id = '${query?['subject']}';
    if (failOn.contains(id)) {
      throw ApiFailure('No connection. Try again in a moment.');
    }
    final offset = int.tryParse('${query?['offset'] ?? 0}') ?? 0;
    final limit = int.tryParse('${query?['limit'] ?? 200}') ?? 200;
    if (offset == 0) fetched.add(id);
    if (gate != null) await gate!.future;

    final total = counts[id] ?? 0;
    final take = (total - offset).clamp(0, limit);
    return {
      'ok': true,
      'pack': {
        'subjectId': id,
        'subjectName': id == 'chem' ? 'Chemistry' : 'Physics',
        'examId': 'e1',
        'examSlug': 'waec',
        'examShort': 'WAEC',
      },
      'total': offset == 0 ? total : null,
      'nextOffset': (take < limit || offset + take >= total)
          ? null
          : offset + take,
      'questions': [
        for (var i = 0; i < take; i++)
          {
            'id': '$id-${offset + i}',
            'question': 'Question ${offset + i} in $id',
            'question_html': '<b>Question ${offset + i}</b> in $id',
            'options': const ['A thing', 'Another thing'],
            'options_html': const ['<i>A thing</i>', 'Another thing'],
            'letters': const ['A', 'B'],
            'answer': 'A',
            'explanation': 'Because.',
          },
      ],
      'passages': const [],
    };
  }
}

void main() {
  late VaultDb db;
  late _Bank api;
  late ProviderContainer c;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = VaultDb.forTesting(NativeDatabase.memory());
    api = _Bank();
    c = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
        vaultDbProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  test(
    'the whole cycle: download, interrupt, resume, sit it, update, delete',
    () async {
      final n = c.read(vaultDownloadProvider.notifier);

      // ── 1 · WHAT IS THERE, AND WHAT IT COSTS ──────────────────────────
      await n.refresh();
      var waec = c.read(vaultDownloadProvider).examFor('waec')!;
      expect(waec.subjects.length, 2);
      expect(waec.questions, 70);
      expect(waec.heldSubjects, 0);
      expect(waec.complete, isFalse);
      expect(VaultDownloadState.mb(waec.bytes), '96 KB');

      // ── 2 · START IT, AND STOP IT PART-WAY ────────────────────────────
      api.gate = Completer<void>();
      final run = n.start('waec');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(vaultDownloadProvider).phase, VaultRunPhase.running);

      n.pause();
      api.gate!.complete();
      api.gate = null;
      await run;

      final paused = c.read(vaultDownloadProvider);
      expect(paused.phase, VaultRunPhase.paused);
      expect(
        (await db.allPacks()).length,
        1,
        reason:
            'the subject in flight must LAND — its bytes are already paid '
            'for, and throwing them away is the opposite of a courtesy',
      );

      // ── 3 · IT SURVIVES THE APP BEING KILLED ──────────────────────────
      /* A fresh container is a fresh launch. "What is still outstanding" is
       recomputed from the VAULT, not from a remembered byte offset, so there
       is no separate resume path to get wrong. */
      final second = ProviderContainer(
        overrides: [
          apiProvider.overrideWithValue(api),
          vaultDbProvider.overrideWithValue(db),
        ],
      );
      addTearDown(second.dispose);
      final n2 = second.read(vaultDownloadProvider.notifier);
      await n2.refresh();
      expect(
        second.read(vaultDownloadProvider).examFor('waec')!.heldSubjects,
        1,
      );

      // ── 4 · FINISH IT ─────────────────────────────────────────────────
      await n2.start('waec');
      final done = second.read(vaultDownloadProvider);
      expect(done.phase, VaultRunPhase.done);
      expect(done.percent, 100);

      waec = done.examFor('waec')!;
      expect(waec.complete, isTrue);
      expect(
        waec.behind,
        0,
        reason: 'a finished download must not still be "behind"',
      );

      // Every question of both subjects is on the phone, not just a first page.
      expect((await db.questionsFor('chem')).length, 40);
      expect((await db.questionsFor('phys')).length, 30);

      // ── 5 · SIT A PAPER WITH NO NETWORK AT ALL ────────────────────────
      api.online = false;
      final repo = VaultRepository(api, db);
      final sitting = await repo.openSitting('chem', count: 10, seed: 7);
      expect(sitting, isNotNull);
      expect(sitting!.questions.length, 10);

      /* AND IT KEPT ITS FORMATTING. The pack sends readable text AND markup;
       the vault used to store only the readable text, so every downloaded
       question lost its bold, its italics and its lists. */
      expect(sitting.questions.first.question, contains('<b>'));
      expect(sitting.questions.first.options.first, contains('<i>'));
      // The answer key travels, or an offline paper cannot be marked.
      expect(sitting.questions.first.answer, 'A');

      // ── 6 · TWELVE NEW QUESTIONS ARRIVE ───────────────────────────────
      api.online = true;
      api.counts['chem'] = 52;
      await n2.refresh();

      waec = second.read(vaultDownloadProvider).examFor('waec')!;
      expect(waec.behind, 12, reason: 'the update count is a real subtraction');
      expect(waec.anyUpdate, isTrue);
      expect(
        waec.outstanding.map((s) => s.subjectId),
        ['chem'],
        reason:
            'only the stale subject should be fetched again, not all of them',
      );

      api.fetched.clear();
      await n2.start('waec');
      expect(api.fetched, ['chem']);
      expect((await db.questionsFor('chem')).length, 52);
      expect(second.read(vaultDownloadProvider).examFor('waec')!.behind, 0);

      // ── 7 · DELETE IT, AND GET THE SPACE BACK ─────────────────────────
      await n2.removeExam('waec');
      expect(await db.allPacks(), isEmpty);
      expect(await db.questionsFor('chem'), isEmpty);
      expect(
        second.read(vaultDownloadProvider).examFor('waec')!.heldSubjects,
        0,
        reason: 'the button must go back to Download, not stay on Downloaded',
      );

      // And with the vault emptied there is nothing to sit offline.
      api.online = false;
      expect(await VaultRepository(api, db).openSitting('chem'), isNull);
    },
  );

  test(
    'a download killed by a dead network keeps what it got, and finishes',
    () async {
      final n = c.read(vaultDownloadProvider.notifier);
      await n.refresh();

      /* THE NETWORK DIES PART-WAY. Subjects are alphabetical within an
         examination, so Chemistry lands and Physics is the one that is
         lost. Failing a named subject rather than racing a timer: a test
         that sometimes passes tells you nothing. */
      api.failOn.add('phys');
      await n.start('waec');

      final st = c.read(vaultDownloadProvider);
      expect(
        st.phase,
        VaultRunPhase.failed,
        reason: 'a run that lost a subject must NOT report success',
      );
      expect(st.problem, isNotEmpty);
      expect(st.problem, isNot(contains('Exception')));

      final held = await db.allPacks();
      expect(
        held.length,
        greaterThanOrEqualTo(1),
        reason: 'what was already downloaded must survive the failure',
      );

      // ── RETRY FINISHES IT, without re-fetching what is already here ──
      api.failOn.clear();
      api.fetched.clear();
      await n.retry();

      expect(c.read(vaultDownloadProvider).phase, VaultRunPhase.done);
      expect(
        api.fetched,
        isNot(contains(held.first.subjectId)),
        reason:
            'retry re-downloaded a subject the phone already had — that '
            'is the student paying twice for the same bytes',
      );
      expect((await db.allPacks()).length, 2);
    },
  );

  test('a manifest that fails does not take the vault down with it', () async {
    final n = c.read(vaultDownloadProvider.notifier);
    await n.refresh();
    await n.start('waec');
    expect((await db.allPacks()).length, 2);

    api.online = false;
    await n.refresh();

    /* A student off signal must still be holding what they downloaded. The
       MANIFEST failed, not the vault, and the two must not be confused. */
    final st = c.read(vaultDownloadProvider);
    expect(st.loading, isFalse, reason: 'a spinner that never stops');
    expect(st.listProblem, isNotEmpty);
    expect(st.listProblem, isNot(contains('Exception')));
    expect((await db.allPacks()).length, 2);
    expect(await db.hasAnyPack(), isTrue);
  });
}
