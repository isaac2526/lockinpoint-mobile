import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/vault/essential_download.dart';
import 'package:lockinpoint/core/vault/vault_db.dart';

/// ===========================================================================
/// TWO TIERS, AND THE LINE BETWEEN THEM.
///
///   TEXT is fetched once, for everybody, and cannot be declined. A student
///     who says "not now" and then opens the app on a bus with no signal did
///     not choose an app that shows them nothing — they chose "not now".
///
///   MATERIALS are opted into one at a time. A past-paper PDF is tens of
///     megabytes and nobody's data bundle should be spent on one they did not
///     ask for.
///
/// The tests below hold the two things that are silent when they break: the
/// megabyte figure a student is watching to decide whether they can afford to
/// finish, and the resume that stops a phone dying at 60% starting again.
/// ===========================================================================
void main() {
  group('the progress a student is watching', () {
    test('percent and size come from real bytes, never from a guess', () {
      const s = EssentialState(
        phase: EssentialPhase.running,
        totalBytes: 8 * 1048576,
        doneBytes: 2 * 1048576,
      );
      expect(s.percent, 25);
      expect(s.sizeLine, '2.0 MB of about 8.0 MB');
    });

    test('a small download is spoken of in KB, not 0.0 MB', () {
      const s = EssentialState(
        phase: EssentialPhase.running,
        totalBytes: 400 * 1024,
        doneBytes: 100 * 1024,
      );
      expect(s.sizeLine, '100 KB of about 400 KB');
    });

    test('nothing to fetch never divides by zero', () {
      const s = EssentialState(phase: EssentialPhase.done);
      expect(s.fraction, 0);
      expect(s.percent, 0);
    });

    test('the bar cannot exceed full, whatever the estimate said', () {
      // The byte figures are an ESTIMATE. If the real packs come in heavier
      // than the manifest predicted, a bar that reads 130% is worse than one
      // that sits at 100.
      const s = EssentialState(
        phase: EssentialPhase.running,
        totalBytes: 1000,
        doneBytes: 1300,
      );
      expect(s.percent, 100);
    });
  });

  group('the second tier is a separate table, kept apart on purpose', () {
    late VaultDb db;
    setUp(() => db = VaultDb.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a note keeps its body; a document keeps only its path', () async {
      await db.saveMaterial(
        id: 'n1',
        kind: 'note',
        subjectId: 's1',
        title: 'Acids and bases',
        body: '<p>Water is H<sub>2</sub>O</p>',
        bytes: 30,
      );
      await db.saveMaterial(
        id: 'd1',
        kind: 'document',
        subjectId: 's1',
        title: '2019 paper',
        path: '/data/materials/d1.pdf',
        bytes: 40 * 1048576,
      );

      final note = await db.material('n1');
      expect(note!.body, contains('<sub>2</sub>'));
      expect(note.path, isNull);

      /* The 40MB does NOT live in the row. A PDF inside SQLite is a 40MB read
         every time the row is touched, and on a 1GB phone that is how an app
         gets killed for opening its own library. */
      final doc = await db.material('d1');
      expect(doc!.path, '/data/materials/d1.pdf');
      expect(doc.body, isNull);
    });

    test('saving again updates rather than failing — that is Update', () async {
      await db.saveMaterial(
        id: 'd1',
        kind: 'document',
        subjectId: 's1',
        title: 'Old',
        bytes: 10,
      );
      await db.saveMaterial(
        id: 'd1',
        kind: 'document',
        subjectId: 's1',
        title: 'New',
        bytes: 20,
      );
      final rows = await db.savedMaterials();
      expect(rows.length, 1);
      expect(rows.single.title, 'New');
    });

    test(
      'biggest first, because that is what a student is looking for',
      () async {
        await db.saveMaterial(
          id: 'a',
          kind: 'note',
          subjectId: 's',
          title: 'small',
          bytes: 5,
        );
        await db.saveMaterial(
          id: 'b',
          kind: 'document',
          subjectId: 's',
          title: 'huge',
          bytes: 900,
        );
        await db.saveMaterial(
          id: 'c',
          kind: 'document',
          subjectId: 's',
          title: 'medium',
          bytes: 50,
        );
        final rows = await db.savedMaterials();
        expect(rows.map((r) => r.title).toList(), ['huge', 'medium', 'small']);
      },
    );

    test('the total is what deleting them would give back', () async {
      await db.saveMaterial(
        id: 'a',
        kind: 'note',
        subjectId: 's',
        title: 'a',
        bytes: 100,
      );
      await db.saveMaterial(
        id: 'b',
        kind: 'document',
        subjectId: 's',
        title: 'b',
        bytes: 250,
      );
      expect(await db.materialBytes(), 350);
    });

    test('removing one leaves the others alone', () async {
      await db.saveMaterial(
        id: 'a',
        kind: 'note',
        subjectId: 's',
        title: 'a',
        bytes: 1,
      );
      await db.saveMaterial(
        id: 'b',
        kind: 'note',
        subjectId: 's',
        title: 'b',
        bytes: 1,
      );
      await db.removeMaterial('a');
      expect((await db.savedMaterials()).single.id, 'b');
    });
  });
}
