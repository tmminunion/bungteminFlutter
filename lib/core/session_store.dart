import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'net/api_cache_store.dart';
import 'net/btapi_auth.dart';

class UserSession {
  const UserSession({
    required this.noreg,
    required this.nama,
    required this.job,
    required this.token,
    this.userId = 1,
    this.komisi = '',
    this.divisi = '',
  });

  final String noreg;
  final String nama;
  final String job;
  final String token;
  final int userId;
  final String komisi;
  final String divisi;

  bool get isValid => noreg.trim().isNotEmpty;

  bool get isModeratorOrPuk {
    final j = job.toLowerCase();
    return RegExp(r'\b(puk|kp)\b').hasMatch(j) || j.contains('superadmin') || j.contains('admin');
  }

  String get avatarUrl {
    final n8 = SessionStore.formatNoreg8(noreg);
    if (n8.isEmpty) return '';
    return SessionStore.btapiAvatarUrl(n8);
  }
}

class SessionStore {
  static const _kNoreg = 'bt_noreg';
  static const _kNama = 'bt_nama';
  static const _kJob = 'bt_job';
  static const _kToken = 'bt_token';
  static const _kUserId = 'bt_user_id';
  static const _kKomisi = 'bt_komisi';
  static const _kDivisi = 'bt_divisi';
  static const _kUidFire = 'bt_uid_fire';
  static const _kDidTutorial = 'bt_did_tutorial';
  static const _kMenuCache = 'bt_menu_cache';
  static const _kKtaCache = 'bt_kta_cache';
  static const _kStrukturCache = 'bt_struktur_cache';
  static const _kTrainingTicketsCache = 'bt_training_tickets';
  static const _kReadBukuId = 'readbukuID';
  static const _kInternalNewsCache = 'bt_internal_news_cache';
  static const _kExternalNewsCache = 'bt_external_news_cache';
  static const _kBannersCache = 'bt_banners_cache';
  static const _kSavedStoryIds = 'bt_saved_story_ids';
  static const _kSavedReelIds = 'bt_saved_reel_ids';
  static const _kServerEncNoreg = 'bt_server_enc_noreg';
  static const _kServerKeyVersion = 'bt_server_key_version';

  static String formatNoreg8(String raw) {
    final clean = raw.trim().replaceFirst(RegExp(r'^0+'), '');
    if (clean.isEmpty) return '';
    return RegExp(r'^\d+$').hasMatch(clean) ? clean.padLeft(8, '0') : raw.trim();
  }

  /// Proxy foto profil HRPortal melalui BTAPI (`https://bungtemin.net/btapi/Calendar/hravatar/{noreg}`)
  /// dengan cache server 1 bulan (30 hari).
  static String btapiAvatarUrl(String rawNoreg) {
    final n8 = formatNoreg8(rawNoreg);
    if (n8.isEmpty || n8 == '00000000') return '';
    return 'https://bungtemin.net/btapi/Calendar/hravatar/$n8';
  }

  /// Normalisasi URL avatar eksternal (misal `hrportal.toyota.co.id` atau `dev.bungtemin.net/api/i-proxy`)
  /// agar selalu melewati proxy BTAPI `bungtemin.net`.
  static String resolveAvatarUrl(String rawAvatar, String fallbackNoreg) {
    final trimmed = rawAvatar.trim();
    if (trimmed.isEmpty) {
      return btapiAvatarUrl(fallbackNoreg);
    }
    if (trimmed.contains('hrportal.toyota.co.id') ||
        trimmed.contains('dev.bungtemin.net/api/i-proxy')) {
      final m = RegExp(r'(\d{5,8})\.jpg', caseSensitive: false).firstMatch(trimmed);
      if (m != null) {
        return btapiAvatarUrl(m.group(1)!);
      }
      final byNoreg = btapiAvatarUrl(fallbackNoreg);
      if (byNoreg.isNotEmpty) return byNoreg;
    }
    return trimmed;
  }

  Future<String> getOrCreateUidFallback() async {
    final prefs = await SharedPreferences.getInstance();
    var uid = prefs.getString(_kUidFire) ?? '';
    if (uid.trim().isEmpty) {
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      final rnd = Random();
      final suffix = List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
      uid = 'bt_${DateTime.now().millisecondsSinceEpoch}_$suffix';
      await prefs.setString(_kUidFire, uid);
    }
    return uid;
  }

  Future<UserSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final noreg = prefs.getString(_kNoreg) ?? '';
    if (noreg.isEmpty) return null;
    final storedToken = prefs.getString(_kToken) ?? '';
    BtapiAuth.setToken(storedToken);
    return UserSession(
      noreg: noreg,
      nama: prefs.getString(_kNama) ?? 'Anggota',
      job: prefs.getString(_kJob) ?? 'ANGGOTA',
      token: storedToken,
      userId: prefs.getInt(_kUserId) ?? 1,
      komisi: prefs.getString(_kKomisi) ?? '',
      divisi: prefs.getString(_kDivisi) ?? '',
    );
  }

  Future<void> save(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNoreg, formatNoreg8(session.noreg));
    await prefs.setString(_kNama, session.nama);
    await prefs.setString(_kJob, session.job);
    await prefs.setString(_kToken, session.token);
    BtapiAuth.setToken(session.token);
    await prefs.setInt(_kUserId, session.userId);
    await prefs.setString(_kKomisi, session.komisi);
    await prefs.setString(_kDivisi, session.divisi);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kNoreg);
    await prefs.remove(_kNama);
    await prefs.remove(_kJob);
    await prefs.remove(_kToken);
    BtapiAuth.clear();
    await prefs.remove(_kUserId);
    await prefs.remove(_kKomisi);
    await prefs.remove(_kDivisi);
    await prefs.remove(_kKtaCache);
    await prefs.remove(_kTrainingTicketsCache);
    // Bersihkan cache API SQLite agar data akun sebelumnya tidak terbawa.
    await ApiCacheStore.instance.clear();
  }

  Future<bool> hasSeenTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDidTutorial) ?? false;
  }

  Future<void> setTutorialSeen([bool seen = true]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDidTutorial, seen);
  }

  Future<String?> loadMenuCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kMenuCache);
  }

  Future<void> saveMenuCache(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMenuCache, rawJson);
  }

  Future<String?> loadKtaCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kKtaCache);
  }

  Future<void> saveKtaCache(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKtaCache, rawJson);
  }

  Future<String?> loadStrukturCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kStrukturCache);
  }

  Future<void> saveStrukturCache(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStrukturCache, rawJson);
  }

  Future<String?> loadTrainingTicketsCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTrainingTicketsCache);
  }

  Future<void> saveTrainingTicketsCache(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTrainingTicketsCache, rawJson);
  }

  Future<String> loadReadBukuId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kReadBukuId) ?? 'assets/doc/1.pdf';
  }

  Future<void> saveReadBukuId(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReadBukuId, url);
  }

  Future<String?> loadInternalNewsCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kInternalNewsCache);
  }

  Future<void> saveInternalNewsCache(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInternalNewsCache, rawJson);
  }

  Future<String?> loadExternalNewsCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kExternalNewsCache);
  }

  Future<void> saveExternalNewsCache(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kExternalNewsCache, rawJson);
  }

  Future<String?> loadBannersCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBannersCache);
  }

  Future<void> saveBannersCache(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBannersCache, rawJson);
  }

  Future<Set<String>> loadSavedStoryIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kSavedStoryIds) ?? const <String>[]).toSet();
  }

  Future<void> saveSavedStoryIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSavedStoryIds, ids.toList());
  }

  Future<Set<String>> loadSavedReelIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kSavedReelIds) ?? const <String>[]).toSet();
  }

  Future<void> saveSavedReelIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSavedReelIds, ids.toList());
  }

  Future<String> loadServerEncNoreg() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_kServerEncNoreg) ?? '').trim();
  }

  Future<String> refreshServerEncNoreg({String? token}) async {
    try {
      var tok = (token ?? '').trim();
      if (tok.isEmpty) {
        final s = await load();
        tok = (s?.token ?? '').trim();
      }
      if (tok.isEmpty) return '';
      final res = await http
          .get(
            Uri.parse('https://bungtemin.net/btapi/User/refresh_qr'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $tok',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          final enc = (decoded['enc_noreg'] ?? '').toString().trim();
          final ver = int.tryParse('${decoded['key_version'] ?? 1}') ?? 1;
          if (enc.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kServerEncNoreg, enc);
            await prefs.setInt(_kServerKeyVersion, ver);
            return enc;
          }
        }
      }
    } catch (_) {}
    return '';
  }
}
