import 'package:flutter/material.dart';
import '../../core/screen_security.dart';
import '../../core/theme.dart';

class KeuanganScreen extends StatefulWidget {
  const KeuanganScreen({super.key});

  @override
  State<KeuanganScreen> createState() => _KeuanganScreenState();
}

class _KeuanganScreenState extends State<KeuanganScreen> {
  @override
  void initState() {
    super.initState();
    ScreenSecurity.enable();
  }

  @override
  void dispose() {
    ScreenSecurity.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Transparansi Keuangan',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.navy, AppColors.navySoft],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Image.asset(
                    'assets/icon/5.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.gold,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'COMING SOON',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Laporan Keuangan Organisasi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Halaman transparansi laporan kas, realisasi anggaran, dan audit keuangan PUK SP LEM SPSI PT. TMMIN sedang dalam tahap pengembangan untuk integrasi langsung dengan portal Bungtemin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text(
                      'Kembali ke Beranda',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
