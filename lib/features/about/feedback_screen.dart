import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_info.dart';
import '../../core/theme.dart';

/// Halaman Saran Aplikasi:
/// - Menampilkan identitas pengirim otomatis jika sudah login (Nama & Noreg)
/// - Form kirim saran (notif otomatis ke WA Admin & BTadmin)
/// - Riwayat saran yang pernah dikirim beserta balasan dari AdminPanel / BTadmin
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _feedbackCtrl = TextEditingController();
  String _category = 'UX';
  bool _sending = false;

  String _noreg = '';
  String _nama = '';
  bool _loadingHistory = false;
  List<Map<String, dynamic>> _history = const [];

  static const _categories = [
    ('UX', Icons.auto_awesome_rounded),
    ('Bug', Icons.bug_report_outlined),
    ('Fitur Baru', Icons.lightbulb_outline_rounded),
  ];

  bool get _isLoggedIn => _noreg.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initUserAndHistory();
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _initUserAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final noreg = (prefs.getString('bt_noreg') ?? '').trim();
    final nama = (prefs.getString('bt_nama') ?? '').trim();
    if (!mounted) return;
    setState(() {
      _noreg = noreg;
      _nama = nama;
    });
    if (noreg.isNotEmpty) {
      await _loadHistory(noreg);
    }
  }

  Future<void> _loadHistory([String? overrideNoreg]) async {
    final nr = (overrideNoreg ?? _noreg).trim();
    if (nr.isEmpty) return;
    if (mounted) setState(() => _loadingHistory = true);
    try {
      final uri = Uri.https(
        'bungtemin.net',
        '/btapi/Feedback/history',
        {'noreg': nr},
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final rawItems = body['items'];
        final parsed = rawItems is List
            ? rawItems.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        setState(() {
          _history = parsed;
          _loadingHistory = false;
        });
        return;
      }
      setState(() => _loadingHistory = false);
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
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
      final noreg = (prefs.getString('bt_noreg') ?? _noreg).trim();
      final nama = (prefs.getString('bt_nama') ?? _nama).trim();

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
          .timeout(const Duration(seconds: 15));

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
        if (noreg.isNotEmpty) {
          await _loadHistory(noreg);
        }
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'BT';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Color _statusBg(String st) {
    switch (st) {
      case 'selesai':
        return const Color(0xFFECFDF5);
      case 'diproses':
        return const Color(0xFFEFF6FF);
      default:
        return const Color(0xFFFFFBEB);
    }
  }

  Color _statusFg(String st) {
    switch (st) {
      case 'selesai':
        return const Color(0xFF059669);
      case 'diproses':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFFD97706);
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
        actions: [
          if (_isLoggedIn)
            IconButton(
              onPressed: _loadingHistory ? null : () => _loadHistory(),
              tooltip: 'Muat ulang riwayat',
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (_isLoggedIn) await _loadHistory();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.navy, AppColors.primaryBlue],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navy.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.rate_review_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Kirim Masukan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    AppInfo.displayVersion,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Masukan Anda langsung diterima tim pengembang & PUK Bungtemin.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Identitas Pengirim (Otomatis jika sudah login)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isLoggedIn
                          ? AppColors.primaryBlue.withValues(alpha: 0.28)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: _isLoggedIn
                            ? AppColors.navy
                            : const Color(0xFFE2E8F0),
                        child: Text(
                          _isLoggedIn
                              ? _initials(_nama.isNotEmpty ? _nama : _noreg)
                              : '?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _isLoggedIn ? Colors.white : AppColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLoggedIn
                                  ? (_nama.isNotEmpty ? _nama : 'Anggota $_noreg')
                                  : 'Pengirim: Mode Tamu',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isLoggedIn
                                  ? 'Noreg $_noreg • Riwayat & balasan admin otomatis tersimpan'
                                  : 'Masuk akun agar nama tercatat & bisa melihat riwayat balasan admin.',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Form Masukan
                Container(
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
                      const Text(
                        'Kategori Masukan',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 10),
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
                              onSelected: (_) =>
                                  setState(() => _category = label),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tulis Pesan',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _feedbackCtrl,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Tulis saran, kendala, atau ide fitur baru...',
                          hintStyle: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.muted,
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.all(14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
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
                        height: 50,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            elevation: 0,
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
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Riwayat Saran & Balasan Admin (hanya jika sudah login)
                if (_isLoggedIn) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Riwayat Saran Anda',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        '${_history.length} masukan',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loadingHistory)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_history.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Belum ada riwayat saran yang Anda kirim. Saran yang Anda kirim akan muncul di sini beserta tanggapan dari Admin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                      ),
                    )
                  else
                    for (final item in _history) _buildHistoryCard(item),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final id = item['id'] ?? '';
    final cat = (item['category'] ?? 'UX').toString();
    final msg = (item['message'] ?? '').toString();
    final status = (item['status'] ?? 'baru').toString().toLowerCase();
    final createdAt = (item['created_at'] ?? '').toString();
    final adminNote = (item['admin_note'] ?? '').toString().trim();
    final repliedBy = (item['replied_by'] ?? '').toString().trim();
    final repliedAt = (item['replied_at'] ?? '').toString().trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '#$id • $cat',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusBg(status),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _statusFg(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            msg,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            createdAt,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          if (adminNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.support_agent_rounded,
                        size: 15,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          repliedBy.isNotEmpty
                              ? 'Balasan Admin ($repliedBy)'
                              : 'Balasan Admin',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      if (repliedAt.isNotEmpty)
                        Text(
                          repliedAt,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adminNote,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
