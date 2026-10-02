import 'dart:io';

import 'package:bleya/services/data_export_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  late DataExportFile exportFile;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('bleya-export-test');
    exportFile = DataExportFile(temporaryDirectory: () async => temp);
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  File exportAt(String folder) =>
      File('${temp.path}/$folder${DataExportFile.fileName}');

  /// The copy share_plus makes on Android for the app it shares to.
  Future<File> androidShareCopy() async {
    final copy = exportAt('share_plus/');
    await copy.create(recursive: true);
    await copy.writeAsString('{"messages": []}');
    return copy;
  }

  test('writes the whole export, and delete removes it after sharing',
      () async {
    final file = await exportFile.write('{"messages": ["hi"]}');

    expect(file.path, exportAt('').path);
    expect(await file.readAsString(), '{"messages": ["hi"]}');

    await exportFile.delete();

    expect(await file.exists(), isFalse);
  });

  test("delete keeps Android's share copy for the app reading it", () async {
    await exportFile.write('{}');
    final copy = await androidShareCopy();

    await exportFile.delete();

    expect(await copy.exists(), isTrue);
  });

  test("deleteAll removes the export and Android's share copy", () async {
    final file = await exportFile.write('{}');
    final copy = await androidShareCopy();

    await exportFile.deleteAll();

    expect(await file.exists(), isFalse);
    expect(await copy.exists(), isFalse);
  });

  test('deleting files that are not there does not throw', () async {
    await expectLater(exportFile.delete(), completes);
    await expectLater(exportFile.deleteAll(), completes);
  });

  test('deleting never throws, even without a temp directory', () async {
    final broken = DataExportFile(
      temporaryDirectory: () async => throw const FileSystemException('gone'),
    );

    await expectLater(broken.delete(), completes);
    await expectLater(broken.deleteAll(), completes);
  });
}
