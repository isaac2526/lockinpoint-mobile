import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The real vault: a SQLite file on the device, opened on a background
/// isolate so a large pack never janks a frame.
///
/// WHY SUPPORT AND NOT DOCUMENTS.
/// The vault is the app's own storage, not the student's. Documents is a
/// user-visible folder — on desktop it is the one they open to find their own
/// files, and on both desktops it is routinely swept into cloud backup. A
/// question cache does not belong there.
///
/// It also does not RESOLVE there. On Linux, getApplicationDocumentsDirectory
/// shells out to `xdg-user-dir DOCUMENTS`, which a minimal desktop image does
/// not ship — so the vault threw MissingPlatformDirectoryException before it
/// had opened a single pack, and the whole feature was dead on a plain Linux
/// build. Found by running the offline check on the real Linux binary; a
/// mocked test could never have seen it.
///
/// Documents remains as a fallback so an existing install that already has a
/// vault.sqlite there keeps reading it rather than silently starting empty.
QueryExecutor openVault() => LazyDatabase(() async {
  final dir = await _vaultDirectory();
  return NativeDatabase.createInBackground(
    File(p.join(dir.path, 'vault.sqlite')),
  );
});

Future<Directory> _vaultDirectory() async {
  try {
    return await getApplicationSupportDirectory();
  } on MissingPlatformDirectoryException {
    // Some platforms have no support directory at all.
    return getApplicationDocumentsDirectory();
  }
}
