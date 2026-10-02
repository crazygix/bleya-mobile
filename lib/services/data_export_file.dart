import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// The file "Export my data" shares. It holds the account's full data
/// (emails, messages, reports and blocks), so it stays on the device only
/// while the share sheet is open, and signing out removes any copy left.
class DataExportFile {
  static const fileName = 'bleya-data-export.json';

  /// The folder share_plus copies shared files into on Android, inside the
  /// temp directory. The receiving app reads that copy after the share
  /// sheet closes, so it stays until sign-out.
  static const _shareCopyFolder = 'share_plus';

  DataExportFile({Future<Directory> Function()? temporaryDirectory})
      : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final Future<Directory> Function() _temporaryDirectory;

  /// Writes [contents] to the export file and returns it, ready to share.
  Future<File> write(String contents) async {
    final file = await _exportFile();
    await file.writeAsString(contents, flush: true);
    return file;
  }

  /// Deletes the file [write] created, once it has been shared. Never
  /// throws.
  Future<void> delete() async {
    await _deleteIfPresent(_exportFile);
  }

  /// Deletes the export file and Android's share copy of it. Never throws.
  Future<void> deleteAll() async {
    await _deleteIfPresent(_exportFile);
    await _deleteIfPresent(() async {
      final directory = await _temporaryDirectory();
      return File('${directory.path}/$_shareCopyFolder/$fileName');
    });
  }

  Future<File> _exportFile() async {
    final directory = await _temporaryDirectory();
    return File('${directory.path}/$fileName');
  }

  static Future<void> _deleteIfPresent(Future<File> Function() file) async {
    try {
      final target = await file();
      if (await target.exists()) {
        await target.delete();
      }
    } catch (error) {
      debugPrint('Deleting the data export failed: $error');
    }
  }
}
