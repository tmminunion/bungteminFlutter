import 'dart:convert';


/// Model tiket / baris kehadiran peserta (tabel `absensi`).
class MyArsTicket {
  const MyArsTicket({
    required this.id,
    required this.idnya,
    required this.nama,
    required this.noreg,
    required this.kp,
    required this.acara,
    required this.tanggal,
    required this.jamMasuk,
    required this.jamKeluar,
    required this.kategori,
    required this.komisi,
    required this.divisi,
    required this.plant,
    required this.kode,
    required this.status,
    required this.sertifikat,
    required this.sertifikatval,
    required this.createdAt,
  });

  final int id;
  final String idnya;
  final String nama;
  final String noreg;
  final String kp;
  final String acara;
  final String tanggal;
  final String jamMasuk;
  final String jamKeluar;
  final String kategori;
  final String komisi;
  final String divisi;
  final String plant;
  final String kode;
  final String status;
  final String sertifikat;
  final String sertifikatval;
  final String createdAt;

  bool get isCheckIn => status == 'CheckIn';

  /// Sesuai `TiketdetailPage.updateUI`: JSON `{n, r, c}`.
  String get qrCodePayload => jsonEncode(<String, dynamic>{
        'n': nama,
        'r': noreg,
        'c': kode,
      });

  String get avatarUrl {
    final clean = noreg.trim();
    if (clean.isEmpty) return '';
    return 'https://bungtemin.net/btapi/Calendar/hravatar/$clean';
  }

  /// Sesuai `TiketlistPage.filteredEvents`.
  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = '$acara $kode $kategori $komisi'.toLowerCase();
    return haystack.contains(q);
  }

  factory MyArsTicket.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? 0;
    }

    String str(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString() != 'null') return v.toString();
      }
      return '';
    }

    return MyArsTicket(
      id: parseInt(json['id']),
      idnya: str(const ['idnya', 'event_slug']),
      nama: str(const ['nama']),
      noreg: str(const ['noreg']),
      kp: str(const ['KP', 'kp']),
      acara: str(const ['Acara', 'acara', 'namaAcara']),
      tanggal: str(const ['tanggal']),
      jamMasuk: str(const ['jam_masuk', 'jamMasuk']),
      jamKeluar: str(const ['jam_keluar', 'jamKeluar']),
      kategori: str(const ['kategori', 'Kategori']),
      komisi: str(const ['komisi', 'Komisi']),
      divisi: str(const ['divisi']),
      plant: str(const ['plant']),
      kode: str(const ['Kode', 'kode']),
      status: str(const ['status']),
      sertifikat: str(const ['sertifikat']),
      sertifikatval: str(const ['sertifikatval']),
      createdAt: str(const ['CreatedAt', 'createdAt', 'created_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'idnya': idnya,
        'nama': nama,
        'noreg': noreg,
        'KP': kp,
        'Acara': acara,
        'tanggal': tanggal,
        'jam_masuk': jamMasuk,
        'jam_keluar': jamKeluar,
        'kategori': kategori,
        'komisi': komisi,
        'divisi': divisi,
        'plant': plant,
        'Kode': kode,
        'status': status,
        'sertifikat': sertifikat,
        'sertifikatval': sertifikatval,
        'CreatedAt': createdAt,
      };

  /// Sesuai `TiketdetailPage.formatDivisi`.
  static String formatDivisi(String divisi) {
    if (divisi.trim().isEmpty) return '-';
    final compact = divisi
        .replaceAll(RegExp(r'\bProduction\b', caseSensitive: false), 'Prod.')
        .replaceAll(RegExp(r'\bDivision\b', caseSensitive: false), 'Div.')
        .replaceAll(RegExp(r'\bEngineering\b', caseSensitive: false), 'Eng.')
        .replaceAll(RegExp(r'\bMaintenance\b', caseSensitive: false), 'Maint.')
        .replaceAll(RegExp(r'\bDepartment\b', caseSensitive: false), 'Dept.')
        .trim();
    return compact.length > 18 ? '${compact.substring(0, 18).trim()}...' : compact;
  }

  /// Sesuai `moment(date).format('DD MMM YYYY')` atau `DD/MM/YYYY`.
  static String formatDate(String? raw, {bool slashNumeric = false}) {
    final clean = (raw ?? '').trim();
    if (clean.isEmpty) return '-';
    final normalized = clean.contains(' ') && !clean.contains('T')
        ? clean.replaceFirst(' ', 'T')
        : clean;
    final dt = DateTime.tryParse(normalized);
    if (dt == null) return '-';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    if (slashNumeric) return '$dd/$mm/$yyyy';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '$dd ${months[dt.month - 1]} $yyyy';
  }
}

/// Model event absensi (tabel `events`).
class MyArsEvent {
  const MyArsEvent({
    required this.id,
    required this.author,
    required this.authorNama,
    required this.namaAcara,
    required this.kategori,
    required this.role,
    required this.sedia,
    required this.jumlahPeserta,
    required this.tempat,
    required this.barcode,
    required this.tiket,
    required this.sertifikat,
    required this.modelSertifikat,
    required this.eventSlug,
    required this.tanggalAcara,
    required this.privacy,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String author;
  final String authorNama;
  final String namaAcara;
  final String kategori;
  final String role;
  final int sedia;
  final int jumlahPeserta;
  final String tempat;
  final String barcode;
  final int tiket;
  final String sertifikat;
  final String modelSertifikat;
  final String eventSlug;
  final String tanggalAcara;
  final String privacy;
  final String createdAt;
  final String updatedAt;

  String get cameraWebUrl => 'https://nudb.bungtemin.net/camera/$eventSlug';
  String get scannerQrData => 'absensi:$eventSlug';

  factory MyArsEvent.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? 0;
    }

    String str(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString() != 'null') return v.toString();
      }
      return '';
    }

    return MyArsEvent(
      id: parseInt(json['id'] ?? json['event_id']),
      author: str(const ['author']),
      authorNama: str(const ['authornama', 'authorNama']),
      namaAcara: str(const ['namaAcara', 'nama_acara']),
      kategori: str(const ['Kategori', 'kategori']),
      role: str(const ['role']),
      sedia: parseInt(json['sedia']),
      jumlahPeserta: parseInt(json['jumlahPeserta']),
      tempat: str(const ['tempat']),
      barcode: str(const ['barcode']),
      tiket: parseInt(json['Tiket'] ?? json['tiket']),
      sertifikat: str(const ['sertifikat']),
      modelSertifikat: str(const ['modelSertifikat']),
      eventSlug: str(const ['event_slug', 'eventSlug']),
      tanggalAcara: str(const ['tanggalAcara', 'tanggal_acara']),
      privacy: str(const ['privacy']),
      createdAt: str(const ['createdAt', 'created_at']),
      updatedAt: str(const ['updatedAt', 'updated_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'author': author,
        'authornama': authorNama,
        'namaAcara': namaAcara,
        'Kategori': kategori,
        'role': role,
        'sedia': sedia,
        'jumlahPeserta': jumlahPeserta,
        'tempat': tempat,
        'barcode': barcode,
        'Tiket': tiket,
        'sertifikat': sertifikat,
        'modelSertifikat': modelSertifikat,
        'event_slug': eventSlug,
        'tanggalAcara': tanggalAcara,
        'privacy': privacy,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

/// Respons detail absensi event (`/absensi/rakernit2025/api/:slug`).
class MyArsEventDetail {
  const MyArsEventDetail({
    required this.status,
    required this.message,
    required this.peserta,
    required this.sudah,
    required this.belum,
    required this.persentase,
    required this.event,
    required this.data,
  });

  final String status;
  final String message;
  final int peserta;
  final int sudah;
  final int belum;
  final double persentase;
  final MyArsEvent? event;
  final List<MyArsTicket> data;

  int get targetPeserta => event?.jumlahPeserta ?? peserta;

  /// Sesuai `AbsensidetailPage.percentasi()`.
  String get percentasiText {
    final target = targetPeserta;
    if (target <= 0) return '0.00';
    return ((data.length / target) * 100).toStringAsFixed(2);
  }

  /// Sesuai `AbsensidetailPage.percentasi2()`.
  double get percentasiProgress {
    final target = targetPeserta;
    if (target <= 0) return 0.0;
    final val = double.tryParse((data.length / target).toStringAsFixed(2)) ?? 0.0;
    return val.clamp(0.0, 1.0);
  }

  factory MyArsEventDetail.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? 0;
    }

    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse((v ?? '').toString()) ?? 0.0;
    }

    final rawEvent = json['event'];
    final MyArsEvent? parsedEvent = rawEvent is Map
        ? MyArsEvent.fromJson(Map<String, dynamic>.from(rawEvent))
        : null;

    final rawData = json['data'];
    final tickets = rawData is List
        ? rawData
            .whereType<Map>()
            .map((e) => MyArsTicket.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <MyArsTicket>[];

    return MyArsEventDetail(
      status: (json['status'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      peserta: parseInt(json['peserta']),
      sudah: parseInt(json['sudah']),
      belum: parseInt(json['belum']),
      persentase: parseDouble(json['persentase']),
      event: parsedEvent,
      data: tickets,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'status': status,
        'message': message,
        'peserta': peserta,
        'sudah': sudah,
        'belum': belum,
        'persentase': persentase,
        'event': event?.toJson(),
        'data': data.map((e) => e.toJson()).toList(),
      };
}

class MyArsPaginatedResult<T> {
  const MyArsPaginatedResult({
    required this.success,
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  final bool success;
  final List<T> items;
  final int page;
  final int perPage;
  final int total;
  final int lastPage;
}

class MyArsCreateEventResult {
  const MyArsCreateEventResult({
    required this.success,
    required this.message,
    this.event,
  });

  final bool success;
  final String message;
  final MyArsEvent? event;
}

class MyArsScanActionResult {
  const MyArsScanActionResult({
    required this.success,
    required this.header,
    required this.message,
    this.kode = '',
  });

  final bool success;
  final String header;
  final String message;
  final String kode;
}
