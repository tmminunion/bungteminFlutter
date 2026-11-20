import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({
    super.key,
    required this.onComplete,
  });

  final VoidCallback onComplete;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _pageCtrl = PageController();
  int _currentIndex = 0;

  static const _slides = [
    _TutorialSlideData(
      stepLabel: '01 · SELAMAT DATANG',
      titlePrefix: 'Selamat Datang di ',
      titleHighlight: 'Bungtemin App',
      description:
          'Aplikasi resmi informasi, layanan anggota, dan aktivitas serikat pekerja dalam satu genggaman digital.',
      imageAsset: 'assets/img/ica-slidebox-img-1.png',
      isFinal: false,
    ),
    _TutorialSlideData(
      stepLabel: '02 · PLATFORM DIGITAL',
      titlePrefix: 'Apa itu ',
      titleHighlight: 'Bungtemin?',
      description:
          'Bungtemin adalah layanan digital di bawah AKO Timedia yang menghadirkan informasi serikat secara cepat, transparan, dan real-time.',
      imageAsset: 'assets/img/ica-slidebox-img-3.png',
      isFinal: false,
    ),
    _TutorialSlideData(
      stepLabel: '03 · FITUR LENGKAP',
      titlePrefix: 'Ekosistem ',
      titleHighlight: 'Terpadu',
      description:
          'Akses berita internal & eksternal, KTA digital 3D, program kerja, ruang pintar, pengaduan anggota, hingga kalender kegiatan.',
      imageAsset: 'assets/img/ica-slidebox-img-2.png',
      isFinal: false,
    ),
    _TutorialSlideData(
      stepLabel: '04 · SIAP DIGUNAKAN',
      titlePrefix: 'Mulai ',
      titleHighlight: 'Jelajahi Sekarang',
      description:
          'Semua informasi penting anggota kini tersinkronisasi otomatis. Yuk masuk ke halaman utama Bungtemin tanpa perlu login dulu!',
      imageAsset: 'assets/img/ica-slidebox-img-4.png',
      isFinal: true,
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _nextSlide() {
    if (_currentIndex < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentIndex == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: Stack(
        children: [
          // Aurora gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.navy,
                  AppColors.navyMid,
                  AppColors.navyDeep,
                ],
              ),
            ),
          ),
          // Glowing aurora orbs
          Positioned(
            top: -70,
            right: -70,
            child: _AuroraOrb(
              size: 250,
              color: AppColors.auroraCyan.withValues(alpha: 0.28),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -80,
            child: _AuroraOrb(
              size: 270,
              color: AppColors.auroraIndigo.withValues(alpha: 0.30),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.asset(
                              'assets/img/appicon.png',
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Bungtemin',
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (!isLast)
                        TextButton.icon(
                          onPressed: widget.onComplete,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF7DD3FC),
                          ),
                          icon: const Text(
                            'Lewati',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          label: const Icon(Icons.arrow_forward_rounded, size: 17),
                        )
                      else
                        const SizedBox(height: 40),
                    ],
                  ),
                ),

                // Slides
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _slides.length,
                    onPageChanged: (idx) => setState(() => _currentIndex = idx),
                    itemBuilder: (context, idx) {
                      final slide = _slides[idx];
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxHeight < 520;
                          final heroSize = compact ? 150.0 : 210.0;
                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 8,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight - 16,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Hero visual with cyan glow
                                  SizedBox(
                                    width: heroSize,
                                    height: heroSize,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: heroSize * 0.78,
                                          height: heroSize * 0.78,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.auroraCyan
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 48,
                                                spreadRadius: 8,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Image.asset(
                                          slide.imageAsset,
                                          fit: BoxFit.contain,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: compact ? 14 : 22),
                                  Text(
                                    slide.stepLabel,
                                    style: const TextStyle(
                                      color: Color(0xFF7DD3FC),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: compact ? 22 : 25,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFF8FAFC),
                                        height: 1.25,
                                      ),
                                      children: [
                                        TextSpan(text: slide.titlePrefix),
                                        TextSpan(
                                          text: slide.titleHighlight,
                                          style: const TextStyle(
                                            color: AppColors.auroraCyan,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 340,
                                    ),
                                    child: Text(
                                      slide.description,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.55,
                                        color: const Color(0xFFE2E8F0)
                                            .withValues(alpha: 0.86),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: compact ? 18 : 28),
                                  _AuroraActionButton(
                                    label: slide.isFinal
                                        ? 'Masuk ke Beranda'
                                        : 'Lanjut',
                                    icon: slide.isFinal
                                        ? Icons.rocket_launch_rounded
                                        : Icons.arrow_forward_rounded,
                                    isFinal: slide.isFinal,
                                    onTap: _nextSlide,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Dots Indicator
                Padding(
                  padding: const EdgeInsets.only(bottom: 24, top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.auroraCyan
                              : Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialSlideData {
  const _TutorialSlideData({
    required this.stepLabel,
    required this.titlePrefix,
    required this.titleHighlight,
    required this.description,
    required this.imageAsset,
    required this.isFinal,
  });

  final String stepLabel;
  final String titlePrefix;
  final String titleHighlight;
  final String description;
  final String imageAsset;
  final bool isFinal;
}

class _AuroraOrb extends StatelessWidget {
  const _AuroraOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _AuroraActionButton extends StatelessWidget {
  const _AuroraActionButton({
    required this.label,
    required this.icon,
    required this.isFinal,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isFinal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: isFinal
                  ? const [AppColors.emerald, AppColors.primaryBlue]
                  : const [AppColors.auroraCyan, AppColors.primaryBlue],
            ),
            boxShadow: [
              BoxShadow(
                color: (isFinal ? AppColors.emerald : AppColors.auroraCyan)
                    .withValues(alpha: 0.36),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: Colors.white, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}
