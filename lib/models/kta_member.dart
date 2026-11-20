import '../core/bungtemin_crypto.dart';
import '../core/session_store.dart';

class KtaMember {
  const KtaMember({
    required this.id,
    required this.noreg,
    required this.nama,
    required this.job,
    required this.ktaNumber,
    required this.lokasi,
    required this.plant,
    required this.dept,
    required this.divisi,
    required this.berlaku,
    required this.aktif,
    required this.avatarUrl,
    required this.qrProfil,
    this.tanggalStart = '-',
    this.tempatLahir = '-',
    this.tglLahir = '-',
    this.agama = '-',
    this.alamat = '-',
  });

  final int id;
  final String noreg;
  final String nama;
  final String job;
  final String ktaNumber;
  final String lokasi;
  final String plant;
  final String dept;
  final String divisi;
  final String berlaku;
  final bool aktif;
  final String avatarUrl;
  final String qrProfil;
  final String tanggalStart;
  final String tempatLahir;
  final String tglLahir;
  final String agama;
  final String alamat;

  static String normalizeJob(String? raw) {
    final v = (raw ?? '').trim().toUpperCase();
    if (v.isEmpty || v == 'MEMBER') return 'ANGGOTA';
    if (v == 'KP' || v.startsWith('KOORDIN') || v.startsWith('KORDIN')) {
      return 'KP';
    }
    return v;
  }

  factory KtaMember.fromJson(Map<String, dynamic> json) {
    final noreg = (json['noreg'] ?? '-').toString();
    final rawAvatar = (json['avatar'] ?? '').toString().trim();
    final resolvedAvatar = SessionStore.resolveAvatarUrl(rawAvatar, noreg);
    final qr = (json['qr_profil'] ?? '').toString().trim();
    final tgl = (json['tgl_lahir_fmt'] ?? json['tgl_lahir'] ?? '-').toString();
    final tglStart = (json['tanggalstart'] ?? '-').toString().trim();
    final a1 = (json['alamat'] ?? '').toString().trim();
    final a2 = (json['alamat2'] ?? '').toString().trim();
    final alamatGabung = a1.isEmpty
        ? '-'
        : (a2.isEmpty ? a1 : '$a1, $a2');

    return KtaMember(
      id: int.tryParse((json['id'] ?? '0').toString()) ?? 0,
      noreg: noreg,
      nama: (json['nama'] ?? '-').toString(),
      job: normalizeJob(json['job']?.toString()),
      ktaNumber: (json['kta'] ?? '-').toString(),
      lokasi: (json['lokasi'] ?? 'Karawang').toString(),
      plant: (json['plant'] ?? 'PLANT').toString(),
      dept: (json['dept'] ?? '-').toString(),
      divisi: (json['divisi'] ?? '-').toString(),
      berlaku: (json['berlaku'] ?? '-').toString(),
      aktif: (json['aktif']?.toString() ?? '1') != '0',
      avatarUrl: resolvedAvatar,
      qrProfil: qr.isNotEmpty ? qr : 'profil:${BungteminCrypto.encrypt(noreg)}',
      tanggalStart: tglStart.isEmpty ? '-' : tglStart,
      tempatLahir: (json['tempat_lahir'] ?? '-').toString(),
      tglLahir: tgl.isEmpty ? '-' : tgl,
      agama: (json['agama'] ?? '-').toString(),
      alamat: alamatGabung,
    );
  }
}
