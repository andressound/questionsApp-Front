import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el token de sesión cifrado (Android Keystore / iOS Keychain) para no
/// pedir login cada vez que se abre la app.
class SessionStore {
  const SessionStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;

  static const _key = 'session_token';

  Future<String?> read() => _storage.read(key: _key);

  Future<void> save(String token) => _storage.write(key: _key, value: token);

  Future<void> clear() => _storage.delete(key: _key);
}

const sessionStore = SessionStore();
