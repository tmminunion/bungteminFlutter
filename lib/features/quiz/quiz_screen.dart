import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/net/cached_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/session_store.dart';
import '../../core/theme.dart';
import '../../core/net/btapi_auth.dart';

class QuizItem {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final bool status;

  const QuizItem({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.status,
  });

  factory QuizItem.fromJson(Map<String, dynamic> j) => QuizItem(
        id: (j['id'] ?? j['Slug'] ?? '').toString(),
        title: (j['Title'] ?? j['title'] ?? 'Kuis').toString(),
        description: (j['Description'] ?? j['description'] ?? '').toString(),
        imageUrl: (j['Image'] ?? j['image'] ?? '').toString(),
        status: j['Status'] != false,
      );
}

class QuizOption {
  final String text;
  final bool correct;

  const QuizOption({required this.text, required this.correct});

  factory QuizOption.fromJson(Map<String, dynamic> j) => QuizOption(
        text: (j['text'] ?? '').toString(),
        correct: j['correct'] == true || j['isCorrect'] == true,
      );
}

class QuizQuestion {
  final String text;
  final int timer;
  final List<QuizOption> options;

  const QuizQuestion({
    required this.text,
    required this.timer,
    required this.options,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) {
    final rawOpts = (j['options'] as List<dynamic>? ?? []);
    return QuizQuestion(
      text: (j['text'] ?? j['question'] ?? '').toString(),
      timer: (j['timer'] as num?)?.toInt() ?? 15,
      options: rawOpts
          .map((e) => QuizOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class QuizLobbyScreen extends StatefulWidget {
  final UserSession? session;

  const QuizLobbyScreen({super.key, this.session});

  @override
  State<QuizLobbyScreen> createState() => _QuizLobbyScreenState();
}

class _QuizLobbyScreenState extends State<QuizLobbyScreen> {
  static const _quizListUrl = 'https://nudb.bungtemin.net/data/Quiz';
  static const _cacheKey = 'quiz_lobby_cache_v1';

  UserSession? _session;
  bool _checkingSession = true;
  List<QuizItem> _quizzes = [];
  Map<String, Map<String, dynamic>> _userStats = {};
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
    await _fetchQuizzes();
  }

  Future<void> _fetchQuizzes() async {
    final s = _session;
    if (s == null || !s.isValid) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final cleanNoreg = SessionStore.formatNoreg8(s.noreg);
    final prefs = await SharedPreferences.getInstance();

    // Ambil statistik user (tidak memblokir daftar kuis jika gagal)
    unawaited(_fetchUserStats(cleanNoreg));

    try {
      final resp = await http
          .get(Uri.parse(_quizListUrl))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final rawList = (decoded['value'] as List<dynamic>? ?? []);
        await prefs.setString(_cacheKey, jsonEncode(rawList));
        final items = rawList
            .map((e) => QuizItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((q) => q.status && q.id.isNotEmpty)
            .toList();
        if (!mounted) return;
        setState(() {
          _quizzes = items;
          _loading = false;
        });
        return;
      }
      throw Exception('HTTP ${resp.statusCode}');
    } catch (e) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        try {
          final rawList = jsonDecode(cached) as List<dynamic>;
          final items = rawList
              .map((e) => QuizItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .where((q) => q.status && q.id.isNotEmpty)
              .toList();
          if (!mounted) return;
          setState(() {
            _quizzes = items;
            _loading = false;
          });
          return;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat daftar kuis ($e)';
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

  void _openGlobalLeaderboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const QuizLeaderboardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    if (_checkingSession) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz Bungtemin')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (s == null || !s.isValid) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Quiz Bungtemin',
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
                  'Masuk dengan akun anggota terlebih dahulu untuk mengikuti Quiz dan mencatat skor ke akun Anda.',
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
    final filtered = _quizzes.where((item) {
      if (q.isEmpty) return true;
      return item.title.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quiz Bungtemin',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            onPressed: _openGlobalLeaderboard,
            icon: const Icon(Icons.leaderboard_rounded),
            tooltip: 'Leaderboard Global',
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
                const Text(
                  'Uji wawasan serikat pekerja, ketenagakerjaan, dan pengetahuan umum secara interaktif.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Cari topik kuis...',
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
                              const Icon(Icons.wifi_off_rounded,
                                  size: 48, color: AppColors.muted),
                              const SizedBox(height: 10),
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _fetchQuizzes,
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.navy),
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchQuizzes,
                        child: filtered.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 80),
                                  Center(
                                    child: Text(
                                      'Kuis tidak ditemukan.',
                                      style: TextStyle(color: AppColors.muted),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
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
                                            builder: (_) => QuizPlayScreen(
                                              quiz: item,
                                              session: s,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          border: Border.all(
                                              color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                color: AppColors.navy
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: item.imageUrl.isNotEmpty
                                                  ? Image.network(
                                                      item.imageUrl,
        headers: BtapiAuth.imageHeaders(item.imageUrl),
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (_, __, ___) =>
                                                              const Icon(
                                                        Icons.quiz_rounded,
                                                        color: AppColors.navy,
                                                        size: 28,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.quiz_rounded,
                                                      color: AppColors.navy,
                                                      size: 28,
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
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: AppColors.navy,
                                                    ),
                                                  ),
                                                  if (item.description
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      item.description,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12.5,
                                                        color:
                                                            Color(0xFF64748B),
                                                      ),
                                                    ),
                                                  ],
                                                  if (_userStats[item.id] !=
                                                      null) ...[
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'Skor terbaik: ${_userStats[item.id]!['high_score'] ?? 0} · Dimainkan ${_userStats[item.id]!['times_played'] ?? 0}x',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: AppColors
                                                            .primaryBlue,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.navy,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Text(
                                                'Main',
                                                style: TextStyle(
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

class QuizPlayScreen extends StatefulWidget {
  final QuizItem quiz;
  final UserSession? session;

  const QuizPlayScreen({super.key, required this.quiz, this.session});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  final Random _rng = Random();
  List<QuizQuestion> _questions = [];
  bool _loading = true;
  String? _error;

  bool _showCountdown = true;
  int _countdown = 3;
  Timer? _countdownTimer;

  int _currentIdx = 0;
  int _totalScore = 0;
  int _correctCount = 0;
  int _timeLeft = 15;
  int _questionMaxTime = 15;
  Timer? _questionTimer;

  int? _selectedOptionIdx;
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
    _questionTimer?.cancel();
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

  List<QuizQuestion> _prepareQuestions(List<QuizQuestion> raw) {
    final shuffledQ = _shuffle(raw);
    return shuffledQ
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
    final url = 'https://nudb.bungtemin.net/data/Pertanyaan/${widget.quiz.id}';

    try {
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final raw = (decoded['value']?['questions'] as List<dynamic>? ?? []);
        if (raw.isNotEmpty) {
          await prefs.setString(cacheKey, jsonEncode(raw));
          final parsed = raw
              .map((e) =>
                  QuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          if (!mounted) return;
          setState(() {
            _questions = _prepareQuestions(parsed);
            _loading = false;
          });
          _startCountdown();
          return;
        }
      }
      throw Exception('Soal tidak tersedia');
    } catch (e) {
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
            _questions = _prepareQuestions(parsed);
            _loading = false;
          });
          _startCountdown();
          return;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat soal kuis ($e)';
      });
    }
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
        _startQuestion();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _startQuestion() {
    _questionTimer?.cancel();
    if (_questions.isEmpty) return;
    final maxT = _questions[_currentIdx].timer;
    setState(() {
      _answered = false;
      _selectedOptionIdx = null;
      _questionMaxTime = maxT;
      _timeLeft = maxT;
    });

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_timeLeft <= 0) {
        t.cancel();
        _handleSelect(null);
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _handleSelect(int? optionIdx) {
    if (_answered) return;
    _questionTimer?.cancel();

    final q = _questions[_currentIdx];
    final isCorrect = optionIdx != null &&
        optionIdx >= 0 &&
        optionIdx < q.options.length &&
        q.options[optionIdx].correct;

    setState(() {
      _answered = true;
      _selectedOptionIdx = optionIdx;
      if (isCorrect) {
        _correctCount++;
        _totalScore += 1000 + (_timeLeft * 50);
      }
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_currentIdx < _questions.length - 1) {
        setState(() => _currentIdx++);
        _startQuestion();
      } else {
        setState(() => _isGameOver = true);
        _submitResult();
      }
    });
  }

  Future<void> _submitResult() async {
    final session = widget.session ?? await SessionStore().load();
    if (session == null || !session.isValid) {
      if (mounted) {
        setState(
          () => _syncNote = 'Sesi login anggota tidak ditemukan. Skor tidak disinkronkan.',
        );
      }
      return;
    }

    final cleanNoreg = SessionStore.formatNoreg8(session.noreg);
    final histKey = 'quiz_history_$cleanNoreg';
    final prefs = await SharedPreferences.getInstance();
    final histRaw = prefs.getString(histKey);
    List<dynamic> hist = [];
    if (histRaw != null && histRaw.isNotEmpty) {
      try {
        hist = jsonDecode(histRaw) as List<dynamic>;
      } catch (_) {}
    }
    hist.insert(0, {
      'user_noreg': cleanNoreg,
      'quizId': widget.quiz.id,
      'quizTitle': widget.quiz.title,
      'score': _totalScore,
      'correct': _correctCount,
      'total': _questions.length,
      'finishedAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(histKey, jsonEncode(hist));

    try {
      final resp = await http
          .post(
            Uri.parse('https://nudb.bungtemin.net/QuizApi/results'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_noreg': cleanNoreg,
              'user_nama': session.nama,
              'quiz_id': widget.quiz.id,
              'quiz_title': widget.quiz.title,
              'score': _totalScore,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _syncNote = resp.statusCode >= 200 && resp.statusCode < 300
              ? 'Skor tersinkronisasi ke Leaderboard!'
              : 'Skor tersimpan lokal (server HTTP ${resp.statusCode}).';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _syncNote = 'Gagal sinkron server, skor tersimpan lokal.');
      }
    }
  }

  void _restart() {
    setState(() {
      _currentIdx = 0;
      _totalScore = 0;
      _correctCount = 0;
      _isGameOver = false;
      _syncNote = null;
      _questions = _prepareQuestions(_questions);
    });
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.quiz.title,
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
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loadQuestions,
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.navy),
                          child: const Text('Muat Ulang'),
                        ),
                      ],
                    ),
                  ),
                )
              : _showCountdown
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'BERSIAP...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
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
                      ? _buildGameOver()
                      : _buildQuestionView(),
    );
  }

  Widget _buildQuestionView() {
    final q = _questions[_currentIdx];
    final timerPct = _questionMaxTime > 0 ? _timeLeft / _questionMaxTime : 0.0;

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
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Skor: $_totalScore',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: timerPct,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _timeLeft <= 5 ? Colors.red : AppColors.primaryBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_timeLeft}d',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _timeLeft <= 5 ? Colors.red : AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
                fontSize: 17,
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
                  } else if (_selectedOptionIdx == idx) {
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
                    onTap: _answered ? null : () => _handleSelect(idx),
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

  Widget _buildGameOver() {
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
              const Icon(Icons.emoji_events_rounded,
                  size: 64, color: AppColors.gold),
              const SizedBox(height: 12),
              const Text(
                'Kuis Selesai!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_totalScore Poin',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Benar $_correctCount dari ${_questions.length} soal',
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF475569)),
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
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            QuizLeaderboardScreen(quizId: widget.quiz.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.leaderboard_rounded),
                  label: const Text('Lihat Leaderboard'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Main Lagi'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuizLeaderboardScreen extends StatefulWidget {
  final String? quizId;

  const QuizLeaderboardScreen({super.key, this.quizId});

  @override
  State<QuizLeaderboardScreen> createState() => _QuizLeaderboardScreenState();
}

class _QuizLeaderboardScreenState extends State<QuizLeaderboardScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final url = widget.quizId != null
        ? 'https://nudb.bungtemin.net/QuizApi/leaderboard-quiz/${widget.quizId}'
        : 'https://nudb.bungtemin.net/QuizApi/leaderboard';

    try {
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
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
        title: Text(
          widget.quizId != null ? 'Leaderboard Kuis' : 'Leaderboard Global',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada data skor leaderboard.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final r = _rows[idx];
                      final name =
                          (r['user_nama'] ?? r['nama'] ?? 'Peserta').toString();
                      final score = (r['score'] ?? r['total_score'] ?? 0).toString();
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
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: idx == 0
                                      ? AppColors.navy
                                      : AppColors.navy,
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
                              '$score pts',
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
                ),
    );
  }
}
