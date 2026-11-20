import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import '../core/net/cached_http.dart' as http;

import '../core/session_store.dart';
import '../models/bungtemin_menu.dart';
import '../models/kta_member.dart';
import '../models/meeting_item.dart';
import '../models/meeting_meta.dart';
import '../models/meeting_room.dart';
import '../models/news_item.dart';
import '../models/struktur_item.dart';
import '../models/tonton_video.dart';
import '../models/training_item.dart';

class BungteminApiException implements Exception {
  BungteminApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class BungteminApi {
  static const String _baseUrl = 'https://bungtemin.net';
  static const String _nudbUrl = 'https://nudb.bungtemin.net';
  // Seluruh API eksternal (Blogger, Noembed, MyTMMIN) diproxy lewat BTAPI dengan cache 1 bulan.
  static const Duration _timeout = Duration(seconds: 15);

  Future<UserSession> login({
    required String noreg,
    required String secret,
  }) async {
    final cleanNoreg = SessionStore.formatNoreg8(noreg);
    final uid = await SessionStore().getOrCreateUidFallback();
    final res = await http
        .post(
          Uri.parse('$_baseUrl/btapi/User/login/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': cleanNoreg,
            'noreg': cleanNoreg,
            'password': secret,
            'pin': secret,
            'uid': uid,
          }),
        )
        .timeout(_timeout);

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw BungteminApiException('Respons server tidak valid.');
    }

    final nested = decoded['data'];
    final payload = nested is Map<String, dynamic> ? nested : decoded;
    final statusStr =
        (decoded['status'] ?? payload['status'] ?? '').toString().toLowerCase();
    final hasError = statusStr == 'error' ||
        statusStr == 'fail' ||
        decoded['success'] == false;
    final hasValidToken = (payload['token_login'] ??
            payload['token'] ??
            decoded['token_login'] ??
            decoded['token'] ??
            '')
        .toString()
        .trim()
        .isNotEmpty;
    final ok = !hasError &&
        (statusStr == 'success' ||
            decoded['success'] == true ||
            (nested is Map<String, dynamic> && hasValidToken));
    if (!ok) {
      final msg = payload['pesan'] ??
          decoded['message'] ??
          decoded['pesan'] ??
          'Login gagal.';
      throw BungteminApiException(msg.toString());
    }

    final resolvedNoreg = SessionStore.formatNoreg8(
      (payload['noreg'] ?? cleanNoreg).toString(),
    );

    final session = UserSession(
      noreg: resolvedNoreg,
      nama: (payload['nama'] ?? payload['name'] ?? 'Anggota').toString(),
      job: KtaMember.normalizeJob(payload['job']?.toString()),
      token: (payload['token_login'] ??
              payload['token'] ??
              decoded['token_login'] ??
              decoded['token'] ??
              '')
          .toString(),
      userId: int.tryParse(
            (payload['login'] ?? payload['id'] ?? '1').toString(),
          ) ??
          1,
      komisi: (payload['Komisi'] ?? payload['komisi'] ?? '').toString(),
      divisi: (payload['divisi'] ?? '').toString(),
    );

    // Sinkronisasi UID ke /btapi/uid (sama seperti DatauserloginService.syncUid di bungteminAPP)
    await syncUid(userId: session.noreg, uid: uid);

    return session;
  }


  Future<bool> fetchSsoEnabled() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/auth/sso_config'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          return decoded['sso_enabled'] == true;
        }
      }
    } catch (_) {}
    return false;
  }

  String generateMsAppSession() {
    final rnd = Random.secure();
    return List.generate(
      32,
      (_) => rnd.nextInt(16).toRadixString(16),
    ).join();
  }

  Uri buildMsLoginUri({
    required String appSession,
    required String uid,
  }) {
    return Uri.parse('$_baseUrl/auth/mslogin').replace(
      queryParameters: {
        'app_session': appSession,
        'uid': uid,
      },
    );
  }

  Future<UserSession?> checkMsAppLoginStatus({
    required String appSession,
    required String uid,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/msapp_status').replace(
      queryParameters: {
        'app_session': appSession,
        'uid': uid,
      },
    );
    final res = await http.get(uri).timeout(_timeout);
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw BungteminApiException('Respons server tidak valid.');
    }

    final status = (decoded['status'] ?? '').toString();
    if (status == 'pending') {
      return null;
    }
    if (status == 'expired') {
      throw BungteminApiException(
        (decoded['message'] ?? 'Sesi login Microsoft kedaluwarsa.').toString(),
      );
    }
    if (status != 'success') {
      throw BungteminApiException(
        (decoded['message'] ?? 'Login Microsoft gagal.').toString(),
      );
    }

    final payload = decoded['data'];
    if (payload is! Map<String, dynamic>) {
      throw BungteminApiException('Data sesi Microsoft tidak lengkap.');
    }

    final resolvedNoreg = SessionStore.formatNoreg8(
      (payload['noreg'] ?? '').toString(),
    );
    final session = UserSession(
      noreg: resolvedNoreg,
      nama: (payload['nama'] ?? 'Anggota').toString(),
      job: KtaMember.normalizeJob(payload['job']?.toString()),
      token: (payload['token_login'] ?? payload['token'] ?? '').toString(),
      userId: int.tryParse((payload['login'] ?? payload['id'] ?? '1').toString()) ?? 1,
      komisi: (payload['komisi'] ?? payload['Komisi'] ?? '').toString(),
      divisi: (payload['divisi'] ?? '').toString(),
    );

    await syncUid(userId: session.noreg, uid: uid);
    return session;
  }

  Future<void> syncUid({
    required String userId,
    String? uid,
  }) async {
    try {
      final tokenUid = uid ?? await SessionStore().getOrCreateUidFallback();
      await http
          .post(
            Uri.parse('$_baseUrl/btapi/uid'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': tokenUid,
              'user_id': userId,
            }),
          )
          .timeout(_timeout);
    } catch (_) {
      // Abaikan jika offline; akan dicoba ulang saat registrasi training.
    }
  }

  Future<String> requestOtpWa({required String noreg}) async {
    final cleanNoreg = SessionStore.formatNoreg8(noreg);
    final uid = await SessionStore().getOrCreateUidFallback();
    final res = await http
        .post(
          Uri.parse('$_baseUrl/btapi/User/request_otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': cleanNoreg,
            'uid': uid,
          }),
        )
        .timeout(const Duration(seconds: 25));

    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final msg = (decoded is Map ? (decoded['pesan'] ?? decoded['message']) : null) ??
          'Gagal mengirim OTP WhatsApp.';
      throw BungteminApiException(msg.toString());
    }

    if (decoded is Map && decoded['message'] != null) {
      return decoded['message'].toString();
    }
    return 'Kode OTP 6 digit telah dikirim ke WhatsApp Anda.';
  }

  Future<({bool? hasPin, String waNumber})> fetchSecurityProfile({
    required String token,
  }) async {
    if (token.trim().isEmpty) return (hasPin: null, waNumber: '');
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/btapi/User/pin_status'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return (hasPin: null, waNumber: '');
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        final hp = decoded['has_pin'] is bool ? decoded['has_pin'] as bool : null;
        final wa = (decoded['wa_number'] ?? '').toString();
        return (hasPin: hp, waNumber: wa);
      }
    } catch (_) {}
    return (hasPin: null, waNumber: '');
  }

  Future<String> updatePhoneNumber({
    required String phone,
    required String token,
  }) async {
    if (token.trim().isEmpty) {
      throw BungteminApiException('Sesi login tidak valid. Silakan login ulang.');
    }
    final res = await http
        .post(
          Uri.parse('$_baseUrl/btapi/User/update_phone'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'phone': phone.trim()}),
        )
        .timeout(_timeout);

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw BungteminApiException('Respons server tidak valid.');
    }
    if (res.statusCode >= 400 || decoded['status'] == 'error') {
      throw BungteminApiException(
        (decoded['pesan'] ?? decoded['message'] ?? 'Gagal menyimpan nomor telepon.').toString(),
      );
    }
    return (decoded['message'] ?? 'Nomor WhatsApp / telepon berhasil diperbarui.').toString();
  }

  Future<bool?> fetchPinStatus({required String token}) async {
    if (token.trim().isEmpty) return null;
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/btapi/User/pin_status'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic> && decoded['has_pin'] is bool) {
        return decoded['has_pin'] as bool;
      }
    } catch (_) {}
    return null;
  }

  Future<String> setMemberPin({
    required String newPin,
    required String token,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token.trim().isNotEmpty) 'Authorization': 'Bearer ${token.trim()}',
    };
    final res = await http
        .post(
          Uri.parse('$_baseUrl/btapi/User/set_pin'),
          headers: headers,
          body: jsonEncode({'new_pin': newPin.trim()}),
        )
        .timeout(_timeout);

    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400 ||
        (decoded is Map && decoded['status'] == 'error')) {
      final msg = (decoded is Map
              ? (decoded['pesan'] ?? decoded['message'])
              : null) ??
          'Gagal menyimpan PIN.';
      throw BungteminApiException(msg.toString());
    }

    if (decoded is Map && decoded['message'] != null) {
      return decoded['message'].toString();
    }
    return 'PIN pribadi berhasil disimpan!';
  }

  Future<KtaMember> fetchKta({
    required String noreg,
    String token = '',
  }) async {
    final cleanNoreg = SessionStore.formatNoreg8(noreg);
    if (token.split('.').length == 3) {
      try {
        final meRes = await http
            .get(
              Uri.parse('$_baseUrl/Idcard/api/me'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(_timeout);
        if (meRes.statusCode == 200) {
          final data = jsonDecode(meRes.body);
          if (data is Map<String, dynamic> && data['pesan'] == null) {
            await SessionStore().saveKtaCache(meRes.body);
            return KtaMember.fromJson(data);
          }
        }
      } catch (_) {
        // Lanjut ke endpoint fallback bila token kedaluwarsa/preview mode.
      }
    }

    try {
      final res = await http
          .get(
            Uri.parse(
              '$_baseUrl/Idcard/api/member/${Uri.encodeComponent(cleanNoreg)}/flutter-app',
            ),
          )
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['status'] != 'error') {
          await SessionStore().saveKtaCache(res.body);
          return KtaMember.fromJson(data);
        }
      }
    } catch (_) {
      // Coba gunakan cache lokal jika jaringan gagal.
    }

    final cachedRaw = await SessionStore().loadKtaCache();
    if (cachedRaw != null) {
      try {
        final cachedMap = jsonDecode(cachedRaw);
        if (cachedMap is Map<String, dynamic>) {
          return KtaMember.fromJson(cachedMap);
        }
      } catch (_) {}
    }

    throw BungteminApiException('Gagal memuat data KTA & profil anggota.');
  }

  Future<MeetingDashboardData> fetchMeetings({
    required String noreg,
    String token = '',
  }) async {
    final cleanNoreg = SessionStore.formatNoreg8(noreg);
    final headers = <String, String>{
      if (token.trim().isNotEmpty) 'Authorization': 'Bearer ${token.trim()}',
    };
    final res = await http
        .get(
          Uri.parse(
            '$_baseUrl/btapi/Meeting/index?noreg=${Uri.encodeComponent(cleanNoreg)}',
          ),
          headers: headers,
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw BungteminApiException('Gagal memuat daftar meeting (HTTP ${res.statusCode}).');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
      throw BungteminApiException('Data meeting belum tersedia.');
    }

    final stats = (decoded['stats'] as Map<String, dynamic>?) ?? const {};
    final auth = (decoded['auth'] as Map<String, dynamic>?) ?? const {};
    final rawList = (decoded['meetings'] as List<dynamic>?) ?? const [];
    final items = rawList
        .whereType<Map<String, dynamic>>()
        .map(MeetingItem.fromJson)
        .toList();

    return MeetingDashboardData(
      total: int.tryParse((stats['total'] ?? items.length).toString()) ?? 0,
      scheduled: int.tryParse((stats['scheduled'] ?? 0).toString()) ?? 0,
      ongoing: int.tryParse((stats['ongoing'] ?? 0).toString()) ?? 0,
      completed: int.tryParse((stats['completed'] ?? 0).toString()) ?? 0,
      meetings: items,
      roleLabel: (auth['role_label'] ?? '').toString(),
      pctHadir: int.tryParse((stats['pct_hadir'] ?? 0).toString()) ?? 0,
    );
  }

  /// Role pengguna + daftar KP/Pleno untuk membuat meeting (`/btapi/Meeting/meta`).
  Future<MeetingMeta> fetchMeetingMeta({
    required String noreg,
    String token = '',
  }) async {
    final cleanNoreg = SessionStore.formatNoreg8(noreg);
    final res = await http
        .get(
          Uri.parse(
            '$_baseUrl/btapi/Meeting/meta?noreg=${Uri.encodeComponent(cleanNoreg)}',
          ),
          headers: _authJsonHeaders(token),
        )
        .timeout(_timeout);

    final decoded = jsonDecode(res.body);
    if (res.statusCode != 200 ||
        decoded is! Map<String, dynamic> ||
        decoded['success'] != true) {
      final msg = decoded is Map ? decoded['message'] : null;
      throw BungteminApiException(
        (msg ?? 'Gagal memuat data pembuatan meeting (HTTP ${res.statusCode}).')
            .toString(),
      );
    }
    return MeetingMeta.fromJson(decoded);
  }

  /// Membuat meeting baru (`/btapi/Meeting/store`). Mengembalikan pesan sukses server.
  Future<String> createMeeting({
    required String noreg,
    String token = '',
    required Map<String, dynamic> payload,
  }) async {
    final cleanNoreg = SessionStore.formatNoreg8(noreg);
    final res = await http
        .post(
          Uri.parse('$_baseUrl/btapi/Meeting/store'),
          headers: _authJsonHeaders(token),
          body: jsonEncode({...payload, 'noreg': cleanNoreg}),
        )
        .timeout(const Duration(seconds: 40));

    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400 ||
        decoded is! Map ||
        decoded['success'] != true) {
      final msg = decoded is Map ? decoded['message'] : null;
      throw BungteminApiException(
        (msg ?? 'Gagal membuat meeting (HTTP ${res.statusCode}).').toString(),
      );
    }
    return (decoded['message'] ?? 'Meeting berhasil dibuat').toString();
  }

  Future<List<String>?> toggleReelLike({
    required String id,
    required String noreg,
    String nama = '',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/btapi/Media/toggle_like'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': id,
              'noreg': SessionStore.formatNoreg8(noreg),
              if (nama.trim().isNotEmpty) 'nama': nama.trim(),
            }),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['likes'] is List) {
        return (decoded['likes'] as List).map((e) => e.toString()).toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<int?> incrementReelView(String id) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/btapi/Media/increment_view'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'id': id}),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['views'] != null) {
        return int.tryParse(decoded['views'].toString());
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteReel(String id) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/btapi/Media/delete_reel'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'id': id}),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchReels() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/btapi/Media/reels'))
          .timeout(_timeout);
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final raw = decoded['data'] ?? decoded['reels'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> uploadStory({
    required Uint8List bytes,
    required String filename,
    required String noreg,
    required String nama,
    String pesan = '',
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/btapi/Media/upload_story'),
    );
    req.fields['noreg'] = SessionStore.formatNoreg8(noreg);
    req.fields['nama'] = nama.trim().isEmpty ? 'Anggota' : nama.trim();
    req.fields['pesan'] = pesan.trim();
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final streamed = await http.apiClient.send(req).timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    final decoded = jsonDecode(body);
    if (streamed.statusCode >= 400 ||
        (decoded is Map && decoded['success'] != true)) {
      final msg = (decoded is Map ? decoded['message'] : null) ??
          'Gagal mengunggah foto cerita.';
      throw BungteminApiException(msg.toString());
    }
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadReel({
    required Uint8List bytes,
    required String filename,
    required String noreg,
    required String nama,
    String text = '',
    String avatar = '',
  }) async {
    const chunkThreshold = 5 * 1024 * 1024; // > 5 MB gunakan chunked upload
    const chunkSize = 4 * 1024 * 1024; // 4 MB per potong agar aman dari batas post_max_size

    final cleanNoreg = SessionStore.formatNoreg8(noreg);
    final cleanNama = nama.trim().isEmpty ? 'Anggota' : nama.trim();

    if (bytes.length <= chunkThreshold) {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/btapi/Media/upload_reel'),
      );
      req.fields['noreg'] = cleanNoreg;
      req.fields['nama'] = cleanNama;
      req.fields['text'] = text.trim();
      req.fields['avatar'] = avatar;
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

      final streamed = await http.apiClient.send(req).timeout(const Duration(seconds: 90));
      final body = await streamed.stream.bytesToString();
      final decoded = jsonDecode(body);
      if (streamed.statusCode >= 400 ||
          (decoded is Map && decoded['success'] != true)) {
        final msg = (decoded is Map ? decoded['message'] : null) ??
            'Gagal mengunggah video Reels.';
        throw BungteminApiException(msg.toString());
      }
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    }

    final totalChunks = (bytes.length / chunkSize).ceil();
    final uploadId = 'r_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    Map<String, dynamic> lastDecoded = <String, dynamic>{};

    for (var i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = min(start + chunkSize, bytes.length);
      final part = bytes.sublist(start, end);

      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/btapi/Media/upload_reel_chunk'),
      );
      req.fields['upload_id'] = uploadId;
      req.fields['chunk_index'] = '$i';
      req.fields['total_chunks'] = '$totalChunks';
      req.fields['filename'] = filename;
      req.fields['noreg'] = cleanNoreg;
      req.fields['nama'] = cleanNama;
      req.fields['text'] = text.trim();
      req.fields['avatar'] = avatar;
      req.files.add(http.MultipartFile.fromBytes('chunk', part, filename: filename));

      final streamed = await http.apiClient.send(req).timeout(const Duration(seconds: 90));
      final body = await streamed.stream.bytesToString();
      final decoded = jsonDecode(body);
      if (streamed.statusCode >= 400 ||
          (decoded is Map && decoded['success'] != true)) {
        final msg = (decoded is Map ? decoded['message'] : null) ??
            'Gagal mengunggah potongan video Reels.';
        throw BungteminApiException(msg.toString());
      }
      if (decoded is Map<String, dynamic>) {
        lastDecoded = decoded;
      }
    }
    return lastDecoded;
  }

  Future<List<String>?> toggleStoryLike({
    required String id,
    required String noreg,
    String nama = '',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/btapi/Media/toggle_story_like'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': id,
              'noreg': SessionStore.formatNoreg8(noreg),
              if (nama.trim().isNotEmpty) 'nama': nama.trim(),
            }),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['likes'] is List) {
        return (decoded['likes'] as List).map((e) => e.toString()).toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchStoryComments(String storyId) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/btapi/Media/story_comments?id=${Uri.encodeComponent(storyId)}'))
          .timeout(_timeout);
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>?> addStoryComment({
    required String id,
    required String noreg,
    required String nama,
    required String comment,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/btapi/Media/add_story_comment'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': id,
              'noreg': SessionStore.formatNoreg8(noreg),
              'nama': nama,
              'comment': comment.trim(),
            }),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['data'] is Map) {
        return Map<String, dynamic>.from(decoded['data'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }


  Future<bool?> toggleMediaSubscribe({
    required String mediaKind,
    required String id,
    required String noreg,
    String nama = '',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/btapi/Media/toggle_subscribe'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'media_kind': mediaKind,
              'id': id,
              'noreg': SessionStore.formatNoreg8(noreg),
              if (nama.trim().isNotEmpty) 'nama': nama.trim(),
            }),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['subscribed'] is bool) {
        return decoded['subscribed'] as bool;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> fetchMediaSubscribeStatus({
    required String mediaKind,
    required String id,
    required String noreg,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/btapi/Media/subscribe_status').replace(
        queryParameters: {
          'media_kind': mediaKind,
          'id': id,
          'noreg': SessionStore.formatNoreg8(noreg),
        },
      );
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return false;
      final decoded = jsonDecode(res.body);
      return decoded is Map && decoded['subscribed'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchReelComments(String reelId) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/btapi/Media/reel_comments?id=${Uri.encodeComponent(reelId)}'))
          .timeout(_timeout);
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>?> addReelComment({
    required String id,
    required String noreg,
    required String nama,
    required String comment,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/btapi/Media/add_reel_comment'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': id,
              'noreg': SessionStore.formatNoreg8(noreg),
              'nama': nama,
              'comment': comment.trim(),
            }),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['data'] is Map) {
        return Map<String, dynamic>.from(decoded['data'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteStory(String id) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/btapi/Media/delete_story'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'id': id}),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<StoryItem>> fetchStories() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/btapi/Media/stories'))
          .timeout(_timeout);
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final raw = decoded['data'] ?? decoded['stories'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(StoryItem.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<BungteminMenuItem>> fetchMenus() async {
    try {
      final ctrlRes = await http
          .get(Uri.parse('$_baseUrl/btapi/Menu/list'))
          .timeout(const Duration(seconds: 8));
      if (ctrlRes.statusCode == 200) {
        final parsed = parseMenuJson(ctrlRes.body);
        if (parsed.isNotEmpty) {
          await SessionStore().saveMenuCache(ctrlRes.body);
          return parsed;
        }
      }
    } catch (_) {}

    try {
      final res = await http
          .get(Uri.parse('$_nudbUrl/data/NewMenu'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final parsed = parseMenuJson(res.body);
        if (parsed.isNotEmpty) {
          await SessionStore().saveMenuCache(res.body);
          return parsed;
        }
      }
    } catch (_) {}

    final cached = await SessionStore().loadMenuCache();
    if (cached != null) {
      final parsed = parseMenuJson(cached);
      if (parsed.isNotEmpty) return parsed;
    }
    return BungteminMenuItem.defaults;
  }

  static List<BungteminMenuItem> parseMenuJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map && decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map>()
            .map((e) => BungteminMenuItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      final sections = decoded is Map ? decoded['value'] : null;
      if (sections is! List) return const [];
      final flat = <BungteminMenuItem>[];
      for (final section in sections) {
        if (section is Map && section['items'] is List) {
          for (final item in section['items'] as List) {
            if (item is Map<String, dynamic>) {
              flat.add(BungteminMenuItem.fromJson(item));
            } else if (item is Map) {
              flat.add(
                BungteminMenuItem.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
        }
      }
      return flat;
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> loadCachedHeroBanners() async {
    final raw = await SessionStore().loadBannersCache();
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {}
    return const [];
  }


  Future<Map<String, dynamic>?> fetchPromoAndUpdateConfig() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/btapi/Promo?_t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['success'] == true) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchPromoModal() async {
    try {
      final res = await http
          .get(Uri.parse('$_nudbUrl/api/v1/PromoModal'))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final payload = decoded['value'] is Map
          ? Map<String, dynamic>.from(decoded['value'] as Map)
          : Map<String, dynamic>.from(decoded);
      if (payload['showAds'] != true) return null;
      if (payload['adsData'] is Map) {
        return Map<String, dynamic>.from(payload['adsData'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> fetchHeroBanners() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/news/wp-json/bungtemin/v1/ads-version'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['images'] is List) {
          final imgs = (decoded['images'] as List)
              .map((e) => e.toString())
              .where((e) => e.startsWith('http'))
              .toList();
          if (imgs.isNotEmpty) {
            await SessionStore().saveBannersCache(jsonEncode(imgs));
            return imgs;
          }
        }
        final ver = decoded is Map ? (decoded['version'] ?? 'new') : 'new';
        final list = [
          for (var i = 1; i <= 6; i++)
            '$_baseUrl/assets/img/ads/$i.jpg?v=$ver',
        ];
        await SessionStore().saveBannersCache(jsonEncode(list));
        return list;
      }
    } catch (_) {
      final cached = await loadCachedHeroBanners();
      if (cached.isNotEmpty) return cached;
    }
    return [
      for (var i = 1; i <= 6; i++) '$_baseUrl/assets/img/ads/$i.jpg?v=new',
    ];
  }

  Future<List<NewsItem>> loadCachedInternalNews() async {
    final raw = await SessionStore().loadInternalNewsCache();
    return NewsItem.decodeList(raw);
  }

  Future<List<NewsItem>> loadCachedExternalNews() async {
    final raw = await SessionStore().loadExternalNewsCache();
    return NewsItem.decodeList(raw);
  }

  Future<List<NewsItem>> fetchInternalNews({int limit = 10}) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/news/wp-json/wp/v2/posts?per_page=$limit'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          final list = decoded
              .whereType<Map<String, dynamic>>()
              .map(NewsItem.fromWordPress)
              .toList();
          if (list.isNotEmpty) {
            await SessionStore().saveInternalNewsCache(NewsItem.encodeList(list));
          }
          return list;
        }
      }
    } catch (_) {}
    return loadCachedInternalNews();
  }

  Future<List<NewsItem>> fetchExternalNews({int limit = 10}) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/btapi/Calendar/blogger?limit=$limit',
      );
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final items = decoded['items'];
          if (items is List) {
            final list = items
                .whereType<Map<String, dynamic>>()
                .map(NewsItem.fromBlogger)
                .toList();
            if (list.isNotEmpty) {
              await SessionStore().saveExternalNewsCache(NewsItem.encodeList(list));
            }
            return list;
          }
        }
      }
    } catch (_) {}
    return loadCachedExternalNews();
  }

  Map<String, String> _authJsonHeaders(String token) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    return headers;
  }

  Future<String> scanMeetingTicket({
    required String meetingId,
    required String code,
    required String noreg,
    String token = '',
  }) async {
    final cleanNoreg = SessionStore.formatNoreg8(noreg);
    final res = await http
        .post(
          Uri.parse(
            '$_baseUrl/btapi/Meeting/scan_absen/${Uri.encodeComponent(meetingId)}',
          ),
          headers: _authJsonHeaders(token),
          body: jsonEncode({'code': code, 'noreg': cleanNoreg}),
        )
        .timeout(_timeout);

    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400 ||
        (decoded is Map && decoded['success'] == false)) {
      final msg = (decoded is Map ? decoded['message'] : null) ??
          'Tiket tidak valid atau Anda bukan pengelola meeting ini.';
      throw BungteminApiException(msg.toString());
    }

    if (decoded is Map && decoded['peserta'] is Map) {
      final p = decoded['peserta'] as Map;
      return '${p['nama'] ?? 'Peserta'} (${p['noreg'] ?? '-'}) berhasil check-in.';
    }
    return (decoded is Map ? decoded['message'] : null)?.toString() ??
        'Kehadiran tiket meeting tercatat.';
  }

  Future<String> selfCheckinMeeting({
    required String meetingRef,
    required String noreg,
    String token = '',
  }) async {
    final cleanNoreg = SessionStore.formatNoreg8(noreg);
    final res = await http
        .post(
          Uri.parse('$_baseUrl/btapi/Meeting/self_checkin'),
          headers: _authJsonHeaders(token),
          body: jsonEncode({'meeting_ref': meetingRef, 'noreg': cleanNoreg}),
        )
        .timeout(_timeout);

    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400 ||
        (decoded is Map && decoded['success'] == false)) {
      final msg = (decoded is Map ? decoded['message'] : null) ??
          'Tidak bisa check-in ke meeting ini.';
      throw BungteminApiException(msg.toString());
    }
    final judul = decoded is Map ? (decoded['meeting_judul'] ?? '') : '';
    final msg = decoded is Map ? (decoded['message'] ?? 'Kehadiran tercatat.') : '';
    return judul.toString().isNotEmpty ? '$judul\n$msg' : msg.toString();
  }

  Future<String> submitNuAbsensi({
    required String eventId,
    required UserSession session,
  }) async {
    var komisi = session.komisi;
    var divisi = session.divisi;
    if (komisi.isEmpty && divisi.isEmpty) {
      final ktaRaw = await SessionStore().loadKtaCache();
      if (ktaRaw != null && ktaRaw.isNotEmpty) {
        try {
          final map = jsonDecode(ktaRaw);
          if (map is Map) {
            komisi = (map['Komisi'] ?? map['komisi'] ?? '').toString();
            divisi = (map['divisi'] ?? map['dept'] ?? '').toString();
          }
        } catch (_) {}
      }
    }

    final res = await http
        .post(
          Uri.parse('$_nudbUrl/api/absensi'),
          headers: _authJsonHeaders(session.token),
          body: jsonEncode({
            'date': DateTime.now().millisecondsSinceEpoch,
            'eventnama': eventId,
            'nama': session.nama,
            'noreg': session.noreg,
            'jabatan': session.job,
            'komisi': komisi,
            'divisi': divisi,
            'id': eventId,
          }),
        )
        .timeout(_timeout);

    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400 || (decoded is Map && decoded['status'] != true)) {
      final msg = (decoded is Map ? decoded['message'] : null) ??
          'Gagal mencatat absensi event.';
      throw BungteminApiException(msg.toString());
    }
    final kode = decoded is Map ? (decoded['kode'] ?? '-') : '-';
    return 'Kode absensi: $kode';
  }

  Future<String> submitNuTicketDt({
    required String barcode,
    required UserSession session,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_nudbUrl/absensi/kirimAbsen'),
          headers: _authJsonHeaders(session.token),
          body: jsonEncode({
            'date': DateTime.now().millisecondsSinceEpoch,
            'noreg': session.noreg,
            'barcode': barcode,
          }),
        )
        .timeout(_timeout);

    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400 || (decoded is Map && decoded['status'] != true)) {
      final msg = (decoded is Map ? decoded['message'] : null) ??
          'Gagal mengirim data tiket absensi.';
      throw BungteminApiException(msg.toString());
    }
    final data = decoded is Map ? decoded['data'] : null;
    final kode = data is Map ? (data['kode'] ?? '-') : '-';
    return 'Kode tiket: $kode';
  }

  Future<List<StrukturPeriodGroup>> fetchStruktur() async {
    try {
      final res = await http
          .get(Uri.parse('$_nudbUrl/data/StrukturAPP'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final parsed = parseStrukturJson(res.body);
        if (parsed.isNotEmpty) {
          await SessionStore().saveStrukturCache(res.body);
          return parsed;
        }
      }
    } catch (_) {
      // Fallback ke cache lokal jika gagal mengambil dari jaringan.
    }

    final cached = await SessionStore().loadStrukturCache();
    if (cached != null) {
      final parsed = parseStrukturJson(cached);
      if (parsed.isNotEmpty) return parsed;
    }
    return const [];
  }

  static List<StrukturPeriodGroup> parseStrukturJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      final valList = decoded is Map ? decoded['value'] : null;
      if (valList is! List || valList.isEmpty) return const [];
      final rawData = valList.first;
      if (rawData is Map) {
        final numericKeys = rawData.keys
            .where((k) => int.tryParse(k.toString()) != null)
            .toList()
          ..sort((a, b) =>
              int.parse(a.toString()).compareTo(int.parse(b.toString())));
        final groups = <StrukturPeriodGroup>[];
        for (final k in numericKeys) {
          final item = rawData[k];
          if (item is Map<String, dynamic>) {
            groups.add(StrukturPeriodGroup.fromJson(item));
          } else if (item is Map) {
            groups.add(
              StrukturPeriodGroup.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
        return groups;
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<List<TontonVideo>> fetchTontonVideos() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/news/wp-json/wp/v2/youtube_playlists'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map(TontonVideo.fromJson)
              .where((v) => v.videoId.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {
      // Fallback kosong bila jaringan offline.
    }
    return const [];
  }

  Future<Map<String, String>> fetchYoutubeNoembed(String videoId) async {
    if (videoId.trim().isEmpty) return const {};
    try {
      final res = await http
          .get(
            Uri.parse(
              '$_baseUrl/btapi/Calendar/ytmeta?v=${Uri.encodeComponent(videoId.trim())}',
            ),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['error'] == null) {
          return {
            'title': (decoded['title'] ?? '').toString(),
            'author': (decoded['author_name'] ?? '').toString(),
          };
        }
      }
    } catch (_) {}
    return const {};
  }

  Future<TrainingPageResponse> fetchTrainings({int page = 1}) async {
    final res = await http
        .get(Uri.parse('$_baseUrl/btapi/training/all?page=$page'))
        .timeout(_timeout);
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        final rawData = decoded['data'];
        final meta = decoded['meta'] is Map
            ? Map<String, dynamic>.from(decoded['meta'] as Map)
            : const <String, dynamic>{};
        final items = rawData is List
            ? rawData
                .whereType<Map>()
                .map((e) =>
                    TrainingEventItem.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const <TrainingEventItem>[];
        return TrainingPageResponse(
          data: items,
          page: int.tryParse((meta['page'] ?? page).toString()) ?? page,
          lastPage: int.tryParse((meta['last_page'] ?? 1).toString()) ?? 1,
          total: int.tryParse((meta['total'] ?? items.length).toString()) ??
              items.length,
        );
      }
    }
    return TrainingPageResponse(
      data: const [],
      page: page,
      lastPage: 1,
      total: 0,
    );
  }

  Future<List<TrainingTicketItem>> fetchTrainingTickets({
    required String noreg,
  }) async {
    final cleanNoreg = SessionStore.formatNoreg8(noreg);
    if (cleanNoreg.isEmpty) {
      final cached = await SessionStore().loadTrainingTicketsCache();
      return TrainingTicketItem.decodeList(cached);
    }

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/btapi/training/getAllByNoreg'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_noreg': cleanNoreg}),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['success'] == true) {
          final rawList = decoded['data'];
          if (rawList is List) {
            final mapped = rawList
                .whereType<Map>()
                .map((e) => TrainingTicketItem.fromApiOrCache(
                    Map<String, dynamic>.from(e)))
                .toList();
            await SessionStore()
                .saveTrainingTicketsCache(TrainingTicketItem.encodeList(mapped));
            return mapped;
          }
        }
      }
    } catch (_) {
      // Gunakan cache lokal jika offline.
    }

    final cached = await SessionStore().loadTrainingTicketsCache();
    return TrainingTicketItem.decodeList(cached);
  }

  Future<TrainingTicketItem> registerTraining({
    required UserSession session,
    required String trainingSlug,
  }) async {
    final cleanNoreg = SessionStore.formatNoreg8(session.noreg);
    final uid = await SessionStore().getOrCreateUidFallback();

    // Pastikan uid tersinkron di TokenModel (/btapi/uid) agar TokenValidator::check($csrf, $user_noreg) valid
    await syncUid(userId: cleanNoreg, uid: uid);

    var komisi = session.komisi;
    var divisi = session.divisi;
    if (komisi.isEmpty && divisi.isEmpty) {
      final ktaRaw = await SessionStore().loadKtaCache();
      if (ktaRaw != null && ktaRaw.isNotEmpty) {
        try {
          final map = jsonDecode(ktaRaw);
          if (map is Map) {
            komisi = (map['Komisi'] ?? map['komisi'] ?? '').toString();
            divisi = (map['divisi'] ?? map['dept'] ?? '').toString();
          }
        } catch (_) {}
      }
    }

    final payload = {
      'user_id': session.userId > 0 ? session.userId : 1,
      'user_nama': session.nama.isNotEmpty ? session.nama : 'Anggota',
      'user_noreg': cleanNoreg.isNotEmpty ? cleanNoreg : '-',
      'training_id': trainingSlug,
      'komisi': komisi,
      'divisi': divisi,
      'csrf': uid,
    };

    final res = await http
        .post(
          Uri.parse('$_baseUrl/btapi/training/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    final decoded = jsonDecode(res.body);
    if (decoded is! Map || decoded['success'] != true || decoded['data'] is! Map) {
      final msg = (decoded is Map ? decoded['message'] : null) ??
          'Gagal mendaftar training.';
      throw BungteminApiException(msg.toString());
    }

    final ticket = TrainingTicketItem.fromApiOrCache(
      Map<String, dynamic>.from(decoded['data'] as Map),
    );

    final cachedRaw = await SessionStore().loadTrainingTicketsCache();
    final current = TrainingTicketItem.decodeList(cachedRaw).toList();
    if (!current.any((t) => t.eventSlug == ticket.eventSlug)) {
      current.insert(0, ticket);
      await SessionStore()
          .saveTrainingTicketsCache(TrainingTicketItem.encodeList(current));
    }

    return ticket;
  }

  // ---------------------------------------------------------------------------
  // Room Meeting (kehadiran, foto, resume, voice member)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _decodeMeetingResponse(
    http.Response res,
    String fallbackMessage,
  ) {
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      decoded = null;
    }
    if (res.statusCode >= 400 ||
        decoded is! Map<String, dynamic> ||
        decoded['success'] == false) {
      final msg = decoded is Map ? decoded['message'] : null;
      throw BungteminApiException((msg ?? fallbackMessage).toString());
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _meetingPost(
    String path,
    Map<String, dynamic> body, {
    required String noreg,
    String token = '',
    String fallbackMessage = 'Permintaan meeting gagal diproses.',
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/btapi/Meeting/$path'),
          headers: _authJsonHeaders(token),
          body: jsonEncode({...body, 'noreg': SessionStore.formatNoreg8(noreg)}),
        )
        .timeout(_timeout);
    return _decodeMeetingResponse(res, fallbackMessage);
  }

  Future<MeetingRoomData> fetchMeetingRoom({
    required String meetingId,
    required String noreg,
    String token = '',
  }) async {
    final res = await http
        .get(
          Uri.parse(
            '$_baseUrl/btapi/Meeting/room/${Uri.encodeComponent(meetingId)}'
            '?noreg=${Uri.encodeComponent(SessionStore.formatNoreg8(noreg))}',
          ),
          headers: _authJsonHeaders(token),
        )
        .timeout(_timeout);
    final decoded =
        _decodeMeetingResponse(res, 'Gagal memuat detail ruang meeting.');
    return MeetingRoomData.fromJson(decoded);
  }

  Future<void> changeMeetingStatus({
    required String meetingId,
    required String status,
    required String noreg,
    String token = '',
  }) async {
    await _meetingPost(
      'change_status/${Uri.encodeComponent(meetingId)}',
      {'status': status},
      noreg: noreg,
      token: token,
      fallbackMessage: 'Gagal mengubah status meeting.',
    );
  }

  Future<void> updateMeetingPeserta({
    required String meetingId,
    required int pesertaId,
    required String status,
    required String noreg,
    String token = '',
  }) async {
    await _meetingPost(
      'update_peserta/${Uri.encodeComponent(meetingId)}',
      {'peserta_id': pesertaId, 'status_kehadiran': status},
      noreg: noreg,
      token: token,
      fallbackMessage: 'Gagal mengubah kehadiran.',
    );
  }

  Future<String> sendMeetingWaTickets({
    required String meetingId,
    required String noreg,
    String token = '',
  }) async {
    final r = await _meetingPost(
      'send_wa_tickets/${Uri.encodeComponent(meetingId)}',
      const {},
      noreg: noreg,
      token: token,
      fallbackMessage: 'Gagal mengantrekan tiket WA.',
    );
    return (r['message'] ?? 'Tiket WA berhasil diantrekan.').toString();
  }

  Future<void> saveMeetingNotulen({
    required String meetingId,
    required String topik,
    required String pembicara,
    required String isiDiskusi,
    required String keputusan,
    required String noreg,
    String token = '',
  }) async {
    await _meetingPost(
      'save_notulen/${Uri.encodeComponent(meetingId)}',
      {
        'topik': topik,
        'pembicara': pembicara,
        'isi_diskusi': isiDiskusi,
        'keputusan': keputusan,
      },
      noreg: noreg,
      token: token,
      fallbackMessage: 'Gagal menyimpan voice member.',
    );
  }

  Future<void> deleteMeetingNotulen({
    required String meetingId,
    required int notulenId,
    required String noreg,
    String token = '',
  }) async {
    await _meetingPost(
      'delete_notulen/${Uri.encodeComponent(meetingId)}',
      {'notulen_id': notulenId},
      noreg: noreg,
      token: token,
      fallbackMessage: 'Gagal menghapus poin.',
    );
  }

  Future<void> updateMeetingKesimpulan({
    required String meetingId,
    required String kesimpulan,
    required String tindakLanjut,
    required String noreg,
    String token = '',
  }) async {
    await _meetingPost(
      'update_kesimpulan/${Uri.encodeComponent(meetingId)}',
      {'kesimpulan': kesimpulan, 'tindak_lanjut': tindakLanjut},
      noreg: noreg,
      token: token,
      fallbackMessage: 'Gagal menyimpan kesimpulan.',
    );
  }

  Future<String> submitMeetingReview({
    required String meetingId,
    required String noreg,
    String token = '',
  }) async {
    final r = await _meetingPost(
      'submit_review/${Uri.encodeComponent(meetingId)}',
      const {},
      noreg: noreg,
      token: token,
      fallbackMessage: 'Gagal mengirim laporan untuk review.',
    );
    return (r['message'] ?? 'Laporan dikirim untuk review.').toString();
  }

  /// Unggah foto dokumentasi (`foto_dokumentasi`) atau file resume (`resume_file`).
  Future<String> uploadMeetingDokumen({
    required String meetingId,
    required String field,
    required String filePath,
    required String noreg,
    String token = '',
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$_baseUrl/btapi/Meeting/upload_dokumen/${Uri.encodeComponent(meetingId)}',
      ),
    );
    if (token.trim().isNotEmpty) {
      req.headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    req.fields['noreg'] = SessionStore.formatNoreg8(noreg);

    final lower = filePath.toLowerCase();
    const okExt = ['.jpg', '.jpeg', '.png', '.webp'];
    final hasOkExt = okExt.any(lower.endsWith);
    final baseName = filePath.split('/').last;
    req.files.add(
      await http.MultipartFile.fromPath(
        field,
        filePath,
        filename: hasOkExt ? baseName : '$baseName.jpg',
      ),
    );

    final streamed = await http.apiClient.send(req).timeout(const Duration(seconds: 90));
    final res = await http.Response.fromStream(streamed);
    final decoded = _decodeMeetingResponse(res, 'Gagal mengunggah file.');
    return (decoded['message'] ?? 'File berhasil diunggah.').toString();
  }
}
