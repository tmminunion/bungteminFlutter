import 'dart:convert';

class TrainingEventItem {
  const TrainingEventItem({
    required this.id,
    required this.eventSlug,
    required this.namaAcara,
    required this.tanggalAcara,
    required this.tempat,
    this.kategori = 'register',
  });

  final int id;
  final String eventSlug;
  final String namaAcara;
  final String tanggalAcara;
  final String tempat;
  final String kategori;

  static const List<String> localThumbs = [
    'assets/hd/ae.jpg',
    'assets/hd/pe.jpg',
    'assets/hd/se.jpg',
    'assets/hd/or.jpg',
    'assets/hd/so.jpg',
  ];

  String get thumbnailAsset => localThumbs[id.abs() % localThumbs.length];

  String get formattedTanggal => formatTanggalIndo(tanggalAcara);

  int? get monthNumber {
    if (tanggalAcara.trim().isEmpty) return null;
    final normalized = tanggalAcara.trim().replaceFirst(' ', 'T');
    final dt = DateTime.tryParse(normalized);
    return dt?.month;
  }

  static String formatTanggalIndo(String dateStr) {
    final clean = dateStr.trim();
    if (clean.isEmpty) return 'Jadwal menyusul';
    final dt = DateTime.tryParse(clean.replaceFirst(' ', 'T'));
    if (dt == null) return clean;
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final dd = dt.day.toString().padLeft(2, '0');
    final mmmm = months[dt.month - 1];
    return '$dd $mmmm ${dt.year}';
  }

  factory TrainingEventItem.fromJson(Map<String, dynamic> json) {
    final rawId = int.tryParse((json['id'] ?? '0').toString()) ?? 0;
    final slug =
        (json['event_slug'] ?? json['idnya'] ?? json['id'] ?? '').toString();
    return TrainingEventItem(
      id: rawId,
      eventSlug: slug,
      namaAcara:
          (json['namaAcara'] ?? json['judul'] ?? 'Agenda Training PUK SPSI')
              .toString(),
      tanggalAcara: (json['tanggalAcara'] ?? json['tanggal'] ?? '').toString(),
      tempat: (json['tempat'] ?? json['lokasi'] ?? '').toString(),
      kategori: (json['kategori'] ?? 'register').toString(),
    );
  }
}

class TrainingPageResponse {
  const TrainingPageResponse({
    required this.data,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<TrainingEventItem> data;
  final int page;
  final int lastPage;
  final int total;
}

class TrainingTicketItem {
  const TrainingTicketItem({
    required this.id,
    required this.eventSlug,
    required this.nama,
    required this.noreg,
    required this.token,
    required this.used,
    required this.eventNama,
    required this.tgl,
  });

  final int id;
  final String eventSlug;
  final String nama;
  final String noreg;
  final String token;
  final bool used;
  final String eventNama;
  final String tgl;

  String get qrPayload => 'untukabsen:$token';

  String get formattedTanggal => TrainingEventItem.formatTanggalIndo(tgl);

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_slug': eventSlug,
        'nama': nama,
        'noreg': noreg,
        'token': token,
        'used': used,
        'event_nama': eventNama,
        'tgl': tgl,
      };

  factory TrainingTicketItem.fromApiOrCache(Map<String, dynamic> json) {
    final eventObj = json['event'];
    final eventMap = eventObj is Map
        ? Map<String, dynamic>.from(eventObj)
        : const <String, dynamic>{};

    final rawUsed = json['used'];
    final statusStr = (json['status'] ?? '').toString();
    // Sama persis dengan logic bungteminAPP: `used: t.status !== 'CheckIn'`
    final resolvedUsed =
        rawUsed is bool ? rawUsed : (statusStr != 'CheckIn');

    return TrainingTicketItem(
      id: int.tryParse((json['id'] ?? '0').toString()) ?? 0,
      eventSlug: (json['event_slug'] ?? json['idnya'] ?? '').toString(),
      nama: (json['nama'] ?? '').toString(),
      noreg: (json['noreg'] ?? '').toString(),
      token: (json['token'] ?? json['Kode'] ?? '').toString(),
      used: resolvedUsed,
      eventNama: (json['event_nama'] ??
              eventMap['namaAcara'] ??
              'Agenda Training PUK SPSI')
          .toString(),
      tgl: (json['tgl'] ?? eventMap['tanggalAcara'] ?? '').toString(),
    );
  }

  static List<TrainingTicketItem> decodeList(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) =>
              TrainingTicketItem.fromApiOrCache(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String encodeList(List<TrainingTicketItem> list) {
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }
}

class BukuPintarItem {
  const BukuPintarItem({
    required this.id,
    required this.title,
    required this.sub,
    required this.desc,
    required this.url,
    required this.jsonAsset,
    required this.badge,
  });

  final String id;
  final String title;
  final String sub;
  final String desc;
  final String url;
  final String jsonAsset;
  final String badge;

  static const List<BukuPintarItem> defaults = [
    BukuPintarItem(
      id: 'uu-13-2003',
      title: 'UU NOMOR 13 TAHUN 2003',
      sub: 'KETENAGAKERJAAN',
      desc:
          'Pokok-pokok hak normatif pekerja, hubungan kerja, waktu kerja, pengupahan, dan perlindungan tenaga kerja.',
      url: 'assets/doc/1.pdf',
      jsonAsset: 'assets/doc/1.json',
      badge: 'Regulasi Utama',
    ),
    BukuPintarItem(
      id: 'uu-21-2000',
      title: 'UU NOMOR 21 TAHUN 2000',
      sub: 'SERIKAT PEKERJA / SERIKAT BURUH',
      desc:
          'Dasar hukum pembentukan, fungsi, hak berorganisasi, dan perlindungan aktivitas serikat pekerja.',
      url: 'assets/doc/2.pdf',
      jsonAsset: 'assets/doc/2.json',
      badge: 'Serikat Pekerja',
    ),
  ];
}
