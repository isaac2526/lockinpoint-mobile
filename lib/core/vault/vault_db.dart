import 'dart:convert';

import 'package:drift/drift.dart';

/* THE OPENER IS CHOSEN AT COMPILE TIME.
   `drift/native.dart` imports `dart:ffi`, which a browser cannot compile —
   so importing it unconditionally does not merely disable the vault on the
   web, it breaks the entire web build. This conditional import keeps the
   device path off the web target entirely. */
import 'vault_open_io.dart' if (dart.library.js_interop) 'vault_open_web.dart';

part 'vault_db.g.dart';

/// ===========================================================================
/// THE OFFLINE VAULT
///
/// A student who has downloaded a subject can practise it on a bus, in a
/// village, in an exam hall car park — anywhere, with no signal at all. The
/// phone must never answer "no internet connection" for questions it is
/// already holding.
///
/// `drift` and `sqlite3_flutter_libs` have been in the pubspec for a long
/// time with no Dart file touching them. This is that scaffolding finally
/// becoming a database.
///
/// WHAT LIVES HERE
///   packs      one downloaded subject, with the EXAM it belongs to
///   questions  the stems, options, answers and explanations
///   passages   comprehension bodies, or an English pack is unreadable
///   results    sittings taken offline, waiting to reach the server
///
/// THE EXAM IS STORED ON EVERY PACK, deliberately. WAEC and WAEC GCE are
/// different examinations, and a vault that forgot which was which would
/// recreate on the phone the exact leak just fixed on the website.
/// ===========================================================================

class Packs extends Table {
  TextColumn get subjectId => text()();
  TextColumn get subjectName => text()();
  TextColumn get examId => text()();
  TextColumn get examSlug => text()();
  TextColumn get examShort => text()();
  IntColumn get count => integer()();
  DateTimeColumn get downloadedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {subjectId};
}

class VaultQuestions extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text()();
  TextColumn get question => text()();

  /// Options and letters as JSON arrays. A join table for four strings would
  /// cost more to read than it saves, and these are never queried by option.
  TextColumn get optionsJson => text()();
  TextColumn get lettersJson => text()();

  TextColumn get passageId => text().nullable()();
  TextColumn get section => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get answer => text().nullable()();
  TextColumn get explanation => text().nullable()();
  TextColumn get mediaJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class VaultPassages extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A sitting taken with no signal, waiting its turn to reach the server.
class PendingResults extends Table {
  TextColumn get localId => text()();
  TextColumn get subjectId => text()();
  TextColumn get examId => text()();
  IntColumn get correct => integer()();
  IntColumn get total => integer()();
  IntColumn get durationSeconds => integer()();

  /// questionId -> chosen letter.
  TextColumn get answersJson => text()();
  DateTimeColumn get takenAt => dateTime()();

  /// Set once the server has accepted it. Kept rather than deleted so a
  /// student can still see the paper they sat in a tunnel.
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {localId};
}

@DriftDatabase(tables: [Packs, VaultQuestions, VaultPassages, PendingResults])
class VaultDb extends _$VaultDb {
  VaultDb() : super(openVault());

  /// Used by tests: an in-memory database, so the vault can be proven to work
  /// offline without touching a real device's filesystem.
  VaultDb.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  // ------------------------------------------------------------- reading ---

  Future<List<Pack>> allPacks() => (select(
    packs,
  )..orderBy([(t) => OrderingTerm(expression: t.subjectName)])).get();

  Future<Pack?> pack(String subjectId) => (select(
    packs,
  )..where((t) => t.subjectId.equals(subjectId))).getSingleOrNull();

  Future<bool> hasAnyPack() async => (await allPacks()).isNotEmpty;

  Future<List<VaultQuestion>> questionsFor(String subjectId, {int? limit}) {
    final q = select(vaultQuestions)
      ..where((t) => t.subjectId.equals(subjectId));
    if (limit != null) q.limit(limit);
    return q.get();
  }

  Future<VaultPassage?> passage(String id) =>
      (select(vaultPassages)..where((t) => t.id.equals(id))).getSingleOrNull();

  // ------------------------------------------------------------- writing ---

  /// Save a downloaded pack. Replaces any earlier copy of the SAME subject
  /// wholesale rather than merging, so a re-download is a clean refresh and
  /// a question deleted upstream does not linger on the phone for ever.
  Future<void> savePack({
    required Map<String, dynamic> pack,
    required List<Map<String, dynamic>> questions,
    required List<Map<String, dynamic>> passages,
  }) async {
    final subjectId = pack['subjectId'] as String;

    await transaction(() async {
      await (delete(
        vaultQuestions,
      )..where((t) => t.subjectId.equals(subjectId))).go();

      await into(packs).insertOnConflictUpdate(
        Pack(
          subjectId: subjectId,
          subjectName: pack['subjectName'] as String? ?? '',
          examId: pack['examId'] as String? ?? '',
          examSlug: pack['examSlug'] as String? ?? '',
          examShort: pack['examShort'] as String? ?? '',
          count: questions.length,
          downloadedAt: DateTime.now(),
        ),
      );

      await batch((b) {
        b.insertAllOnConflictUpdate(
          vaultQuestions,
          questions.map(
            (q) => VaultQuestion(
              id: q['id'] as String,
              subjectId: subjectId,
              question: q['question'] as String? ?? '',
              optionsJson: jsonEncode(q['options'] ?? const []),
              lettersJson: jsonEncode(q['letters'] ?? const []),
              passageId: q['passage_id'] as String?,
              section: q['section'] as String?,
              year: (q['year'] as num?)?.toInt(),
              answer: (q['answer'] as String?)?.toUpperCase(),
              explanation: q['explanation'] as String?,
              mediaJson: q['media'] == null ? null : jsonEncode(q['media']),
            ),
          ),
        );

        b.insertAllOnConflictUpdate(
          vaultPassages,
          passages.map(
            (p) => VaultPassage(
              id: p['id'] as String,
              title: p['title'] as String? ?? '',
              body: p['body'] as String? ?? '',
            ),
          ),
        );
      });
    });
  }

  /// Forget a subject. The passages are left alone: they are shared between
  /// subjects and are small.
  Future<void> removePack(String subjectId) async {
    await transaction(() async {
      await (delete(
        vaultQuestions,
      )..where((t) => t.subjectId.equals(subjectId))).go();
      await (delete(packs)..where((t) => t.subjectId.equals(subjectId))).go();
    });
  }

  // ------------------------------------------------- results taken offline --

  Future<void> queueResult(PendingResult r) =>
      into(pendingResults).insertOnConflictUpdate(r);

  Future<List<PendingResult>> unsyncedResults() =>
      (select(pendingResults)..where((t) => t.synced.equals(false))).get();

  Future<void> markSynced(String localId) =>
      (update(pendingResults)..where((t) => t.localId.equals(localId))).write(
        const PendingResultsCompanion(synced: Value(true)),
      );

  /// Rough size on disk, for the screen that offers to free space.
  Future<int> questionCount() async {
    final rows = await select(vaultQuestions).get();
    return rows.length;
  }
}
