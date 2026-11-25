import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bungtemin_crypto.dart';
import '../../core/session_store.dart';
import '../../models/aspirasi_item.dart';

class LaporScreen extends StatefulWidget {
  const LaporScreen({
    super.key,
    this.session,
    this.initialCategoryKey,
  });

  final UserSession? session;
  final String? initialCategoryKey;

  @override
  State<LaporScreen> createState() => _LaporScreenState();
}

class _LaporScreenState extends State<LaporScreen> {
  static const String _kHistoryKey = 'bt_aspirasi_history';

  final List<AspirasiCategory> _categories = AspirasiCategory.defaults;
  List<AspirasiTicket> _riwayatList = const [];

  String _prefillNama = '';
  String _prefillNoreg = '';
  String _prefillBagian = '';
  String _sessionToken = '';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final s = widget.session ?? await SessionStore().load();
    String bagian = '';
    final ktaRaw = await SessionStore().loadKtaCache();
    if (ktaRaw != null && ktaRaw.isNotEmpty) {
      try {
        final map = jsonDecode(ktaRaw);
        if (map is Map) {
          bagian = (map['dept'] ?? map['divisi'] ?? map['plant'] ?? '')
              .toString()
              .trim();
        }
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getString(_kHistoryKey);
    final history = AspirasiTicket.decodeList(rawHistory);

    if (!mounted) return;
    setState(() {
      _prefillNama = s?.nama ?? '';
      _prefillNoreg = s?.noreg ?? '';
      _prefillBagian = bagian;
      _sessionToken = (s?.token ?? '').trim();
      _riwayatList = history;
    });

    final initKey = widget.initialCategoryKey?.trim().toLowerCase();
    if (initKey != null && initKey.isNotEmpty) {
      final matched = _categories.where((c) => c.key == initKey).toList();
      if (matched.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openFormSheet(matched.first);
        });
      }
    }
  }

  Future<void> _saveTicket(AspirasiTicket ticket) async {
    var finalStatus = ticket.status;
    try {
      final noregVal = _prefillNoreg.isNotEmpty ? _prefillNoreg : ticket.noreg;
      final res = await http
          .post(
            Uri.parse('https://bungtemin.net/btapi/Hallopuk/submit'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (_sessionToken.isNotEmpty)
                'Authorization': 'Bearer $_sessionToken',
            },
            body: jsonEncode({
              'ticket_code': ticket.id,
              'kategori': ticket.kategori,
              'kategori_label': ticket.kategoriLabel,
              'enc_noreg': BungteminCrypto.encrypt(noregVal),
              'nama': ticket.nama,
              'bagian': ticket.bagian,
              'judul': ticket.judul,
              'isi': ticket.isi,
              'has_attachment': ticket.hasAttachment,
              'attachment_name': ticket.attachmentName,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['success'] == true) {
          finalStatus = 'Terkirim ke PUK';
        }
      }
    } catch (_) {
      finalStatus = 'Tersimpan Lokal';
    }

    final saved = AspirasiTicket(
      id: ticket.id,
      kategori: ticket.kategori,
      kategoriLabel: ticket.kategoriLabel,
      nama: ticket.nama,
      noreg: ticket.noreg,
      bagian: ticket.bagian,
      judul: ticket.judul,
      isi: ticket.isi,
      hasAttachment: ticket.hasAttachment,
      attachmentName: ticket.attachmentName,
      createdAtIso: ticket.createdAtIso,
      status: finalStatus,
    );

    final updated = [saved, ..._riwayatList].take(20).toList();
    if (!mounted) return;
    setState(() {
      _riwayatList = updated;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHistoryKey, AspirasiTicket.encodeList(updated));
  }

  void _openFormSheet(AspirasiCategory initialCategory) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AspirasiFormSheet(
        categories: _categories,
        initialCategory: initialCategory,
        initialNama: _prefillNama,
        initialNoreg: _prefillBagian.isNotEmpty && _prefillNoreg.isNotEmpty
            ? '$_prefillNoreg / $_prefillBagian'
            : _prefillNoreg,
        initialBagian: _prefillBagian,
        onSubmitted: (ticket, categoryTitle) async {
          await _saveTicket(ticket);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF059669),
              content: Text(
                '$categoryTitle berhasil dikirim (#${ticket.id})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroHeader(context, topPad),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < _categories.length; i++) ...[
                            if (i > 0) const SizedBox(height: 14),
                            _AspirasiCategoryCard(
                              category: _categories[i],
                              onTap: () => _openFormSheet(_categories[i]),
                            ),
                          ],
                          if (_riwayatList.isNotEmpty) ...[
                            const SizedBox(height: 26),
                            _buildHistorySection(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, double topPad) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, topPad + 18, 18, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.58, 1.0],
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF0284C7),
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
        boxShadow: [
          BoxShadow(
            color: Color(0x380F172A),
            blurRadius: 36,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -50,
            right: -40,
            child: IgnorePointer(
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0.35),
                      const Color(0xFF38BDF8).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: IgnorePointer(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.28),
                      const Color(0xFF6366F1).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Beranda',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF34D399).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 15,
                          color: Color(0xFF34D399),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Privasi Terlindungi',
                          style: TextStyle(
                            color: Color(0xFFA7F3D0),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x400F172A),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icon/3.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LAYANAN SUARA ANGGOTA',
                          style: TextStyle(
                            fontSize: 10.8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: Color(0xFF7DD3FC),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Ruang Aspirasi & Laporan',
                          style: TextStyle(
                            fontSize: 20.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Apa yang ingin Anda sampaikan hari ini?',
                          style: TextStyle(
                            fontSize: 12.8,
                            fontWeight: FontWeight.w600,
                            color: Color(0xD9E2E8F0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riwayat Penyampaian Saya',
                      style: TextStyle(
                        fontSize: 15.4,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tiket aspirasi yang tersimpan di perangkat ini',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_riwayatList.length} Tiket',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _riwayatList.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _HistoryItemCard(ticket: _riwayatList[i]),
        ],
      ],
    );
  }
}

class _AspirasiCategoryCard extends StatelessWidget {
  const _AspirasiCategoryCard({
    required this.category,
    required this.onTap,
  });

  final AspirasiCategory category;
  final VoidCallback onTap;

  Color get _accentColor {
    switch (category.accent) {
      case AspirasiAccent.purple:
        return const Color(0xFF7C3AED);
      case AspirasiAccent.amber:
        return const Color(0xFFD97706);
      case AspirasiAccent.blue:
        return const Color(0xFF2563EB);
    }
  }

  Color get _accentSoftBg {
    switch (category.accent) {
      case AspirasiAccent.purple:
        return const Color(0xFFF5F3FF);
      case AspirasiAccent.amber:
        return const Color(0xFFFFFBEB);
      case AspirasiAccent.blue:
        return const Color(0xFFEFF6FF);
    }
  }

  Color get _accentBorder {
    switch (category.accent) {
      case AspirasiAccent.purple:
        return const Color(0xFFEDE9FE);
      case AspirasiAccent.amber:
        return const Color(0xFFFEF3C7);
      case AspirasiAccent.blue:
        return const Color(0xFFDBEAFE);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x180F172A),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _accentSoftBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _accentBorder),
                    ),
                    child: Image.asset(
                      category.iconAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.forum_rounded,
                        color: _accentColor,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.eyebrow.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.7,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: _accentColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          category.title,
                          style: const TextStyle(
                            fontSize: 16.8,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: category.accent == AspirasiAccent.blue
                          ? const Color(0xFFF8FAFC)
                          : _accentSoftBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: _accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                category.desc,
                style: const TextStyle(
                  fontSize: 13.1,
                  height: 1.5,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 15,
                            color: Color(0xFF10B981),
                          ),
                          SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Respon Cepat & Terjadwal',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _accentSoftBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            category.cta,
                            style: TextStyle(
                              fontSize: 11.8,
                              fontWeight: FontWeight.w800,
                              color: _accentColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 15,
                            color: _accentColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  const _HistoryItemCard({required this.ticket});

  final AspirasiTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${ticket.id}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      ticket.status,
                      style: const TextStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ticket.judul,
            style: const TextStyle(
              fontSize: 14.4,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ticket.isi,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                ticket.kategoriLabel,
                style: const TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const Text(
                '•',
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
              Text(
                ticket.formattedDate,
                style: const TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
              if (ticket.hasAttachment) ...[
                const Text(
                  '•',
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const Icon(
                  Icons.attachment_rounded,
                  size: 13,
                  color: Color(0xFF2563EB),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AspirasiFormSheet extends StatefulWidget {
  const _AspirasiFormSheet({
    required this.categories,
    required this.initialCategory,
    required this.initialNama,
    required this.initialNoreg,
    required this.initialBagian,
    required this.onSubmitted,
  });

  final List<AspirasiCategory> categories;
  final AspirasiCategory initialCategory;
  final String initialNama;
  final String initialNoreg;
  final String initialBagian;
  final Future<void> Function(AspirasiTicket ticket, String categoryTitle)
      onSubmitted;

  @override
  State<_AspirasiFormSheet> createState() => _AspirasiFormSheetState();
}

class _AspirasiFormSheetState extends State<_AspirasiFormSheet> {
  late AspirasiCategory _activeCategory;
  late final TextEditingController _namaCtrl;
  late final TextEditingController _noregCtrl;
  late final TextEditingController _judulCtrl;
  late final TextEditingController _isiCtrl;

  bool _hasAttachment = false;
  String _attachmentLabel = '';
  bool _isSubmitting = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.initialCategory;
    _namaCtrl = TextEditingController(text: widget.initialNama);
    _noregCtrl = TextEditingController(text: widget.initialNoreg);
    _judulCtrl = TextEditingController();
    _isiCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _noregCtrl.dispose();
    _judulCtrl.dispose();
    _isiCtrl.dispose();
    super.dispose();
  }

  void _toggleAttachment() {
    setState(() {
      if (_hasAttachment) {
        _hasAttachment = false;
        _attachmentLabel = '';
      } else {
        _hasAttachment = true;
        _attachmentLabel =
            'evidence_${DateTime.now().millisecondsSinceEpoch}.jpg';
      }
    });
  }

  Future<void> _submit() async {
    final judul = _judulCtrl.text.trim();
    final isi = _isiCtrl.text.trim();
    if (judul.isEmpty || isi.isEmpty) {
      setState(() {
        _validationError =
            'Mohon isi judul dan detail penyampaian terlebih dahulu.';
      });
      return;
    }

    setState(() {
      _validationError = null;
      _isSubmitting = true;
    });

    final ticketId = AspirasiTicket.generateTicketId();
    final ticket = AspirasiTicket(
      id: ticketId,
      kategori: _activeCategory.key,
      kategoriLabel: _activeCategory.title,
      nama: _namaCtrl.text.trim().isNotEmpty
          ? _namaCtrl.text.trim()
          : 'Anggota Bungtemin',
      noreg: _noregCtrl.text.trim().isNotEmpty ? _noregCtrl.text.trim() : '-',
      bagian: widget.initialBagian.isNotEmpty ? widget.initialBagian : '-',
      judul: judul,
      isi: isi,
      hasAttachment: _hasAttachment,
      attachmentName: _attachmentLabel,
      createdAtIso: DateTime.now().toIso8601String(),
      status: 'Terkirim',
    );

    await widget.onSubmitted(ticket, _activeCategory.title);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxWidth: 520,
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Color(0x400F172A),
            blurRadius: 40,
            offset: Offset(0, -16),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          bottomInset + safeBottom + 26,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Image.asset(
                    _activeCategory.iconAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.campaign_rounded,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _activeCategory.eyebrow.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10.4,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _activeCategory.title,
                        style: const TextStyle(
                          fontSize: 16.3,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < widget.categories.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _CategoryPillButton(
                      label: widget.categories[i].pillLabel,
                      active: _activeCategory.key == widget.categories[i].key,
                      onTap: () {
                        setState(() {
                          _activeCategory = widget.categories[i];
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
            if (_validationError != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 17,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildFieldGroup(
                    label: 'Nama Anggota',
                    controller: _namaCtrl,
                    placeholder: 'Nama Anda',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildFieldGroup(
                    label: 'NOREG / Bagian',
                    controller: _noregCtrl,
                    placeholder: 'Contoh: 050xxxxx',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildFieldGroup(
              label: 'Judul / Topik Utama *',
              controller: _judulCtrl,
              placeholder: _activeCategory.placeholderTitle,
            ),
            const SizedBox(height: 12),
            _buildFieldGroup(
              label: 'Uraian Lengkap *',
              controller: _isiCtrl,
              placeholder: _activeCategory.placeholderBody,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            const Text(
              'Lampiran Foto / Bukti Pendukung (Opsional)',
              style: TextStyle(
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 5),
            if (!_hasAttachment)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _toggleAttachment,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF93C5FD),
                      width: 1.5,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 20,
                        color: Color(0xFF2563EB),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Ketuk untuk melampirkan foto pendukung',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _attachmentLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Text(
                            'Foto bukti siap dilampirkan',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _toggleAttachment,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFFE11D48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 15),
                      label: const Text(
                        'Hapus Foto',
                        style: TextStyle(
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF0284C7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x472563EB),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    'Kirim ${_activeCategory.cta}',
                    style: const TextStyle(
                      fontSize: 14.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldGroup({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.8,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 13.4,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryPillButton extends StatelessWidget {
  const _CategoryPillButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x402563EB),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
