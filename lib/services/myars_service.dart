import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/bungtemin_crypto.dart';
import '../core/net/offline_first_client.dart';
import '../core/session_store.dart';
import '../models/myars_models.dart';
import 'nudb_ws_client.dart';

/// Service MyArs & Absensi Online — menyamakan logika 100% dengan
/// `FiredataService`, `UploadingService`, `AbsensifireService`, `DbAbsensiService`,
/// dan `PresenceService.setAbsensi()` di `bungteminAPP`.
class MyArsService {
  MyArsService({
    http.Client? client,
    this.enablePresenceWs = true,
  }) : _client = client ?? OfflineFirstClient();

  static const String baseUrl = 'https://bungtemin.net';
  static const String nudbHttpUrl = 'https://nudb.bungtemin.net';
  static const String nudbWsUrl = NudbWsClient.wsUrl;
  static const String nudbApiKey = NudbWsClient.apiKey;
  static const String absensiWsPath =
      'Absensi/BT0zrOCM8y4qgwXlCzQDG0oGb2dMuK0t1774235256';
  static const String defaultFallbackNoreg = '';

  static const _timeout = Duration(seconds: 15);
  static const _kPublicEventsCache = 'bt_myars_public_events';
  static const _kMyAcaraAllCache = 'bt_myars_my_acara_all';
  static const _kMyEventsPrefix = 'bt_myars_my_events_';
  static const _kTiketUserPrefix = 'bt_myars_tiket_user_';
  static const _kTiketIdPrefix = 'bt_myars_tiket_id_';
  static const _kEventDetailPrefix = 'bt_myars_detail_';

  final http.Client _client;
  final bool enablePresenceWs;

  /// Sesuai `localStorage.getItem('user_noreg') || '00415024'`.
  static String resolveActiveNoreg(UserSession? session) {
    final raw = session?.noreg.trim() ?? '';
    if (raw.isEmpty) return defaultFallbackNoreg;
    final formatted = SessionStore.formatNoreg8(raw);
    return formatted.isNotEmpty ? formatted : raw;
  }

  Map<String, String> _authJsonHeaders([String token = '']) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    return headers;
  }

  // ---------------------------------------------------------------------------
  // 1. TIKET SAYA (TiketlistPage)
  // ---------------------------------------------------------------------------

  Future<List<MyArsTicket>> loadLocalTiketByNoreg(String noreg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kTiketUserPrefix$noreg');
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => MyArsTicket.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveLocalTiketList(
    String noreg,
    List<MyArsTicket> tickets,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(tickets.map((e) => e.toJson()).toList());
      await prefs.setString('$_kTiketUserPrefix$noreg', encoded);
    } catch (_) {}
  }

  Future<MyArsPaginatedResult<MyArsTicket>> getTiketByUser(
    String noreg, {
    int page = 1,
  }) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/btapi/MyEvent/tiket/$noreg?page=$page'))
        .timeout(_timeout);
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400 || decoded is! Map) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final success = decoded['success'] == true;
    final rawList = decoded['data'];
    final items = rawList is List
        ? rawList
            .whereType<Map>()
            .map((e) => MyArsTicket.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <MyArsTicket>[];
    final meta = decoded['meta'] is Map
        ? Map<String, dynamic>.from(decoded['meta'] as Map)
        : const <String, dynamic>{};

    return MyArsPaginatedResult<MyArsTicket>(
      success: success,
      items: items,
      page: _parseInt(meta['page'], fallback: page),
      perPage: _parseInt(meta['per_page'], fallback: 10),
      total: _parseInt(meta['total'], fallback: items.length),
      lastPage: _parseInt(meta['last_page'], fallback: 1),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. DETAIL TIKET & E-PASS (TiketdetailPage)
  // ---------------------------------------------------------------------------

  Future<MyArsTicket?> loadLocalTicket({
    required String id,
    String? noreg,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cek cache per ticket id langsung
      final byIdRaw = prefs.getString('$_kTiketIdPrefix$id');
      if (byIdRaw != null && byIdRaw.isNotEmpty) {
        final decoded = jsonDecode(byIdRaw);
        if (decoded is Map) {
          return MyArsTicket.fromJson(Map<String, dynamic>.from(decoded));
        }
      }

      // Cek cache absensi detail (cocokkan slug idnya + noreg ATAU row id)
      final detailRaw = prefs.getString('$_kEventDetailPrefix$id');
      if (detailRaw != null && detailRaw.isNotEmpty) {
        final detail = MyArsEventDetail.fromJson(
          Map<String, dynamic>.from(jsonDecode(detailRaw) as Map),
        );
        for (final t in detail.data) {
          if (noreg == null || noreg.isEmpty || t.noreg == noreg) {
            return t;
          }
        }
      }

      // Cek cache daftar tiket user aktif
      final targetNoreg = (noreg ?? '').trim().isNotEmpty
          ? noreg!.trim()
          : defaultFallbackNoreg;
      final userTickets = await loadLocalTiketByNoreg(targetNoreg);
      for (final t in userTickets) {
        if (t.id.toString() == id || t.idnya == id) {
          return t;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<MyArsTicket?> getTiketById(
    String id, {
    String? noreg,
  }) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/btapi/MyEvent/tiketbyid/$id'))
        .timeout(_timeout);
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400 || decoded is! Map) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final rawData = decoded['data'];
    MyArsTicket? ticket;
    if (rawData is List) {
      final list = rawData
          .whereType<Map>()
          .map((e) => MyArsTicket.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (list.isNotEmpty) {
        if (noreg != null && noreg.isNotEmpty) {
          ticket = list.firstWhere(
            (x) => x.noreg == noreg,
            orElse: () => list.first,
          );
        } else {
          ticket = list.first;
        }
      }
    } else if (rawData is Map) {
      ticket = MyArsTicket.fromJson(Map<String, dynamic>.from(rawData));
    }

    if (ticket != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '$_kTiketIdPrefix$id',
          jsonEncode(ticket.toJson()),
        );
      } catch (_) {}
    }
    return ticket;
  }

  // ---------------------------------------------------------------------------
  // 3. ACARA SAYA & ACARA PUBLIK (AbsensiPage & AbsensilistPage)
  // ---------------------------------------------------------------------------

  Future<List<MyArsEvent>> loadLocalMyEvents(String noreg) async {
    return _loadCachedEventList('$_kMyEventsPrefix$noreg');
  }

  Future<void> saveLocalMyEvents(String noreg, List<MyArsEvent> events) async {
    await _saveCachedEventList('$_kMyEventsPrefix$noreg', events);
    await _saveCachedEventList(_kMyAcaraAllCache, events);
  }

  Future<List<MyArsEvent>> loadLocalPublicEvents() async {
    return _loadCachedEventList(_kPublicEventsCache);
  }

  Future<void> saveLocalPublicEvents(List<MyArsEvent> events) async {
    await _saveCachedEventList(_kPublicEventsCache, events);
    await _mergeCachedEventsToMyAcara(events);
  }

  Future<MyArsEvent?> findCachedEventBySlug(String slug) async {
    final list = await _loadCachedEventList(_kMyAcaraAllCache);
    for (final e in list) {
      if (e.eventSlug == slug) return e;
    }
    final pub = await loadLocalPublicEvents();
    for (final e in pub) {
      if (e.eventSlug == slug) return e;
    }
    return null;
  }

  Future<MyArsPaginatedResult<MyArsEvent>> getMyEventNoreg(
    String noreg, {
    int page = 1,
  }) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/btapi/MyEvent/absensi/$noreg?page=$page'))
        .timeout(_timeout);
    return _parseEventsPageResponse(res, fallbackPage: page);
  }

  Future<MyArsPaginatedResult<MyArsEvent>> getMyEventAll({int page = 1}) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/btapi/absensiincome/all?page=$page'))
        .timeout(_timeout);
    return _parseEventsPageResponse(res, fallbackPage: page);
  }

  MyArsPaginatedResult<MyArsEvent> _parseEventsPageResponse(
    http.Response res, {
    required int fallbackPage,
  }) {
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400 || decoded is! Map) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final rawList = decoded['data'];
    final items = rawList is List
        ? rawList
            .whereType<Map>()
            .map((e) => MyArsEvent.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <MyArsEvent>[];
    final meta = decoded['meta'] is Map
        ? Map<String, dynamic>.from(decoded['meta'] as Map)
        : const <String, dynamic>{};

    return MyArsPaginatedResult<MyArsEvent>(
      success: decoded['success'] == true,
      items: items,
      page: _parseInt(meta['page'], fallback: fallbackPage),
      perPage: _parseInt(meta['per_page'], fallback: 10),
      total: _parseInt(meta['total'], fallback: items.length),
      lastPage: _parseInt(meta['last_page'], fallback: 1),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. DETAIL ABSENSI EVENT (AbsensidetailPage)
  // ---------------------------------------------------------------------------

  Future<MyArsEventDetail?> loadLocalEventDetail(String slug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kEventDetailPrefix$slug');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return MyArsEventDetail.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<MyArsEventDetail> getAbsensiById(String slug) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/absensi/rakernit2025/api/$slug'))
        .timeout(_timeout);
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400 || decoded is! Map) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final detail = MyArsEventDetail.fromJson(Map<String, dynamic>.from(decoded));
    if (detail.status == 'success') {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '$_kEventDetailPrefix$slug',
          jsonEncode(detail.toJson()),
        );
        if (detail.event != null) {
          await _mergeCachedEventsToMyAcara([detail.event!]);
        }
      } catch (_) {}
    }
    return detail;
  }

  // ---------------------------------------------------------------------------
  // 5. BUAT ACARA BARU (AbsensinewPage)
  // ---------------------------------------------------------------------------

  Future<MyArsCreateEventResult> makeEvent({
    required String acara,
    required int jumlah,
    UserSession? session,
  }) async {
    final payload = <String, dynamic>{
      'noreg': session?.noreg ?? '',
      'nama': session?.nama ?? '',
      'acara': acara.trim(),
      'jumlah': jumlah,
    };

    final res = await _client
        .post(
          Uri.parse('$baseUrl/btapi/MyEvent/create'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    final decoded = jsonDecode(res.body);
    if (decoded is Map) {
      final ok =
          decoded['success'] == true || decoded['status'] == 'success';
      final msg = (decoded['message'] ??
              (ok ? 'Acara berhasil dibuat' : 'Gagal membuat acara'))
          .toString();
      final event = decoded['data'] is Map
          ? MyArsEvent.fromJson(
              Map<String, dynamic>.from(decoded['data'] as Map),
            )
          : null;
      return MyArsCreateEventResult(
        success: ok && res.statusCode < 400,
        message: msg,
        event: event,
      );
    }
    return const MyArsCreateEventResult(
      success: false,
      message: 'Gagal membuat acara',
    );
  }

  // ---------------------------------------------------------------------------
  // 6. MYSCANNER PANITIA (MyscannerPage + AbsensifireService + PresenceService)
  // ---------------------------------------------------------------------------

  /// Routing scan identik dengan `MyscannerPage.prosesHasilScan` + JSON E-Pass.
  Future<MyArsScanActionResult> processEventScannerQr({
    required String rawQr,
    required String eventSlug,
    UserSession? session,
  }) async {
    final raw = rawQr.trim();
    if (raw.isEmpty) {
      return const MyArsScanActionResult(
        success: false,
        header: 'Gagal',
        message: 'Kode QR kosong.',
      );
    }

    // Dukung QR E-Pass Tiket JSON `{"n":...,"r":"00415024","c":"..."}`
    if (raw.startsWith('{')) {
      var epassNoreg = '';
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['r'] != null) {
          epassNoreg = decoded['r'].toString().trim();
        }
      } catch (_) {}
      if (epassNoreg.isNotEmpty) {
        return addFromUserid(
          epassNoreg,
          eventSlug: eventSlug,
          session: session,
          rawBarcode: epassNoreg,
        );
      }
    }

    final delimIdx = raw.indexOf(':');
    final prefix =
        delimIdx != -1 ? raw.substring(0, delimIdx).toLowerCase() : '';
    final datas = delimIdx != -1 ? raw.substring(delimIdx + 1).trim() : raw;

    switch (prefix) {
      case 'untukabsen':
        return addFromTiket(datas, session: session);
      case 'profil':
      case 'userid':
        return addFromUserid(
          datas,
          eventSlug: eventSlug,
          session: session,
          rawBarcode: raw,
        );
      case 'dt':
        return addFromTiketDt(datas, session: session);
      default:
        return addFromUserid(
          raw,
          eventSlug: eventSlug,
          session: session,
          rawBarcode: raw,
        );
    }
  }

  Future<MyArsScanActionResult> addFromUserid(
    String data, {
    required String eventSlug,
    UserSession? session,
    String? rawBarcode,
  }) async {
    final decrypted = BungteminCrypto.decrypt(data);
    final userid = decrypted.isNotEmpty ? decrypted : data.trim();
    final payload = <String, dynamic>{
      'date': DateTime.now().millisecondsSinceEpoch,
      'noreg': session?.noreg.isNotEmpty == true ? session!.noreg : 'admin',
      'id': userid,
      'event': eventSlug,
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('scnerEvetlast', jsonEncode(payload));
    } catch (_) {}

    final res = await _client
        .post(
          Uri.parse('$nudbHttpUrl/api/absensiuser'),
          headers: _authJsonHeaders(session?.token ?? ''),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    final primary = await _handleScannerResponse(
      res,
      session: session,
      nestedDataKode: false,
    );
    if (primary.success) {
      return primary;
    }

    // Fallback ke endpoint gate Bungtemin web jika peserta bukan pemandatan
    // atau QR Base64 berasal dari kartu KTA lama.
    final shouldFallback = res.statusCode == 404 ||
        primary.message.toLowerCase().contains('tidak terdaftar') ||
        decrypted.isEmpty;
    if (!shouldFallback) {
      return primary;
    }

    try {
      final gateRes = await _client
          .post(
            Uri.parse('$baseUrl/camera/absensi/kirimAbsen'),
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
              'X-Requested-With': 'XMLHttpRequest',
            },
            body: <String, String>{
              'barcode': (rawBarcode ?? data).trim(),
              'event_slug': eventSlug,
              'string': 'Absensi${DateTime.now().millisecondsSinceEpoch}',
            },
          )
          .timeout(_timeout);
      final gateDecoded = jsonDecode(gateRes.body);
      if (gateDecoded is Map && gateDecoded['status'] == 'success') {
        final kode = (gateDecoded['tiket'] ??
                (gateDecoded['data'] is Map ? gateDecoded['data']['Kode'] : '') ??
                '')
            .toString();
        final info = (gateDecoded['message'] ?? 'Presensi berhasil').toString();
        if (enablePresenceWs) {
          unawaited(setAbsensiPresence(session: session));
        }
        return MyArsScanActionResult(
          success: true,
          header: gateDecoded['already'] == true ? 'Sudah Check-In' : 'Berhasil',
          message: kode.isNotEmpty ? '$info\nKode: $kode' : info,
          kode: kode,
        );
      }
    } catch (_) {}

    return primary;
  }

  Future<MyArsScanActionResult> addFromTiket(
    String data, {
    UserSession? session,
  }) async {
    final payload = <String, dynamic>{
      'date': DateTime.now().millisecondsSinceEpoch,
      'noreg': session?.noreg.isNotEmpty == true ? session!.noreg : 'admin',
      'id': data,
    };

    final res = await _client
        .post(
          Uri.parse('$nudbHttpUrl/api/absensitiket'),
          headers: _authJsonHeaders(session?.token ?? ''),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    return _handleScannerResponse(res, session: session, nestedDataKode: false);
  }

  Future<MyArsScanActionResult> addFromTiketDt(
    String data, {
    UserSession? session,
  }) async {
    final payload = <String, dynamic>{
      'date': DateTime.now().millisecondsSinceEpoch,
      'noreg': session?.noreg.isNotEmpty == true ? session!.noreg : 'admin',
      'barcode': data,
    };

    final res = await _client
        .post(
          Uri.parse('$nudbHttpUrl/absensi/kirimAbsen'),
          headers: _authJsonHeaders(session?.token ?? ''),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    return _handleScannerResponse(res, session: session, nestedDataKode: true);
  }

  Future<MyArsScanActionResult> _handleScannerResponse(
    http.Response res, {
    UserSession? session,
    required bool nestedDataKode,
  }) async {
    final decoded = jsonDecode(res.body);
    if (decoded is Map) {
      final ok = decoded['status'] == true;
      final kode = nestedDataKode
          ? (decoded['data'] is Map ? (decoded['data']['kode'] ?? '') : '')
              .toString()
          : (decoded['kode'] ?? '').toString();
      final msg = ok
          ? 'Kode: $kode'
          : (decoded['message'] ?? 'Gagal mencatat absensi').toString();

      if (enablePresenceWs) {
        unawaited(setAbsensiPresence(session: session));
      }
      return MyArsScanActionResult(
        success: ok && res.statusCode < 400,
        header: ok ? 'Berhasil' : 'Gagal',
        message: msg,
        kode: kode,
      );
    }
    return const MyArsScanActionResult(
      success: false,
      header: 'Error',
      message: 'Tidak bisa koneksi ke server',
    );
  }

  /// Sesuai `PresenceService.setAbsensi()` via NuDB WebSocket.
  Future<void> setAbsensiPresence({UserSession? session}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uidFire = prefs.getString('bt_uid_fire') ?? '';
      final noreg = session?.noreg ?? '';
      await NudbWsClient.sendCommand(
        type: 'set',
        path: absensiWsPath,
        data: <String, dynamic>{
          'online': true,
          'lastActive': DateTime.now().millisecondsSinceEpoch,
          'id': uidFire,
          'nama': session?.nama ?? '',
          'noreg': noreg,
          'avatar': 'https://bungtemin.net/btapi/Calendar/hravatar/$noreg',
        },
        settleDelay: const Duration(milliseconds: 250),
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // CACHE HELPERS
  // ---------------------------------------------------------------------------

  Future<List<MyArsEvent>> _loadCachedEventList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => MyArsEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveCachedEventList(String key, List<MyArsEvent> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode(list.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _mergeCachedEventsToMyAcara(List<MyArsEvent> incoming) async {
    if (incoming.isEmpty) return;
    final existing = await _loadCachedEventList(_kMyAcaraAllCache);
    final bySlug = <String, MyArsEvent>{
      for (final e in existing) e.eventSlug: e,
    };
    for (final e in incoming) {
      if (e.eventSlug.isNotEmpty) {
        bySlug[e.eventSlug] = e;
      }
    }
    await _saveCachedEventList(_kMyAcaraAllCache, bySlug.values.toList());
  }

  static int _parseInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? fallback;
  }
}
