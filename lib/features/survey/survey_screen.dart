import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/session_store.dart';
import '../../services/survey_service.dart';

Color _parseSurveyColor(String hex, Color fallback) {
  final clean = hex.replaceAll('#', '').trim();
  if (clean.length == 6) {
    final val = int.tryParse('FF$clean', radix: 16);
    if (val != null) return Color(val);
  }
  return fallback;
}

class SurveyListScreen extends StatefulWidget {
  const SurveyListScreen({super.key});

  @override
  State<SurveyListScreen> createState() => _SurveyListScreenState();
}

class _SurveyListScreenState extends State<SurveyListScreen> {
  bool _loading = true;
  String? _error;
  List<SurveySummary> _items = const [];

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
      final list = await SurveyService.instance.fetchSurveys();
      if (!mounted) return;
      setState(() {
        _items = list;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'Form & Survey Bungtemin',
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
                        const Icon(Icons.cloud_off_rounded, size: 42, color: AppColors.muted),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada form atau survey aktif saat ini.',
                        style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _items.length,
                        itemBuilder: (_, idx) {
                          final s = _items[idx];
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SurveyFormScreen(slug: s.slug, initialTitle: s.title),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Builder(builder: (_) {
                                      final accent = _parseSurveyColor(s.accentColor, AppColors.primaryBlue);
                                      return Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: s.iconUrl.isNotEmpty
                                            ? Image.network(
                                                s.iconUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Icon(Icons.assignment_rounded, color: accent),
                                              )
                                            : Icon(Icons.assignment_rounded, color: accent),
                                      );
                                    }),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.title,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.navy,
                                            ),
                                          ),
                                          if (s.description.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              s.description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.emerald.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  '${s.questionCount} Pertanyaan',
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.emerald,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${s.responseCount} responden',
                                                style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
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

class SurveyFormScreen extends StatefulWidget {
  const SurveyFormScreen({
    super.key,
    required this.slug,
    this.initialTitle,
  });

  final String slug;
  final String? initialTitle;

  @override
  State<SurveyFormScreen> createState() => _SurveyFormScreenState();
}

class _SurveyFormScreenState extends State<SurveyFormScreen> {
  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;
  String? _userLabel;
  SurveyDetail? _detail;

  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _textCtrls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _textCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await SessionStore().load();
      final detail = await SurveyService.instance.fetchSurveyBySlug(widget.slug);
      if (!mounted) return;
      for (final c in _textCtrls.values) {
        c.dispose();
      }
      _textCtrls.clear();
      _answers.clear();
      for (final f in detail.fields) {
        if (f.type == 'text' || f.type == 'textarea' || f.type == 'number' || f.type == 'date') {
          _textCtrls[f.key] = TextEditingController();
        }
      }
      setState(() {
        _detail = detail;
        _userLabel = session != null
            ? '${session.nama} • ${SessionStore.formatNoreg8(session.noreg)}'
            : null;
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

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? const Color(0xFFDC2626) : AppColors.emerald,
      ),
    );
  }

  Future<void> _submit() async {
    final detail = _detail;
    if (detail == null || _submitting) return;

    final payload = <String, dynamic>{..._answers};
    for (final e in _textCtrls.entries) {
      payload[e.key] = e.value.text.trim();
    }

    for (final f in detail.fields) {
      if (!f.required) continue;
      final v = payload[f.key];
      final empty = v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty);
      if (empty) {
        _snack('Pertanyaan "${f.label}" wajib diisi.', isError: true);
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final msg = await SurveyService.instance.submitSurvey(
        surveyId: detail.surveyId,
        answer: payload,
      );
      if (!mounted) return;
      setState(() => _submitted = true);
      _snack(msg);
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildField(SurveyField f, int idx) {
    final title = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            '${idx + 1}. ${f.label}${f.required ? ' *' : ''}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.navy),
          ),
        ),
      ],
    );

    Widget input;
    if (f.type == 'textarea') {
      input = TextField(
        controller: _textCtrls[f.key],
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Tulis jawaban Anda...',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (f.type == 'date') {
      final ctrl = _textCtrls[f.key]!;
      input = TextField(
        controller: ctrl,
        readOnly: true,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
          );
          if (picked != null) {
            ctrl.text =
                '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          }
        },
        decoration: InputDecoration(
          hintText: 'Pilih tanggal...',
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (f.type == 'select') {
      final cur = _answers[f.key]?.toString();
      input = DropdownButtonFormField<String>(
        initialValue: f.options.contains(cur) ? cur : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        hint: const Text('-- Pilih salah satu --'),
        items: f.options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: (v) => setState(() => _answers[f.key] = v),
      );
    } else if (f.type == 'radio') {
      final cur = _answers[f.key]?.toString();
      input = Column(
        children: f.options.map((o) {
          final selected = cur == o;
          return InkWell(
            onTap: () => setState(() => _answers[f.key] = o),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryBlue.withValues(alpha: 0.08) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppColors.primaryBlue : const Color(0xFFCBD5E1),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 19,
                    color: selected ? AppColors.primaryBlue : AppColors.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(o, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          );
        }).toList(),
      );
    } else if (f.type == 'checkbox') {
      final selectedSet = <String>{
        ...((_answers[f.key] is List) ? (_answers[f.key] as List).map((e) => '$e') : const <String>[]),
      };
      input = Column(
        children: f.options.map((o) {
          final checked = selectedSet.contains(o);
          return InkWell(
            onTap: () {
              setState(() {
                if (checked) {
                  selectedSet.remove(o);
                } else {
                  selectedSet.add(o);
                }
                _answers[f.key] = selectedSet.toList();
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: checked ? AppColors.emerald.withValues(alpha: 0.08) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: checked ? AppColors.emerald : const Color(0xFFCBD5E1),
                  width: checked ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    size: 19,
                    color: checked ? AppColors.emerald : AppColors.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(o, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          );
        }).toList(),
      );
    } else if (f.type == 'rating') {
      final cur = int.tryParse('${_answers[f.key] ?? ''}') ?? 0;
      input = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (i) {
          final val = i + 1;
          final active = val <= cur;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () => setState(() => _answers[f.key] = val),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? AppColors.amber.withValues(alpha: 0.16) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? AppColors.amber : const Color(0xFFCBD5E1),
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        active ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: active ? AppColors.amber : AppColors.muted,
                        size: 24,
                      ),
                      Text(
                        '$val',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: active ? AppColors.navy : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      );
    } else {
      input = TextField(
        controller: _textCtrls[f.key],
        keyboardType: f.type == 'number' ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: 'Tulis jawaban...',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 10),
          input,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(
          detail?.title ?? widget.initialTitle ?? 'Form Bungtemin',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
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
                        const Icon(Icons.error_outline_rounded, size: 42, color: AppColors.rose),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Coba Lagi')),
                      ],
                    ),
                  ),
                )
              : _submitted
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.emerald.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle_rounded, size: 44, color: AppColors.emerald),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Terima Kasih!',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.navy),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Jawaban form Anda sudah tersimpan ke sistem Bungtemin.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Kembali'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        if (detail!.bannerUrl.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Image.network(
                              detail.bannerUrl,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.navy,
                                _parseSurveyColor(detail.accentColor, AppColors.blueAccent),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                detail.title,
                                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                              if (detail.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  detail.description,
                                  style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85)),
                                ),
                              ],
                              if (_userLabel != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Pengisi: $_userLabel',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        for (var i = 0; i < detail.fields.length; i++) _buildField(detail.fields[i], i),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(
                              _submitting ? 'Mengirim...' : 'Kirim Jawaban',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
    );
  }
}
