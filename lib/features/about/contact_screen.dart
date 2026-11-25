import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/theme.dart';
import 'feedback_screen.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  static const String officialEmail = 'sekretariat@bungtemin.net';
  static const String feedbackEmail = 'bungtemin@gmail.com';
  static const String officialWaNumber = '6281315881071';
  static const String officialContactUrl = 'https://bungtemin.net/contact';
  static const String officialNewsUrl = 'https://bungtemin.net/news';
  static const String officialAddress =
      'Jl. Laks. Yos Sudarso, Sunter II, Jakarta Utara 14330, Indonesia';

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
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

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label disalin ke clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'Hubungi Kami',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.navy, AppColors.navyMid],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.asset('assets/img/appicon.png'),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bung Temin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Portal Berita & Layanan Anggota\nPUK SP LEM SPSI PT. TMMIN\nVersi ${AppInfo.displayVersion}',
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Informasi Kontak Resmi (Official Contact)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          _ContactTile(
            icon: Icons.email_outlined,
            color: AppColors.primaryBlue,
            label: 'Email Redaksi & Pengembang',
            value: ContactScreen.officialEmail,
            onTap: () => _launch('mailto:${ContactScreen.officialEmail}'),
            onCopy: () => _copy('Email', ContactScreen.officialEmail),
          ),
          const SizedBox(height: 10),
          _ContactTile(
            icon: Icons.language_rounded,
            color: AppColors.indigo,
            label: 'Halaman Kontak Website (Contact Us)',
            value: ContactScreen.officialContactUrl,
            onTap: () => _launch(ContactScreen.officialContactUrl),
            onCopy: () => _copy('URL Kontak', ContactScreen.officialContactUrl),
          ),
          const SizedBox(height: 10),
          _ContactTile(
            icon: Icons.newspaper_rounded,
            color: AppColors.navySoft,
            label: 'Portal Berita Resmi',
            value: ContactScreen.officialNewsUrl,
            onTap: () => _launch(ContactScreen.officialNewsUrl),
            onCopy: () => _copy('URL Berita', ContactScreen.officialNewsUrl),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: AppColors.primaryBlue,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Alamat Sekretariat',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Sekretariat PUK SP LEM SPSI PT. TMMIN\n${ContactScreen.officialAddress}',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: Color(0xFF334155),
                  ),
                ),
                SizedBox(height: 12),
                Divider(height: 1, color: Color(0xFFE2E8F0)),
                SizedBox(height: 12),
                Text(
                  'Transparansi Sumber Berita',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Berita internal diterbitkan langsung oleh Redaksi Timedia PUK SP LEM SPSI PT. TMMIN. Berita eksternal selalu mencantumkan keterangan sumber dan tautan penerbit aslinya.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FeedbackScreen()),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.rate_review_outlined, size: 19),
            label: const Text(
              'Beri Saran & Masukan Aplikasi',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onCopy,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: AppColors.muted,
                tooltip: 'Salin',
                onPressed: onCopy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
