import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'net/btapi_auth.dart';

/// Disk cache manager khusus video Reels Bungtemin.
class BungteminReelCache {
  BungteminReelCache._();

  static const String cacheKey = 'bungteminReelCache';
  static final Set<String> _inFlight = <String>{};

  static final CacheManager manager = CacheManager(
    Config(
      cacheKey,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 100,
    ),
  );

  static Future<FileInfo?> getCachedFile(String url) async {
    final clean = url.trim();
    if (kIsWeb || clean.isEmpty) return null;
    try {
      return await manager.getFileFromCache(clean);
    } catch (_) {
      return null;
    }
  }

  static Future<void> precache(String url) async {
    final clean = url.trim();
    if (kIsWeb || clean.isEmpty || _inFlight.contains(clean)) return;
    _inFlight.add(clean);
    try {
      final existing = await manager.getFileFromCache(clean);
      if (existing != null) return;
      await manager.downloadFile(clean);
    } catch (_) {
      // Abaikan error precache background agar tidak mengganggu UI
    } finally {
      _inFlight.remove(clean);
    }
  }
}

/// Widget gambar jaringan menggunakan `Image.network` bawaan Flutter
/// (dengan memory cache `ImageCache` & `cacheWidth`/`cacheHeight`) agar tidak
/// pernah stuck di placeholder akibat `flutter_cache_manager`/`sqflite` pada build release Android.
class BungteminCachedImage extends StatelessWidget {
  const BungteminCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;

  static String _normalizeUrl(String raw) {
    final u = raw.trim();
    if (u.startsWith('http://bungtemin.net/') ||
        u.startsWith('http://nudb.bungtemin.net/')) {
      return u.replaceFirst('http://', 'https://');
    }
    return u;
  }

  @override
  Widget build(BuildContext context) {
    final url = _normalizeUrl(imageUrl);
    if (url.isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    return Image.network(
      url,
        headers: BtapiAuth.imageHeaders(url),
      fit: fit,
      width: width,
      height: height,
      cacheWidth: memCacheWidth,
      cacheHeight: memCacheHeight,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return placeholder ?? Container(color: const Color(0xFFE2E8F0));
      },
      errorBuilder: (_, __, ___) => errorWidget ?? const SizedBox.shrink(),
    );
  }
}
