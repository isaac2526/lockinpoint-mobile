import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the student's session lives on the phone.
///
/// The Keychain on iOS and the Keystore-backed EncryptedSharedPreferences on
/// Android — never plain preferences, because a refresh token in plaintext is
/// a permanent login for anyone who gets the file.
class SessionStore {
  static const _access = 'lip.access_token';
  static const _refresh = 'lip.refresh_token';

  final _box = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> save({required String access, required String refresh}) async {
    await _box.write(key: _access, value: access);
    await _box.write(key: _refresh, value: refresh);
  }

  Future<String?> accessToken() => _box.read(key: _access);
  Future<String?> refreshToken() => _box.read(key: _refresh);

  Future<void> clear() async {
    await _box.delete(key: _access);
    await _box.delete(key: _refresh);
  }
}
