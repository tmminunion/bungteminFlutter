import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../services/inbox_service.dart';

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
                  ? const Center(
                      child: Text(
                        'Belum ada pesan broadcast di kotak masuk.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _items.length,
                        itemBuilder: (_, idx) {
                          final item = _items[idx];
                          final (catLabel, catColor, catIcon) = _catMeta(item.category);
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: item.isRead
                                    ? const Color(0xFFE2E8F0)
                                    : catColor.withValues(alpha: 0.45),
                                width: item.isRead ? 1 : 1.5,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => BroadcastInboxDetailScreen(item: item),
                                  ),
                                );
                                _load();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: catColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(catIcon, size: 13, color: catColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                catLabel,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: catColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        if (!item.isRead)
                                          Container(
                                            width: 9,
                                            height: 9,
                                            decoration: BoxDecoration(
                                              color: catColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        if (item.isConfirmed || item.hasSubmitted)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 6),
                                            child: Icon(Icons.check_circle_rounded,
                                                size: 16, color: Color(0xFF059669)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: item.isRead
                                            ? FontWeight.w600
                                            : FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (item.body.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        item.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      '${item.createdByName} • ${item.createdAt}',
                                      style: const TextStyle(
                                          fontSize: 11, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
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

  Future<void> _openAttachment() async {
    final uri = Uri.tryParse(widget.item.attachmentUrl.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text('Detail Pesan', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Dari: ${item.createdByName} • ${item.createdAt}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                if (item.body.isNotEmpty) ...[
                  const Divider(height: 22),
                  SelectableText(
                    item.body,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
                if (item.attachmentUrl.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _openAttachment,
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
                ],
              ],
            ),
          ),
          if (hasConfirmBtn && !hasForm) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _confirmed
                      ? const Color(0xFF059669)
                      : AppColors.navy,
                ),
                onPressed: (_submitting || _confirmed) ? null : _confirmAction,
                icon: Icon(
                  _confirmed ? Icons.check_circle_rounded : Icons.touch_app_rounded,
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
          ],
          if (hasForm) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                              fontSize: 15, fontWeight: FontWeight.w800),
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
                      ),
                      onPressed: _submitting ? null : _submitForm,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        _submitting
                            ? 'Mengirim...'
                            : (_submitted ? 'Perbarui Jawaban' : 'Kirim Jawaban'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
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
