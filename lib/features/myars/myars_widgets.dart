import 'package:flutter/material.dart';

/// Shared Aurora UI components for the MyArs & Absensi Online screens.
class MyArsHeroHeader extends StatelessWidget {
  const MyArsHeroHeader({
    super.key,
    required this.titleChip,
    required this.countLabel,
    this.title,
    this.subtitle,
    this.icon,
    this.iconAsset,
    this.bottomChild,
    this.extraAction,
  });

  final String titleChip;
  final String countLabel;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final String? iconAsset;
  final Widget? bottomChild;
  final Widget? extraAction;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.56, 1.0],
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF0284C7),
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Color(0x330F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _NavPillButton(
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  titleChip,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              const Spacer(),
              if (extraAction != null) ...[
                extraAction!,
                const SizedBox(width: 8),
              ],
              if (countLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF7DD3FC).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    countLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (title != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                if (icon != null || iconAsset != null) ...[
                  Container(
                    width: 52,
                    height: 52,
                    padding: iconAsset != null
                        ? const EdgeInsets.all(10)
                        : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: iconAsset != null
                        ? Image.asset(
                            iconAsset!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              icon ?? Icons.qr_code_2_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          )
                        : Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (bottomChild != null) ...[
            const SizedBox(height: 16),
            bottomChild!,
          ],
        ],
      ),
    );
  }
}

class _NavPillButton extends StatelessWidget {
  const _NavPillButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class MyArsStatusChip extends StatelessWidget {
  const MyArsStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isPresent = status == 'CheckIn';
    final bgColor =
        isPresent ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7);
    final fgColor =
        isPresent ? const Color(0xFF15803D) : const Color(0xFFB45309);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.isNotEmpty ? status : 'Hadir',
        style: TextStyle(
          color: fgColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class MyArsEmptyCard extends StatelessWidget {
  const MyArsEmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: const Color(0xFF1D4ED8), size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class MyArsLoadingCard extends StatelessWidget {
  const MyArsLoadingCard({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
