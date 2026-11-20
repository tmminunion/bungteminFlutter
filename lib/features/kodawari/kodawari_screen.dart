import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';

enum TaskPriority { low, medium, high }

class KodawariGroup {
  final String id;
  final String name;
  final int colorValue;
  final int iconCodePoint;

  const KodawariGroup({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
  });

  factory KodawariGroup.fromJson(Map<String, dynamic> j) => KodawariGroup(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? 'Umum').toString(),
        colorValue: (j['colorValue'] as num?)?.toInt() ?? 0xFF2563EB,
        iconCodePoint:
            (j['iconCodePoint'] as num?)?.toInt() ?? Icons.folder_rounded.codePoint,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'iconCodePoint': iconCodePoint,
      };

  KodawariGroup copyWith({
    String? name,
    int? colorValue,
    int? iconCodePoint,
  }) =>
      KodawariGroup(
        id: id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      );
}

class KodawariTask {
  final String id;
  final String groupId;
  final String title;
  final String notes;
  final bool isDone;
  final TaskPriority priority;
  final String? dueDateIso;
  final String createdAtIso;

  const KodawariTask({
    required this.id,
    required this.groupId,
    required this.title,
    this.notes = '',
    this.isDone = false,
    this.priority = TaskPriority.medium,
    this.dueDateIso,
    required this.createdAtIso,
  });

  factory KodawariTask.fromJson(Map<String, dynamic> j) {
    final pStr = (j['priority'] ?? 'medium').toString();
    final priority = TaskPriority.values.firstWhere(
      (e) => e.name == pStr,
      orElse: () => TaskPriority.medium,
    );
    return KodawariTask(
      id: (j['id'] ?? '').toString(),
      groupId: (j['groupId'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      notes: (j['notes'] ?? '').toString(),
      isDone: j['isDone'] == true,
      priority: priority,
      dueDateIso: j['dueDateIso'] as String?,
      createdAtIso: (j['createdAtIso'] ?? DateTime.now().toIso8601String()).toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'title': title,
        'notes': notes,
        'isDone': isDone,
        'priority': priority.name,
        'dueDateIso': dueDateIso,
        'createdAtIso': createdAtIso,
      };

  KodawariTask copyWith({
    String? groupId,
    String? title,
    String? notes,
    bool? isDone,
    TaskPriority? priority,
    String? dueDateIso,
    bool clearDueDate = false,
  }) =>
      KodawariTask(
        id: id,
        groupId: groupId ?? this.groupId,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        isDone: isDone ?? this.isDone,
        priority: priority ?? this.priority,
        dueDateIso: clearDueDate ? null : (dueDateIso ?? this.dueDateIso),
        createdAtIso: createdAtIso,
      );
}

class KodawariScreen extends StatefulWidget {
  const KodawariScreen({super.key});

  @override
  State<KodawariScreen> createState() => _KodawariScreenState();
}

class _KodawariScreenState extends State<KodawariScreen> {
  static const _groupsKey = 'kodawari_task_groups_v1';
  static const _tasksKey = 'kodawari_tasks_v1';

  static final List<Color> _palette = [
    const Color(0xFF2563EB), // Blue
    const Color(0xFF0F766E), // Teal
    const Color(0xFFD97706), // Amber
    const Color(0xFF7C3AED), // Violet
    const Color(0xFFDC2626), // Red
    const Color(0xFF059669), // Emerald
  ];

  static final List<IconData> _groupIcons = [
    Icons.work_outline_rounded,
    Icons.groups_rounded,
    Icons.checklist_rounded,
    Icons.precision_manufacturing_rounded,
    Icons.person_outline_rounded,
    Icons.bolt_rounded,
  ];

  static IconData _resolveGroupIcon(int codePoint) {
    for (final icon in _groupIcons) {
      if (icon.codePoint == codePoint) return icon;
    }
    return Icons.folder_rounded;
  }

  List<KodawariGroup> _groups = [];
  List<KodawariTask> _tasks = [];
  String? _selectedGroupId; // null = Semua Grup
  String _statusFilter = 'all'; // all | active | done | high
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawGroups = prefs.getString(_groupsKey);
    final rawTasks = prefs.getString(_tasksKey);

    List<KodawariGroup> groups = [];
    List<KodawariTask> tasks = [];

    if (rawGroups != null && rawGroups.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawGroups) as List<dynamic>;
        groups = decoded
            .map((e) => KodawariGroup.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }

    if (rawTasks != null && rawTasks.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTasks) as List<dynamic>;
        tasks = decoded
            .map((e) => KodawariTask.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }

    if (groups.isEmpty) {
      groups = [
        KodawariGroup(
          id: 'grp_kerja',
          name: 'Pekerjaan & Line',
          colorValue: _palette[0].toARGB32(),
          iconCodePoint: Icons.precision_manufacturing_rounded.codePoint,
        ),
        KodawariGroup(
          id: 'grp_org',
          name: 'Organisasi & Meeting',
          colorValue: _palette[1].toARGB32(),
          iconCodePoint: Icons.groups_rounded.codePoint,
        ),
        KodawariGroup(
          id: 'grp_pribadi',
          name: 'Pribadi',
          colorValue: _palette[2].toARGB32(),
          iconCodePoint: Icons.person_outline_rounded.codePoint,
        ),
      ];
      await prefs.setString(
        _groupsKey,
        jsonEncode(groups.map((e) => e.toJson()).toList()),
      );
    }

    if (!mounted) return;
    setState(() {
      _groups = groups;
      _tasks = tasks;
      _loading = false;
    });
  }

  Future<void> _saveGroups() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _groupsKey,
      jsonEncode(_groups.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _tasksKey,
      jsonEncode(_tasks.map((e) => e.toJson()).toList()),
    );
  }

  KodawariGroup? _groupById(String id) {
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return _groups.isNotEmpty ? _groups.first : null;
  }

  List<KodawariTask> get _filteredTasks {
    final list = _tasks.where((t) {
      if (_selectedGroupId != null && t.groupId != _selectedGroupId) {
        return false;
      }
      if (_statusFilter == 'active' && t.isDone) return false;
      if (_statusFilter == 'done' && !t.isDone) return false;
      if (_statusFilter == 'high' && (t.priority != TaskPriority.high || t.isDone)) {
        return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      final pCmp = b.priority.index.compareTo(a.priority.index);
      if (pCmp != 0) return pCmp;
      return b.createdAtIso.compareTo(a.createdAtIso);
    });
    return list;
  }

  Future<void> _toggleTask(KodawariTask task) async {
    setState(() {
      _tasks = _tasks
          .map((t) => t.id == task.id ? t.copyWith(isDone: !t.isDone) : t)
          .toList();
    });
    await _saveTasks();
  }

  Future<void> _deleteTask(KodawariTask task) async {
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
    });
    await _saveTasks();
  }

  Future<void> _clearCompleted() async {
    final doneCount = _tasks.where((t) => t.isDone).length;
    if (doneCount == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bersihkan Tugas Selesai?'),
        content: Text('Hapus $doneCount tugas yang sudah selesai?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _tasks.removeWhere((t) => t.isDone);
    });
    await _saveTasks();
  }

  Future<void> _openGroupSheet({KodawariGroup? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    int chosenColor = editing?.colorValue ?? _palette.first.toARGB32();
    int chosenIcon = editing?.iconCodePoint ?? _groupIcons.first.codePoint;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom +
                20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                editing == null ? 'Buat Task Group Baru' : 'Edit Task Group',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nama Task Group',
                  hintText: 'Contoh: Persiapan Audit 5R',
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Warna Label',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: _palette.map((c) {
                  final selected = c.toARGB32() == chosenColor;
                  return GestureDetector(
                    onTap: () => setModalState(() => chosenColor = c.toARGB32()),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: AppColors.navy, width: 3)
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Text(
                'Ikon Grup',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: _groupIcons.map((ic) {
                  final selected = ic.codePoint == chosenIcon;
                  return GestureDetector(
                    onTap: () => setModalState(() => chosenIcon = ic.codePoint),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? Color(chosenColor).withValues(alpha: 0.16)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? Color(chosenColor) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Icon(
                        ic,
                        color: selected ? Color(chosenColor) : const Color(0xFF64748B),
                        size: 20,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (editing != null && _groups.length > 1)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final fallbackId = _groups
                              .firstWhere((g) => g.id != editing.id)
                              .id;
                          setState(() {
                            _groups.removeWhere((g) => g.id == editing.id);
                            _tasks = _tasks
                                .map((t) => t.groupId == editing.id
                                    ? t.copyWith(groupId: fallbackId)
                                    : t)
                                .toList();
                            if (_selectedGroupId == editing.id) {
                              _selectedGroupId = null;
                            }
                          });
                          await _saveGroups();
                          await _saveTasks();
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  if (editing != null && _groups.length > 1) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        setState(() {
                          if (editing == null) {
                            final newGrp = KodawariGroup(
                              id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
                              name: name,
                              colorValue: chosenColor,
                              iconCodePoint: chosenIcon,
                            );
                            _groups.add(newGrp);
                            _selectedGroupId = newGrp.id;
                          } else {
                            _groups = _groups
                                .map((g) => g.id == editing.id
                                    ? g.copyWith(
                                        name: name,
                                        colorValue: chosenColor,
                                        iconCodePoint: chosenIcon,
                                      )
                                    : g)
                                .toList();
                          }
                        });
                        await _saveGroups();
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        editing == null ? 'Simpan Grup' : 'Perbarui Grup',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
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

  Future<void> _openTaskSheet({KodawariTask? editing}) async {
    if (_groups.isEmpty) return;
    final titleCtrl = TextEditingController(text: editing?.title ?? '');
    final notesCtrl = TextEditingController(text: editing?.notes ?? '');
    String groupId = editing?.groupId ?? _selectedGroupId ?? _groups.first.id;
    if (!_groups.any((g) => g.id == groupId)) {
      groupId = _groups.first.id;
    }
    TaskPriority priority = editing?.priority ?? TaskPriority.medium;
    DateTime? dueDate = editing?.dueDateIso != null
        ? DateTime.tryParse(editing!.dueDateIso!)
        : null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom +
                20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  editing == null ? 'Tambah Tugas Baru' : 'Edit Tugas',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  autofocus: editing == null,
                  decoration: const InputDecoration(
                    labelText: 'Judul Tugas *',
                    hintText: 'Contoh: Cek daftar hadir Meeting Pleno',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan / Rincian (Opsional)',
                    hintText: 'Detail singkat atau PIC terkait...',
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Task Group',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _groups.map((g) {
                    final selected = g.id == groupId;
                    final c = Color(g.colorValue);
                    return ChoiceChip(
                      label: Text(g.name),
                      selected: selected,
                      selectedColor: c.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: selected ? c : const Color(0xFF334155),
                      ),
                      side: BorderSide(color: selected ? c : const Color(0xFFE2E8F0)),
                      onSelected: (_) => setModalState(() => groupId = g.id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prioritas',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 6),
                          SegmentedButton<TaskPriority>(
                            segments: const [
                              ButtonSegment(value: TaskPriority.low, label: Text('Rendah')),
                              ButtonSegment(value: TaskPriority.medium, label: Text('Sedang')),
                              ButtonSegment(value: TaskPriority.high, label: Text('Tinggi')),
                            ],
                            selected: {priority},
                            onSelectionChanged: (s) =>
                                setModalState(() => priority = s.first),
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              textStyle: WidgetStateProperty.all(
                                const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: dueDate ?? DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setModalState(() => dueDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(
                          dueDate == null
                              ? 'Set Tenggat Tanggal'
                              : _formatDate(dueDate!),
                        ),
                      ),
                    ),
                    if (dueDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => setModalState(() => dueDate = null),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Hapus tanggal',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      final notes = notesCtrl.text.trim();
                      final dueIso = dueDate?.toIso8601String();
                      setState(() {
                        if (editing == null) {
                          _tasks.insert(
                            0,
                            KodawariTask(
                              id: 'tsk_${DateTime.now().millisecondsSinceEpoch}',
                              groupId: groupId,
                              title: title,
                              notes: notes,
                              priority: priority,
                              dueDateIso: dueIso,
                              createdAtIso: DateTime.now().toIso8601String(),
                            ),
                          );
                        } else {
                          _tasks = _tasks
                              .map((t) => t.id == editing.id
                                  ? t.copyWith(
                                      groupId: groupId,
                                      title: title,
                                      notes: notes,
                                      priority: priority,
                                      dueDateIso: dueIso,
                                      clearDueDate: dueIso == null,
                                    )
                                  : t)
                              .toList();
                        }
                      });
                      await _saveTasks();
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      editing == null ? 'Simpan Tugas' : 'Simpan Perubahan',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
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

  @override
  Widget build(BuildContext context) {
    final total = _tasks.length;
    final done = _tasks.where((t) => t.isDone).length;
    final active = total - done;
    final highActive =
        _tasks.where((t) => !t.isDone && t.priority == TaskPriority.high).length;
    final pct = total == 0 ? 0.0 : done / total;
    final filtered = _filteredTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kodawari · Task & To-Do',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            onPressed: () => _openGroupSheet(),
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Buat Task Group',
          ),
          if (done > 0)
            IconButton(
              onPressed: _clearCompleted,
              icon: const Icon(Icons.cleaning_services_outlined),
              tooltip: 'Hapus Tugas Selesai',
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskSheet(),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Tugas Baru', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. Header Progress Summary
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.navy, AppColors.navySoft],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'RINGKASAN PRODUKTIVITAS',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            '${(pct * 100).round()}% Selesai',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 7,
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _statPill('Total', '$total', Colors.white),
                          const SizedBox(width: 8),
                          _statPill('Aktif', '$active', AppColors.auroraCyan),
                          const SizedBox(width: 8),
                          _statPill('Selesai', '$done', AppColors.emerald),
                          const SizedBox(width: 8),
                          _statPill('Prioritas', '$highActive', AppColors.rose),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Task Groups Horizontal Carousel
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _groups.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (ctx, idx) {
                      if (idx == 0) {
                        final isAll = _selectedGroupId == null;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedGroupId = null),
                          child: Container(
                            width: 132,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isAll ? AppColors.navy : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isAll ? AppColors.navy : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  Icons.apps_rounded,
                                  color: isAll ? AppColors.gold : AppColors.navy,
                                  size: 20,
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Semua Grup',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isAll ? Colors.white : AppColors.navy,
                                      ),
                                    ),
                                    Text(
                                      '$active aktif · $total total',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isAll
                                            ? Colors.white70
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final grp = _groups[idx - 1];
                      final selected = _selectedGroupId == grp.id;
                      final grpColor = Color(grp.colorValue);
                      final grpTasks = _tasks.where((t) => t.groupId == grp.id).toList();
                      final grpDone = grpTasks.where((t) => t.isDone).length;
                      final grpPct = grpTasks.isEmpty ? 0.0 : grpDone / grpTasks.length;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedGroupId = grp.id),
                        onLongPress: () => _openGroupSheet(editing: grp),
                        child: Container(
                          width: 164,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected ? grpColor.withValues(alpha: 0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? grpColor : const Color(0xFFE2E8F0),
                              width: selected ? 1.6 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    _resolveGroupIcon(grp.iconCodePoint),
                                    color: grpColor,
                                    size: 19,
                                  ),
                                  GestureDetector(
                                    onTap: () => _openGroupSheet(editing: grp),
                                    child: const Icon(
                                      Icons.more_horiz,
                                      size: 17,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    grp.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(99),
                                          child: LinearProgressIndicator(
                                            value: grpPct,
                                            minHeight: 4,
                                            backgroundColor: const Color(0xFFE2E8F0),
                                            valueColor: AlwaysStoppedAnimation<Color>(grpColor),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$grpDone/${grpTasks.length}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 3. Filter Chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('all', 'Semua'),
                        const SizedBox(width: 8),
                        _filterChip('active', 'Aktif'),
                        const SizedBox(width: 8),
                        _filterChip('high', 'Prioritas Tinggi'),
                        const SizedBox(width: 8),
                        _filterChip('done', 'Selesai'),
                      ],
                    ),
                  ),
                ),

                // 4. Task List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.task_alt_rounded,
                                  size: 56,
                                  color: AppColors.muted.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Belum ada tugas di daftar ini',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tap "+ Tugas Baru" untuk mulai menyusun agenda Anda.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 92),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final task = filtered[idx];
                            final grp = _groupById(task.groupId);
                            final grpColor = Color(grp?.colorValue ?? 0xFF2563EB);
                            final due = task.dueDateIso != null
                                ? DateTime.tryParse(task.dueDateIso!)
                                : null;
                            final now = DateTime.now();
                            final today = DateTime(now.year, now.month, now.day);
                            final isOverdue = !task.isDone &&
                                due != null &&
                                DateTime(due.year, due.month, due.day).isBefore(today);

                            return Dismissible(
                              key: ValueKey(task.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete_outline, color: Colors.white),
                              ),
                              onDismissed: (_) => _deleteTask(task),
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _openTaskSheet(editing: task),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Checkbox(
                                          value: task.isDone,
                                          onChanged: (_) => _toggleTask(task),
                                          activeColor: AppColors.emerald,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                task.title,
                                                style: TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: task.isDone
                                                      ? AppColors.muted
                                                      : AppColors.navy,
                                                  decoration: task.isDone
                                                      ? TextDecoration.lineThrough
                                                      : null,
                                                ),
                                              ),
                                              if (task.notes.isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  task.notes,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: [
                                                  if (grp != null)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: grpColor.withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        grp.name,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: grpColor,
                                                        ),
                                                      ),
                                                    ),
                                                  _priorityBadge(task.priority),
                                                  if (due != null)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: isOverdue
                                                            ? const Color(0xFFFEE2E2)
                                                            : const Color(0xFFF1F5F9),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.event_rounded,
                                                            size: 12,
                                                            color: isOverdue
                                                                ? const Color(0xFFDC2626)
                                                                : const Color(0xFF475569),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            _formatDate(due),
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w700,
                                                              color: isOverdue
                                                                  ? const Color(0xFFDC2626)
                                                                  : const Color(0xFF475569),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
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
              ],
            ),
    );
  }

  Widget _statPill(String label, String value, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final selected = _statusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = key),
      selectedColor: AppColors.navy,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : const Color(0xFF475569),
      ),
      side: BorderSide(color: selected ? AppColors.navy : const Color(0xFFE2E8F0)),
    );
  }

  Widget _priorityBadge(TaskPriority p) {
    final (String text, Color bg, Color fg) = switch (p) {
      TaskPriority.high => ('Tinggi', const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
      TaskPriority.medium => ('Sedang', const Color(0xFFFEF3C7), const Color(0xFFD97706)),
      TaskPriority.low => ('Rendah', const Color(0xFFE0F2FE), const Color(0xFF0284C7)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
