import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/cached_image.dart';

class PromoModalHelper {
  PromoModalHelper._();

  static const _kHidePromoKey = 'bt_hide_promo_today';

  static String _todayString() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  static Future<bool> isHiddenToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kHidePromoKey) == _todayString();
    } catch (_) {
      return false;
    }
  }

  static Future<void> hideForToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kHidePromoKey, _todayString());
    } catch (_) {}
  }

  static Future<void> showUpdateDialog(
    BuildContext context, {
    required Map<String, dynamic> updateInfo,
  }) async {
    final title = (updateInfo['title'] ?? 'Update Aplikasi Tersedia')
        .toString()
        .trim();
    final message = (updateInfo['message'] ??
            'Versi terbaru Bungtemin tersedia di Google Play Store.')
        .toString()
        .trim();
    final latestVer = (updateInfo['latest_version'] ?? '').toString().trim();
    final latestBuild =
        int.tryParse((updateInfo['latest_build'] ?? '0').toString()) ?? 0;
    final playUrl = (updateInfo['play_store_url'] ??
            'https://play.google.com/store/apps/details?id=com.bung.teminapps')
        .toString()
        .trim();
    final forceUpdate = updateInfo['force_update'] == true;

    await showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Versi terpasang: ${AppInfo.displayVersion}\nVersi terbaru: v$latestVer ($latestBuild)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Nanti'),
              ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
              ),
              onPressed: () {
                final uri = Uri.tryParse(playUrl);
                if (uri != null) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                if (!forceUpdate && ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              icon: const Icon(Icons.shop_rounded, size: 18),
              label: const Text('Update di Play Store'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> adsData,
    required ValueChanged<String> onInternalRoute,
  }) async {
    await showMulti(
      context,
      promos: [adsData],
      onInternalRoute: onInternalRoute,
    );
  }

  static Future<void> showMulti(
    BuildContext context, {
    required List<Map<String, dynamic>> promos,
    required ValueChanged<String> onInternalRoute,
  }) async {
    final valid = promos.where((adsData) {
      final title = (adsData['title'] ?? '').toString().trim();
      final desc = (adsData['desc'] ?? '').toString().trim();
      final image = (adsData['image'] ?? '').toString().trim();
      return title.isNotEmpty || desc.isNotEmpty || image.isNotEmpty;
    }).toList();

    if (valid.isEmpty) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xC2050914),
      builder: (ctx) => _MultiPromoDialog(
        promos: valid,
        onInternalRoute: onInternalRoute,
      ),
    );
  }
}

class _MultiPromoDialog extends StatefulWidget {
  const _MultiPromoDialog({
    required this.promos,
    required this.onInternalRoute,
  });

  final List<Map<String, dynamic>> promos;
  final ValueChanged<String> onInternalRoute;

  @override
  State<_MultiPromoDialog> createState() => _MultiPromoDialogState();
}

class _MultiPromoDialogState extends State<_MultiPromoDialog> {
  final _pageCtrl = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _handleAction(Map<String, dynamic> adsData) {
    final actionType =
        (adsData['actionType'] ?? 'internal').toString().toLowerCase().trim();
    final link = (adsData['link'] ?? '/news').toString().trim();
    final externalUrl = (adsData['externalUrl'] ?? '').toString().trim();

    Navigator.pop(context);
    if (actionType == 'external' && externalUrl.startsWith('http')) {
      launchUrl(
        Uri.parse(externalUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      widget.onInternalRoute(link);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.promos.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (count > 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Promo ${_index + 1} / $count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              Material(
                color: Colors.white.withValues(alpha: 0.16),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 490,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: count,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final adsData = widget.promos[i];
                final title = (adsData['title'] ?? '').toString().trim();
                final desc = (adsData['desc'] ?? '').toString().trim();
                final image = (adsData['image'] ?? '').toString().trim();

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (image.isNotEmpty)
                        GestureDetector(
                          onTap: () => _handleAction(adsData),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 310),
                            child: BungteminCachedImage(
                              imageUrl: image,
                              fit: BoxFit.contain,
                              memCacheWidth: 1080,
                              placeholder: const SizedBox(
                                height: 180,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF38BDF8),
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      if (title.isNotEmpty || desc.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                          decoration: BoxDecoration(
                            color: const Color(0xB80B132B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Column(
                            children: [
                              if (title.isNotEmpty)
                                Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                  ),
                                ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  desc,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFE2E8F0),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 11),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () => _handleAction(adsData),
                                  child: const Text(
                                    'Lihat Info',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: () => _handleAction(adsData),
                          child: const Text(
                            'Lihat Info',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          if (count > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < count; i++)
                  Container(
                    width: i == _index ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _index
                          ? const Color(0xFF38BDF8)
                          : Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          TextButton(
            onPressed: () async {
              await PromoModalHelper.hideForToday();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(
              'Jangan tampilkan lagi hari ini',
              style: TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
