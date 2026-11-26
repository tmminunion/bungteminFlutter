import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/screen_security.dart';
import '../../core/theme.dart';
import '../../services/inbox_service.dart';
import '../survey/survey_screen.dart';

class BroadcastInboxScreen extends StatefulWidget {
  const BroadcastInboxScreen({super.key});

  @override
  State<BroadcastInboxScreen> createState() => _BroadcastInboxScreenState();
}

class _BroadcastInboxScreenState extends State<BroadcastInboxScreen> {
  final _service = InboxService();
  bool _loading = true;
  String? _error;
  List<BroadcastInboxItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _service.fetchList();
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _deleteItem(BroadcastInboxItem item) async {
    if (!item.allowDelete) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pesan?'),
        content: Text('Hapus "${item.title}" dari kotak masuk Anda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.deleteMessage(item.id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((e) => e.id != item.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesan berhasil dihapus.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  (String, Color, IconData) _catMeta(String cat) {
    switch (cat.toLowerCase()) {
      case 'pdf':
        return ('PDF', const Color(0xFFDC2626), Icons.picture_as_pdf_rounded);
      case 'link':
        return ('Tautan', const Color(0xFF0284C7), Icons.link_rounded);
      case 'konfirmasi':
        return ('Konfirmasi', const Color(0xFF059669), Icons.task_alt_rounded);
      case 'form':
        return ('Form Isian', const Color(0xFF7C3AED), Icons.assignment_rounded);
      default:
        return ('Pengumuman', const Color(0xFF0F766E), Icons.campaign_rounded);
    }
  }

  String _plainPreview(String raw) {
    return raw
        .replaceAll(
          RegExp(r'<(head|style|script)\b[^>]*>[\s\S]*?</\1>', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'&nbsp;|&#160;', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'&amp;', caseSensitive: false), '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'Kotak Masuk Bungtemin',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: 'Form & Survey',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SurveyListScreen()),
            ),
            icon: const Icon(Icons.assignment_outlined),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Coba Lagi')),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: AppColors.navy.withValues(alpha: 0.07),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.mark_email_read_outlined,
                                size: 34,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Kotak Masuk Kosong',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Belum ada pesan broadcast di kotak masuk Anda.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                        itemCount: _items.length,
                        itemBuilder: (_, idx) {
                          final item = _items[idx];
                          final (catLabel, catColor, catIcon) = _catMeta(item.category);
                          final preview = _plainPreview(item.body);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: item.isRead
                                  ? Colors.white
                                  : Color.alphaBlend(
                                      catColor.withValues(alpha: 0.035),
                                      Colors.white,
                                    ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: item.isRead
                                    ? const Color(0xFFE2E8F0)
                                    : catColor.withValues(alpha: 0.45),
                                width: item.isRead ? 1 : 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: item.isRead ? 0.03 : 0.07),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => BroadcastInboxDetailScreen(item: item),
                                    ),
                                  );
                                  _load();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 9, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: catColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(catIcon, size: 13, color: catColor),
                                                const SizedBox(width: 5),
                                                Text(
                                                  catLabel,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: catColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (item.preventScreenshot)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 6),
                                              child: Tooltip(
                                                message: 'Dilindungi Anti-Screenshot',
                                                child: Icon(
                                                  Icons.shield_outlined,
                                                  size: 15,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          const Spacer(),
                                          if (!item.isRead)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: catColor,
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                'BARU',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          if (item.isConfirmed || item.hasSubmitted)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 6),
                                              child: Icon(Icons.check_circle_rounded,
                                                  size: 17, color: Color(0xFF059669)),
                                            ),
                                          if (item.allowDelete)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 6),
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(16),
                                                onTap: () => _deleteItem(item),
                                                child: Container(
                                                  padding: const EdgeInsets.all(5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEE2E2)
                                                        .withValues(alpha: 0.7),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.delete_outline_rounded,
                                                    size: 16,
                                                    color: Color(0xFFDC2626),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          height: 1.28,
                                          fontWeight: item.isRead
                                              ? FontWeight.w700
                                              : FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (preview.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          preview,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            height: 1.4,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.person_outline_rounded,
                                            size: 13,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item.createdByName,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            item.createdAt,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: Color(0xFF94A3B8),
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
                        },
                      ),
                    ),
    );
  }
}

class BroadcastInboxDetailScreen extends StatefulWidget {
  const BroadcastInboxDetailScreen({super.key, required this.item});

  final BroadcastInboxItem item;

  @override
  State<BroadcastInboxDetailScreen> createState() =>
      _BroadcastInboxDetailScreenState();
}

class _BroadcastInboxDetailScreenState
    extends State<BroadcastInboxDetailScreen> {
  final _service = InboxService();
  final Map<String, TextEditingController> _textCtrls = {};
  final Map<String, dynamic> _answers = {};
  bool _submitting = false;
  late bool _confirmed;
  late bool _submitted;

  @override
  void initState() {
    super.initState();
    if (widget.item.preventScreenshot) {
      ScreenSecurity.enable();
    }
    _confirmed = widget.item.isConfirmed;
    _submitted = widget.item.hasSubmitted;
    if (widget.item.answers != null) {
      _answers.addAll(widget.item.answers!);
    }
    for (final f in widget.item.formSchema) {
      if (f.type == 'text' ||
          f.type == 'textarea' ||
          f.type == 'number' ||
          f.type == 'date') {
        _textCtrls[f.key] = TextEditingController(
          text: (_answers[f.key] ?? '').toString(),
        );
      }
    }
    if (!widget.item.isRead) {
      _service.markRead(widget.item.id);
    }
  }

  @override
  void dispose() {
    if (widget.item.preventScreenshot) {
      ScreenSecurity.disable();
    }
    for (final c in _textCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
      ),
    );
  }

  Future<void> _openUrl(String raw) async {
    final trimmed = raw.trim();
    final surveyMatch = RegExp(r'/survey/([a-zA-Z0-9_-]+)', caseSensitive: false).firstMatch(trimmed);
    if (surveyMatch != null && mounted) {
      final slug = surveyMatch.group(1)!;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SurveyFormScreen(slug: slug)),
      );
      return;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _looksLikeHtml(String s) {
    return RegExp(
      r'<(!doctype|html|head|body|div|p|br|table|tr|td|h[1-6]|ul|ol|li|img|strong|b|em|a|span|section|header)\b',
      caseSensitive: false,
    ).hasMatch(s);
  }

  /// Ekstrak konten dalam <body> dan bersihkan <head>/<style>/MSO comment
  /// agar dokumen HTML penuh dari Mail Studio / BEE ter-render bersih oleh HtmlWidget.
  String _prepareHtmlForWidget(String raw) {
    var html = raw;
    final bodyMatch = RegExp(
      r'<body\b[^>]*>([\s\S]*?)</body>',
      caseSensitive: false,
    ).firstMatch(html);
    if (bodyMatch != null) {
      html = bodyMatch.group(1) ?? html;
    }
    html = html
        .replaceAll(
          RegExp(r'<(head|style|script|meta|title)\b[^>]*>[\s\S]*?</\1>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<!doctype[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    return html.trim();
  }

  bool _isImageUrl(String url) {
    final l = url.toLowerCase();
    return l.endsWith('.jpg') ||
        l.endsWith('.jpeg') ||
        l.endsWith('.png') ||
        l.endsWith('.webp') ||
        l.endsWith('.gif');
  }

  Future<void> _confirmAction() async {
    setState(() => _submitting = true);
    try {
      final msg = await _service.submitResponse(id: widget.item.id, confirm: true);
      if (!mounted) return;
      setState(() => _confirmed = true);
      _snack(msg);
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitForm() async {
    final payload = <String, dynamic>{..._answers};
    for (final e in _textCtrls.entries) {
      payload[e.key] = e.value.text.trim();
    }
    for (final f in widget.item.formSchema) {
      if (!f.required) continue;
      final v = payload[f.key];
      final empty = v == null ||
          (v is String && v.trim().isEmpty) ||
          (v is List && v.isEmpty);
      if (empty) {
        _snack('Field "${f.label}" wajib diisi.', isError: true);
        return;
      }
    }
    setState(() => _submitting = true);
    try {
      final msg = await _service.submitResponse(
        id: widget.item.id,
        confirm: true,
        answers: payload,
      );
      if (!mounted) return;
      setState(() {
        _confirmed = true;
        _submitted = true;
      });
      _snack(msg);
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasConfirmBtn =
        item.actionLabel.isNotEmpty || item.category == 'konfirmasi';
    final hasForm = item.formSchema.isNotEmpty;
    final isHtml = _looksLikeHtml(item.body);
    final isImgAtt =
        item.attachmentUrl.isNotEmpty && _isImageUrl(item.attachmentUrl);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        title: const Text(
          'Detail Inbox',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          if (item.allowDelete)
            IconButton(
              tooltip: 'Hapus Pesan',
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus Pesan?'),
                    content: Text('Hapus "${item.title}" dari kotak masuk Anda?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );
                if (ok != true || !mounted) return;
                try {
                  await _service.deleteMessage(item.id);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                } catch (e) {
                  _snack('$e'.replaceFirst('Exception: ', ''), isError: true);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header Email-style
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'From: ${item.createdByName}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.createdAt,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Konten Newsletter / HTML / Template Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isHtml)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0B3B8C), Color(0xFF0F766E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'PUK SP LEM SPSI\nPT. TMMIN | BUNGTEMIN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item.category.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF0B3B8C),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isImgAtt)
                  Image.network(
                    item.attachmentUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                if (item.body.isNotEmpty)
                  Padding(
                    padding: isHtml
                        ? const EdgeInsets.all(14)
                        : const EdgeInsets.fromLTRB(18, 18, 18, 20),
                    child: isHtml
                        ? HtmlWidget(
                            _prepareHtmlForWidget(item.body),
                            onTapUrl: (url) {
                              _openUrl(url);
                              return true;
                            },
                            textStyle: const TextStyle(
                              fontSize: 14,
                              height: 1.55,
                              color: Color(0xFF1E293B),
                            ),
                          )
                        : SelectableText(
                            item.body,
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.6,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                  ),
                if (item.attachmentUrl.isNotEmpty && !isImgAtt)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _openUrl(item.attachmentUrl),
                        icon: Icon(
                          item.category == 'pdf'
                              ? Icons.picture_as_pdf_rounded
                              : Icons.open_in_new_rounded,
                        ),
                        label: Text(
                          item.attachmentLabel.isNotEmpty
                              ? item.attachmentLabel
                              : (item.category == 'pdf'
                                  ? 'Buka Dokumen PDF'
                                  : 'Buka Tautan'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (hasConfirmBtn && !hasForm)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _confirmed
                        ? const Color(0xFF059669)
                        : AppColors.navy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: (_submitting || _confirmed) ? null : _confirmAction,
                  icon: Icon(
                    _confirmed
                        ? Icons.check_circle_rounded
                        : Icons.touch_app_rounded,
                  ),
                  label: Text(
                    _confirmed
                        ? 'Sudah Dikonfirmasi'
                        : (item.actionLabel.isNotEmpty
                            ? item.actionLabel
                            : 'Konfirmasi'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),

          if (hasForm)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Formulir Isian',
                          style: TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (_submitted)
                        const Chip(
                          label: Text('Terkirim',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF059669))),
                          backgroundColor: Color(0xFFECFDF5),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final f in item.formSchema) _buildDynamicField(f),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _submitting ? null : _submitForm,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        _submitting
                            ? 'Mengirim...'
                            : (_submitted
                                ? 'Perbarui Jawaban'
                                : 'Kirim Jawaban'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDynamicField(BroadcastInboxField f) {
    final reqMark = f.required ? ' *' : '';
    if (f.type == 'select') {
      final cur = _answers[f.key]?.toString();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          initialValue: f.options.contains(cur) ? cur : null,
          decoration: InputDecoration(
            labelText: '${f.label}$reqMark',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final opt in f.options)
              DropdownMenuItem(value: opt, child: Text(opt)),
          ],
          onChanged: (v) => setState(() => _answers[f.key] = v),
        ),
      );
    }
    if (f.type == 'radio') {
      final cur = _answers[f.key]?.toString();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${f.label}$reqMark',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            for (final opt in f.options)
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(opt, style: const TextStyle(fontSize: 13)),
                value: opt,
                groupValue: cur,
                onChanged: (v) => setState(() => _answers[f.key] = v),
              ),
          ],
        ),
      );
    }
    if (f.type == 'checkbox') {
      final list = (_answers[f.key] is List)
          ? List<String>.from((_answers[f.key] as List).map((e) => e.toString()))
          : <String>[];
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${f.label}$reqMark',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            for (final opt in f.options)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(opt, style: const TextStyle(fontSize: 13)),
                value: list.contains(opt),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      if (!list.contains(opt)) list.add(opt);
                    } else {
                      list.remove(opt);
                    }
                    _answers[f.key] = list;
                  });
                },
              ),
          ],
        ),
      );
    }
    if (f.type == 'date') {
      final ctrl = _textCtrls[f.key]!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: ctrl,
          readOnly: true,
          decoration: InputDecoration(
            labelText: '${f.label}$reqMark',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              final s =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              setState(() => ctrl.text = s);
            }
          },
        ),
      );
    }

    final ctrl = _textCtrls[f.key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        maxLines: f.type == 'textarea' ? 4 : 1,
        keyboardType: f.type == 'number' ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: '${f.label}$reqMark',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
