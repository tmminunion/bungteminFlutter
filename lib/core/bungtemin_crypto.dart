import 'package:encrypt/encrypt.dart' as enc;

/// Enkripsi & dekripsi AES-256-CBC URL-Safe yang identik dengan
/// `CryptoService` di bungteminAPP dan `App\Core\Enskripsi` di bungtemin.net.
class BungteminCrypto {
  static const String _defaultKey = '7b9e2f4a5d8c1b6e3f0a9d8c7b6a5e4d';
  static const String _defaultIv = '1a2b3c4d5e6f7g8h';

  static final enc.Key _key = enc.Key.fromUtf8(_defaultKey);
  static final enc.IV _iv = enc.IV.fromUtf8(_defaultIv);
  static final enc.Encrypter _encrypter = enc.Encrypter(
    enc.AES(_key, mode: enc.AESMode.cbc, padding: 'PKCS7'),
  );

  static String encrypt(String? plainText) {
    final trimmed = (plainText ?? '').trim();
    if (trimmed.isEmpty) return '';
    final encrypted = _encrypter.encrypt(trimmed, iv: _iv);
    return encrypted.base64
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll(RegExp(r'=+$'), '');
  }

  static String decrypt(String? encryptedText) {
    var data = (encryptedText ?? '').trim();
    if (data.isEmpty) return '';

    final lower = data.toLowerCase();
    if (lower.startsWith('profil:')) {
      data = data.substring(7).trim();
    } else if (lower.startsWith('userid:')) {
      data = data.substring(7).trim();
    }

    if (RegExp(r'^[0-9]{5,10}$').hasMatch(data)) {
      return data;
    }

    data = data.replaceAll('-', '+').replaceAll('_', '/').replaceAll(' ', '+');
    final mod4 = data.length % 4;
    if (mod4 > 0) {
      data = data.padRight(data.length + (4 - mod4), '=');
    }

    try {
      return _encrypter.decrypt64(data, iv: _iv).trim();
    } catch (_) {
      return '';
    }
  }
}
