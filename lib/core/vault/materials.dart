import '../../core/json.dart';

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
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

/// ===========================================================================
/// OPENING A DOCUMENT — the step that did not exist.
///
/// Tapping a file used to hand its URL to the phone's browser. That URL is
/// `/api/doc/<id>`: the gate that checks activation and floods every page
/// with the reader's name. The browser has no session, so the student landed
/// on the LOGIN PAGE where a PDF should have been — and the copy the Keep
/// button had correctly downloaded could never be opened either, because
/// nothing in the app ever read a saved file back.
///
/// So: use the kept copy when there is one — instant, and works with no
/// signal — otherwise fetch it through the gate with the session attached,
/// cache it, and open that. Either way the file the student sees carries
/// their own name on every page, which is the entire point of the gate.
/// ===========================================================================
class DocumentOpener {
  const DocumentOpener(this._api, this._db);

  final Api _api;
  final VaultDb _db;

  /// Where a fetched-but-not-kept document lives. Separate from `materials/`
  /// so clearing the vault does not delete what a student is reading, and
  /// vice versa.
  Future<Directory> _cacheDir() async {
    final dir = Directory(
      p.join((await getTemporaryDirectory()).path, 'documents'),
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// Returns null on success, or a sentence to show the student.
  Future<String?> open({required String id, required String url}) async {
    if (kIsWeb) {
      /* On the web the browser IS the session — it carries the cookie — so
         the original behaviour is correct there and only there. */
      return 'openInBrowser';
    }

    try {
      // 1. Already kept? Open that, and never touch the network.
      final kept = await _db.material(id);
      final keptPath = kept?.path;
      if (keptPath != null && keptPath.isNotEmpty) {
        final f = File(keptPath);
        if (await f.exists()) return await _launch(f);
      }

      // 2. Cached from a previous read?
      final dir = await _cacheDir();
      final cached = File(p.join(dir.path, '$id.pdf'));
      if (await cached.exists() && await cached.length() > 0) {
        return await _launch(cached);
      }

      // 3. Through the gate, with the session attached.
      final bytes = await _api.download(
        url.startsWith('http') ? url : '${AppConfig.apiBase}$url',
      );
      if (bytes.isEmpty) return 'That file is empty.';
      await cached.writeAsBytes(bytes, flush: true);
      /* AWAITED, not returned bare: a Future returned out of a try block
         escapes its own catch, so a platform channel that throws would have
         surfaced as an unhandled error instead of the sentence below. */
      return await _launch(cached);
    } on ApiFailure catch (e) {
      return e.message;
    } catch (_) {
      return 'That file could not be opened.';
    }
  }

  /// Hands a downloaded file to whatever the operating system uses to read
  /// PDFs.
  ///
  /// TWO PLUGINS, BECAUSE ONE DOES NOT EXIST EVERYWHERE. open_filex ships
  /// android and ios ONLY — its pubspec says so. On macOS, Windows and Linux
  /// the call throws MissingPluginException, which this class caught and
  /// reported as "That file could not be opened": so EVERY document, on every
  /// desktop build, failed identically, with no reason and no way forward.
  ///
  /// url_launcher does support all three, and a file:// URI is exactly what
  /// its desktop implementations are for. Android and iOS keep open_filex,
  /// because it is the one that can tell "no PDF reader installed" apart from
  /// "that did not work" — a distinction a student on a cheap Android needs.
  Future<String?> _launch(File f) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final r = await OpenFilex.open(f.path);
      if (r.type == ResultType.done) return null;
      /* NO PDF READER ON THE PHONE is a real state on a cheap Android, and it
         is the student's to fix — so it is said plainly rather than reported
         as a failure of the app. */
      if (r.type == ResultType.noAppToOpen) {
        return 'No app on this phone can open a PDF. Install a PDF reader and '
            'try again — the file is already downloaded.';
      }
      return 'That file could not be opened.';
    }

    final ok = await launchUrl(f.uri);
    if (ok) return null;
    return 'Nothing on this computer is set up to open that file. It is '
        'saved at ${f.path} if you want to open it yourself.';
  }
}

final documentOpenerProvider = Provider<DocumentOpener>(
  (ref) => DocumentOpener(ref.read(apiProvider), ref.read(vaultDbProvider)),
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
    final body = asText(n['body']);
    await _db.saveMaterial(
      id: id,
      kind: 'note',
      subjectId: subjectId,
      title: title.isEmpty ? (asText(n['title'], 'Note')) : title,
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
