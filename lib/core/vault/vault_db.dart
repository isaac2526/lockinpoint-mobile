import '../../core/json.dart';

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

/// ONE SAVED MATERIAL · a note read offline, or a document kept on the phone.
///
/// THE SECOND TIER, and the reason it is a separate table rather than more
/// columns on Packs: a subject's QUESTIONS are a few hundred kilobytes and
/// everybody gets them; a subject's PDFs are tens of megabytes and only some
/// are ever wanted. Mixing the two would mean either forcing the PDFs on
/// everyone or making the questions optional, and both are wrong.
///
/// A NOTE'S BODY LIVES HERE. A DOCUMENT'S BYTES DO NOT — `path` points at a
/// real file on disk instead. A 40MB PDF inside a SQLite row is a 40MB read
/// every time the row is touched, and on a 1GB phone that is how an app gets
/// killed for opening its own library.
class VaultMaterials extends Table {
  TextColumn get id => text()();

  /// 'note' | 'document'
  TextColumn get kind => text()();
  TextColumn get subjectId => text()();
  TextColumn get title => text()();

  /// The note's HTML. Null for a document.
  TextColumn get body => text().nullable()();

  /// Where the file was written. Null for a note.
  TextColumn get path => text().nullable()();

  /// What it actually cost, so the vault screen can tell a student what
  /// deleting it would give back.
  IntColumn get bytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get savedAt => dateTime()();

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

@DriftDatabase(
  tables: [
    Packs,
    VaultQuestions,
    VaultPassages,
    VaultMaterials,
    PendingResults,
  ],
)
class VaultDb extends _$VaultDb {
  VaultDb() : super(openVault());

  /// Used by tests: an in-memory database, so the vault can be proven to work
  /// offline without touching a real device's filesystem.
  VaultDb.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  /* VERSION 2 ADDS SAVED MATERIALS.
     Created rather than recreated: an upgrade must not touch packs,
     questions or pending results, because a student who has downloaded forty
     subjects and has three unsent sittings on a phone with no signal would
     lose all of it to a table that could simply have been added beside
     them. */
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(vaultMaterials);
    },
  );

  // ----------------------------------------------------- saved materials ---
  //
  // TIER TWO. The questions are fetched once for everybody; these are opted
  // into one at a time, because a past-paper PDF is tens of megabytes and
  // nobody's data bundle should be spent on one they did not ask for.

  /// Biggest first — the order a student wants when they are looking for
  /// space to free.
  Future<List<VaultMaterial>> savedMaterials() =>
      (select(vaultMaterials)..orderBy([
            (t) => OrderingTerm(expression: t.bytes, mode: OrderingMode.desc),
          ]))
          .get();

  Future<List<VaultMaterial>> materialsFor(String subjectId) => (select(
    vaultMaterials,
  )..where((t) => t.subjectId.equals(subjectId))).get();

  Future<VaultMaterial?> material(String id) =>
      (select(vaultMaterials)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Upsert, so saving something already held refreshes it rather than
  /// failing — which is what "Update" on the shelf has to do.
  Future<void> saveMaterial({
    required String id,
    required String kind,
    required String subjectId,
    required String title,
    String? body,
    String? path,
    int bytes = 0,
  }) => into(vaultMaterials).insertOnConflictUpdate(
    VaultMaterialsCompanion.insert(
      id: id,
      kind: kind,
      subjectId: subjectId,
      title: title,
      body: Value(body),
      path: Value(path),
      bytes: Value(bytes),
      savedAt: DateTime.now(),
    ),
  );

  Future<void> removeMaterial(String id) =>
      (delete(vaultMaterials)..where((t) => t.id.equals(id))).go();

  /// What the saved materials actually cost, for the line on the vault screen
  /// that tells a student what deleting them would give back.
  Future<int> materialBytes() async {
    final rows = await select(vaultMaterials).get();
    return rows.fold<int>(0, (a, m) => a + m.bytes);
  }

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

  /// Save a downloaded pack.
  ///
  /// [replace] wipes any earlier copy of the SAME subject first, so a
  /// re-download is a clean refresh and a question deleted upstream does not
  /// linger on the phone for ever. It is TRUE ONLY FOR THE FIRST PAGE: a
  /// subject is fetched five hundred questions at a time, and wiping on
  /// every page would leave the phone holding only the last one.
  ///
  /// [runningCount] is how many questions the subject has after this page, so
  /// the pack row's count is the whole subject rather than the size of the
  /// last page — the vault screen and the update check both read it.
  Future<void> savePack({
    required Map<String, dynamic> pack,
    required List<Map<String, dynamic>> questions,
    required List<Map<String, dynamic>> passages,
    bool replace = true,
    int? runningCount,
  }) async {
    final subjectId = asText(pack['subjectId']);

    await transaction(() async {
      if (replace) {
        await (delete(
          vaultQuestions,
        )..where((t) => t.subjectId.equals(subjectId))).go();
      }

      await into(packs).insertOnConflictUpdate(
        Pack(
          subjectId: subjectId,
          subjectName: asText(pack['subjectName']),
          examId: asText(pack['examId']),
          examSlug: asText(pack['examSlug']),
          examShort: asText(pack['examShort']),
          count: runningCount ?? questions.length,
          downloadedAt: DateTime.now(),
        ),
      );

      await batch((b) {
        b.insertAllOnConflictUpdate(
          vaultQuestions,
          questions.map(
            (q) => VaultQuestion(
              id: asText(q['id']),
              subjectId: subjectId,
              question: asText(q['question']),
              optionsJson: jsonEncode(q['options'] ?? const []),
              lettersJson: jsonEncode(q['letters'] ?? const []),
              passageId: asTextOrNull(q['passage_id']),
              section: asTextOrNull(q['section']),
              year: asIntOrNull(q['year']),
              answer: (asTextOrNull(q['answer']))?.toUpperCase(),
              explanation: asTextOrNull(q['explanation']),
              mediaJson: q['media'] == null ? null : jsonEncode(q['media']),
            ),
          ),
        );

        b.insertAllOnConflictUpdate(
          vaultPassages,
          passages.map(
            (p) => VaultPassage(
              id: asText(p['id']),
              title: asText(p['title']),
              body: asText(p['body']),
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
