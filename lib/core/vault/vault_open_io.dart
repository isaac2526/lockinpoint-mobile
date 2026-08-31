import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The real vault: a SQLite file on the device, opened on a background
/// isolate so a large pack never janks a frame.
QueryExecutor openVault() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  return NativeDatabase.createInBackground(
    File(p.join(dir.path, 'vault.sqlite')),
  );
});
