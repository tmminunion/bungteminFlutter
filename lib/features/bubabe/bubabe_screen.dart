import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/session_store.dart';
import '../../core/theme.dart';

class BubabeItem {
  final String id;
  final String title;
  final int price;
  final String category;
  final String condition;
  final String location;
  final String description;
  final String sellerName;
  final String sellerWa;
  final String createdAtIso;

  const BubabeItem({
    required this.id,
    required this.title,
    required this.price,
    required this.category,
    required this.condition,
    required this.location,
    required this.description,
    required this.sellerName,
    required this.sellerWa,
    required this.createdAtIso,
  });

  factory BubabeItem.fromJson(Map<String, dynamic> j) => BubabeItem(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        price: (j['price'] as num?)?.toInt() ?? 0,
        category: (j['category'] ?? 'Lainnya').toString(),
        condition: (j['condition'] ?? 'Bekas Layak').toString(),
        location: (j['location'] ?? 'Karawang').toString(),
        description: (j['description'] ?? '').toString(),
        sellerName: (j['sellerName'] ?? 'Anggota').toString(),
        sellerWa: (j['sellerWa'] ?? '').toString(),
        createdAtIso:
            (j['createdAtIso'] ?? DateTime.now().toIso8601String()).toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'price': price,
        'category': category,
        'condition': condition,
        'location': location,
        'description': description,
        'sellerName': sellerName,
        'sellerWa': sellerWa,
        'createdAtIso': createdAtIso,
      };
}

class BubabeScreen extends StatefulWidget {
  final UserSession? session;

  const BubabeScreen({super.key, this.session});

  @override
  State<BubabeScreen> createState() => _BubabeScreenState();
}

class _BubabeScreenState extends State<BubabeScreen> {
  static const _storageKey = 'bubabe_items_v1';

  static const List<String> _categories = [
    'Semua',
    'Elektronik',
    'Otomotif',
    'Rumah Tangga',
    'Perlengkapan Kerja',
    'Lainnya',
  ];

  static const List<String> _conditions = [
    'Bekas Mulus',
    'Bekas Layak',
    'Seperti Baru',
  ];

  List<BubabeItem> _items = [];
  String _selectedCat = 'Semua';
  String _searchQuery = '';
  bool _loading = true;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    List<BubabeItem> items = [];

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        items = decoded
            .map((e) => BubabeItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  String _formatRupiah(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) {
        buf.write('.');
      }
    }
    return 'Rp $buf';
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Elektronik':
        return Icons.devices_other_rounded;
      case 'Otomotif':
        return Icons.directions_car_filled_rounded;
      case 'Rumah Tangga':
        return Icons.chair_rounded;
      case 'Perlengkapan Kerja':
        return Icons.engineering_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }

  Future<void> _contactSeller(BubabeItem item) async {
    var hp = item.sellerWa.replaceAll(RegExp(r'[^0-9]'), '');
    if (hp.startsWith('0')) {
      hp = '62${hp.substring(1)}';
    }
    if (hp.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp penjual belum tersedia.')),
      );
      return;
    }
    final text = Uri.encodeComponent(
      'Halo ${item.sellerName}, saya lihat iklan "${item.title}" (${_formatRupiah(item.price)}) di Bubabe Bungtemin. Apakah masih tersedia?',
    );
    final uri = Uri.parse('https://wa.me/$hp?text=$text');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openCreateSheet() async {
    final titleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final locCtrl = TextEditingController(text: 'Karawang');
    final waCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'Elektronik';
    String condition = 'Bekas Mulus';

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
                const Text(
                  'Pasang Barang Bekas (Bubabe)',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Barang *',
                    hintText: 'Contoh: Helm Safety / Sepeda Lipat / Monitor',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga (Rp) *',
                          hintText: '250000',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: locCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Lokasi / Plant',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(labelText: 'Kategori'),
                        items: _categories
                            .where((c) => c != 'Semua')
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => category = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: condition,
                        decoration: const InputDecoration(labelText: 'Kondisi'),
                        items: _conditions
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => condition = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: waCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor WhatsApp Penjual *',
                    hintText: '08xxxxxxxxxx',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan / Kelengkapan',
                    hintText: 'Kondisi fisik, minus (jika ada), COD area...',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      final price = int.tryParse(
                            priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                          ) ??
                          0;
                      final wa = waCtrl.text.trim();
                      if (title.isEmpty || price <= 0 || wa.isEmpty) return;

                      final newItem = BubabeItem(
                        id: 'bbb_${DateTime.now().millisecondsSinceEpoch}',
                        title: title,
                        price: price,
                        category: category,
                        condition: condition,
                        location: locCtrl.text.trim().isEmpty
                            ? 'Karawang'
                            : locCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        sellerName: widget.session?.nama ?? 'Anggota Bungtemin',
                        sellerWa: wa,
                        createdAtIso: DateTime.now().toIso8601String(),
                      );

                      setState(() {
                        _items.insert(0, newItem);
                      });
                      await _saveItems();
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.publish_rounded),
                    label: const Text(
                      'Terbitkan Iklan',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

  void _openDetail(BubabeItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.of(ctx).padding.bottom + 20,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.category,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.condition,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatRupiah(item.price),
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: AppColors.emerald,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  '${item.sellerName} · ${item.location}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                item.description,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: Color(0xFF334155),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                IconButton(
                  onPressed: () async {
                    setState(() {
                      _items.removeWhere((x) => x.id == item.id);
                    });
                    await _saveItems();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Hapus Iklan',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _contactSeller(item),
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text(
                      'Hubungi via WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = _items.where((item) {
      if (_selectedCat != 'Semua' && item.category != _selectedCat) {
        return false;
      }
      if (q.isNotEmpty) {
        return item.title.toLowerCase().contains(q) ||
            item.description.toLowerCase().contains(q) ||
            item.location.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bubabe · Bursa Barang Bekas',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text(
          'Jual Barang',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bursa jual-beli barang bekas sesama anggota PUK SP LEM SPSI PT. TMMIN.',
                        style:
                            TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Cari barang, lokasi plant, atau deskripsi...',
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
                            final selected = _selectedCat == cat;
                            return ChoiceChip(
                              label: Text(cat),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _selectedCat = cat),
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
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.storefront_rounded,
                                  size: 56,
                                  color: AppColors.muted.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Belum ada barang di bursa',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tap "+ Jual Barang" untuk memasang barang bekas Anda.',
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
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, idx) {
                            final item = filtered[idx];
                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => _openDetail(item),
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
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: AppColors.navy
                                              .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          _categoryIcon(item.category),
                                          color: AppColors.navy,
                                          size: 26,
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
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.navy,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _formatRupiah(item.price),
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.emerald,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${item.condition} · ${item.location} · ${item.sellerName}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Color(0xFF94A3B8),
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
}
