import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [FlutterSecureStorage]. Like the iOS Keychain, a delete only
/// matches an item stored with the same accessibility.
class InMemorySecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> values = {};
  final Map<String, String> accessibilityByKey = {};

  static String _accessibility(IOSOptions? options) {
    return (options ?? IOSOptions.defaultOptions).toMap()['accessibility'] ??
        'unlocked';
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
      accessibilityByKey.remove(key);
      return;
    }
    values[key] = value;
    accessibilityByKey[key] = _accessibility(iOptions);
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (accessibilityByKey[key] != _accessibility(iOptions)) return;
    values.remove(key);
    accessibilityByKey.remove(key);
  }
}
