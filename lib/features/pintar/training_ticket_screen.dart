import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/session_store.dart';
import '../../models/training_item.dart';
import '../../services/bungtemin_api.dart';

class TrainingTicketScreen extends StatefulWidget {
  const TrainingTicketScreen({
    super.key,
    this.session,
    this.initialTickets,
    this.onOpenPleno,
  });

  final UserSession? session;
  final List<TrainingTicketItem>? initialTickets;
  final VoidCallback? onOpenPleno;

  @override
  State<TrainingTicketScreen> createState() => _TrainingTicketScreenState();
}

class _TrainingTicketScreenState extends State<TrainingTicketScreen> {
  final BungteminApi _api = BungteminApi();
  List<TrainingTicketItem> _tickets = const [];
  final Map<int, bool> _flipped = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTickets != null) {
      _tickets = widget.initialTickets!;
    } else {
      _loadTickets();
    }
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final s = widget.session ?? await SessionStore().load();
    final noreg = s?.noreg ?? '';
    final loaded = await _api.fetchTrainingTickets(noreg: noreg);
    if (!mounted) return;
    setState(() {
      _tickets = loaded;
      _isLoading = false;
    });
  }

  void _toggleFlip(int id) {
    setState(() {
      _flipped[id] = !(_flipped[id] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: RefreshIndicator(
        onRefresh: _loadTickets,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroHeader(context, topPad),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isLoading && _tickets.isEmpty)
                          _buildLoadingBox()
                        else if (!_isLoading && _tickets.isEmpty)
                          _buildEmptyCard(context)
                        else
                          for (var i = 0; i < _tickets.length; i++) ...[
                            if (i > 0) const SizedBox(height: 16),
                            _TrainingFlipTicketCard(
                              ticket: _tickets[i],
                              isFlipped: _flipped[_tickets[i].id] == true,
                              onTap: () => _toggleFlip(_tickets[i].id),
                            ),
                          ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, double topPad) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, topPad + 16, 18, 24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Material(
                color: Colors.white.withValues(alpha: 0.12),
                shape: StadiumBorder(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                          'Training',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
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
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF7DD3FC).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      size: 15,
                      color: Color(0xFFE0F2FE),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_tickets.length} Tiket',
                      style: const TextStyle(
                        color: Color(0xFFE0F2FE),
                        fontSize: 12,
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
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.26),
                  ),
                ),
                child: Image.asset(
                  'assets/icon/4.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.confirmation_number_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'E-TIKET KEHADIRAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: Color(0xFF7DD3FC),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Tiket Training Saya',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ketuk kartu tiket untuk membalik & menampilkan QR absensi',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xE0E2E8F0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'Memuat e-tiket training...',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            size: 40,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 8),
          const Text(
            'Belum Ada Tiket Training',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Daftar agenda Training Pleno terlebih dahulu untuk mendapatkan QR tiket kehadiran.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          if (widget.onOpenPleno != null) ...[
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF0284C7)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                onPressed: widget.onOpenPleno,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Lihat Agenda Training',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrainingFlipTicketCard extends StatelessWidget {
  const _TrainingFlipTicketCard({
    required this.ticket,
    required this.isFlipped,
    required this.onTap,
  });

  final TrainingTicketItem ticket;
  final bool isFlipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 290,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: isFlipped
              ? _buildBackSide(key: const ValueKey('back'))
              : _buildFrontSide(key: const ValueKey('front')),
        ),
      ),
    );
  }

  Widget _buildFrontSide({required Key key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.65, 1.0],
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF0369A1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x240F172A),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: ticket.used
                      ? const Color(0xFF64748B)
                      : const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  ticket.used ? 'TERPAKAI' : 'TIKET AKTIF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.confirmation_number_outlined,
                size: 18,
                color: Color(0xFF7DD3FC),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ticket.eventNama.isNotEmpty
                    ? ticket.eventNama
                    : 'Agenda Training PUK SPSI',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: Color(0xFFE2E8F0),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      ticket.formattedTanggal,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xEBE2E8F0),
                      ),
                    ),
                  ),
                ],
              ),
              if (ticket.nama.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 16,
                      color: Color(0xFFE2E8F0),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${ticket.nama} (${ticket.noreg})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xEBE2E8F0),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_rounded,
                      size: 16,
                      color: Color(0xFF7DD3FC),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Ketuk Kartu Untuk Tampilkan QR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7DD3FC),
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.sync_rounded,
                  size: 18,
                  color: Color(0xFF7DD3FC),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackSide({required Key key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x240F172A),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            children: [
              Text(
                'SCAN QR KEHADIRAN',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Tunjukkan QR ini kepada panitia check-in',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: QrImageView(
              data: ticket.qrPayload,
              version: QrVersions.auto,
              size: 170,
              backgroundColor: Colors.white,
            ),
          ),
          const Text(
            'Ketuk lagi untuk kembali ke info tiket',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0284C7),
            ),
          ),
        ],
      ),
    );
  }
}
