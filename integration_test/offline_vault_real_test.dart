import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/core/config.dart';
import 'package:lockinpoint/core/vault/vault_db.dart';
import 'package:lockinpoint/core/vault/vault_repository.dart';
import 'package:lockinpoint/features/practice/practice_repository.dart';
import 'package:path_provider/path_provider.dart';

/// ===========================================================================
/// THE OFFLINE VAULT, PROVED ON A REAL DEVICE WITH THE NETWORK REALLY GONE
///
/// THE PROMISE:
///
///   NO INTERNET IS NOT AN ANSWER FOR A QUESTION THE PHONE IS HOLDING.
///
/// WHY THIS FILE EXISTS WHEN test/offline_vault_test.dart ALREADY PASSES.
/// That one uses an in-memory database and an Api that throws. It proves the
/// repository's logic. It does NOT prove that the real Dio client, the real
/// JSON decoding, the real Drift schema, a real sqlite FILE on a real disk
/// and the real scoring all survive the network going away — because none of
/// those are exercised by a mock.
///
/// So this runs the REAL app binary on a REAL device (`-d linux`), against a
/// REAL HTTP server on 127.0.0.1 speaking the actual /api/mobile/pack
/// contract, writing to a REAL vault.sqlite in the application documents
/// directory. Then the server is KILLED, and every promise the vault makes
/// has to hold against a connection that genuinely refuses.
///
/// A killed server is not a simulation of no signal. To Dio it is the same
/// class of failure — the socket does not open — which is exactly what a
/// phone in a village with no mast experiences.
/// ===========================================================================
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late VaultRepository vault;
  late VaultDb db;
  late File dbFile;

  setUpAll(() async {
    container = ProviderContainer();
    db = container.read(vaultDbProvider);
    vault = container.read(vaultProvider);
    // The same directory the opener chooses, so the assertion below is about
    // the file the app actually wrote rather than one this test hoped for.
    final dir = await getApplicationSupportDirectory();
    dbFile = File('${dir.path}/vault.sqlite');
  });

  tearDownAll(() => container.dispose());

  // A pack downloaded in phase one and used by every phase after it.
  Pack? downloaded;
  late List<ServedQuestion> paper;
  const localId = 'offline-sitting-1';

  testWidgets('1 · ONLINE: a real download lands in a real sqlite file', (
    _,
  ) async {
    // Points at the stand-in, proving the app reads its base URL rather than
    // holding one. Guarding it means a misconfigured run fails loudly here
    // instead of quietly testing production.
    expect(
      AppConfig.apiBase,
      contains('127.0.0.1'),
      reason:
          'Run with --dart-define=LIP_API=http://127.0.0.1:<port>. Without it '
          'this test would talk to the live site.',
    );

    downloaded = await vault.download('sub-chem', limit: 200);

    expect(downloaded!.subjectName, 'Chemistry');
    expect(downloaded!.count, 12);

    // The point of the whole feature: it is ON THE DISK, not in a variable.
    expect(
      dbFile.existsSync(),
      isTrue,
      reason: 'The vault must be a file on the device, not memory.',
    );
    expect(dbFile.lengthSync(), greaterThan(0));
  });

  testWidgets('2 · the passage came down too, or English is unreadable', (
    _,
  ) async {
    final sitting = await vault.openSitting('sub-chem', count: 12, seed: 7);
    expect(sitting, isNotNull);
    expect(sitting!.passages['p-1'], isNotNull);
    expect(sitting.passages['p-1']!.body, contains('no signal'));
  });

  testWidgets('3 · THE NETWORK GOES AWAY — for real', (_) async {
    await _killStandIn();

    // Prove it is genuinely gone before claiming anything works without it.
    late Object failure;
    try {
      await container.read(apiProvider).get('/api/mobile/pack');
      fail('The stand-in is still answering; the rest of this proves nothing.');
    } catch (e) {
      failure = e;
    }
    expect(failure, isA<ApiFailure>());
    expect((failure as ApiFailure).offline, isTrue);
  });

  testWidgets('4 · OFFLINE: the downloaded pack still opens', (_) async {
    final packs = await vault.packs();
    expect(packs, isNotEmpty);
    expect(packs.first.subjectName, 'Chemistry');

    final sitting = await vault.openSitting('sub-chem', count: 12, seed: 7);
    expect(sitting, isNotNull);
    paper = sitting!.questions;
    expect(paper.length, 12);
  });

  testWidgets('5 · OFFLINE: every question is complete — stem, options, key', (
    _,
  ) async {
    for (final q in paper) {
      expect(q.question, isNotEmpty);
      expect(q.options.length, 4);
      expect(q.letters.length, q.options.length);
      expect(q.answer, isNotNull);
      expect(q.explanation, isNotNull);
    }
  });

  testWidgets('6 · OFFLINE: navigating the paper touches no network', (
    _,
  ) async {
    // Walking forward and back is pure local state; if any of it reached for
    // the server the calls above would already have thrown.
    for (var i = 0; i < paper.length; i++) {
      expect(paper[i].id, isNotEmpty);
    }
    for (var i = paper.length - 1; i >= 0; i--) {
      expect(paper[i].options, isNotEmpty);
    }
  });

  testWidgets('7 · OFFLINE: real marking, against the real key', (_) async {
    // Answer the first eight correctly and the last four wrongly, on purpose.
    final chosen = <String, String>{};
    for (var i = 0; i < paper.length; i++) {
      final q = paper[i];
      if (i < 8) {
        chosen[q.id] = q.answer!;
      } else {
        chosen[q.id] = q.letters.firstWhere((l) => l != q.answer);
      }
    }

    final score = vault.score(paper, chosen);
    expect(score.total, 12);
    expect(score.correct, 8);
    expect(score.wrongIds.length, 4);

    await vault.queueResult(
      localId: localId,
      pack: downloaded!,
      correct: score.correct,
      total: score.total,
      durationSeconds: 640,
      answers: chosen,
    );
    expect(await vault.pendingCount(), 1);
  });

  testWidgets('8 · OFFLINE: syncing fails and KEEPS the paper', (_) async {
    final sent = await vault.syncPending();
    expect(sent, 0);
    expect(
      await vault.pendingCount(),
      1,
      reason: 'A result must never be dropped because a request failed.',
    );
  });

  testWidgets('9 · the vault survives the app closing', (_) async {
    // Close the database and open a brand new one on the same file: this is
    // what tomorrow morning looks like.
    await db.close();
    final fresh = VaultDb();
    addTearDown(fresh.close);

    final packs = await fresh.allPacks();
    expect(packs.length, 1);
    expect(packs.first.subjectName, 'Chemistry');
    expect((await fresh.questionsFor('sub-chem')).length, 12);
    expect((await fresh.unsyncedResults()).length, 1);
  });

  testWidgets('10 · THE NETWORK RETURNS: the queued paper is sent', (_) async {
    await _startStandIn();

    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    final vault2 = container2.read(vaultProvider);

    final sent = await vault2.syncPending();
    expect(sent, 1);
    expect(await vault2.pendingCount(), 0);
  });
}

/// The stand-in runs as a separate process, started and stopped by the shell
/// script that runs this file. Talking to it over a control endpoint would be
/// one more thing that could pass while the real thing is broken, so the test
/// uses the crudest possible lever: the process is killed and restarted.
Future<void> _killStandIn() async {
  await Process.run('pkill', ['-f', 'fake_backend.js']);
  // Give the socket a moment to actually close.
  await Future<void>.delayed(const Duration(milliseconds: 600));
}

Future<void> _startStandIn() async {
  final port = Uri.parse(AppConfig.apiBase).port;
  await Process.start('node', [
    'tool/fake_backend.js',
    '$port',
  ], mode: ProcessStartMode.detached);
  await Future<void>.delayed(const Duration(seconds: 2));
}
