import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/session_store.dart';

class SurveySummary {
  const SurveySummary({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.questionCount,
    required this.responseCount,
    required this.createdAt,
    this.iconUrl = '',
    this.bannerUrl = '',
    this.accentColor = '#2563EB',
    this.floatingEnabled = false,
    this.floatingImageUrl = '',
    this.floatingLabel = '',
  });

  final int id;
  final String title;
  final String slug;
  final String description;
  final int questionCount;
  final int responseCount;
  final String createdAt;
  final String iconUrl;
  final String bannerUrl;
  final String accentColor;
  final bool floatingEnabled;
  final String floatingImageUrl;
  final String floatingLabel;

  factory SurveySummary.fromJson(Map<String, dynamic> json) {
    return SurveySummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
      responseCount: (json['response_count'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] ?? '').toString(),
      iconUrl: (json['icon_url'] ?? '').toString().trim(),
      bannerUrl: (json['banner_url'] ?? '').toString().trim(),
      accentColor: (json['accent_color'] ?? '#2563EB').toString().trim(),
      floatingEnabled: json['floating_enabled'] == true,
      floatingImageUrl: (json['floating_image_url'] ?? '').toString().trim(),
      floatingLabel: (json['floating_label'] ?? '').toString().trim(),
    );
  }
}

class SurveyField {
  const SurveyField({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    required this.options,
  });

  final String key;
  final String label;
  final String type; // text | textarea | number | date | radio | checkbox | select | rating
  final bool required;
  final List<String> options;

  factory SurveyField.fromJson(Map<String, dynamic> json) {
    final opts = (json['options'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    return SurveyField(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      type: (json['type'] ?? 'text').toString().toLowerCase(),
      required: json['required'] == true,
      options: opts,
    );
  }
}

class SurveyDetail {
  const SurveyDetail({
    required this.surveyId,
    required this.slug,
    required this.title,
    required this.description,
    required this.fields,
    this.iconUrl = '',
    this.bannerUrl = '',
    this.accentColor = '#2563EB',
  });

  final int surveyId;
  final String slug;
  final String title;
  final String description;
  final List<SurveyField> fields;
  final String iconUrl;
  final String bannerUrl;
  final String accentColor;

  factory SurveyDetail.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'];
    final fields = rawFields is List
        ? rawFields
            .whereType<Map>()
            .map((e) => SurveyField.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <SurveyField>[];
    return SurveyDetail(
      surveyId: (json['survey_id'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      fields: fields,
      iconUrl: (json['icon_url'] ?? '').toString().trim(),
      bannerUrl: (json['banner_url'] ?? '').toString().trim(),
      accentColor: (json['accent_color'] ?? '#2563EB').toString().trim(),
    );
  }
}

class SurveyService {
  SurveyService._();
  static final SurveyService instance = SurveyService._();

  static const String _baseUrl = 'https://bungtemin.net/btapi/survey';

  Future<SurveySummary?> fetchFloatingSurvey() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/floating'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final map = jsonDecode(res.body);
      if (map is Map && map['status'] == 'success' && map['data'] is Map) {
        return SurveySummary.fromJson(Map<String, dynamic>.from(map['data'] as Map));
      }
    } catch (_) {}
    return null;
  }

  Future<List<SurveySummary>> fetchSurveys() async {
    final res = await http
        .get(Uri.parse('$_baseUrl/list'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Gagal memuat daftar form (HTTP ${res.statusCode})');
    }
    final map = jsonDecode(res.body);
    if (map is! Map || map['status'] != 'success') {
      throw Exception((map is Map ? map['message'] : null)?.toString() ?? 'Gagal memuat daftar form');
    }
    final list = map['data'] is List ? map['data'] as List : const [];
    return list
        .whereType<Map>()
        .map((e) => SurveySummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SurveyDetail> fetchSurveyBySlug(String slug) async {
    final res = await http
        .get(Uri.parse('$_baseUrl/get/${Uri.encodeComponent(slug)}'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Form tidak ditemukan (HTTP ${res.statusCode})');
    }
    final map = jsonDecode(res.body);
    if (map is! Map || map['status'] != 'success') {
      throw Exception((map is Map ? map['message'] : null)?.toString() ?? 'Form tidak tersedia');
    }
    return SurveyDetail.fromJson(Map<String, dynamic>.from(map));
  }

  Future<String> submitSurvey({
    required int surveyId,
    required Map<String, dynamic> answer,
  }) async {
    final session = await SessionStore().load();
    final noreg = session != null ? SessionStore.formatNoreg8(session.noreg) : '';
    final nama = session?.nama ?? '';

    final res = await http
        .post(
          Uri.parse('$_baseUrl/submit'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'survey_id': surveyId,
            'noreg': noreg,
            'nama': nama,
            'platform': 'android',
            'answer': answer,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final map = jsonDecode(res.body);
    if (res.statusCode == 200 && map is Map && map['status'] == 'success') {
      return (map['message'] ?? 'Tanggapan berhasil disimpan!').toString();
    }
    throw Exception((map is Map ? map['message'] : null)?.toString() ?? 'Gagal mengirim tanggapan');
  }
}
