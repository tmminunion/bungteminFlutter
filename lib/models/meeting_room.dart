int _i(dynamic v) => int.tryParse((v ?? '0').toString()) ?? 0;

String _s(dynamic v, [String fallback = '']) {
  final t = (v ?? '').toString();
  return t.isEmpty ? fallback : t;
}

bool _b(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

/// Peserta (kehadiran) pada room meeting.
class MeetingPeserta {
  const MeetingPeserta({
    required this.id,
    required this.nama,
    required this.noreg,
    this.jabatan = '',
    this.statusKehadiran = 'pending',
    this.waktuAbsen = '',
    this.metodeAbsen = '',
  });

  final int id;
  final String nama;
  final String noreg;
  final String jabatan;
  final String statusKehadiran;
  final String waktuAbsen;
  final String metodeAbsen;

  factory MeetingPeserta.fromJson(Map<String, dynamic> j) => MeetingPeserta(
        id: _i(j['id']),
        nama: _s(j['nama'], '-'),
        noreg: _s(j['noreg'], '-'),
        jabatan: _s(j['jabatan']),
        statusKehadiran: _s(j['status_kehadiran'], 'pending').toLowerCase(),
        waktuAbsen: _s(j['waktu_absen']),
        metodeAbsen: _s(j['metode_absen']),
      );
}

/// Poin Voice Member / Rekomendasi (notulen) pada room meeting.
class MeetingNotulen {
  const MeetingNotulen({
    required this.id,
    required this.topik,
    this.pembicara = '',
    this.isiDiskusi = '',
    this.keputusan = '',
  });

  final int id;
  final String topik;
  final String pembicara;
  final String isiDiskusi;
  final String keputusan;

  factory MeetingNotulen.fromJson(Map<String, dynamic> j) => MeetingNotulen(
        id: _i(j['id']),
        topik: _s(j['topik'], '-'),
        pembicara: _s(j['pembicara']),
        isiDiskusi: _s(j['isi_diskusi']),
        keputusan: _s(j['keputusan']),
      );
}

/// Checklist kelengkapan 4 tab (Kehadiran, Foto, Resume, Voice Member).
class MeetingProgress {
  const MeetingProgress({
    this.absensiOk = false,
    this.voiceOk = false,
    this.resumeOk = false,
    this.galeriOk = false,
    this.completedTabs = 0,
    this.percent = 0,
    this.missing = const [],
    this.isReadyForReview = false,
    this.minResumeWords = 30,
    this.resumeWordCount = 0,
    this.incentiveUnlocked = false,
  });

  final bool absensiOk;
  final bool voiceOk;
  final bool resumeOk;
  final bool galeriOk;
  final int completedTabs;
  final int percent;
  final List<String> missing;
  final bool isReadyForReview;
  final int minResumeWords;
  final int resumeWordCount;
  final bool incentiveUnlocked;

  factory MeetingProgress.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const MeetingProgress();
    final miss = j['missing'];
    return MeetingProgress(
      absensiOk: _b(j['absensi_ok']),
      voiceOk: _b(j['voice_ok']),
      resumeOk: _b(j['resume_ok']),
      galeriOk: _b(j['galeri_ok']),
      completedTabs: _i(j['completed_tabs']),
      percent: _i(j['percent']),
      missing: miss is List ? miss.map((e) => e.toString()).toList() : const [],
      isReadyForReview: _b(j['is_ready_for_review']),
      minResumeWords: _i(j['min_resume_words']) > 0 ? _i(j['min_resume_words']) : 30,
      resumeWordCount: _i(j['resume_word_count']),
      incentiveUnlocked: _b(j['incentive_unlocked']),
    );
  }
}

/// Data lengkap room meeting (`GET /btapi/Meeting/room/:id`).
class MeetingRoomData {
  const MeetingRoomData({
    required this.id,
    required this.uuid,
    required this.judul,
    required this.kategori,
    required this.tanggal,
    required this.jamMulai,
    required this.tempat,
    required this.tipeMeeting,
    required this.status,
    required this.pimpinanRapat,
    required this.notulis,
    required this.kpNama,
    required this.plenoNama,
    required this.kesimpulan,
    required this.tindakLanjut,
    required this.pesertas,
    required this.notulens,
    required this.totalPeserta,
    required this.totalHadir,
    required this.totalPending,
    required this.totalIzinSakit,
    required this.canManage,
    required this.canChangeStatus,
    required this.progress,
    required this.resumeFileUrl,
    required this.fotoUrl,
    required this.undanganUrl,
    required this.resumeUrl,
    required this.dokumenUrl,
  });

  final int id;
  final String uuid;
  final String judul;
  final String kategori;
  final String tanggal;
  final String jamMulai;
  final String tempat;
  final String tipeMeeting;
  final String status;
  final String pimpinanRapat;
  final String notulis;
  final String kpNama;
  final String plenoNama;
  final String kesimpulan;
  final String tindakLanjut;
  final List<MeetingPeserta> pesertas;
  final List<MeetingNotulen> notulens;
  final int totalPeserta;
  final int totalHadir;
  final int totalPending;
  final int totalIzinSakit;

  /// Pengelola/owner meeting (scan kamera & ubah kehadiran).
  final bool canManage;

  /// Boleh mengisi voice, resume, foto, dan mengubah status.
  final bool canChangeStatus;
  final MeetingProgress progress;
  final String resumeFileUrl;
  final String fotoUrl;
  final String undanganUrl;
  final String resumeUrl;
  final String dokumenUrl;

  /// Referensi QR self check-in (`meeting:<uuid|id>`).
  String get qrData => 'meeting:${uuid.isNotEmpty ? uuid : id}';

  factory MeetingRoomData.fromJson(Map<String, dynamic> json) {
    final m = (json['meeting'] as Map?)?.cast<String, dynamic>() ?? const {};
    final st = (json['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    final peserta = (m['pesertas'] as List?) ?? const [];
    final notulen = (m['notulens'] as List?) ?? const [];

    return MeetingRoomData(
      id: _i(m['id']),
      uuid: _s(m['uuid']),
      judul: _s(m['judul'], 'Tanpa Judul'),
      kategori: _s(m['kategori'], 'Rapat'),
      tanggal: _s(m['tanggal'], '-'),
      jamMulai: _s(m['jam_mulai'], '-'),
      tempat: _s(m['tempat'], '-'),
      tipeMeeting: _s(m['tipe_meeting']),
      status: _s(m['status'], 'planning').toLowerCase(),
      pimpinanRapat: _s(m['pimpinan_rapat']),
      notulis: _s(m['notulis']),
      kpNama: _s(m['kp_nama']),
      plenoNama: _s(m['pleno_nama']),
      kesimpulan: _s(m['kesimpulan']),
      tindakLanjut: _s(m['tindak_lanjut']),
      pesertas: peserta
          .whereType<Map>()
          .map((e) => MeetingPeserta.fromJson(e.cast<String, dynamic>()))
          .toList(),
      notulens: notulen
          .whereType<Map>()
          .map((e) => MeetingNotulen.fromJson(e.cast<String, dynamic>()))
          .toList(),
      totalPeserta: _i(st['total_peserta']),
      totalHadir: _i(st['total_hadir']),
      totalPending: _i(st['total_pending']),
      totalIzinSakit: _i(st['total_izin']) + _i(st['total_sakit']),
      canManage: _b(json['can_manage']),
      canChangeStatus: _b(json['can_change_status']),
      progress: MeetingProgress.fromJson(
        (json['progress'] as Map?)?.cast<String, dynamic>(),
      ),
      resumeFileUrl: _s(json['resume_file_url']),
      fotoUrl: _s(json['foto_dokumentasi_url']),
      undanganUrl: _s(json['undangan_url']),
      resumeUrl: _s(json['resume_url']),
      dokumenUrl: _s(json['dokumen_url']),
    );
  }
}
