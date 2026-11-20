/// Token sesi untuk endpoint BTAPI yang kini wajib login
/// (`/btapi/MyEvent/*`, `/btapi/Calendar/hravatar/*`, `/btapi/absensiincome/all`,
/// `/btapi/training/*`).
///
/// Diisi otomatis oleh `SessionStore` saat sesi dimuat/disimpan dan dikosongkan
/// saat logout, sehingga `OfflineFirstClient`, request manual, dan gambar
/// (`Image.network(headers: ...)`) cukup memakai helper ini.
class BtapiAuth {
  BtapiAuth._();

  static String _token = '';

  static String get token => _token;

  static void setToken(String? value) => _token = (value ?? '').trim();

  static void clear() => _token = '';

  /// Hanya URL BTAPI milik bungtemin.net yang boleh menerima token.
  static bool isBtapiUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    final okHost = host == 'bungtemin.net' || host == 'www.bungtemin.net';
    return okHost && uri.path.toLowerCase().startsWith('/btapi/');
  }

  /// Header Authorization (kosong bila belum login).
  static Map<String, String> headers() =>
      _token.isEmpty ? const {} : {'Authorization': 'Bearer $_token'};

  /// Header untuk `Image.network` / provider gambar: token hanya dikirim ke BTAPI.
  static Map<String, String>? imageHeaders(String url) =>
      (_token.isNotEmpty && isBtapiUrl(url)) ? headers() : null;
}
