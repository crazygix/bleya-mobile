import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Downloads the picture at a web address.
typedef PhotoDownloader = Future<Uint8List> Function(Uri uri);

/// Keeps downloaded photos (profile photos, room and city pictures) on the
/// device between launches, so each one is downloaded once rather than on
/// every launch.
///
/// A photo's address never changes its picture: a new profile photo gets a
/// new, random address. So a photo kept here is shown without asking the
/// server again.
///
/// The photos live in [folder], inside the app's cache folder, which isn't
/// backed up and which the system may empty when space runs low. [trim]
/// keeps the photos seen in the last [maxAge], up to [maxBytes], and signing
/// out deletes them all ([clear]). Without a [folder], photos are downloaded
/// every time, as by [NetworkImage].
class ImageDiskCache {
  ImageDiskCache({
    this.folder,
    PhotoDownloader? download,
    this.maxBytes = 50 * 1024 * 1024,
    this.maxAge = const Duration(days: 30),
  }) : _download = download ?? _downloadWithHttpClient;

  /// The cache the app's photos load through. The app gives it its folder at
  /// startup.
  static ImageDiskCache instance = ImageDiskCache();

  /// The folder for the photos, inside the app's cache folder [cacheFolder].
  static Directory folderIn(Directory cacheFolder) =>
      Directory('${cacheFolder.path}/photos');

  // A photo read again after this long counts as seen now, for [trim].
  static const _markUsedAfter = Duration(days: 1);

  // Left by a write the app didn't finish (it was closed meanwhile).
  static const _staleWriteAge = Duration(hours: 1);
  static const _writeSuffix = '.part';

  final Directory? folder;
  final int maxBytes;
  final Duration maxAge;
  final PhotoDownloader _download;

  // Whether [folder] exists, as far as this cache knows.
  bool _folderCreated = false;
  int _writes = 0;
  // Loads of the same photo at the same time share one download.
  final Map<String, Future<Uint8List>> _loading = {};

  /// The photo at [url]: from the device when it's kept there, otherwise
  /// downloaded and kept.
  Future<Uint8List> load(String url) {
    // The block body matters: returning the removed future from the
    // callback would make this load wait for itself.
    return _loading[url] ??= _load(url).whenComplete(() {
      _loading.remove(url);
    });
  }

  Future<Uint8List> _load(String url) async {
    File? file;
    try {
      file = await _fileFor(url);
      if (file != null && await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          unawaited(_markUsed(file));
          return bytes;
        }
      }
    } catch (error) {
      // No usable cache folder: the photo still downloads.
      debugPrint('Reading a kept photo failed: $error');
      file = null;
    }

    final bytes = await _download(Uri.base.resolve(url));
    if (file != null) {
      unawaited(_keep(file, bytes));
    }
    return bytes;
  }

  /// Forgets the photo at [url], e.g. because what was kept isn't a picture.
  /// Never throws.
  Future<void> evict(String url) async {
    try {
      final file = await _fileFor(url);
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      debugPrint('Forgetting a kept photo failed: $error');
    }
  }

  /// Deletes every kept photo. Never throws.
  Future<void> clear() async {
    final folder = this.folder;
    if (folder == null) return;
    try {
      _folderCreated = false;
      if (await folder.exists()) {
        await folder.delete(recursive: true);
      }
    } catch (error) {
      debugPrint('Deleting the kept photos failed: $error');
    }
  }

  /// Deletes the photos not seen in [maxAge], then the least recently seen
  /// ones until the rest fit in [maxBytes]. Never throws.
  Future<void> trim() async {
    final folder = this.folder;
    if (folder == null || !await folder.exists()) return;
    try {
      final now = DateTime.now();
      final photos = <(File, FileStat)>[];
      await for (final entity in folder.list(followLinks: false)) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        if (entity.path.endsWith(_writeSuffix)) {
          if (now.difference(stat.modified) > _staleWriteAge) {
            await _deleteQuietly(entity);
          }
          continue;
        }
        photos.add((entity, stat));
      }

      // Most recently seen first.
      photos.sort((a, b) => b.$2.modified.compareTo(a.$2.modified));
      var keptBytes = 0;
      for (final (file, stat) in photos) {
        keptBytes += stat.size;
        if (now.difference(stat.modified) > maxAge || keptBytes > maxBytes) {
          await _deleteQuietly(file);
        }
      }
    } catch (error) {
      debugPrint('Trimming the kept photos failed: $error');
    }
  }

  /// Where the photo at [url] is kept, or null without a [folder].
  Future<File?> _fileFor(String url) async {
    final folder = this.folder;
    if (folder == null) return null;
    if (!_folderCreated) {
      await folder.create(recursive: true);
      _folderCreated = true;
    }
    final name = sha256.convert(utf8.encode(url)).toString();
    return File('${folder.path}/$name');
  }

  /// Writes [bytes] next to [file] and then moves it into place, so a photo
  /// being read is never half written.
  Future<void> _keep(File file, Uint8List bytes) async {
    final partial = File('${file.path}.${_writes++}$_writeSuffix');
    try {
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(file.path);
    } catch (error) {
      debugPrint('Keeping a photo failed: $error');
      await _deleteQuietly(partial);
    }
  }

  /// Marks [file] as seen now, at most once a day, so [trim] keeps it.
  Future<void> _markUsed(File file) async {
    try {
      final now = DateTime.now();
      if (now.difference(await file.lastModified()) > _markUsedAfter) {
        await file.setLastModified(now);
      }
    } catch (_) {
      // Only matters for trimming.
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  // One client for every download, as NetworkImage does.
  static final HttpClient _httpClient = HttpClient()..autoUncompress = false;

  static Future<Uint8List> _downloadWithHttpClient(Uri uri) async {
    final request = await _httpClient.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<List<int>>(<int>[]);
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: uri,
      );
    }
    final bytes = await consolidateHttpClientResponseBytes(response);
    if (bytes.lengthInBytes == 0) {
      throw NetworkImageLoadException(
          statusCode: response.statusCode, uri: uri);
    }
    return bytes;
  }
}

/// Like [NetworkImage], but the photo is downloaded once and then kept on the
/// device between launches ([ImageDiskCache]).
@immutable
class DiskCachedNetworkImage extends ImageProvider<DiskCachedNetworkImage> {
  const DiskCachedNetworkImage(this.url);

  final String url;

  @override
  Future<DiskCachedNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<DiskCachedNetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    DiskCachedNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadCodec(key, decode),
      scale: 1.0,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<DiskCachedNetworkImage>('Image key', key),
      ],
    );
  }

  static Future<ui.Codec> _loadCodec(
    DiskCachedNetworkImage key,
    ImageDecoderCallback decode,
  ) async {
    final cache = ImageDiskCache.instance;
    final bytes = await cache.load(key.url);
    try {
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      // Not a picture (an error page, a broken file): the next try downloads
      // it again.
      unawaited(cache.evict(key.url));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DiskCachedNetworkImage && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() =>
      '${objectRuntimeType(this, 'DiskCachedNetworkImage')}("$url")';
}
