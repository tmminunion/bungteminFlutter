import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Kontrol keamanan layar per halaman (Android FLAG_SECURE anti-screenshot & screen record).
class ScreenSecurity {
  static const MethodChannel _channel =
      MethodChannel('com.bung.teminapps/security');

  static Future<void> setSecure(bool enable) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('setSecureScreen', {'enable': enable});
    } catch (_) {
      // Abaikan pada platform non-Android atau environment test.
    }
  }

  static Future<void> enable() => setSecure(true);
  static Future<void> disable() => setSecure(false);
}
