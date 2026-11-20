import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/app_control_service.dart';

class ServiceBlockScreen extends StatelessWidget {
  const ServiceBlockScreen({
    super.key,
    required this.status,
    required this.onRetry,
    required this.checking,
  });

  final AppControlStatus status;
  final VoidCallback onRetry;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final isShutdown = status.isShutdown;
    final accent = isShutdown ? AppColors.rose : AppColors.amber;
    final badgeText = isShutdown
        ? 'PEMBERITAHUAN LAYANAN · NONAKTIF SEMENTARA'
        : 'PEMELIHARAAN SISTEM · MAINTENANCE';
    final titleText = isShutdown
        ? 'Layanan Sedang Tidak Tersedia'
        : 'Sedang Dalam Pemeliharaan';

    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.navyDeep,
              AppColors.navy,
              Color(0xFF1E1B4B),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 34,
                ),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: accent.withValues(alpha: 0.14),
                        border: Border.all(color: accent, width: 2),
                      ),
                      child: Icon(
                        isShutdown
                            ? Icons.gpp_bad_rounded
                            : Icons.build_circle_outlined,
                        color: accent,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        badgeText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      titleText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Layanan: ${status.serviceName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.auroraCyan,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      status.message.isNotEmpty
                          ? status.message
                          : (isShutdown
                              ? 'Mohon maaf, layanan ini sedang dinonaktifkan sementara oleh pengelola. Silakan coba kembali beberapa saat lagi.'
                              : 'Layanan sedang menjalani pemeliharaan rutin dan peningkatan performa. Silakan kembali beberapa saat lagi.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13.5,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
