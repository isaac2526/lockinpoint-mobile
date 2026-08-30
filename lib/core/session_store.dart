import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ===========================================================================
/// WHERE THE STUDENT'S SESSION LIVES ON THE PHONE
///
/// First choice: the Keychain on iOS, the Keystore-backed
/// EncryptedSharedPreferences on Android. That is where a refresh token
/// belongs, because in plaintext it is a permanent login for anyone who gets
/// the file.
///
/// But on a real student's phone the secure store is not guaranteed to work.
/// Some Android builds (Xiaomi's MIUI is the famous one) corrupt the Keystore
/// entry behind EncryptedSharedPreferences, and then writes quietly vanish:
/// the save "succeeds", the very next read returns null, and the app sends a
/// request with no key on it. The server answers 401 and a freshly logged-in
/// student is told their session ended. That exact failure was traced on a
/// live device, so this store defends against it three ways:
///
///   1. AN IN-MEMORY CACHE. The moment tokens are saved, this run of the app
///      holds them in memory. Nothing the platform does after that can take
///      the session away from the run that created it.
///   2. A READ-BACK CHECK. Every save is read back. If the secure store did
///      not return what was written, the phone's secure storage is declared
///      broken for this install.
///   3. A GUARDED FALLBACK. Only when the secure store is proven broken do
///      tokens go to SharedPreferences instead. That is a real trade-off:
///      the fallback file is not hardware-encrypted. It is accepted knowingly,
///      because the alternative on those phones is an app that cannot stay
///      logged in at all — and the token still expires and can be revoked
///      server-side.
/// ===========================================================================
class SessionStore {
  SessionStore({FlutterSecureStorage? secure}) : _box = secure ?? _defaultBox;

  static const _access = 'lip.access_token';
  static const _refresh = 'lip.refresh_token';

  /// Set once the secure store fails a write, a read or a read-back on this
  /// install, so every later launch goes straight to the store that works.
  static const _brokenFlag = 'lip.secure_store_broken';

  static const _defaultBox = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  final FlutterSecureStorage _box;

  // The cache that makes the current run unsinkable.
  String? _memAccess;
  String? _memRefresh;
  bool _memLoaded = false;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> _secureBroken() async =>
      (await _prefs).getBool(_brokenFlag) ?? false;

  Future<void> _markSecureBroken() async =>
      (await _prefs).setBool(_brokenFlag, true);

  Future<void> save({required String access, required String refresh}) async {
    _memAccess = access;
    _memRefresh = refresh;
    _memLoaded = true;

    if (!await _secureBroken()) {
      try {
        await _box.write(key: _access, value: access);
        await _box.write(key: _refresh, value: refresh);
        // Trust, then verify: did the platform actually keep it?
        final back = await _box.read(key: _access);
        if (back == access) return;
        await _markSecureBroken();
      } catch (_) {
        await _markSecureBroken();
      }
    }

    // The secure store is broken on this phone. Keep the student logged in
    // anyway — see the header for why this trade is accepted.
    final p = await _prefs;
    await p.setString(_access, access);
    await p.setString(_refresh, refresh);
  }

  Future<void> _loadIntoMemory() async {
    if (_memLoaded) return;
    _memLoaded = true;
    String? a, r;
    if (!await _secureBroken()) {
      try {
        a = await _box.read(key: _access);
        r = await _box.read(key: _refresh);
      } catch (_) {
        await _markSecureBroken();
      }
    }
    if (a == null || r == null) {
      final p = await _prefs;
      a ??= p.getString(_access);
      r ??= p.getString(_refresh);
    }
    _memAccess = a;
    _memRefresh = r;
  }

  Future<String?> accessToken() async {
    await _loadIntoMemory();
    return _memAccess;
  }

  Future<String?> refreshToken() async {
    await _loadIntoMemory();
    return _memRefresh;
  }

  Future<void> clear() async {
    _memAccess = null;
    _memRefresh = null;
    _memLoaded = true;
    try {
      await _box.delete(key: _access);
      await _box.delete(key: _refresh);
    } catch (_) {}
    final p = await _prefs;
    await p.remove(_access);
    await p.remove(_refresh);
  }
}
