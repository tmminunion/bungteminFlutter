import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/net/btapi_auth.dart';
import 'nudb_ws_client.dart';

/// Top-level background handler untuk FCM saat aplikasi dalam keadaan terminated/background.
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  if (response.actionId == 'reply_chat' &&
      (response.input ?? '').trim().isNotEmpty) {
    await FcmService.handleInlineReply(response);
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Abaikan jika Firebase belum dikonfigurasi pada environment non-Android.
  }
}

/// Payload terstruktur notifikasi push (migrasi dari `bungteminAPP/src/app/service/fcm.service.ts`).
class PushPayload {
  const PushPayload({
    required this.type,
    required this.pageId,
    required this.url,
    required this.title,
    required this.body,
  });

  final String type;
  final String pageId;
  final String url;
  final String title;
  final String body;

  factory PushPayload.fromRemoteMessage(RemoteMessage msg) {
    final data = msg.data;
    return PushPayload(
      type: (data['type'] ?? '').toString().trim(),
      pageId: (data['pageid'] ?? data['pageId'] ?? '').toString().trim(),
      url: (data['url'] ?? '').toString().trim(),
      title: (msg.notification?.title ?? data['title'] ?? '').toString().trim(),
      body: (msg.notification?.body ?? data['body'] ?? '').toString().trim(),
    );
  }

  factory PushPayload.fromJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PushPayload(
          type: (decoded['type'] ?? '').toString().trim(),
          pageId: (decoded['pageId'] ?? decoded['pageid'] ?? '').toString().trim(),
          url: (decoded['url'] ?? '').toString().trim(),
          title: (decoded['title'] ?? '').toString().trim(),
          body: (decoded['body'] ?? '').toString().trim(),
        );
      }
    } catch (_) {}
    return const PushPayload(type: '', pageId: '', url: '', title: '', body: '');
  }

  String toJsonString() => jsonEncode({
        'type': type,
        'pageId': pageId,
        'url': url,
        'title': title,
        'body': body,
      });

  /// Topik berbasis peran organisasi yang dikelola oleh `FcmService`.
  static const List<String> managedRoleTopics = <String>[
    'kp',
    'pleno',
    'puk',
    'pengurus',
    'anggota',
    'member',
  ];

  /// Ekstrak topik peran FCM (`kp`, `pleno`, `puk`, `pengurus`, `anggota`, `member`)
  /// dari string `job` user yang sedang login.
  static List<String> buildRoleTopics(String? job) {
    final raw = (job ?? '').trim().toLowerCase();
    if (raw.isEmpty) return const <String>[];

    final roles = <String>[];
    if (RegExp(r'\bkp\b').hasMatch(raw)) roles.add('kp');
    if (raw.contains('pleno')) roles.add('pleno');
    if (RegExp(r'\bpuk\b').hasMatch(raw)) roles.add('puk');

    final isPengurus = roles.isNotEmpty ||
        raw.contains('pengurus') ||
        raw.contains('admin');
    if (isPengurus) {
      roles.add('pengurus');
    } else {
      roles.add('anggota');
      roles.add('member');
    }
    return roles;
  }

  /// Daftar topik FCM standar Bungtemin (`news`, `feeds`, `<noreg>`, `noreg_<noreg>`,
  /// serta topik peran `kp`/`pleno`/`puk`/`pengurus`/`anggota`/`member`).
  static List<String> buildUserTopics(String? noreg, {String? job}) {
    final topics = <String>['news', 'feeds'];
    final clean = (noreg ?? '').trim();
    if (clean.isNotEmpty) {
      topics.add(clean);
      final prefixed = 'noreg_$clean';
      if (!topics.contains(prefixed)) {
        topics.add(prefixed);
      }
      for (final roleTopic in buildRoleTopics(job)) {
        if (!topics.contains(roleTopic)) {
          topics.add(roleTopic);
        }
      }
    }
    return topics;
  }

  /// Normalisasi tipe/path tujuan notifikasi menjadi rute internal Flutter.
  String resolveTargetRoute() {
    final u = url.toLowerCase();
    if (u.startsWith('/aplikasi')) return url;
    if (u.startsWith('/chat/')) return url;
    if (u.startsWith('/chat')) return pageId.isNotEmpty ? '/chat/$pageId' : '/chat';
    if (u.startsWith('/feed') || u.startsWith('/tabfeed')) return '/tabfeed';
    if (u.startsWith('/news')) return '/news';
    if (u.startsWith('/meeting/')) return u;
    if (u.startsWith('/meeting')) return pageId.isNotEmpty ? '/meeting/$pageId' : '/meeting';
    if (u.startsWith('/training-pleno')) return '/training-pleno';
    if (u.startsWith('/training-ticket')) return '/training-ticket';
    if (u.startsWith('/training')) return '/training';
    if (u.startsWith('/pintar')) return '/pintar';
    if (u.startsWith('/buku')) return u;
    if (u.startsWith('/kalender')) return '/kalender';
    if (u.startsWith('/struktur')) return '/struktur';
    if (u.startsWith('/proker')) return '/proker';
    if (u.startsWith('/tonton')) return '/tonton';
    if (u.startsWith('/lapor') || u.startsWith('/hallopuk')) return '/lapor';
    if (u.startsWith('/scanner')) return '/scanner';
    if (u.startsWith('/idcard') || u.startsWith('/kta')) return '/idcard';
    if (u.startsWith('/profil') || u.contains('user-profile')) return '/profil';

    switch (type.toLowerCase()) {
      case 'feedkoment':
      case 'mention':
      case 'feedlike':
      case 'feeds':
        return '/tabfeed';
      case 'myars':
      case 'absensi':
        return '/aplikasi/absensi/tiketlist';
      case 'chat':
        return pageId.isNotEmpty ? '/chat/$pageId' : '/chat';
      case 'news':
      case 'berita':
        return '/news';
      case 'meeting':
        return pageId.isNotEmpty ? '/meeting/$pageId' : '/meeting';
      case 'training':
      case 'pintar':
        return '/training';
      case 'kalender':
        return '/kalender';
      case 'struktur':
        return '/struktur';
      case 'proker':
        return '/proker';
      case 'tonton':
        return '/tonton';
      case 'lapor':
      case 'aspirasi':
      case 'hallopuk':
        return '/lapor';
      case 'kta':
      case 'idcard':
        return '/idcard';
      case 'profil':
      case 'newfollower':
        return '/profil';
      default:
        return u.startsWith('http://') || u.startsWith('https://') ? url : '/home';
    }
  }
}

/// Service terpusat Firebase Cloud Messaging + Local Notifications + NuDB `firetoken`.
class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  static const _kTokenPrefKey = 'bt_fcm_token';
  static const _kHistoryPrefKey = 'bt_push_history';

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
    'chat_messages',
    'Chat Messages',
    description: 'Notifikasi berita, diskusi, agenda meeting, dan pesan Bungtemin',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<PushPayload> _tapController =
      StreamController<PushPayload>.broadcast();
  final StreamController<PushPayload> _foregroundController =
      StreamController<PushPayload>.broadcast();

  bool _initialized = false;
  String? _currentToken;
  String? _activeNoreg;
  PushPayload? _pendingLaunchPayload;

  Stream<PushPayload> get onNotificationTap => _tapController.stream;
  Stream<PushPayload> get onForegroundMessage => _foregroundController.stream;
  String? get currentToken => _currentToken;

  /// Ambil & hapus payload awal bila aplikasi dibuka langsung lewat tap notifikasi.
  PushPayload? consumePendingLaunchPayload() {
    final pending = _pendingLaunchPayload;
    _pendingLaunchPayload = null;
    return pending;
  }

  /// Inisialisasi Firebase Messaging & saluran notifikasi Android (`chat_messages`).
  Future<void> init({String? initialNoreg}) async {
    _activeNoreg = initialNoreg?.trim().isEmpty ?? true ? null : initialNoreg?.trim();
    if (_initialized || kIsWeb) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _initLocalNotifications();
      await _requestPermissions();
      await _configureMessagingListeners();

      _initialized = true;
      await syncUser(_activeNoreg);
    } catch (e) {
      debugPrint('[FCM] Init dilewati / error: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.actionId == 'reply_chat' &&
            (response.input ?? '').trim().isNotEmpty) {
          await handleInlineReply(response);
          final raw = response.payload ?? '';
          if (raw.isNotEmpty) {
            _foregroundController.add(PushPayload.fromJsonString(raw));
          }
          return;
        }
        final raw = response.payload ?? '';
        if (raw.isEmpty) return;
        final payload = PushPayload.fromJsonString(raw);
        _emitTapPayload(payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_defaultChannel);
  }

  Future<void> _requestPermissions() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _configureMessagingListeners() async {
    final messaging = FirebaseMessaging.instance;

    final initialMsg = await messaging.getInitialMessage();
    if (initialMsg != null) {
      final p = PushPayload.fromRemoteMessage(initialMsg);
      _pendingLaunchPayload = p;
      await _saveToHistory(p);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final payload = PushPayload.fromRemoteMessage(msg);
      await _saveToHistory(payload);
      _foregroundController.add(payload);
      await _showForegroundNotification(msg, payload);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) async {
      final payload = PushPayload.fromRemoteMessage(msg);
      await _saveToHistory(payload);
      _emitTapPayload(payload);
    });

    messaging.onTokenRefresh.listen((newToken) async {
      await _persistAndPushToken(newToken, _activeNoreg);
    });
  }

  void _emitTapPayload(PushPayload payload) {
    if (_tapController.hasListener) {
      _tapController.add(payload);
    } else {
      _pendingLaunchPayload = payload;
    }
  }

  Future<void> _showForegroundNotification(
    RemoteMessage msg,
    PushPayload payload,
  ) async {
    final title = payload.title.isNotEmpty ? payload.title : 'Bungtemin';
    final body = payload.body;
    if (title.isEmpty && body.isEmpty) return;

    final isChat = payload.type.toLowerCase() == 'chat' && payload.pageId.isNotEmpty;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _defaultChannel.id,
        _defaultChannel.name,
        channelDescription: _defaultChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        actions: isChat
            ? const <AndroidNotificationAction>[
                AndroidNotificationAction(
                  'reply_chat',
                  'Balas',
                  showsUserInterface: false,
                  allowGeneratedReplies: true,
                  inputs: <AndroidNotificationActionInput>[
                    AndroidNotificationActionInput(label: 'Balas pesan...'),
                  ],
                ),
              ]
            : null,
      ),
    );

    final notifId = msg.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _localNotifications.show(
      id: notifId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload.toJsonString(),
    );
  }

  /// Sinkronisasi token FCM ke NuDB (`firetoken/<noreg>`) dan subscribe topik.
  Future<void> syncUser(String? noreg, {String? job}) async {
    final cleanNoreg = noreg?.trim();
    _activeNoreg = (cleanNoreg != null && cleanNoreg.isNotEmpty) ? cleanNoreg : null;
    if (kIsWeb || !_initialized) return;

    try {
      String? effectiveJob = job?.trim();
      if ((effectiveJob == null || effectiveJob.isEmpty) && _activeNoreg != null) {
        final prefs = await SharedPreferences.getInstance();
        effectiveJob = (prefs.getString('bt_job') ?? '').trim();
      }

      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _persistAndPushToken(token, _activeNoreg);
      }

      final targetTopics =
          PushPayload.buildUserTopics(_activeNoreg, job: effectiveJob);
      for (final topic in targetTopics) {
        unawaited(
          messaging.subscribeToTopic(topic).catchError((Object e) {
            debugPrint('[FCM] Gagal subscribe topic $topic: $e');
          }),
        );
      }
      for (final roleTopic in PushPayload.managedRoleTopics) {
        if (!targetTopics.contains(roleTopic)) {
          unawaited(
            messaging.unsubscribeFromTopic(roleTopic).catchError((Object e) {
              debugPrint('[FCM] Gagal unsubscribe topic $roleTopic: $e');
            }),
          );
        }
      }
    } catch (e) {
      debugPrint('[FCM] syncUser gagal: $e');
    }
  }

  /// Hapus langganan topik personal Noreg & peran saat user logout.
  Future<void> clearUser(String? previousNoreg) async {
    _activeNoreg = null;
    final clean = previousNoreg?.trim() ?? '';
    if (kIsWeb || !_initialized) return;

    try {
      final messaging = FirebaseMessaging.instance;
      if (clean.isNotEmpty) {
        await messaging.unsubscribeFromTopic(clean);
        await messaging.unsubscribeFromTopic('noreg_$clean');
      }
      for (final roleTopic in PushPayload.managedRoleTopics) {
        await messaging.unsubscribeFromTopic(roleTopic);
      }
    } catch (e) {
      debugPrint('[FCM] clearUser gagal: $e');
    }
  }

  Future<void> _saveToHistory(PushPayload payload) async {
    if (payload.title.isEmpty && payload.body.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHistoryPrefKey);
      final list = <Map<String, dynamic>>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) list.add(Map<String, dynamic>.from(item));
          }
        }
      }
      list.insert(0, {
        'title': payload.title,
        'body': payload.body,
        'type': payload.type,
        'url': payload.url,
        'pageId': payload.pageId,
        'receivedAt': DateTime.now().toIso8601String(),
      });
      if (list.length > 40) {
        list.removeRange(40, list.length);
      }
      await prefs.setString(_kHistoryPrefKey, jsonEncode(list));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHistoryPrefKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHistoryPrefKey);
  }

  Future<void> _persistAndPushToken(String token, String? noreg) async {
    _currentToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenPrefKey, token);

    final cleanNoreg = noreg?.trim() ?? '';
    if (cleanNoreg.isNotEmpty) {
      await _updateNuDbFiretoken(cleanNoreg, token);
    }
  }

  /// Mengirim balasan chat langsung dari notification bar (Inline Reply).
  static Future<void> handleInlineReply(NotificationResponse response) async {
    final text = (response.input ?? '').trim();
    if (text.isEmpty) return;

    try {
      final payload = PushPayload.fromJsonString(response.payload ?? '');
      final roomId = payload.pageId.trim();
      if (roomId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final rawNoreg = (prefs.getString('bt_noreg') ?? '').trim();
      final rawNama = (prefs.getString('bt_nama') ?? '').trim();
      final digits = rawNoreg.replaceAll(RegExp(r'\D+'), '');
      if (digits.isEmpty) return;
      final self8 = digits.padLeft(8, '0');
      final nama = rawNama.isNotEmpty ? rawNama : 'Anggota';

      var receiver8 = '';
      if (roomId.startsWith('dm_')) {
        final parts = roomId.split('_');
        if (parts.length == 3) {
          receiver8 = parts[1] == self8 ? parts[2] : parts[1];
        }
      }

      await http
          .post(
            Uri.parse('https://bungtemin.net/btapi/Chat/send'),
            headers: {'Content-Type': 'application/json', ...BtapiAuth.headers()},
            body: jsonEncode({
              'room_id': roomId,
              'sender_noreg': self8,
              'sender_nama': nama,
              'receiver_noreg': receiver8,
              'message': text,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[FCM] Inline reply gagal: $e');
    }
  }

  Future<void> _updateNuDbFiretoken(String noreg, String token) async {
    await NudbWsClient.sendCommand(
      type: 'update',
      path: 'firetoken/$noreg',
      data: <String, dynamic>{'tokenfcm': token},
    );
  }
}
