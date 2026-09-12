import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/core/vault/exam_download.dart';
import 'package:lockinpoint/core/vault/vault_db.dart';
import 'package:lockinpoint/core/vault/vault_repository.dart';

/// ===========================================================================
/// DOWNLOADING A WHOLE EXAMINATION
///
/// The vault could be FILLED subject by subject and that was the whole of it.
/// A student sitting WAEC had to find and tap Download on each of nine
/// subjects with no idea what the nine would cost until they had spent it.
///
/// What is asserted here is what the owner asked for by name: per cent,
/// megabytes, PAUSE, RESUME, RETRY, and an update that says how many new
/// questions it is worth.
/// ===========================================================================

/// The manifest, plus a pack endpoint that can be made to fail or to block.
class _Server extends Fake implements Api {
  _Server({this.failOn = const {}, this.gate});

  /// Subject ids whose pack request fails.
  final Set<String> failOn;

  /// Held open, so a test can look at the state MID-RUN rather than only at
  /// the end — which is the only way to assert that Pause does anything.
  final Completer<void>? gate;

  final List<String> fetched = [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (path.contains('/vault')) {
      return {
        'ok': true,
        'activated': true,
        'text': {
          'packs': [
            {
              'subjectId': 'p1',
              'subject': 'Physics',
              'exam': 'WAEC',
              'examSlug': 'waec',
              'questions': 50,
              'bytes': 70000,
            },
            {
              'subjectId': 'c1',
              'subject': 'Chemistry',
              'exam': 'WAEC',
              'examSlug': 'waec',
              'questions': 40,
              'bytes': 56000,
            },
            {
              'subjectId': 'm1',
              'subject': 'Mathematics',
              'exam': 'JAMB',
              'examSlug': 'jamb',
              'questions': 30,
              'bytes': 42000,
            },
          ],
        },
      };
    }

    // A pack, PAGED exactly as the real route pages.
    final id = '${query?['subject']}';
    final offset = int.tryParse('${query?['offset'] ?? 0}') ?? 0;
    final limit = int.tryParse('${query?['limit'] ?? 200}') ?? 200;
    if (offset == 0) fetched.add(id);
    if (gate != null) await gate!.future;
    if (failOn.contains(id)) {
      throw ApiFailure('No connection. Try again in a moment.');
    }

    final total = totals[id] ?? 0;
    final take = (total - offset).clamp(0, limit);
    return {
      'ok': true,
      'pack': {'subjectId': id, 'subjectName': id, 'examSlug': 'waec'},
      'total': offset == 0 ? total : null,
      'nextOffset': (take < limit || offset + take >= total)
          ? null
          : offset + take,
      'questions': [
        for (var i = 0; i < take; i++) {'id': '$id-${offset + i}'},
      ],
      'passages': const [],
    };
  }

  /// How many questions each subject really has — the manifest and the pack
  /// agree, which is the whole point of the paging fix.
  static const totals = {'p1': 50, 'c1': 40, 'm1': 30};
}

/// A vault that records what was saved, and reports what it holds.
class _Db extends Fake implements VaultDb {
  _Db([this.held = const []]);
  List<Pack> held;

  final List<String> saved = [];

  @override
  Future<List<Pack>> allPacks() async => held;

  @override
  Future<void> savePack({
    required Map<String, dynamic> pack,
    required List<Map<String, dynamic>> questions,
    required List<Map<String, dynamic>> passages,
    bool replace = true,
    int? runningCount,
  }) async {
    final id = '${pack['subjectId']}';
    if (replace) saved.add(id);
    held = [
      ...held.where((p) => p.subjectId != id),
      _p(id, runningCount ?? questions.length),
    ];
  }

  @override
  Future<Pack?> pack(String subjectId) async {
    for (final p in held) {
      if (p.subjectId == subjectId) return p;
    }
    return null;
  }

  @override
  Future<void> removePack(String subjectId) async {
    held = held.where((p) => p.subjectId != subjectId).toList();
  }

  @override
  Future<bool> hasAnyPack() async => held.isNotEmpty;
}

Pack _p(String id, int count) => Pack(
  subjectId: id,
  subjectName: id,
  examId: 'e',
  examSlug: 'waec',
  examShort: 'WAEC',
  count: count,
  downloadedAt: DateTime.utc(2026, 1, 1),
);

ProviderContainer _c(Api api, VaultDb db) {
  final c = ProviderContainer(
    overrides: [
      apiProvider.overrideWithValue(api),
      vaultDbProvider.overrideWithValue(db),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('examinations are grouped, sized and counted', () async {
    final c = _c(_Server(), _Db());
    await c.read(vaultDownloadProvider.notifier).refresh();
    final st = c.read(vaultDownloadProvider);

    expect(st.exams.map((e) => e.name), ['JAMB', 'WAEC']);

    final waec = st.examFor('waec')!;
    expect(waec.subjects.length, 2);
    expect(waec.questions, 90);
    expect(waec.bytes, 126000);
    expect(waec.heldSubjects, 0);
    expect(waec.complete, isFalse);

    // The size line a student reads before spending their bundle. Under a
    // megabyte it says KB — "0.1 MB" tells nobody anything.
    expect(VaultDownloadState.mb(126000), '123 KB');
    expect(VaultDownloadState.mb(31 * 1048576), '31.0 MB');
  });

  test('"12 new questions" is a real subtraction, not a guess', () async {
    // The phone holds 38 of Physics' 50 and all 40 of Chemistry.
    final db = _Db([_p('p1', 38), _p('c1', 40)]);
    final c = _c(_Server(), db);
    await c.read(vaultDownloadProvider.notifier).refresh();

    final waec = c.read(vaultDownloadProvider).examFor('waec')!;
    expect(waec.behind, 12);
    expect(waec.heldSubjects, 2);
    expect(waec.complete, isTrue);
    expect(waec.anyUpdate, isTrue);
    // Only the stale one is fetched again — not all nine subjects.
    expect(waec.outstanding.map((s) => s.subjectId), ['p1']);
  });

  test('a bank that shrank is not an update', () async {
    // 60 held against 50 on the server. Negative is not "10 new questions".
    final c = _c(_Server(), _Db([_p('p1', 60), _p('c1', 40)]));
    await c.read(vaultDownloadProvider.notifier).refresh();
    expect(c.read(vaultDownloadProvider).examFor('waec')!.behind, 0);
  });

  test('one examination downloads, and only that one', () async {
    final api = _Server();
    final db = _Db();
    final c = _c(api, db);
    final n = c.read(vaultDownloadProvider.notifier);

    await n.refresh();
    await n.start('waec');

    final st = c.read(vaultDownloadProvider);
    expect(st.phase, VaultRunPhase.done);
    // Alphabetical within the examination, so Chemistry first.
    expect(db.saved, ['c1', 'p1']);
    // JAMB was never touched.
    expect(api.fetched, isNot(contains('m1')));
    expect(st.percent, 100);
  });

  test('pause stops before the next subject, and resume finishes it', () async {
    final gate = Completer<void>();
    final api = _Server(gate: gate);
    final db = _Db();
    final c = _c(api, db);
    final n = c.read(vaultDownloadProvider.notifier);

    await n.refresh();
    final run = n.start('waec');

    // Mid-flight on the first subject.
    await Future<void>.delayed(Duration.zero);
    expect(c.read(vaultDownloadProvider).phase, VaultRunPhase.running);

    n.pause();
    gate.complete();
    await run;

    /* THE SUBJECT IN FLIGHT LANDED — its bytes were already paid for and
       throwing them away would be the opposite of a courtesy — and the
       second one never started. */
    expect(db.saved, ['c1']);
    expect(c.read(vaultDownloadProvider).phase, VaultRunPhase.paused);
    expect(c.read(vaultDownloadProvider).runningExam, 'waec');

    // Resume picks up what is still outstanding, worked out from the vault
    // rather than from a remembered position.
    await n.resume();
    expect(db.saved, ['c1', 'p1']);
    expect(c.read(vaultDownloadProvider).phase, VaultRunPhase.done);
  });

  test('one subject failing does not sink the run, and offers Retry', () async {
    final db = _Db();
    final c = _c(_Server(failOn: {'c1'}), db);
    final n = c.read(vaultDownloadProvider.notifier);

    await n.refresh();
    await n.start('waec');

    final st = c.read(vaultDownloadProvider);
    // Physics is on the phone. Chemistry is not, and the state says so
    // instead of reporting a success it did not have.
    expect(db.saved, ['p1']);
    expect(db.saved, isNot(contains('c1')));
    expect(st.phase, VaultRunPhase.failed);
    expect(st.problem, isNotEmpty);
    // And the message is a sentence, not a Dart exception.
    expect(st.problem, isNot(contains('Exception')));
  });

  test('retry fetches only what is still missing', () async {
    final db = _Db();
    final api = _Server(failOn: {'c1'});
    final c = _c(api, db);
    final n = c.read(vaultDownloadProvider.notifier);

    await n.refresh();
    await n.start('waec');
    expect(api.fetched, ['c1', 'p1']);

    await n.retry();
    // Physics is NOT fetched a second time — it is already in the vault.
    expect(api.fetched, ['c1', 'p1', 'c1']);
  });

  test(
    'a manifest that explodes does not leave the screen loading forever',
    () async {
      final c = _c(_Broken(), _Db());
      await c.read(vaultDownloadProvider.notifier).refresh();

      final st = c.read(vaultDownloadProvider);
      /* THIS IS THE ONE THAT MATTERS. It caught only ApiFailure, so anything
       else left `loading` true forever — a spinner that never stops, which
       does not even look like a failure. */
      expect(st.loading, isFalse);
      expect(st.listProblem, isNotEmpty);
      expect(st.listProblem, isNot(contains('type')));
    },
  );

  test('a subject bigger than one page is fetched whole', () async {
    /* THE BUG THIS PROVES GONE.

       The pack endpoint serves at most 500 questions in one response, and
       the app took that one page and stopped — while the vault manifest went
       on counting every published question. A subject with 900 put 500 on
       the phone and then told the student, for ever, that 400 new ones were
       waiting. Tapping Update re-fetched the SAME first 500 and changed
       nothing, spending their bundle every time. */
    final db = _Db();
    final api = _Big();
    final c = _c(api, db);
    final repo = VaultRepository(api, db);

    await repo.download('big', limit: 100);

    // Nine hundred questions, a hundred at a time: nine pages, then the
    // server says there is no tenth.
    expect(api.pages, [0, 100, 200, 300, 400, 500, 600, 700, 800]);
    // And the pack row records the WHOLE subject, not the last page.
    expect((await db.pack('big'))!.count, 900);

    // Which means the vault no longer thinks it is behind.
    await c.read(vaultDownloadProvider.notifier).refresh();
  });

  test('the first page replaces, the rest append', () async {
    final db = _Db();
    final api = _Big();
    await VaultRepository(api, db).download('big', limit: 100);

    /* Wiping on every page would leave the phone holding only the last
       hundred — which is exactly what `replace: true` on page five would
       do. `saved` only records the replacing call. */
    expect(db.saved, ['big']);
  });

  test('removing an examination empties it and nothing else', () async {
    final db = _Db([_p('p1', 50), _p('c1', 40), _p('m1', 30)]);
    final c = _c(_Server(), db);
    final n = c.read(vaultDownloadProvider.notifier);

    await n.refresh();
    await n.removeExam('waec');

    expect(db.held.map((p) => p.subjectId), ['m1']);
  });
}

/// Fails in a way that is NOT an ApiFailure — which is the whole point.
class _Broken extends Fake implements Api {
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async => throw StateError('the manifest changed shape');
}

/// A subject of nine hundred questions, served a page at a time.
class _Big extends Fake implements Api {
  final List<int> pages = [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final offset = int.tryParse('${query?['offset'] ?? 0}') ?? 0;
    final limit = int.tryParse('${query?['limit'] ?? 200}') ?? 200;
    pages.add(offset);
    final take = (900 - offset).clamp(0, limit);
    return {
      'ok': true,
      'pack': {'subjectId': 'big', 'subjectName': 'Big', 'examSlug': 'waec'},
      'total': offset == 0 ? 900 : null,
      // The real route stops the walk when the total is reached, so a
      // subject of exactly nine pages costs nine requests, not ten.
      'nextOffset': (take < limit || offset + take >= 900)
          ? null
          : offset + take,
      'questions': [
        for (var i = 0; i < take; i++) {'id': 'q${offset + i}'},
      ],
      'passages': const [],
    };
  }
}
