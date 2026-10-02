import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Reads a property list (XML format) into Dart maps, lists and values.
Map<String, Object?> readPlist(String path) {
  final document = XmlDocument.parse(File(path).readAsStringSync());
  return _plistValue(document.rootElement.childElements.single)
      as Map<String, Object?>;
}

Object? _plistValue(XmlElement element) {
  switch (element.name.local) {
    case 'dict':
      final children = element.childElements.toList();
      return {
        for (var i = 0; i < children.length; i += 2)
          children[i].innerText: _plistValue(children[i + 1]),
      };
    case 'array':
      return element.childElements.map(_plistValue).toList();
    case 'string':
      return element.innerText;
    case 'integer':
      return int.parse(element.innerText);
    case 'true':
      return true;
    case 'false':
      return false;
    default:
      throw FormatException('Unexpected <${element.name}> in a plist');
  }
}

void main() {
  group('iOS privacy manifest', () {
    final manifest = readPlist('ios/Runner/PrivacyInfo.xcprivacy');

    test('declares exactly the data types in the App Store answers', () {
      // docs/store-privacy-answers.md, "App Store Connect → App Privacy".
      final types = (manifest['NSPrivacyCollectedDataTypes'] as List)
          .cast<Map<String, Object?>>();

      expect(
        types.map((type) => type['NSPrivacyCollectedDataType']),
        unorderedEquals([
          'NSPrivacyCollectedDataTypeEmailAddress',
          'NSPrivacyCollectedDataTypeUserID',
          'NSPrivacyCollectedDataTypePhotosorVideos',
          'NSPrivacyCollectedDataTypeOtherUserContent',
        ]),
      );
      for (final type in types) {
        final name = type['NSPrivacyCollectedDataType'];
        expect(type['NSPrivacyCollectedDataTypeLinked'], isTrue,
            reason: '$name');
        expect(
          type['NSPrivacyCollectedDataTypeTracking'],
          isFalse,
          reason: '$name',
        );
        expect(
          type['NSPrivacyCollectedDataTypePurposes'],
          ['NSPrivacyCollectedDataTypePurposeAppFunctionality'],
          reason: '$name',
        );
      }
    });

    test('declares no tracking', () {
      expect(manifest['NSPrivacyTracking'], isFalse);
      expect(manifest['NSPrivacyTrackingDomains'], isEmpty);
    });

    test('keeps the reasons for the APIs the app uses', () {
      final reasons = {
        for (final api in (manifest['NSPrivacyAccessedAPITypes'] as List)
            .cast<Map<String, Object?>>())
          api['NSPrivacyAccessedAPIType']:
              api['NSPrivacyAccessedAPITypeReasons'],
      };

      expect(reasons, {
        'NSPrivacyAccessedAPICategoryUserDefaults': ['CA92.1'],
        'NSPrivacyAccessedAPICategoryFileTimestamp': ['C617.1'],
        'NSPrivacyAccessedAPICategorySystemBootTime': ['35F9.1'],
        'NSPrivacyAccessedAPICategoryDiskSpace': ['E174.1'],
      });
    });
  });

  group('links', () {
    test('iOS claims bleyachat.com for passkeys only, not for links', () {
      final entitlements = readPlist('ios/Runner/Runner.entitlements');

      expect(
        entitlements['com.apple.developer.associated-domains'],
        ['webcredentials:bleyachat.com'],
      );
    });

    test('iOS turns off Flutter deep linking', () {
      final info = readPlist('ios/Runner/Info.plist');

      expect(info['FlutterDeepLinkingEnabled'], isFalse);
    });

    test('Android turns off Flutter deep linking for the app screen', () {
      final manifest = XmlDocument.parse(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      );
      final mainActivity = manifest.findAllElements('activity').singleWhere(
          (a) => a.getAttribute('android:name') == '.MainActivity');
      final deepLinking = mainActivity.findElements('meta-data').where(
            (m) =>
                m.getAttribute('android:name') == 'flutter_deeplinking_enabled',
          );

      expect(deepLinking, hasLength(1));
      expect(deepLinking.single.getAttribute('android:value'), 'false');
    });
  });
}
