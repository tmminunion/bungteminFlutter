class StrukturMember {
  const StrukturMember({
    required this.no,
    required this.nama,
    required this.job,
    required this.image,
    required this.level,
  });

  final int no;
  final String nama;
  final String job;
  final String image;
  final String level;

  bool get isTop => level.toLowerCase() == 'top';
  bool get isHigh => level.toLowerCase() == 'high';

  String get cleanedJob {
    final cleaned =
        job.replaceAll(RegExp(r'\bPUK\b', caseSensitive: false), '').trim();
    return cleaned.isEmpty ? 'Pengurus' : cleaned;
  }

  factory StrukturMember.fromJson(Map<String, dynamic> json, int fallbackNo) {
    final rawNo = int.tryParse((json['no'] ?? '').toString()) ?? fallbackNo;
    return StrukturMember(
      no: rawNo,
      nama: (json['nama'] ?? '-').toString().trim(),
      job: (json['job'] ?? 'Pengurus').toString().trim(),
      image: (json['image'] ?? '').toString().trim(),
      level: (json['level'] ?? '').toString().trim(),
    );
  }
}

class StrukturPeriodGroup {
  const StrukturPeriodGroup({
    required this.periode,
    required this.tag,
    required this.anggota,
  });

  final String periode;
  final String tag;
  final List<StrukturMember> anggota;

  String get cleanedTag {
    final cleaned =
        tag.replaceAll(RegExp(r'\bPUK\b', caseSensitive: false), '').trim();
    return cleaned.isEmpty ? 'STRUKTUR RESMI' : cleaned;
  }

  factory StrukturPeriodGroup.fromJson(Map<String, dynamic> json) {
    final rawList = json['anggota'];
    final members = <StrukturMember>[];
    if (rawList is List) {
      for (var i = 0; i < rawList.length; i++) {
        final item = rawList[i];
        if (item is Map<String, dynamic>) {
          members.add(StrukturMember.fromJson(item, i + 1));
        } else if (item is Map) {
          members.add(
            StrukturMember.fromJson(Map<String, dynamic>.from(item), i + 1),
          );
        }
      }
    }
    return StrukturPeriodGroup(
      periode: (json['periode'] ?? '-').toString().trim(),
      tag: (json['tag'] ?? 'STRUKTUR ORGANISASI').toString().trim(),
      anggota: members,
    );
  }
}
