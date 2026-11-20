import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Client WebSocket terpusat untuk NuDB RealtimeDB (`wss://nudb.bungtemin.net`).
class NudbWsClient {
  NudbWsClient._();

  static const String wsUrl = 'wss://nudb.bungtemin.net';
  static const String apiKey = String.fromEnvironment('NUDB_API_KEY');

  /// Mengirim satu perintah (`set` / `update` / `delete`) ke NuDB via WebSocket.
  static Future<bool> sendCommand({
    required String type,
    required String path,
    required Map<String, dynamic> data,
    Duration timeout = const Duration(seconds: 6),
    Duration settleDelay = const Duration(milliseconds: 350),
  }) async {
    WebSocketChannel? channel;
    try {
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await channel.ready.timeout(timeout);
      channel.sink.add(
        jsonEncode(<String, dynamic>{
          'type': type,
          'path': path,
          'data': data,
          'headers': const <String, String>{'x-api-key': apiKey},
        }),
      );
      await Future<void>.delayed(settleDelay);
      return true;
    } catch (e) {
      debugPrint('[NuDB WS] $type $path gagal: $e');
      return false;
    } finally {
      try {
        await channel?.sink.close();
      } catch (_) {}
    }
  }
}
