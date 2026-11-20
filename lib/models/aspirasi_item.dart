import 'dart:convert';
import 'dart:math';

enum AspirasiAccent { blue, purple, amber }

class AspirasiCategory {
  const AspirasiCategory({
    required this.key,
    required this.title,
    required this.eyebrow,
    required this.desc,
    required this.cta,
    required this.pillLabel,
    required this.iconAsset,
    required this.accent,
    required this.placeholderTitle,
    required this.placeholderBody,
  });

  final String key;
  final String title;
  final String eyebrow;
  final String desc;
  final String cta;
  final String pillLabel;
  final String iconAsset;
  final AspirasiAccent accent;
  final String placeholderTitle;
  final String placeholderBody;

  static const List<AspirasiCategory> defaults = [
    AspirasiCategory(
      key: 'lapor',
      title: 'Lapor Ketenagakerjaan',
      eyebrow: 'Pengaduan & Kesejahteraan',
      desc:
          'Sampaikan laporan terkait kondisi kerja, K3, fasilitas, atau kesejahteraan anggota secara profesional dan aman.',
      cta: 'Buat Laporan',
      pillLabel: 'Laporan',
      iconAsset: 'assets/icon/20.png',
      accent: AspirasiAccent.blue,
      placeholderTitle:
          'Contoh: Perbaikan ventilasi / fasilitas kerja di area...',
      placeholderBody:
          'Jelaskan kronologi atau detail kondisi yang ingin dilaporkan secara lengkap...',
    ),
    AspirasiCategory(
      key: 'usul',
      title: 'Usul...!!! Bukan Usil',
      eyebrow: 'Ide Kreatif & Inovatif',
      desc:
          'Berikan ide program, saran perbaikan, dan gagasan cemerlang untuk meningkatkan kesejahteraan bersama.',
      cta: 'Ajukan Usulan',
      pillLabel: 'Usulan Ide',
      iconAsset: 'assets/icon/21.png',
      accent: AspirasiAccent.purple,
      placeholderTitle:
          'Contoh: Usulan program edukasi / peningkatan fasilitas...',
      placeholderBody:
          'Tuliskan gagasan, manfaat, dan usulan implementasinya...',
    ),
    AspirasiCategory(
      key: 'nanya',
      title: 'Nanya Dong...!!!',
      eyebrow: 'Tanya Jawab & Konsultasi',
      desc:
          'Ruang konsultasi dan pertanyaan seputar PKB, hak & kewajiban anggota, serta agenda kegiatan organisasi.',
      cta: 'Tanya Sekarang',
      pillLabel: 'Pertanyaan',
      iconAsset: 'assets/icon/22.png',
      accent: AspirasiAccent.amber,
      placeholderTitle:
          'Contoh: Pertanyaan mengenai ketentuan cuti / tunjangan...',
      placeholderBody: 'Tuliskan pertanyaan yang ingin Anda konsultasikan...',
    ),
  ];
}

class AspirasiTicket {
  const AspirasiTicket({
    required this.id,
    required this.kategori,
    required this.kategoriLabel,
    required this.nama,
    required this.noreg,
    required this.bagian,
    required this.judul,
    required this.isi,
    required this.hasAttachment,
    required this.createdAtIso,
    required this.status,
    this.attachmentName = '',
  });

  final String id;
  final String kategori;
  final String kategoriLabel;
  final String nama;
  final String noreg;
  final String bagian;
  final String judul;
  final String isi;
  final bool hasAttachment;
  final String createdAtIso;
  final String status;
  final String attachmentName;

  static String generateTicketId() {
    final nowStr = DateTime.now().millisecondsSinceEpoch.toString();
    final tail =
        nowStr.length >= 6 ? nowStr.substring(nowStr.length - 6) : nowStr;
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    final suffix =
        '${chars[rnd.nextInt(chars.length)]}${chars[rnd.nextInt(chars.length)]}';
    return 'ASP-$tail$suffix';
  }

  String get formattedDate {
    final dt = DateTime.tryParse(createdAtIso)?.toLocal();
    if (dt == null) return createdAtIso;
    const months = [
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
    final dd = dt.day.toString().padLeft(2, '0');
    final mmm = months[dt.month - 1];
    final yyyy = dt.year;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$dd $mmm $yyyy, $hh:$mm';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kategori': kategori,
        'kategoriLabel': kategoriLabel,
        'nama': nama,
        'noreg': noreg,
        'bagian': bagian,
        'judul': judul,
        'isi': isi,
        'hasAttachment': hasAttachment,
        'createdAt': createdAtIso,
        'status': status,
        if (attachmentName.isNotEmpty) 'attachmentName': attachmentName,
      };

  factory AspirasiTicket.fromJson(Map<String, dynamic> json) {
    return AspirasiTicket(
      id: (json['id'] ?? 'ASP-000000').toString(),
      kategori: (json['kategori'] ?? 'lapor').toString(),
      kategoriLabel:
          (json['kategoriLabel'] ?? 'Lapor Ketenagakerjaan').toString(),
      nama: (json['nama'] ?? 'Anggota Bungtemin').toString(),
      noreg: (json['noreg'] ?? '-').toString(),
      bagian: (json['bagian'] ?? '-').toString(),
      judul: (json['judul'] ?? '').toString(),
      isi: (json['isi'] ?? '').toString(),
      hasAttachment: json['hasAttachment'] == true,
      createdAtIso:
          (json['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
      status: (json['status'] ?? 'Terkirim').toString(),
      attachmentName: (json['attachmentName'] ?? '').toString(),
    );
  }

  static List<AspirasiTicket> decodeList(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => AspirasiTicket.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String encodeList(List<AspirasiTicket> list) {
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }
}
