import 'dart:io';
import 'dart:math';

import 'package:bleya/services/app_client_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bleya-install-id');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  group('AppClientInfo.headers', () {
    test('sends what is known and leaves out the rest', () {
      const info = AppClientInfo(platform: 'ios', appVersion: '1.0.0+13');

      expect(info.headers, {
        'X-App-Platform': 'ios',
        'X-App-Version': '1.0.0+13',
      });
    });

    test('nothing when unknown', () {
      expect(AppClientInfo.unknown.headers, isEmpty);
    });
  });

  group('AppClientInfo.load', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('reads the platform, the version with its build and the install id',
        () async {
      PackageInfo.setMockInitialValues(
        appName: 'Bleya',
        packageName: 'com.bleyachat',
        version: '1.0.0',
        buildNumber: '13',
        buildSignature: '',
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final info = await AppClientInfo.load(directory: directory.path);

      expect(info.platform, 'ios');
      expect(info.appVersion, '1.0.0+13');
      expect(info.installId, matches(uuidV4));
      expect(
        (await AppClientInfo.load(directory: directory.path)).installId,
        info.installId,
      );
    });

    test('names no platform other than iOS and Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final info = await AppClientInfo.load(directory: directory.path);

      expect(info.platform, isNull);
      expect(info.headers.keys, isNot(contains('X-App-Platform')));
    });
  });

  group('InstallIdStore', () {
    test('creates the id on first launch and keeps it', () async {
      final first = await InstallIdStore(directory.path).read();
      final second = await InstallIdStore(directory.path).read();

      expect(first, matches(uuidV4));
      expect(second, first);
      expect(
        File('${directory.path}/install_id').readAsStringSync(),
        first,
      );
    });

    test('creates the directory if it is missing', () async {
      final nested = '${directory.path}/bleya';

      expect(await InstallIdStore(nested).read(), matches(uuidV4));
    });

    test('replaces a stored value that is not an id', () async {
      File('${directory.path}/install_id').writeAsStringSync('???');

      final id = await InstallIdStore(directory.path).read();

      expect(id, matches(uuidV4));
    });

    test('is null when the storage cannot be used', () async {
      // A file where the directory should be.
      final blocked = File('${directory.path}/blocked')..writeAsStringSync('');

      expect(await InstallIdStore(blocked.path).read(), isNull);
    });

    test('new ids are random version 4 UUIDs', () {
      final ids = {
        for (var seed = 0; seed < 20; seed++)
          InstallIdStore.newInstallId(Random(seed)),
      };

      expect(ids, hasLength(20));
      expect(ids, everyElement(matches(uuidV4)));
    });
  });
}
