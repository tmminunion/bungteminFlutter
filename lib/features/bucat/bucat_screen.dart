import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/session_store.dart';
import '../../core/theme.dart';

class BucatNote {
  final String id;
  final String title;
  final String content;
  final String category;
  final int paperColorValue;
  final bool isPinned;
  final String createdAtIso;
  final String updatedAtIso;

  const BucatNote({
    required this.id,
    required this.title,
    required this.content,
    this.category = 'Umum',
    this.paperColorValue = 0xFFFFFFFF,
    this.isPinned = false,
    required this.createdAtIso,
    required this.updatedAtIso,
  });

  factory BucatNote.fromJson(Map<String, dynamic> j) => BucatNote(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        content: (j['content'] ?? '').toString(),
        category: (j['category'] ?? 'Umum').toString(),
        paperColorValue: (j['paperColorValue'] as num?)?.toInt() ?? 0xFFFFFFFF,
        isPinned: j['isPinned'] == true,
        createdAtIso:
            (j['createdAtIso'] ?? DateTime.now().toIso8601String()).toString(),
        updatedAtIso:
            (j['updatedAtIso'] ?? DateTime.now().toIso8601String()).toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'category': category,
        'paperColorValue': paperColorValue,
        'isPinned': isPinned,
        'createdAtIso': createdAtIso,
        'updatedAtIso': updatedAtIso,
      };

  BucatNote copyWith({
    String? title,
    String? content,
    String? category,
    int? paperColorValue,
    bool? isPinned,
    String? updatedAtIso,
  }) =>
      BucatNote(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        category: category ?? this.category,
        paperColorValue: paperColorValue ?? this.paperColorValue,
        isPinned: isPinned ?? this.isPinned,
        createdAtIso: createdAtIso,
        updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      );
}

class BucatScreen extends StatefulWidget {
  const BucatScreen({super.key});

  @override
  State<BucatScreen> createState() => _BucatScreenState();
}

class _BucatScreenState extends State<BucatScreen> {
  static const _storageKey = 'bucat_notes_v1';
  static const _bucatApiBase = 'https://bungtemin.net/btapi/Bucat';
  String _noreg = '';

  static const List<String> _categories = [
    'Semua',
    'Disematkan',
    'Umum',
    'Kerja',
    'Organisasi',
    'Pribadi',
  ];

  List<BucatNote> _notes = [];
  String _selectedFilter = 'Semua';
  String _searchQuery = '';
  bool _isGrid = false;
  bool _loading = true;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    List<BucatNote> notes = [];

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        notes = decoded
            .map((e) => BucatNote.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }

    final session = await SessionStore().load();
    _noreg = (session?.noreg ?? '').trim();

    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });

    if (_noreg.isNotEmpty) {
      unawaited(_syncWithServer(notes));
    }
  }

  Future<void> _syncWithServer(List<BucatNote> localNotes) async {
    try {
      final res = await http
          .get(Uri.parse('$_bucatApiBase/list?noreg=${Uri.encodeComponent(_noreg)}'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final items = (decoded is Map ? decoded['items'] : null) as List?;
        if (items != null && items.isNotEmpty) {
          final serverNotes = items
              .whereType<Map>()
              .map((e) => BucatNote.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          if (!mounted) return;
          setState(() => _notes = serverNotes);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            _storageKey,
            jsonEncode(serverNotes.map((e) => e.toJson()).toList()),
          );
        } else if (localNotes.isNotEmpty) {
          await http
              .post(
                Uri.parse('$_bucatApiBase/sync'),
                headers: const {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'noreg': _noreg,
                  'notes': localNotes.map((e) => e.toJson()).toList(),
                }),
              )
              .timeout(const Duration(seconds: 12));
        }
      }
    } catch (_) {}
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_notes.map((e) => e.toJson()).toList()),
    );
    if (_noreg.isNotEmpty) {
      unawaited(
        http
            .post(
              Uri.parse('$_bucatApiBase/sync'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({
                'noreg': _noreg,
                'notes': _notes.map((e) => e.toJson()).toList(),
              }),
            )
            .timeout(const Duration(seconds: 12))
            .catchError((_) => http.Response('', 500)),
      );
    }
  }

  List<BucatNote> get _filteredNotes {
    final q = _searchQuery.trim().toLowerCase();
    final list = _notes.where((n) {
      if (_selectedFilter == 'Disematkan' && !n.isPinned) return false;
      if (_selectedFilter != 'Semua' &&
          _selectedFilter != 'Disematkan' &&
          n.category != _selectedFilter) {
        return false;
      }
      if (q.isNotEmpty) {
        final hitTitle = n.title.toLowerCase().contains(q);
        final hitContent = n.content.toLowerCase().contains(q);
        if (!hitTitle && !hitContent) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAtIso.compareTo(a.updatedAtIso);
    });
    return list;
  }

  Future<void> _openEditor({BucatNote? note}) async {
    final result = await Navigator.of(context).push<_BucatEditorResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BucatEditorScreen(initialNote: note),
      ),
    );
    if (!mounted || result == null) return;

    if (result.deleted && note != null) {
      setState(() {
        _notes.removeWhere((n) => n.id == note.id);
      });
      await _saveNotes();
      return;
    }

    if (result.note != null) {
      final saved = result.note!;
      setState(() {
        final idx = _notes.indexWhere((n) => n.id == saved.id);
        if (idx >= 0) {
          _notes[idx] = saved;
        } else {
          _notes.insert(0, saved);
        }
      });
      await _saveNotes();
    }
  }

  Future<void> _togglePin(BucatNote note) async {
    setState(() {
      _notes = _notes
          .map((n) => n.id == note.id
              ? n.copyWith(
                  isPinned: !n.isPinned,
                  updatedAtIso: DateTime.now().toIso8601String(),
                )
              : n)
          .toList();
    });
    await _saveNotes();
  }

  Future<void> _deleteNote(BucatNote note) async {
    setState(() {
      _notes.removeWhere((n) => n.id == note.id);
    });
    await _saveNotes();
    if (_noreg.isNotEmpty) {
      unawaited(
        http
            .post(
              Uri.parse('$_bucatApiBase/delete'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'noreg': _noreg, 'id': note.id}),
            )
            .timeout(const Duration(seconds: 10))
            .catchError((_) => http.Response('', 500)),
      );
    }
  }

  String _formatUpdated(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotes;
    final pinnedCount = _notes.where((n) => n.isPinned).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bucat · Buku Catatan',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isGrid = !_isGrid),
            icon: Icon(
              _isGrid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
            ),
            tooltip: _isGrid ? 'Tampilan Daftar' : 'Tampilan Grid',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text(
          'Catatan Baru',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header ringkas & Search
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${_notes.length} Catatan',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (pinnedCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '$pinnedCount disematkan',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Cari judul atau isi catatan...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, idx) {
                            final cat = _categories[idx];
                            final selected = _selectedFilter == cat;
                            return ChoiceChip(
                              label: Text(cat),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _selectedFilter = cat),
                              selectedColor: AppColors.navy,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                              side: BorderSide(
                                color: selected
                                    ? AppColors.navy
                                    : const Color(0xFFE2E8F0),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Daftar / Grid Catatan
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 56,
                                  color: AppColors.muted.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Belum ada catatan',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tap "+ Catatan Baru" untuk mulai menulis di editor layar penuh.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _isGrid
                          ? GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.86,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (_, idx) =>
                                  _buildNoteCard(filtered[idx], isGrid: true),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, idx) {
                                final note = filtered[idx];
                                return Dismissible(
                                  key: ValueKey(note.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade600,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onDismissed: (_) => _deleteNote(note),
                                  child: _buildNoteCard(note, isGrid: false),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildNoteCard(BucatNote note, {required bool isGrid}) {
    final bgColor = Color(note.paperColorValue);
    final titleText = note.title.trim().isEmpty ? 'Tanpa Judul' : note.title;
    final preview = note.content.trim();
    final words = _wordCount(note.content);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openEditor(note: note),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: note.isPinned
                  ? AppColors.gold
                  : const Color(0xFFE2E8F0),
              width: note.isPinned ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      note.category,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _togglePin(note),
                    child: Icon(
                      note.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      size: 18,
                      color: note.isPinned
                          ? const Color(0xFFD97706)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                titleText,
                maxLines: isGrid ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              if (isGrid)
                Expanded(
                  child: Text(
                    preview.isEmpty ? 'Ketuk untuk menulis catatan...' : preview,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: preview.isEmpty
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                    ),
                  ),
                )
              else
                Text(
                  preview.isEmpty ? 'Ketuk untuk menulis catatan...' : preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: preview.isEmpty
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatUpdated(note.updatedAtIso),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '$words kata',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BucatEditorResult {
  final BucatNote? note;
  final bool deleted;

  const _BucatEditorResult({this.note, this.deleted = false});
}

class BucatEditorScreen extends StatefulWidget {
  final BucatNote? initialNote;

  const BucatEditorScreen({super.key, this.initialNote});

  @override
  State<BucatEditorScreen> createState() => _BucatEditorScreenState();
}

class _BucatEditorScreenState extends State<BucatEditorScreen> {
  static const List<String> _editableCategories = [
    'Umum',
    'Kerja',
    'Organisasi',
    'Pribadi',
  ];

  static final List<Color> _paperColors = [
    Colors.white,
    const Color(0xFFFFFBEB), // Warm Cream
    const Color(0xFFF0F9FF), // Soft Sky
    const Color(0xFFF0FDF4), // Mint Soft
    const Color(0xFFFAF5FF), // Lavender Soft
  ];

  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late String _noteId;
  late String _createdAtIso;
  late String _category;
  late int _paperColorValue;
  late bool _isPinned;
  bool _dirty = false;
  String _statusLabel = 'Siap menulis';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final n = widget.initialNote;
    _noteId = n?.id ?? 'bucat_${DateTime.now().millisecondsSinceEpoch}';
    _createdAtIso = n?.createdAtIso ?? DateTime.now().toIso8601String();
    _category = n?.category ?? 'Umum';
    _paperColorValue = n?.paperColorValue ?? Colors.white.toARGB32();
    _isPinned = n?.isPinned ?? false;
    _titleCtrl = TextEditingController(text: n?.title ?? '');
    _contentCtrl = TextEditingController(text: n?.content ?? '');
    if (n != null) {
      _statusLabel = 'Tersimpan';
    }
    _titleCtrl.addListener(_onChanged);
    _contentCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    _dirty = true;
    if (mounted) {
      setState(() => _statusLabel = 'Mengetik...');
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        setState(() => _statusLabel = 'Tersimpan di draf');
      }
    });
  }

  BucatNote? _buildNoteOrNull() {
    final t = _titleCtrl.text.trim();
    final c = _contentCtrl.text.trim();
    if (t.isEmpty && c.isEmpty && widget.initialNote == null) {
      return null;
    }
    return BucatNote(
      id: _noteId,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text,
      category: _category,
      paperColorValue: _paperColorValue,
      isPinned: _isPinned,
      createdAtIso: _createdAtIso,
      updatedAtIso: _dirty || widget.initialNote == null
          ? DateTime.now().toIso8601String()
          : widget.initialNote!.updatedAtIso,
    );
  }

  void _closeAndSave() {
    Navigator.of(context).pop(_BucatEditorResult(note: _buildNoteOrNull()));
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan?'),
        content: const Text('Catatan ini akan dihapus permanen dari perangkat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(const _BucatEditorResult(deleted: true));
    }
  }

  Future<void> _copyToClipboard() async {
    final text = '${_titleCtrl.text.trim()}\n\n${_contentCtrl.text}'.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Catatan disalin ke clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = Color(_paperColorValue);
    final rawText = _contentCtrl.text.trim();
    final wordCount =
        rawText.isEmpty ? 0 : rawText.split(RegExp(r'\s+')).length;
    final charCount = _contentCtrl.text.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closeAndSave();
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _closeAndSave,
            tooltip: 'Simpan & Kembali',
          ),
          title: Text(
            _statusLabel,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  _isPinned = !_isPinned;
                  _dirty = true;
                });
              },
              icon: Icon(
                _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: _isPinned ? AppColors.gold : Colors.white,
              ),
              tooltip: _isPinned ? 'Lepas Sematan' : 'Sematkan Catatan',
            ),
            IconButton(
              onPressed: _copyToClipboard,
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Salin Teks',
            ),
            if (widget.initialNote != null)
              IconButton(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Hapus Catatan',
              ),
            TextButton(
              onPressed: _closeAndSave,
              child: const Text(
                'Selesai',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Bar kategori & warna kertas
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.03),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _category,
                        isDense: true,
                        borderRadius: BorderRadius.circular(12),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                        items: _editableCategories
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text('Kategori: $c'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _category = v;
                              _dirty = true;
                            });
                          }
                        },
                      ),
                    ),
                    const Spacer(),
                    ..._paperColors.map((c) {
                      final selected = c.toARGB32() == _paperColorValue;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _paperColorValue = c.toARGB32();
                          _dirty = true;
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? AppColors.navy
                                  : const Color(0xFFCBD5E1),
                              width: selected ? 2.4 : 1,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Area Editor Full Screen
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Judul Catatan...',
                          hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _contentCtrl,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          autofocus: widget.initialNote == null,
                          style: const TextStyle(
                            fontSize: 15.5,
                            height: 1.65,
                            color: Color(0xFF1E293B),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Mulai tulis catatan Anda di sini...',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Status bar bawah editor
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.03),
                  border: const Border(
                    top: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$wordCount kata · $charCount karakter',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      _isPinned ? 'Disematkan' : 'Catatan Lokal',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
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
