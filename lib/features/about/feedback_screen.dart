import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/theme.dart';
import 'contact_screen.dart';

/// Halaman ringkas & compact khusus Saran Aplikasi (tersimpan ke DB & push FCM ke Admin).
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _feedbackCtrl = TextEditingController();
  String _category = 'UX';
  bool _sending = false;

  static const _categories = [
    ('UX', Icons.auto_awesome_rounded),
    ('Bug', Icons.bug_report_outlined),
    ('Fitur Baru', Icons.lightbulb_outline_rounded),
  ];

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitToServer() async {
    final text = _feedbackCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tuliskan saran terlebih dahulu.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final noreg = (prefs.getString('bt_noreg') ?? '').trim();
      final nama = (prefs.getString('bt_nama') ?? '').trim();

      final res = await http
          .post(
            Uri.parse('https://bungtemin.net/btapi/Feedback/submit'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'noreg': noreg,
              'nama': nama,
              'category': _category,
              'message': text,
              'app_version': AppInfo.displayVersion,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (res.statusCode == 200 && body['success'] == true) {
        _feedbackCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (body['message'] ?? 'Terima kasih! Saran Anda sudah terkirim.')
                  .toString(),
            ),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception(body['message'] ?? 'Gagal mengirim saran');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak dapat membuka $url'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendExternal({required bool viaWa}) async {
    final text = _feedbackCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tuliskan saran terlebih dahulu.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final body = '[Saran Aplikasi ${AppInfo.displayVersion}]\n'
        'Kategori: $_category\n\n'
        '$text';

    if (viaWa) {
      await _launch(
        'https://wa.me/${ContactScreen.officialWaNumber}?text=${Uri.encodeComponent(body)}',
      );
    } else {
      final subject =
          Uri.encodeComponent('Saran Aplikasi Bungtemin ($_category)');
      await _launch(
        'mailto:${ContactScreen.feedbackEmail}?subject=$subject&body=${Uri.encodeComponent(body)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'Saran Aplikasi',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryBlue, AppColors.indigo],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.rate_review_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Kirim Masukan',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        AppInfo.displayVersion,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, icon) in _categories)
                      ChoiceChip(
                        avatar: Icon(
                          icon,
                          size: 16,
                          color: _category == label
                              ? Colors.white
                              : AppColors.navy,
                        ),
                        label: Text(label),
                        selected: _category == label,
                        showCheckmark: false,
                        selectedColor: AppColors.navy,
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _category == label
                              ? Colors.white
                              : AppColors.navy,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _category == label
                                ? AppColors.navy
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        onSelected: (_) => setState(() => _category = label),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _feedbackCtrl,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Tulis saran, kendala, atau ide fitur...',
                    hintStyle: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.muted,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primaryBlue,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _sending ? null : _submitToServer,
                    icon: _sending
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _sending ? 'Mengirim...' : 'Kirim Masukan',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF16A34A),
                          side: const BorderSide(color: Color(0xFFBBF7D0)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _sendExternal(viaWa: true),
                        icon: const Icon(Icons.chat_rounded, size: 16),
                        label: const Text(
                          'Via WhatsApp',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.navy,
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _sendExternal(viaWa: false),
                        icon: const Icon(Icons.email_outlined, size: 16),
                        label: const Text(
                          'Via Email',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
