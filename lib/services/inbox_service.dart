import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/net/btapi_auth.dart';

class BroadcastInboxField {
  const BroadcastInboxField({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    required this.options,
  });

  final String key;
  final String label;
  final String type; // text | textarea | number | select | radio | checkbox | date
  final bool required;
  final List<String> options;

  factory BroadcastInboxField.fromJson(Map<String, dynamic> json) {
    final opts = (json['options'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    return BroadcastInboxField(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      type: (json['type'] ?? 'text').toString().toLowerCase(),
      required: json['required'] == true,
      options: opts,
    );
  }
}

class BroadcastInboxItem {
  const BroadcastInboxItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.targetGroup,
    required this.attachmentUrl,
    required this.attachmentLabel,
    required this.actionLabel,
    required this.formSchema,
    required this.createdByName,
    required this.createdAt,
    required this.isRead,
    required this.isConfirmed,
    required this.hasSubmitted,
    required this.answers,
    this.preventScreenshot = false,
    this.allowDelete = true,
  });

  final int id;
  final String title;
  final String body;
  final String category;
  final String targetGroup;
  final String attachmentUrl;
  final String attachmentLabel;
  final String actionLabel;
  final List<BroadcastInboxField> formSchema;
  final String createdByName;
  final String createdAt;
  final bool isRead;
  final bool isConfirmed;
  final bool hasSubmitted;
  final Map<String, dynamic>? answers;
  final bool preventScreenshot;
  final bool allowDelete;

  factory BroadcastInboxItem.fromJson(Map<String, dynamic> json) {
    final rawSchema = json['form_schema'];
    final schema = rawSchema is List
        ? rawSchema
            .whereType<Map>()
            .map((e) => BroadcastInboxField.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <BroadcastInboxField>[];
    final rawAns = json['answers'];
    return BroadcastInboxItem(
      id: int.tryParse('${json['id']}') ?? 0,
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      category: (json['category'] ?? 'pengumuman').toString(),
      targetGroup: (json['target_group'] ?? 'all').toString(),
      attachmentUrl: (json['attachment_url'] ?? '').toString(),
      attachmentLabel: (json['attachment_label'] ?? '').toString(),
      actionLabel: (json['action_label'] ?? '').toString(),
      formSchema: schema,
      createdByName: (json['created_by_name'] ?? 'Admin Bungtemin').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      isRead: json['is_read'] == true,
      isConfirmed: json['is_confirmed'] == true,
      hasSubmitted: json['has_submitted'] == true,
      answers: rawAns is Map ? Map<String, dynamic>.from(rawAns) : null,
      preventScreenshot: json['prevent_screenshot'] == true ||
          json['prevent_screenshot'] == 1 ||
          '${json['prevent_screenshot']}' == '1',
      allowDelete: json['allow_delete'] == null
          ? true
          : (json['allow_delete'] == true ||
              json['allow_delete'] == 1 ||
              '${json['allow_delete']}' == '1'),
    );
  }
}

class InboxListResult {
  const InboxListResult({required this.unreadCount, required this.items});
  final int unreadCount;
  final List<BroadcastInboxItem> items;
}

class InboxService {
  static const String _base = 'https://bungtemin.net/btapi/Inbox';
  static const Duration _timeout = Duration(seconds: 12);

  Future<InboxListResult> fetchList() async {
    final res = await http
        .get(Uri.parse('$_base/list'), headers: BtapiAuth.headers())
        .timeout(_timeout);
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400 || decoded is! Map) {
      throw Exception('Gagal memuat inbox (HTTP ${res.statusCode})');
    }
    final items = (decoded['items'] as List?)
            ?.whereType<Map>()
            .map((e) => BroadcastInboxItem.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <BroadcastInboxItem>[];
    final unread = int.tryParse('${decoded['unread_count'] ?? 0}') ?? 0;
    return InboxListResult(unreadCount: unread, items: items);
  }

  Future<void> markRead(int id) async {
    try {
      await http
          .post(
            Uri.parse('$_base/read'),
            headers: {'Content-Type': 'application/json', ...BtapiAuth.headers()},
            body: jsonEncode({'id': id}),
          )
          .timeout(_timeout);
    } catch (_) {}
  }

  Future<void> deleteMessage(int id) async {
    final res = await http
        .post(
          Uri.parse('$_base/delete'),
          headers: {'Content-Type': 'application/json', ...BtapiAuth.headers()},
          body: jsonEncode({'id': id}),
        )
        .timeout(_timeout);
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400 || decoded is! Map || decoded['success'] != true) {
      final msg = decoded is Map
          ? (decoded['message'] ?? 'Gagal menghapus pesan')
          : 'HTTP ${res.statusCode}';
      throw Exception(msg);
    }
  }

  Future<String> submitResponse({
    required int id,
    bool confirm = false,
    Map<String, dynamic>? answers,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_base/submit'),
          headers: {'Content-Type': 'application/json', ...BtapiAuth.headers()},
          body: jsonEncode({
            'id': id,
            'confirm': confirm,
            if (answers != null) 'answers': answers,
          }),
        )
        .timeout(_timeout);
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400 || decoded is! Map || decoded['success'] != true) {
      final msg = decoded is Map ? (decoded['message'] ?? 'Gagal mengirim') : 'HTTP ${res.statusCode}';
      throw Exception(msg.toString());
    }
    return (decoded['message'] ?? 'Berhasil disimpan.').toString();
  }
}
