import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/cached_image.dart';
import '../../core/theme.dart';
import '../../models/news_item.dart';
import '../../services/app_analytics_service.dart';
import '../about/contact_screen.dart';

class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({super.key, required this.item});

  final NewsItem item;

  Future<void> _shareToWhatsApp() async {
    final link = item.linkUrl.isNotEmpty ? item.linkUrl : 'https://bungtemin.net/news';
    final text = '*${item.title}*\n\nBaca selengkapnya di Bungtemin:\n$link';
    final waUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    await launchUrl(waUri, mode: LaunchMode.externalApplication);
  }

  void _copyLink(BuildContext context) {
    final target = item.linkUrl.isNotEmpty ? item.linkUrl : item.title;
    Clipboard.setData(ClipboardData(text: target));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tautan berita disalin ke clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badgeText =
        item.isInternal ? 'BERITA INTERNAL RESMI' : 'KABAR EKSTERNAL';
    final badgeColor =
        item.isInternal ? AppColors.primaryBlue : AppColors.indigo;

    return ScreenViewTracker(
      onTrack: () => AppAnalyticsService.instance.trackNews(item),
      child: Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppColors.navy,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: AppColors.navy.withValues(alpha: 0.65),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: CircleAvatar(
                  backgroundColor: const Color(0xCC16A34A),
                  child: IconButton(
                    icon: const Icon(
                      Icons.share_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    tooltip: 'Bagikan ke WhatsApp',
                    onPressed: _shareToWhatsApp,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: CircleAvatar(
                  backgroundColor: AppColors.navy.withValues(alpha: 0.65),
                  child: IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    tooltip: 'Salin Tautan',
                    onPressed: () => _copyLink(context),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.imageUrl.isNotEmpty)
                    BungteminCachedImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 1080,
                      placeholder: _FallbackNewsHero(
                        isInternal: item.isInternal,
                      ),
                      errorWidget: _FallbackNewsHero(
                        isInternal: item.isInternal,
                      ),
                    )
                  else
                    _FallbackNewsHero(isInternal: item.isInternal),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.navy.withValues(alpha: 0.45),
                          Colors.transparent,
                          AppColors.navy.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Image.asset(
                            item.isInternal
                                ? 'assets/img/appicon.png'
                                : 'assets/icon/1.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.isInternal
                                    ? 'Redaksi Bungtemin • Timedia'
                                    : 'Informasi Ketenagakerjaan',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.displayDate,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                    ),
                    SelectableText(
                      item.plainBody.isNotEmpty
                          ? item.plainBody
                          : 'Konten berita tidak tersedia.',
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.7,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                item.isInternal
                                    ? Icons.verified_user_outlined
                                    : Icons.public_rounded,
                                color: badgeColor,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.isInternal
                                      ? 'Penerbit: Redaksi Timedia PUK SP LEM SPSI PT. TMMIN'
                                      : 'Sumber: ${Uri.tryParse(item.linkUrl)?.host ?? 'Berita Eksternal Terpercaya'}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navySoft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (item.linkUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                final uri = Uri.tryParse(item.linkUrl);
                                if (uri != null) {
                                  launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Text(
                                item.linkUrl,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryBlue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ContactScreen(),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.support_agent_rounded, size: 16),
                              label: const Text(
                                'Hubungi Redaksi / Contact Us',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _FallbackNewsHero extends StatelessWidget {
  const _FallbackNewsHero({required this.isInternal});

  final bool isInternal;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isInternal
              ? const [AppColors.navy, AppColors.primaryBlue]
              : const [AppColors.navy, AppColors.indigo],
        ),
      ),
      child: Center(
        child: Image.asset(
          'assets/icon/1.png',
          width: 72,
          height: 72,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
