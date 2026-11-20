import 'package:flutter/material.dart';

/// Model data satu Bidang Program Kerja PUK SP LEM SPSI PT. TMMIN.
class BidangProker {
  const BidangProker({
    required this.no,
    required this.bidang,
    required this.tagline,
    required this.imageAsset,
    required this.accent,
    required this.icon,
    required this.programList,
  });

  final String no;
  final String bidang;
  final String tagline;
  final String imageAsset;
  final Color accent;
  final IconData icon;
  final List<String> programList;

  /// Label kode bidang dua digit, mis. `Bidang 01`.
  String get formattedBadge => 'Bidang ${no.padLeft(2, '0')}';

  /// Filter daftar bidang berdasarkan nama bidang, tagline, atau fokus program.
  static List<BidangProker> filter(List<BidangProker> items, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List<BidangProker>.unmodifiable(items);

    return items
        .where(
          (b) =>
              b.bidang.toLowerCase().contains(q) ||
              b.tagline.toLowerCase().contains(q) ||
              b.programList.any((p) => p.toLowerCase().contains(q)),
        )
        .toList(growable: false);
  }

  /// 7 Bidang Program Kerja standar sesuai `bungteminAPP/src/app/proker/proker.page.ts`.
  static const List<BidangProker> defaults = [
    BidangProker(
      no: '1',
      bidang: 'Kesekertariatan',
      tagline:
          'Administrasi, kesekretariatan, persuratan, dan dokumentasi digital PUK.',
      imageAsset: 'assets/hd/se.jpg',
      accent: Color(0xFF2563EB),
      icon: Icons.folder_copy_rounded,
      programList: [
        'Digitalisasi arsip surat menyurat, mandat, dan notulensi rapat PUK.',
        'Pengelolaan jadwal rapat Pleno, Pengurus Harian, dan koordinasi antar bidang.',
        'Pemutakhiran database keanggotaan dan sistem informasi internal Bungtemin.',
      ],
    ),
    BidangProker(
      no: '2',
      bidang: 'Bendahara',
      tagline:
          'Transparansi tata kelola keuangan, iuran COS, dan audit kas organisasi.',
      imageAsset: 'assets/hd/be.jpg',
      accent: Color(0xFF0D9488),
      icon: Icons.account_balance_wallet_rounded,
      programList: [
        'Penyusunan anggaran kerja tahunan seluruh bidang secara akuntabel.',
        'Pelaporan realisasi kas dan alokasi dana kegiatan organisasi secara berkala.',
        'Pengelolaan dukungan operasional bidang dan bantuan sosial anggota.',
      ],
    ),
    BidangProker(
      no: '3',
      bidang: 'Organisasi',
      tagline:
          'Konsolidasi anggota, penguatan struktur KP/Pleno, dan KTA digital.',
      imageAsset: 'assets/hd/pe.jpg',
      accent: Color(0xFF7C3AED),
      icon: Icons.hub_rounded,
      programList: [
        'Pendataan, pemetaan, dan penguatan jaringan Komisariat Plant (KP) & Pleno.',
        'Penerbitan serta pembaruan KTA Digital anggota terintegrasi aplikasi.',
        'Penyelenggaraan Rapat Anggota dan penguatan solidaritas antar unit kerja.',
      ],
    ),
    BidangProker(
      no: '4',
      bidang: 'Pendidikan',
      tagline:
          'Peningkatan kapasitas SDM, pelatihan serikat pekerja, dan literasi PKB.',
      imageAsset: 'assets/hd/ae.jpg',
      accent: Color(0xFFEA580C),
      icon: Icons.school_rounded,
      programList: [
        'Pelatihan dasar dan lanjutan kepemimpinan bagi Pleno serta kader muda.',
        'Sosialisasi dan bedah isi Perjanjian Kerja Bersama (PKB) secara berkala.',
        'Edukasi digital melalui modul Pintar, Pretest, dan Kuis interaktif.',
      ],
    ),
    BidangProker(
      no: '5',
      bidang: 'Ketenagakerjaan',
      tagline:
          'Advokasi hak normatif, pendampingan anggota, dan perundingan ketenagakerjaan.',
      imageAsset: 'assets/hd/tn.jpg',
      accent: Color(0xFFDC2626),
      icon: Icons.gavel_rounded,
      programList: [
        'Advokasi serta pendampingan permasalahan hubungan industrial anggota.',
        'Kajian regulasi ketenagakerjaan, K3, dan peningkatan kesejahteraan kerja.',
        'Layanan respons cepat aspirasi & keluhan anggota melalui Hallo PUK.',
      ],
    ),
    BidangProker(
      no: '6',
      bidang: 'HIPP',
      tagline:
          'Hubungan Industrial Pancasila, komunikasi manajemen, dan dialog bipartit.',
      imageAsset: 'assets/hd/or.jpg',
      accent: Color(0xFF0284C7),
      icon: Icons.handshake_rounded,
      programList: [
        'Penguatan forum LKS Bipartit antara Serikat Pekerja dan Manajemen perusahaan.',
        'Harmonisasi hubungan kerja yang produktif, adil, dan saling menghormati.',
        'Penyelesaian perselisihan secara musyawarah serta berkeadilan.',
      ],
    ),
    BidangProker(
      no: '7',
      bidang: 'Sosial Ekonomi',
      tagline:
          'Kesejahteraan sosial, aksi kemanusiaan, olahraga, dan koperasi anggota.',
      imageAsset: 'assets/hd/so.jpg',
      accent: Color(0xFF059669),
      icon: Icons.volunteer_activism_rounded,
      programList: [
        'Program santunan duka, tanggap bencana, dan bakti sosial kemasyarakatan.',
        'Pengembangan program ekonomi kerakyatan & kemitraan untuk anggota.',
        'Penyelenggaraan kegiatan olahraga, seni, dan kebersamaan keluarga besar.',
      ],
    ),
  ];
}
