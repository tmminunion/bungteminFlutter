import 'package:flutter_test/flutter_test.dart';
import 'package:bungtemin_flutter/core/net/btapi_auth.dart';

void main() {
  tearDown(BtapiAuth.clear);

  test('token hanya dikirim ke BTAPI bungtemin.net', () {
    BtapiAuth.setToken('  abc.def.ghi ');
    expect(
      BtapiAuth.imageHeaders('https://bungtemin.net/btapi/Calendar/hravatar/00415024'),
      {'Authorization': 'Bearer abc.def.ghi'},
    );
    expect(BtapiAuth.imageHeaders('https://evil.example/btapi/x'), isNull);
    expect(BtapiAuth.imageHeaders('https://bungtemin.net/gambar/foto.jpg'), isNull);
    expect(BtapiAuth.imageHeaders('https://bungtemin.net.evil.com/btapi/x'), isNull);
  });

  test('tanpa token tidak ada header', () {
    expect(BtapiAuth.headers(), isEmpty);
    expect(
      BtapiAuth.imageHeaders('https://bungtemin.net/btapi/Calendar/hravatar/1'),
      isNull,
    );
  });
}
