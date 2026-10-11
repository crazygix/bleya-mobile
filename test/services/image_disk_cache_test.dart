import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bleya/services/image_disk_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 2 x 2 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGPQTvsPRAwQCgAofg'
  'ZBTE9LHAAAAABJRU5ErkJggg==',
);

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
    answer = (_) async => Uint8List.fromList(_png);
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

  /// Lets the background write finish.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  List<File> keptFiles() =>
      folder.listSync().whereType<File>().toList(growable: false);

  test('downloads a photo once, then the next launch reads it from the device',
      () async {
    expect(await launch().load(_photo), _png);
    await settle();
    expect(downloads, [Uri.parse(_photo)]);

    final bytes = await launch().load(_photo);

    expect(bytes, _png);
    expect(downloads, hasLength(1));
  });

  test('loads of the same photo at the same time share one download', () async {
    final download = Completer<Uint8List>();
    answer = (_) => download.future;
    final cache = launch();

    final first = cache.load(_photo);
    final second = cache.load(_photo);
    download.complete(Uint8List.fromList(_png));

    expect(await first, _png);
    expect(await second, _png);
    expect(downloads, hasLength(1));
  });

  test('a failed download keeps nothing, and the next load tries again',
      () async {
    answer = (_) async => throw const SocketException('offline');
    final cache = launch();

    await expectLater(cache.load(_photo), throwsA(isA<SocketException>()));
    await settle();
    expect(folder.existsSync() ? keptFiles() : const <File>[], isEmpty);

    answer = (_) async => Uint8List.fromList(_png);
    expect(await cache.load(_photo), _png);
    expect(downloads, hasLength(2));
  });

  test('without a folder every load downloads and nothing is written',
      () async {
    final cache = ImageDiskCache(
      download: (uri) async {
        downloads.add(uri);
        return Uint8List.fromList(_png);
      },
    );

    await cache.load(_photo);
    await settle();
    await cache.load(_photo);

    expect(downloads, hasLength(2));
    expect(folder.existsSync(), isFalse);
    // Clearing and trimming have nothing to do.
    await cache.clear();
    await cache.trim();
  });

  test('evict forgets one photo', () async {
    final cache = launch();
    await cache.load(_photo);
    await cache.load('https://cdn.test/profiles/profile-2.webp');
    await settle();

    await cache.evict(_photo);
    await cache.load(_photo);

    expect(keptFiles(), hasLength(2));
    expect(downloads, hasLength(3));
  });

  test('clear deletes every kept photo, and loading keeps them again',
      () async {
    final cache = launch();
    await cache.load(_photo);
    await settle();

    await cache.clear();
    expect(folder.existsSync(), isFalse);

    await cache.load(_photo);
    await settle();
    expect(keptFiles(), hasLength(1));
    expect(downloads, hasLength(2));
  });

  group('trim', () {
    Future<File> keptPhoto(String name, {required int ageDays, int size = 10}) {
      folder.createSync(recursive: true);
      final file = File('${folder.path}/$name')
        ..writeAsBytesSync(List.filled(size, 1));
      file.setLastModifiedSync(
        DateTime.now().subtract(Duration(days: ageDays)),
      );
      return Future.value(file);
    }

    test('drops photos not seen for 30 days, and keeps the rest', () async {
      final recent = await keptPhoto('recent', ageDays: 2);
      final old = await keptPhoto('old', ageDays: 31);

      await launch().trim();

      expect(recent.existsSync(), isTrue);
      expect(old.existsSync(), isFalse);
    });

    test('drops the least recently seen photos over the size limit', () async {
      final newest = await keptPhoto('newest', ageDays: 1);
      final middle = await keptPhoto('middle', ageDays: 2);
      final oldest = await keptPhoto('oldest', ageDays: 3);

      await launch(maxBytes: 25).trim();

      expect(newest.existsSync(), isTrue);
      expect(middle.existsSync(), isTrue);
      expect(oldest.existsSync(), isFalse);
    });

    test('drops writes left unfinished, but not one in progress', () async {
      final stale = await keptPhoto('abc.0.part', ageDays: 1);
      final fresh = await keptPhoto('abc.1.part', ageDays: 0);

      await launch().trim();

      expect(stale.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue);
    });

    test('a photo seen again counts as recent', () async {
      final cache = launch();
      await cache.load(_photo);
      await settle();
      final file = keptFiles().single;
      file.setLastModifiedSync(
          DateTime.now().subtract(const Duration(days: 40)));

      await launch().load(_photo);
      await settle();
      await launch().trim();

      expect(file.existsSync(), isTrue);
      expect(downloads, hasLength(1));
    });
  });

  group('DiskCachedNetworkImage', () {
    late ImageDiskCache previous;

    setUp(() => previous = ImageDiskCache.instance);
    tearDown(() => ImageDiskCache.instance = previous);

    testWidgets('shows a kept photo without downloading it', (tester) async {
      await tester.runAsync(() async {
        await launch().load(_photo);
        await settle();
      });
      ImageDiskCache.instance = launch();
      const image = DiskCachedNetworkImage(_photo);

      await tester.pumpWidget(const Image(image: image));
      await tester.runAsync(() async {
        await precacheImage(image, tester.element(find.byType(Image)));
      });
      await tester.pump();

      final painted = tester.widget<Image>(find.byType(Image));
      expect(painted.image, image);
      expect(
        tester.state<State<Image>>(find.byType(Image)).toString(),
        contains('2×2'),
      );
      expect(downloads, hasLength(1));
    });

    testWidgets("a download that isn't a picture is forgotten", (tester) async {
      answer = (_) async => Uint8List.fromList(utf8.encode('<html>oops'));
      ImageDiskCache.instance = launch();
      const image = DiskCachedNetworkImage(_photo);
      Object? error;

      await tester.pumpWidget(
        Image(
            image: image,
            errorBuilder: (_, e, __) {
              error = e;
              return const SizedBox();
            }),
      );
      await tester.runAsync(() async {
        await precacheImage(
          image,
          tester.element(find.byType(Image)),
          onError: (_, __) {},
        );
        await settle();
      });
      await tester.pump();

      expect(error, isNotNull);
      await tester.runAsync(() async {
        await settle();
        expect(keptFiles(), isEmpty);
      });
    });

    test('is equal for the same address', () {
      expect(
        const DiskCachedNetworkImage(_photo),
        const DiskCachedNetworkImage(_photo),
      );
      expect(
        const DiskCachedNetworkImage(_photo),
        isNot(const DiskCachedNetworkImage('https://cdn.test/other.webp')),
      );
    });
  });
}
