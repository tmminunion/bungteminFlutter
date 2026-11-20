import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/net/cached_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../quiz/quiz_screen.dart';

class PretestLobbyScreen extends StatefulWidget {
  final UserSession? session;

  const PretestLobbyScreen({super.key, this.session});

  @override
  State<PretestLobbyScreen> createState() => _PretestLobbyScreenState();
}

class _PretestLobbyScreenState extends State<PretestLobbyScreen> {
  static const _quizListUrl = 'https://nudb.bungtemin.net/data/Quiz';
  static const _cacheKey = 'pretest_lobby_cache_v1';

  UserSession? _session;
  bool _checkingSession = true;
  List<QuizItem> _items = [];
  Map<String, Map<String, dynamic>> _userStats = {};
  String _mode = 'pre'; // 'pre' | 'post'
  String _search = '';
  bool _loading = true;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSessionAndLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSessionAndLoad() async {
    final resolved = widget.session ?? await SessionStore().load();
    if (!mounted) return;
    setState(() {
      _session = resolved;
      _checkingSession = false;
    });
    if (resolved == null || !resolved.isValid) {
      setState(() => _loading = false);
      return;
    }
    await _fetchList();
  }

  Future<void> _fetchList() async {
    final s = _session;
    if (s == null || !s.isValid) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final cleanNoreg = SessionStore.formatNoreg8(s.noreg);
    unawaited(_fetchUserStats(cleanNoreg));

    final prefs = await SharedPreferences.getInstance();
    try {
      final resp = await http
          .get(Uri.parse(_quizListUrl))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final raw = (decoded['value'] as List<dynamic>? ?? []);
        await prefs.setString(_cacheKey, jsonEncode(raw));
        final parsed = raw
            .map((e) => QuizItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((q) => q.status && q.id.isNotEmpty)
            .toList();
        if (!mounted) return;
        setState(() {
          _items = parsed;
          _loading = false;
        });
        return;
      }
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        try {
          final raw = jsonDecode(cached) as List<dynamic>;
          final parsed = raw
              .map((e) => QuizItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .where((q) => q.status && q.id.isNotEmpty)
              .toList();
          if (!mounted) return;
          setState(() {
            _items = parsed;
            _loading = false;
          });
          return;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat daftar materi test ($e)';
      });
    }
  }

  Future<void> _fetchUserStats(String cleanNoreg) async {
    if (cleanNoreg.isEmpty) return;
    try {
      final resp = await http
          .get(Uri.parse('https://nudb.bungtemin.net/QuizStatsApi/$cleanNoreg'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final val = decoded is Map ? decoded['value'] : null;
        if (val is Map && mounted) {
          final mapped = <String, Map<String, dynamic>>{};
          val.forEach((k, v) {
            if (v is Map) {
              mapped[k.toString()] = Map<String, dynamic>.from(v);
            }
          });
          setState(() => _userStats = mapped);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    if (_checkingSession) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pretest & Posttest')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (s == null || !s.isValid) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Pretest & Posttest',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 56, color: AppColors.navy),
                const SizedBox(height: 12),
                const Text(
                  'Login Anggota Diperlukan',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Masuk dengan akun anggota terlebih dahulu untuk mengikuti Pretest & Posttest sesuai data Noreg Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final q = _search.trim().toLowerCase();
    final filtered = _items.where((item) {
      if (q.isEmpty) return true;
      return item.title.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pretest & Posttest',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PretestLeaderboardScreen(),
                ),
              );
            },
            icon: const Icon(Icons.leaderboard_rounded),
            tooltip: 'Leaderboard Pretest',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        size: 16,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${s.nama} • Noreg ${SessionStore.formatNoreg8(s.noreg)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'pre',
                      icon: Icon(Icons.play_lesson_outlined, size: 17),
                      label: Text('Pre-Test (Awal)'),
                    ),
                    ButtonSegment(
                      value: 'post',
                      icon: Icon(Icons.verified_outlined, size: 17),
                      label: Text('Post-Test (Min 80)'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Cari materi evaluasi...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
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
                              FilledButton(
                                onPressed: _fetchList,
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.navy),
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchList,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, idx) {
                            final item = filtered[idx];
                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PretestPlayScreen(
                                        quiz: item,
                                        mode: _mode,
                                        session: s,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: (_mode == 'post'
                                                  ? AppColors.emerald
                                                  : AppColors.primaryBlue)
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          _mode == 'post'
                                              ? Icons.fact_check_rounded
                                              : Icons.assignment_outlined,
                                          color: _mode == 'post'
                                              ? AppColors.emerald
                                              : AppColors.primaryBlue,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.navy,
                                              ),
                                            ),
                                            if (item.description.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                item.description,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                            if (_userStats[item.id] != null) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                'Pre: ${_userStats[item.id]!['has_pre'] == true ? (_userStats[item.id]!['pre_score'] ?? 0) : '-'} · Post: ${_userStats[item.id]!['has_post'] == true ? (_userStats[item.id]!['post_score'] ?? 0) : '-'}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primaryBlue,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.navy,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _mode == 'post' ? 'Post' : 'Pre',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class PretestPlayScreen extends StatefulWidget {
  final QuizItem quiz;
  final String mode; // 'pre' | 'post'
  final UserSession? session;

  const PretestPlayScreen({
    super.key,
    required this.quiz,
    required this.mode,
    this.session,
  });

  @override
  State<PretestPlayScreen> createState() => _PretestPlayScreenState();
}

class _PretestPlayScreenState extends State<PretestPlayScreen> {
  final Random _rng = Random();
  List<QuizQuestion> _questions = [];
  bool _loading = true;
  String? _error;

  bool _showCountdown = true;
  int _countdown = 3;
  Timer? _countdownTimer;

  int _totalSeconds = 0;
  Timer? _stopwatchTimer;

  int _currentIdx = 0;
  int _correctCount = 0;
  int? _selectedIdx;
  bool _answered = false;
  bool _isGameOver = false;
  String? _syncNote;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  List<T> _shuffle<T>(List<T> items) {
    final copy = List<T>.from(items);
    for (int i = copy.length - 1; i > 0; i--) {
      final j = _rng.nextInt(i + 1);
      final tmp = copy[i];
      copy[i] = copy[j];
      copy[j] = tmp;
    }
    return copy;
  }

  List<QuizQuestion> _prepare(List<QuizQuestion> raw) {
    return _shuffle(raw)
        .map((q) => QuizQuestion(
              text: q.text,
              timer: q.timer,
              options: _shuffle(q.options),
            ))
        .toList();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'quiz_cache_${widget.quiz.id}';

    for (final url in [
      'https://nudb.bungtemin.net/QuizQuestionApi/${widget.quiz.id}',
      'https://nudb.bungtemin.net/data/Pertanyaan/${widget.quiz.id}',
    ]) {
      try {
        final resp =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
          final raw = (decoded['questions'] ??
                  decoded['value']?['questions'] ??
                  []) as List<dynamic>;
          if (raw.isNotEmpty) {
            await prefs.setString(cacheKey, jsonEncode(raw));
            final parsed = raw
                .map((e) =>
                    QuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
            if (!mounted) return;
            setState(() {
              _questions = _prepare(parsed);
              _loading = false;
            });
            _startCountdown();
            return;
          }
        }
      } catch (_) {}
    }

    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final raw = jsonDecode(cached) as List<dynamic>;
        final parsed = raw
            .map((e) =>
                QuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (!mounted) return;
        setState(() {
          _questions = _prepare(parsed);
          _loading = false;
        });
        _startCountdown();
        return;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = 'Soal pretest belum tersedia.';
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _showCountdown = true;
      _countdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdown <= 1) {
        t.cancel();
        setState(() => _showCountdown = false);
        _startStopwatch();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _startStopwatch() {
    _stopwatchTimer?.cancel();
    _totalSeconds = 0;
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _totalSeconds++);
    });
  }

  void _selectOption(int idx) {
    if (_answered) return;
    final q = _questions[_currentIdx];
    final isCorrect = q.options[idx].correct;
    setState(() {
      _answered = true;
      _selectedIdx = idx;
      if (isCorrect) _correctCount++;
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      if (_currentIdx < _questions.length - 1) {
        setState(() {
          _currentIdx++;
          _answered = false;
          _selectedIdx = null;
        });
      } else {
        _stopwatchTimer?.cancel();
        setState(() => _isGameOver = true);
        _submitResult();
      }
    });
  }

  int get _finalScore => _questions.isEmpty
      ? 0
      : ((_correctCount / _questions.length) * 100).round();

  Future<void> _submitResult() async {
    final score = _finalScore;
    final session = widget.session ?? await SessionStore().load();
    if (session == null || !session.isValid) {
      if (mounted) {
        setState(
          () => _syncNote =
              'Sesi login anggota tidak ditemukan. Hasil tidak dikirim ke server.',
        );
      }
      return;
    }

    final cleanNoreg = SessionStore.formatNoreg8(session.noreg);
    final histKey = 'pretest_history_$cleanNoreg';
    final prefs = await SharedPreferences.getInstance();
    final rawHist = prefs.getString(histKey);
    List<dynamic> hist = [];
    if (rawHist != null && rawHist.isNotEmpty) {
      try {
        hist = jsonDecode(rawHist) as List<dynamic>;
      } catch (_) {}
    }
    hist.insert(0, {
      'user_noreg': cleanNoreg,
      'quiz_id': widget.quiz.id,
      'quiz_title': widget.quiz.title,
      'test_type': widget.mode,
      'score': score,
      'duration': _totalSeconds,
      'finished_at': DateTime.now().toIso8601String(),
    });
    await prefs.setString(histKey, jsonEncode(hist));

    try {
      final resp = await http
          .post(
            Uri.parse('https://nudb.bungtemin.net/test/api/submit-result'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_noreg': cleanNoreg,
              'user_name': session.nama,
              'quiz_id': widget.quiz.id,
              'test_type': widget.mode,
              'score': score,
              'duration': _totalSeconds,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _syncNote = resp.statusCode >= 200 && resp.statusCode < 300
              ? 'Hasil ${widget.mode == 'post' ? 'Post-Test' : 'Pre-Test'} tersimpan di server!'
              : 'Hasil tersimpan lokal (server HTTP ${resp.statusCode}).';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _syncNote = 'Gagal kirim ke server, tersimpan lokal.');
      }
    }
  }

  String _fmtDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.mode == 'post' ? 'Post-Test' : 'Pre-Test'} · ${widget.quiz.title}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _showCountdown
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.mode == 'post'
                                ? 'POST-TEST (TARGET 80)'
                                : 'PRE-TEST AWAL',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$_countdown',
                            style: const TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _isGameOver
                      ? _buildResult()
                      : _buildQuestion(),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_currentIdx];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Soal ${_currentIdx + 1} / ${_questions.length}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.navy),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 15, color: AppColors.navy),
                    const SizedBox(width: 4),
                    Text(
                      _fmtDuration(_totalSeconds),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              q.text,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                height: 1.45,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: q.options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, idx) {
                final opt = q.options[idx];
                Color bg = Colors.white;
                Color border = const Color(0xFFE2E8F0);
                Color fg = AppColors.navy;
                if (_answered) {
                  if (opt.correct) {
                    bg = const Color(0xFFDCFCE7);
                    border = AppColors.emerald;
                    fg = const Color(0xFF065F46);
                  } else if (_selectedIdx == idx) {
                    bg = const Color(0xFFFEE2E2);
                    border = Colors.red;
                    fg = const Color(0xFF991B1B);
                  }
                }
                return Material(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _answered ? null : () => _selectOption(idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border, width: 1.4),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor:
                                AppColors.navy.withValues(alpha: 0.08),
                            child: Text(
                              String.fromCharCode(65 + idx),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: fg,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              opt.text,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: fg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final score = _finalScore;
    final lulus = score >= 80;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.mode == 'post'
                    ? (lulus ? Icons.verified_rounded : Icons.info_outline_rounded)
                    : Icons.assignment_turned_in_rounded,
                size: 62,
                color: widget.mode == 'post'
                    ? (lulus ? AppColors.emerald : AppColors.amber)
                    : AppColors.primaryBlue,
              ),
              const SizedBox(height: 12),
              Text(
                widget.mode == 'post'
                    ? (lulus ? 'Selamat! Anda Lulus' : 'Belum Mencapai Target 80')
                    : 'Pre-Test Selesai',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$score / 100',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Benar $_correctCount dari ${_questions.length} soal · Durasi ${_fmtDuration(_totalSeconds)}',
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
              ),
              if (_syncNote != null) ...[
                const SizedBox(height: 10),
                Text(
                  _syncNote!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Kembali ke Daftar Test'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PretestLeaderboardScreen extends StatefulWidget {
  const PretestLeaderboardScreen({super.key});

  @override
  State<PretestLeaderboardScreen> createState() =>
      _PretestLeaderboardScreenState();
}

class _PretestLeaderboardScreenState extends State<PretestLeaderboardScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await http
          .get(Uri.parse('https://nudb.bungtemin.net/test/api/global-leaderboard'))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final list = (decoded is List
                ? decoded
                : (decoded['value'] as List<dynamic>? ?? []))
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (!mounted) return;
        setState(() {
          _rows = list;
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Leaderboard Pretest',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada data leaderboard pretest.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final r = _rows[idx];
                    final name =
                        (r['user_name'] ?? r['user_nama'] ?? 'Peserta').toString();
                    final score = (r['score'] ?? 0).toString();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: idx < 3
                              ? AppColors.gold
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: idx == 0
                                ? AppColors.gold
                                : AppColors.navy.withValues(alpha: 0.1),
                            child: Text(
                              '#${idx + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          Text(
                            '$score / 100',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
