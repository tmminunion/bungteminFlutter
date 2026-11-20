/// Metadata pembuatan meeting dari `GET /btapi/Meeting/meta`
/// (role pengguna + daftar KP / Pleno untuk dropdown).
class MetaPerson {
  const MetaPerson({
    required this.id,
    required this.noreg,
    required this.nama,
    required this.kp,
    required this.lokasi,
  });

  final int id;
  final String noreg;
  final String nama;

  /// Nomor KP (untuk Pleno = KP induknya).
  final int kp;
  final String lokasi;

  factory MetaPerson.fromJson(Map<String, dynamic> json) {
    return MetaPerson(
      id: int.tryParse((json['id'] ?? '0').toString()) ?? 0,
      noreg: (json['Noreg'] ?? json['noreg'] ?? '').toString(),
      nama: (json['Nama'] ?? json['nama'] ?? '-').toString(),
      kp: int.tryParse((json['KP'] ?? json['kp'] ?? '0').toString()) ?? 0,
      lokasi: (json['Lokasi'] ?? json['lokasi'] ?? '').toString(),
    );
  }
}

class MeetingMeta {
  const MeetingMeta({
    required this.roleLabel,
    required this.canCreate,
    required this.canManageAll,
    required this.isKp,
    required this.isPleno,
    required this.kpNo,
    required this.plenoId,
    required this.defaultPlant,
    required this.defaultTanggal,
    required this.kpList,
    required this.plenoList,
    required this.memberCount,
    required this.minMember,
  });

  final String roleLabel;
  final bool canCreate;

  /// Superadmin / Pengurus PUK.
  final bool canManageAll;
  final bool isKp;
  final bool isPleno;
  final int kpNo;
  final int plenoId;
  final String defaultPlant;
  final String defaultTanggal;
  final List<MetaPerson> kpList;
  final List<MetaPerson> plenoList;
  final int memberCount;
  final int minMember;

  bool get isAdminOrPuk => canManageAll;

  /// Sama dengan sidebar web: grup Pleno untuk PUK, KP, dan Pleno.
  bool get canSeePleno => canManageAll || isKp || isPleno;

  static bool _b(dynamic v) => v == true || v == 1 || v == '1';

  factory MeetingMeta.fromJson(Map<String, dynamic> json) {
    final auth = (json['auth'] as Map?)?.cast<String, dynamic>() ?? const {};
    List<MetaPerson> people(dynamic raw) => raw is List
        ? raw
            .whereType<Map>()
            .map((e) => MetaPerson.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <MetaPerson>[];

    return MeetingMeta(
      roleLabel: (auth['role_label'] ?? '').toString(),
      canCreate: _b(auth['can_create']),
      canManageAll: _b(auth['can_manage_all']),
      isKp: _b(auth['is_kp']),
      isPleno: _b(auth['is_pleno']),
      kpNo: int.tryParse((auth['kp_no'] ?? '0').toString()) ?? 0,
      plenoId: int.tryParse((auth['pleno_id'] ?? '0').toString()) ?? 0,
      defaultPlant: (json['default_plant'] ?? 'KRW #1').toString(),
      defaultTanggal: (json['default_tanggal'] ?? '').toString(),
      kpList: people(json['kp_list']),
      plenoList: people(json['pleno_list']),
      memberCount: int.tryParse((json['member_count'] ?? '0').toString()) ?? 0,
      minMember: int.tryParse((json['min_member'] ?? '5').toString()) ?? 5,
    );
  }
}
