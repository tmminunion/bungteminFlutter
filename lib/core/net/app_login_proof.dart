import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Generator header `api-key` bertanda tangan HMAC-SHA256 untuk `/btapi/loginapk`.
class AppLoginProof {
  AppLoginProof._();

  static const String _secret = String.fromEnvironment('APP_LOGIN_SECRET');
  static const String _appId = 'com.bung.teminapps';
  static const String loginPath = '/btapi/loginapk';

  static bool get isConfigured => _secret.isNotEmpty;

  static String? buildHeader({required String noreg, required String uid}) {
    if (_secret.isEmpty) return null;
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final rng = Random.secure();
    final nonce = List<int>.generate(16, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final canonical = 'POST|$loginPath|$ts|$nonce|$noreg|$uid';
    final sig = Hmac(sha256, utf8.encode(_secret))
        .convert(utf8.encode(canonical))
        .toString();
    return 'v1|$_appId|$ts|$nonce|flutter|$sig';
  }
}
