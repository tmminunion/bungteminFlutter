class MeetingItem {
  const MeetingItem({
    required this.id,
    required this.kodeMeeting,
    required this.judul,
    required this.kategori,
    required this.tanggal,
    required this.jamMulai,
    required this.tempat,
    required this.status,
    required this.kpNama,
    required this.plenoNama,
    required this.totalPeserta,
    required this.totalHadir,
    this.bidang = '',
    this.pimpinanRapat = '',
    this.kpNo = '',
    this.tarifInsentif = 0,
    this.totalNotulen = 0,
    this.totalAction = 0,
  });

  final int id;
  final String kodeMeeting;
  final String judul;
  final String kategori;
  final String tanggal;
  final String jamMulai;
  final String tempat;
  final String status;
  final String kpNama;
  final String plenoNama;
  final int totalPeserta;
  final int totalHadir;
  final String bidang;
  final String pimpinanRapat;
  final String kpNo;
  final int tarifInsentif;
  final int totalNotulen;
  final int totalAction;

  bool get isPleno => kategori.toLowerCase().contains('pleno');
  bool get isPuk => RegExp(r'\bpuk\b').hasMatch(kategori.toLowerCase());
  bool get isKp => RegExp(r'\bkp\b').hasMatch(kategori.toLowerCase());

  /// Pembagian seperti router organisasi web (`/organisasi/meeting/kategori/...`):
  /// 0 = Rapat PUK, 1 = Rapat KP, 2 = Rapat Pleno, 3 = Rapat Member (Anggota).
  int get segment => isPuk
      ? 0
      : isKp
          ? 1
          : isPleno
              ? 2
              : 3;

  factory MeetingItem.fromJson(Map<String, dynamic> json) {
    return MeetingItem(
      id: int.tryParse((json['id'] ?? '0').toString()) ?? 0,
      kodeMeeting: (json['kode_meeting'] ?? '-').toString(),
      judul: (json['judul'] ?? 'Tanpa Judul').toString(),
      kategori: (json['kategori'] ?? 'Rapat').toString(),
      tanggal: (json['tanggal'] ?? '-').toString(),
      jamMulai: (json['jam_mulai'] ?? '-').toString(),
      tempat: (json['tempat'] ?? '-').toString(),
      status: (json['status'] ?? 'planning').toString(),
      kpNama: (json['kp_nama'] ?? '-').toString(),
      plenoNama: (json['pleno_nama'] ?? '-').toString(),
      totalPeserta: int.tryParse((json['total_peserta'] ?? '0').toString()) ?? 0,
      totalHadir: int.tryParse((json['total_hadir'] ?? '0').toString()) ?? 0,
      bidang: (json['bidang'] ?? '').toString(),
      pimpinanRapat: (json['pimpinan_rapat'] ?? '').toString(),
      kpNo: (json['kp_no'] ?? '').toString(),
      tarifInsentif:
          int.tryParse((json['tarif_insentif'] ?? '0').toString()) ?? 0,
      totalNotulen:
          int.tryParse((json['total_notulen'] ?? '0').toString()) ?? 0,
      totalAction: int.tryParse((json['total_action'] ?? '0').toString()) ?? 0,
    );
  }
}

class MeetingDashboardData {
  const MeetingDashboardData({
    required this.total,
    required this.scheduled,
    required this.ongoing,
    required this.completed,
    required this.meetings,
    this.roleLabel = '',
    this.pctHadir = 0,
  });

  final int total;
  final int scheduled;
  final int ongoing;
  final int completed;
  final List<MeetingItem> meetings;
  final String roleLabel;
  final int pctHadir;
}

class StoryItem {
  const StoryItem({
    required this.id,
    required this.nama,
    required this.caption,
    required this.mediaUrl,
    this.noreg = '',
    this.createdAt = '',
    this.mediaType = 'image',
    this.likes = const [],
    this.commentsCount = 0,
  });

  final String id;
  final String nama;
  final String caption;
  final String mediaUrl;
  final String noreg;
  final String createdAt;
  final String mediaType;
  final List<String> likes;
  final int commentsCount;

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    final rawLikes = json['likes'];
    return StoryItem(
      id: (json['id'] ?? json[r'$id'] ?? '').toString(),
      nama: (json['user_nama'] ?? json['nama'] ?? 'Anggota').toString(),
      caption: (json['pesan'] ?? json['caption'] ?? json['text'] ?? '').toString(),
      mediaUrl: (json['mediaUrl'] ?? json['media_url'] ?? json['url'] ?? '').toString(),
      noreg: (json['noreg'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      mediaType: (json['mediaType'] ?? 'image').toString(),
      likes: rawLikes is List
          ? rawLikes.map((e) => e.toString()).toList()
          : const [],
      commentsCount: int.tryParse((json['comments_count'] ?? 0).toString()) ?? 0,
    );
  }
}
