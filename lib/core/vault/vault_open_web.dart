import 'package:drift/drift.dart';

/// ===========================================================================
/// THE VAULT ON THE WEB
///
/// Every native drift backend — including its in-memory one — reaches for
/// `dart:ffi`, which a browser cannot compile. Importing any of them into a
/// web build does not merely disable the vault; it breaks the entire
/// application. So this file imports NOTHING native, and the conditional
/// import in `vault_db.dart` picks it for the web target.
///
/// The executor it returns refuses politely if anything ever asks it to open.
/// Nothing should: the vault's tile and drawer row are hidden on the web, and
/// an offline question pack is a thing a student carries on a phone to a
/// place with no mast, not something a browser tab needs.
///
/// Making it work properly on the web means drift's WASM backend with
/// `sqlite3.wasm` and `drift_worker.js` shipped as assets. Worth doing the
/// day the browser becomes a real target for offline study; not worth
/// pretending to have done today.
/// ===========================================================================
QueryExecutor openVault() => LazyDatabase(
  () async => throw UnsupportedError(
    'The offline vault stores questions on a device. On the web there is '
    'nothing to store them in — practise online instead.',
  ),
);
