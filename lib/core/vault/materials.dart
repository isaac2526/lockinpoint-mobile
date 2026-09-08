import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../api.dart';
import '../config.dart';
import 'vault_db.dart';
import 'vault_repository.dart';

/// ===========================================================================
/// TIER TWO · notes and documents, one at a time, because the student said so.
///
/// The questions are fetched once for everybody: a few hundred kilobytes a
/// subject, and without them the app cannot show a single thing offline.
/// MATERIALS ARE DIFFERENT. A past paper PDF is tens of megabytes, most
/// students want three of them and not three hundred, and spending somebody's
/// data bundle on a file they did not ask for is a way to lose them.
///
/// So every note and every document carries its own button, and nothing here
/// ever runs on its own.
///
/// A DOCUMENT COMES THROUGH THE GATE. `/api/doc/<id>` checks the session,
/// checks activation, and burns the reader's name across every page — so the
/// copy saved to the phone is watermarked exactly like the one read online.
/// Fetching from storage directly would be faster and would hand out a clean
/// copy, which is the one thing the gate exists to prevent.
/// ===========================================================================

final materialVaultProvider = Provider<MaterialVault>(
  (ref) => MaterialVault(ref.read(apiProvider), ref.read(vaultDbProvider)),
);

/// Everything kept on this phone, biggest first — the order a student wants
/// when they are looking for space to free.
final savedMaterialsProvider = FutureProvider<List<VaultMaterial>>(
  (ref) => ref.read(vaultDbProvider).savedMaterials(),
);

/// Whether one particular material is already here. Keyed by id so a shelf
/// can ask about each row without a query per frame.
final materialSavedProvider = FutureProvider.family<bool, String>(
  (ref, id) async => await ref.read(vaultDbProvider).material(id) != null,
);

class MaterialVault {
  MaterialVault(this._api, this._db);

  final Api _api;
  final VaultDb _db;

  /// Keeps a note. Its body is HTML and small, so it lives in the database
  /// beside the questions rather than as a file.
  Future<void> saveNote({
    required String id,
    required String subjectId,
    required String title,
  }) async {
    final res = await _api.get('/api/mobile/classroom', query: {'note': id});
    final n = res['note'];
    if (n is! Map) throw ApiFailure('That note is not available.');
    final body = n['body'] as String? ?? '';
    await _db.saveMaterial(
      id: id,
      kind: 'note',
      subjectId: subjectId,
      title: title.isEmpty ? (n['title'] as String? ?? 'Note') : title,
      body: body,
      bytes: body.length,
    );
  }

  /// Keeps a document. The bytes go to a real file; only the path is stored.
  /// A 40MB PDF inside a SQLite row is a 40MB read every time the row is
  /// touched, and on a 1GB phone that is how an app gets killed for opening
  /// its own library.
  Future<void> saveDocument({
    required String id,
    required String subjectId,
    required String title,

    /// The path the server gave — `/api/doc/<id>`, the watermark gate.
    required String url,
  }) async {
    if (kIsWeb) {
      throw ApiFailure('There is nowhere to keep files on the web.');
    }
    final dir = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'materials'),
    );
    await dir.create(recursive: true);
    // The id names the file, so a title with a slash in it cannot escape the
    // directory and two documents with the same title cannot collide.
    final file = File(p.join(dir.path, '$id.pdf'));

    final bytes = await _api.download(
      url.startsWith('http') ? url : '${AppConfig.apiBase}$url',
    );
    await file.writeAsBytes(bytes, flush: true);

    await _db.saveMaterial(
      id: id,
      kind: 'document',
      subjectId: subjectId,
      title: title,
      path: file.path,
      bytes: bytes.length,
    );
  }

  /// Gives the space back. The row and the file go together — a row with no
  /// file is a button that fails, and a file with no row is space nobody can
  /// find.
  Future<void> forget(String id) async {
    final m = await _db.material(id);
    final path = m?.path;
    if (path != null && path.isNotEmpty && !kIsWeb) {
      try {
        final f = File(path);
        if (f.existsSync()) await f.delete();
      } catch (_) {
        /* A file that has already gone is the outcome we wanted anyway. */
      }
    }
    await _db.removeMaterial(id);
  }

  /// The saved copy of a note, or null when it was never kept.
  Future<String?> noteBody(String id) async => (await _db.material(id))?.body;

  /// The saved file, or null. Checked for existence rather than trusted: a
  /// student who cleared the app's storage from Android settings has a row
  /// pointing at nothing, and opening that must fail like a missing download
  /// rather than crash.
  Future<File?> documentFile(String id) async {
    if (kIsWeb) return null;
    final path = (await _db.material(id))?.path;
    if (path == null || path.isEmpty) return null;
    final f = File(path);
    return f.existsSync() ? f : null;
  }
}
