import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fast local cache: in-memory layer over SharedPreferences.
class LocalCache {
  LocalCache._();

  static SharedPreferences? _prefs;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static final Map<String, String> _memory = {};

  static Future<SharedPreferences> get prefs async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> warm() async {
    await prefs;
  }

  static Future<String?> read(String key) async {
    final mem = _memory[key];
    if (mem != null) return mem;
    final stored = (await prefs).getString(key);
    if (stored != null) _memory[key] = stored;
    return stored;
  }

  static Future<void> write(String key, String value) async {
    _memory[key] = value;
    await (await prefs).setString(key, value);
  }

  static Future<void> remove(String key) async {
    _memory.remove(key);
    await (await prefs).remove(key);
  }

  static Future<String?> readSecure(String key) async {
    final mem = _memory[key];
    if (mem != null) return mem;
    final stored = kIsWeb
        ? (await prefs).getString(key)
        : await _secureStorage.read(key: key);
    if (stored != null) _memory[key] = stored;
    return stored;
  }

  static Future<void> writeSecure(String key, String value) async {
    _memory[key] = value;
    if (kIsWeb) {
      await (await prefs).setString(key, value);
      return;
    }
    await _secureStorage.write(key: key, value: value);
  }

  static Future<void> removeSecure(String key) async {
    _memory.remove(key);
    if (kIsWeb) {
      await (await prefs).remove(key);
      return;
    }
    await _secureStorage.delete(key: key);
  }

  static void clearMemory() => _memory.clear();
}
