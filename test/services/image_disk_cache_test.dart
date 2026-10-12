import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bleya/services/image_disk_cache.dart';
import 'package:flutter_test/flutter_test.dart';

final _photoBytes = Uint8List.fromList(List.generate(64, (i) => i));

const _photo = 'https://cdn.test/profiles/profile-1.webp';

void main() {
  late Directory cacheDir;
  late Directory folder;
  late List<Uri> downloads;
  late Future<Uint8List> Function(Uri uri) answer;

  setUp(() async {
    cacheDir = await Directory.systemTemp.createTemp('bleya-photos-test');
    folder = ImageDiskCache.folderIn(cacheDir);
    downloads = [];
    answer = (_) async => _photoBytes;
  });

  tearDown(() async {
    await cacheDir.delete(recursive: true);
  });

  /// A cache over the test folder, as the app makes one each launch.
  ImageDiskCache launch({int maxBytes = 50 * 1024 * 1024}) {
    return ImageDiskCache(
      folder: folder,
      maxBytes: maxBytes,
      download: (uri) {
        downloads.add(uri);
        return answer(uri);
      },
    );
  }

  List<File> keptFiles() => folder.existsSync()
      ? folder.listSync().whereType<File>().toList(growable: false)
      : const [];

  test('downloads a photo once, then the next launch reads it from the device',
      () async {
    final first = launch();
    expect(await first.load(_photo), _photoBytes);
    await first.writesDone();
    expect(downloads, [Uri.parse(_photo)]);
    expect(keptFiles(), hasLength(1));

    expect(await launch().load(_photo), _photoBytes);
    expect(downloads, hasLength(1));
  });

  test('loads of the same photo at the same time share one download', () async {
    final download = Completer<Uint8List>();
    answer = (_) => download.future;
    final cache = launch();

    final first = cache.load(_photo);
    final second = cache.load(_photo);
    download.complete(_photoBytes);

    expect(await first, _photoBytes);
    expect(await second, _photoBytes);
    expect(downloads, hasLength(1));
  });

  test('a failed download keeps nothing, and the next load tries again',
      () async {
    answer = (_) async => throw const SocketException('offline');
    final cache = launch();

    await expectLater(cache.load(_photo), throwsA(isA<SocketException>()));
    await cache.writesDone();
    expect(keptFiles(), isEmpty);

    answer = (_) async => _photoBytes;
    expect(await cache.load(_photo), _photoBytes);
    expect(downloads, hasLength(2));
  });

  test('without a folder every load downloads and nothing is written',
      () async {
    final cache = ImageDiskCache(
      download: (uri) async {
        downloads.add(uri);
        return _photoBytes;
      },
    );

    await cache.load(_photo);
    await cache.load(_photo);
    // Clearing and trimming have nothing to do.
    await cache.clear();
    await cache.trim();

    expect(downloads, hasLength(2));
    expect(folder.existsSync(), isFalse);
  });

  test('evict forgets one photo', () async {
    final cache = launch();
    await cache.load(_photo);
    await cache.load('https://cdn.test/profiles/profile-2.webp');
    await cache.writesDone();

    await cache.evict(_photo);
    expect(keptFiles(), hasLength(1));

    await cache.load(_photo);
    await cache.writesDone();
    expect(keptFiles(), hasLength(2));
    expect(downloads, hasLength(3));
  });

  test('clear deletes every kept photo, and loading keeps them again',
      () async {
    final cache = launch();
    await cache.load(_photo);
    await cache.writesDone();

    await cache.clear();
    expect(folder.existsSync(), isFalse);

    await cache.load(_photo);
    await cache.writesDone();
    expect(keptFiles(), hasLength(1));
    expect(downloads, hasLength(2));
  });

  group('trim', () {
    File keptPhoto(String name, {required int ageDays, int size = 10}) {
      folder.createSync(recursive: true);
      return File('${folder.path}/$name')
        ..writeAsBytesSync(List.filled(size, 1))
        ..setLastModifiedSync(
          DateTime.now().subtract(Duration(days: ageDays)),
        );
    }

    test('drops photos not seen for 30 days, and keeps the rest', () async {
      final recent = keptPhoto('recent', ageDays: 2);
      final old = keptPhoto('old', ageDays: 31);

      await launch().trim();

      expect(recent.existsSync(), isTrue);
      expect(old.existsSync(), isFalse);
    });

    test('drops the least recently seen photos over the size limit', () async {
      final newest = keptPhoto('newest', ageDays: 1);
      final middle = keptPhoto('middle', ageDays: 2);
      final oldest = keptPhoto('oldest', ageDays: 3);

      await launch(maxBytes: 25).trim();

      expect(newest.existsSync(), isTrue);
      expect(middle.existsSync(), isTrue);
      expect(oldest.existsSync(), isFalse);
    });

    test('drops writes left unfinished, but not one in progress', () async {
      final stale = keptPhoto('abc.1-0.part', ageDays: 1);
      final fresh = keptPhoto('abc.1-1.part', ageDays: 0);

      await launch().trim();

      expect(stale.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue);
    });

    test('a photo seen again counts as recent', () async {
      final first = launch();
      await first.load(_photo);
      await first.writesDone();
      final file = keptFiles().single
        ..setLastModifiedSync(
          DateTime.now().subtract(const Duration(days: 40)),
        );

      await launch().load(_photo);
      // Marking it seen runs in the background too.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await launch().trim();

      expect(file.existsSync(), isTrue);
      expect(downloads, hasLength(1));
    });
  });

  test('DiskCachedNetworkImage is equal for the same address', () {
    expect(
      const DiskCachedNetworkImage(_photo),
      const DiskCachedNetworkImage(_photo),
    );
    expect(
      const DiskCachedNetworkImage(_photo),
      isNot(const DiskCachedNetworkImage('https://cdn.test/other.webp')),
    );
  });
}
