import 'package:package_info_plus/package_info_plus.dart';

/// Versi aplikasi diambil dari paket yang terpasang (versionName / versionCode Android),
/// yaitu nilai `version:` di pubspec.yaml saat build, sehingga selalu sama dengan build Play Store.
/// Jangan menulis versi manual di sini.
class AppInfo {
  AppInfo._();

  static String _version = '';
  static int _buildNumber = 0;

  /// true setelah [init] berhasil membaca versi dari perangkat.
  static bool get isLoaded => _version.isNotEmpty;

  static String get version => _version.isEmpty ? '-' : _version;
  static int get buildNumber => _buildNumber;
  static String get displayVersion =>
      isLoaded ? 'v$_version ($_buildNumber)' : 'v-';

  /// Panggil sekali di main() sebelum runApp.
  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version.trim();
      _buildNumber = int.tryParse(info.buildNumber.trim()) ?? 0;
    } catch (_) {
      // Gagal baca (mis. saat test): biarkan kosong, jangan crash.
    }
  }

  /// Mengembalikan true jika versi aplikasi terpasang lebih lama daripada
  /// target versi/build dari /adminpanel/promo (/btapi/Promo).
  static bool isOlderThan(String latestVersion, int latestBuild) {
    if (!isLoaded) return false;
    final curParts = version
        .split('.')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .toList();
    final remParts = latestVersion
        .split('.')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .toList();

    final maxLen =
        curParts.length > remParts.length ? curParts.length : remParts.length;
    for (var i = 0; i < maxLen; i++) {
      final c = i < curParts.length ? curParts[i] : 0;
      final r = i < remParts.length ? remParts[i] : 0;
      if (c < r) return true;
      if (c > r) return false;
    }
    return latestBuild > buildNumber;
  }
}
