import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/core/vault/vault_db.dart';
import 'package:lockinpoint/core/vault/vault_repository.dart';

/// ===========================================================================
/// THE OFFLINE VAULT, PROVEN WITH THE NETWORK OFF
///
/// THE PROMISE THIS FILE DEFENDS:
///
///   NO INTERNET IS NOT AN ANSWER FOR A QUESTION THE PHONE IS HOLDING.
///
/// The Api below THROWS on every single call — it is a phone in a tunnel,
/// not a slow phone. If any part of opening, answering or marking a
/// downloaded pack reaches for the network, these tests fail.
/// ===========================================================================

/// A network that does not exist. Every call fails, exactly as it would in a
/// village with no mast.
class _NoNetwork extends Fake implements Api {
  int calls = 0;

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) {
    calls++;
    throw ApiFailure('No connection.', offline: true);
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) {
    calls++;
    throw ApiFailure('No connection.', offline: true);
  }
}

/// A network that works, for the download and sync halves.
class _Network extends Fake implements Api {
  _Network(this.pack);
  final Map<String, dynamic> pack;
  final List<Map<String, dynamic>> posted = [];
  int failFirst = 0;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async => pack;

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    if (failFirst > 0) {
      failFirst--;
      throw ApiFailure('No connection.', offline: true);
    }
    posted.add((body as Map).cast<String, dynamic>());
    return {'ok': true};
  }
}

Map<String, dynamic> _packPayload({int questions = 5}) => {
  'ok': true,
  'pack': {
    'subjectId': 'sub-chem',
    'subjectName': 'Chemistry',
    'examId': 'exam-waec',
    'examSlug': 'waec',
    'examShort': 'WAEC',
  },
  'questions': [
    for (var i = 0; i < questions; i++)
      {
        'id': 'q$i',
        'question': 'Question $i',
        'options': ['alpha', 'beta', 'gamma', 'delta'],
        'letters': ['A', 'B', 'C', 'D'],
        'passage_id': i == 0 ? 'p1' : null,
        'section': null,
        'year': 2024,
        // Every question's answer is C, so a test can answer deliberately.
        'answer': 'C',
        'explanation': 'Because of reason $i.',
        'media': null,
      },
  ],
  'passages': [
    {'id': 'p1', 'title': 'A passage', 'body': 'Some comprehension text.'},
  ],
};

void main() {
  late VaultDb db;

  setUp(() => db = VaultDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('downloading a pack', () {
    test('keeps the questions, answers, explanations and passages', () async {
      final vault = VaultRepository(_Network(_packPayload()), db);
      final pack = await vault.download('sub-chem');

      expect(pack.subjectName, 'Chemistry');
      expect(pack.count, 5);
      // The exam travels with the pack. WAEC and WAEC GCE are different
      // examinations and the vault must never forget which it holds.
      expect(pack.examSlug, 'waec');

      final qs = await db.questionsFor('sub-chem');
      expect(qs.length, 5);
      expect(qs.first.answer, 'C');
      expect(qs.first.explanation, contains('Because of reason'));

      final passage = await db.passage('p1');
      expect(passage, isNotNull);
      expect(passage!.body, contains('comprehension'));
    });

    test('re-downloading REPLACES rather than duplicating', () async {
      final vault = VaultRepository(_Network(_packPayload(questions: 5)), db);
      await vault.download('sub-chem');
      await VaultRepository(
        _Network(_packPayload(questions: 3)),
        db,
      ).download('sub-chem');

      final qs = await db.questionsFor('sub-chem');
      expect(
        qs.length,
        3,
        reason: 'a question deleted upstream must not linger on the phone',
      );
    });
  });

  group('WITH THE NETWORK OFF', () {
    late _NoNetwork offline;
    late VaultRepository vault;

    setUp(() async {
      // Download first, with a network...
      await VaultRepository(_Network(_packPayload()), db).download('sub-chem');
      // ...then lose it entirely.
      offline = _NoNetwork();
      vault = VaultRepository(offline, db);
    });

    test('a downloaded pack still opens', () async {
      final sitting = await vault.openSitting('sub-chem');
      expect(sitting, isNotNull);
      expect(sitting!.questions.length, 5);
      expect(sitting.pack.subjectName, 'Chemistry');
      expect(
        offline.calls,
        0,
        reason: 'opening downloaded questions must not touch the network',
      );
    });

    test('its comprehension passages come with it', () async {
      final sitting = await vault.openSitting('sub-chem');
      expect(sitting!.passages['p1']?.body, contains('comprehension'));
      expect(offline.calls, 0);
    });

    test(
      'answering is MARKED on the phone, with real right and wrong',
      () async {
        final sitting = await vault.openSitting('sub-chem');
        final qs = sitting!.questions;

        // Every answer is C. Get three right, two wrong.
        final chosen = <String, String>{
          for (var i = 0; i < qs.length; i++) qs[i].id: i < 3 ? 'C' : 'A',
        };

        final score = vault.score(qs, chosen);
        expect(score.correct, 3);
        expect(score.total, 5);
        expect(score.wrongIds.length, 2);
        expect(score.percent, 60);
        expect(offline.calls, 0, reason: 'marking happens on the phone');
      },
    );

    test('the explanation is there to read, offline', () async {
      final sitting = await vault.openSitting('sub-chem');
      expect(sitting!.questions.first.explanation, isNotNull);
      expect(sitting.questions.first.explanation, isNotEmpty);
    });

    test('a sitting is queued, not lost', () async {
      final sitting = await vault.openSitting('sub-chem');
      await vault.queueResult(
        localId: 'local-1',
        pack: sitting!.pack,
        correct: 3,
        total: 5,
        durationSeconds: 400,
        answers: {'q0': 'C'},
      );
      expect(await vault.pendingCount(), 1);
    });

    test('syncing while still offline LEAVES the result queued', () async {
      final sitting = await vault.openSitting('sub-chem');
      await vault.queueResult(
        localId: 'local-1',
        pack: sitting!.pack,
        correct: 3,
        total: 5,
        durationSeconds: 400,
        answers: {'q0': 'C'},
      );

      final sent = await vault.syncPending();
      expect(sent, 0);
      expect(
        await vault.pendingCount(),
        1,
        reason: 'a paper is never dropped because a request failed',
      );
    });

    test(
      'a subject NOT downloaded returns null rather than pretending',
      () async {
        expect(await vault.openSitting('sub-physics'), isNull);
      },
    );
  });

  group('when the network returns', () {
    test('queued results are sent and marked synced', () async {
      await VaultRepository(_Network(_packPayload()), db).download('sub-chem');
      final pack = (await db.pack('sub-chem'))!;

      final net = _Network(_packPayload());
      final vault = VaultRepository(net, db);

      await vault.queueResult(
        localId: 'local-1',
        pack: pack,
        correct: 3,
        total: 5,
        durationSeconds: 400,
        answers: {'q0': 'C', 'q1': 'A'},
      );
      await vault.queueResult(
        localId: 'local-2',
        pack: pack,
        correct: 5,
        total: 5,
        durationSeconds: 300,
        answers: {'q0': 'C'},
      );

      expect(await vault.syncPending(), 2);
      expect(await vault.pendingCount(), 0);

      // What reached the server is what the phone marked.
      expect(net.posted.length, 2);
      expect(net.posted.first['correct'], 3);
      expect(net.posted.first['total'], 5);
      expect(net.posted.first['localId'], 'local-1');
      expect(jsonDecode(jsonEncode(net.posted.first['answers']))['q0'], 'C');
    });

    test('a mid-sync failure keeps the rest queued for next time', () async {
      await VaultRepository(_Network(_packPayload()), db).download('sub-chem');
      final pack = (await db.pack('sub-chem'))!;

      final net = _Network(_packPayload())..failFirst = 1;
      final vault = VaultRepository(net, db);

      await vault.queueResult(
        localId: 'a',
        pack: pack,
        correct: 1,
        total: 5,
        durationSeconds: 10,
        answers: {},
      );
      await vault.queueResult(
        localId: 'b',
        pack: pack,
        correct: 2,
        total: 5,
        durationSeconds: 10,
        answers: {},
      );

      expect(await vault.syncPending(), 0);
      expect(await vault.pendingCount(), 2);

      // The signal comes back properly.
      expect(await vault.syncPending(), 2);
      expect(await vault.pendingCount(), 0);
    });
  });

  group('managing space', () {
    test('a pack can be removed, and takes its questions with it', () async {
      final vault = VaultRepository(_Network(_packPayload()), db);
      await vault.download('sub-chem');
      expect(await db.questionCount(), 5);

      await vault.remove('sub-chem');
      expect(await db.allPacks(), isEmpty);
      expect(await db.questionCount(), 0);
    });

    test('hasAnyPack tells the UI which offline message to show', () async {
      expect(await db.hasAnyPack(), isFalse);
      await VaultRepository(_Network(_packPayload()), db).download('sub-chem');
      expect(await db.hasAnyPack(), isTrue);
    });
  });
}
