import 'package:flutter_test/flutter_test.dart';

import 'package:bungtemin_flutter/services/fcm_service.dart';
import 'package:bungtemin_flutter/services/myars_service.dart';
import 'package:bungtemin_flutter/services/nudb_ws_client.dart';

void main() {
  group('NuDB WebSocket endpoint', () {
    test('mengarah ke wss://nudb.bungtemin.net', () {
      expect(NudbWsClient.wsUrl, 'wss://nudb.bungtemin.net');
      expect(MyArsService.nudbWsUrl, 'wss://nudb.bungtemin.net');
      expect(MyArsService.nudbApiKey, NudbWsClient.apiKey);
    });
  });

  group('PushPayload & topik FCM', () {
    test('buildUserTopics menyertakan topik default dan noreg', () {
      expect(PushPayload.buildUserTopics(null), ['news', 'feeds']);
      expect(
        PushPayload.buildUserTopics('00415024'),
        ['news', 'feeds', '00415024', 'noreg_00415024'],
      );
    });

    test('fromJsonString dan resolveTargetRoute memetakan rute dengan benar', () {
      const payload = PushPayload(
        type: 'feedkoment',
        pageId: '123',
        url: '/feed/fkomen/123',
        title: 'Komentar Baru',
        body: 'Ada balasan pada cerita Anda',
      );
      final parsed = PushPayload.fromJsonString(payload.toJsonString());
      expect(parsed.type, 'feedkoment');
      expect(parsed.pageId, '123');
      expect(parsed.resolveTargetRoute(), '/tabfeed');
    });
  });
}
