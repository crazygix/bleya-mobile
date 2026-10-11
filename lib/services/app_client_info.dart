import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// What the app tells the backend about itself on every request and socket
/// connection, for analytics: the platform, the app version and a random id
/// for this install. The backend uses the install id to count sign-in
/// attempts per person instead of per attempt.
class AppClientInfo {
  final String? platform;
  final String? appVersion;
  final String? installId;

  const AppClientInfo({this.platform, this.appVersion, this.installId});

  /// Nothing known (tests, or before [load] ran): no headers are sent.
  static const unknown = AppClientInfo();

  static const platformHeader = 'X-App-Platform';
  static const versionHeader = 'X-App-Version';
  static const installIdHeader = 'X-Install-Id';

  Map<String, String> get headers => {
        if (platform != null) platformHeader: platform!,
        if (appVersion != null) versionHeader: appVersion!,
        if (installId != null) installIdHeader: installId!,
      };

  /// Reads the version and this install's id (created on first launch in
  /// [directory]). Anything that can't be read is left out; this never throws.
  static Future<AppClientInfo> load({required String directory}) async {
    String? appVersion;
    try {
      final package = await PackageInfo.fromPlatform();
      appVersion = '${package.version}+${package.buildNumber}';
    } catch (_) {
      appVersion = null;
    }

    return AppClientInfo(
      platform: switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'ios',
        TargetPlatform.android => 'android',
        _ => null,
      },
      appVersion: appVersion,
      installId: await InstallIdStore(directory).read(),
    );
  }
}

/// This install's id: a random UUID created on first launch and kept in a
/// file in the app's own storage, so uninstalling the app removes it. It is
/// not tied to the device, the account or anything else.
class InstallIdStore {
  final String directory;

  InstallIdStore(this.directory);

  static const fileName = 'install_id';
  static final _validId = RegExp(r'^[A-Za-z0-9-]{8,64}$');

  /// The stored id, or a new one (stored for next time). Null when the
  /// storage can't be used.
  Future<String?> read() async {
    final file = File('$directory/$fileName');
    try {
      if (await file.exists()) {
        final stored = (await file.readAsString()).trim();
        if (_validId.hasMatch(stored)) {
          return stored;
        }
      }
      final id = newInstallId();
      await file.create(recursive: true);
      await file.writeAsString(id, flush: true);
      return id;
    } catch (_) {
      return null;
    }
  }

  /// A random version 4 UUID.
  static String newInstallId([Random? random]) {
    final source = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => source.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}'
        '-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
