/// Pengganti langsung `package:http/http.dart` dengan cache SQLite local-first.
///
/// Cukup ganti import:
/// ```dart
/// import '../core/net/cached_http.dart' as http;
/// ```
/// Semua `http.get(...)` / `http.post(...)` otomatis lewat [OfflineFirstClient],
/// sementara `http.Response`, `http.MultipartRequest`, dll tetap tersedia.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'offline_first_client.dart';

export 'package:http/http.dart' hide get, post;
export 'offline_first_client.dart' show OfflineFirstClient;

/// Client tunggal untuk seluruh aplikasi.
final OfflineFirstClient apiClient = OfflineFirstClient();

Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
    apiClient.get(url, headers: headers);

Future<http.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    apiClient.post(url, headers: headers, body: body, encoding: encoding);
