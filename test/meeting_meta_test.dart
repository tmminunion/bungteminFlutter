import 'package:flutter_test/flutter_test.dart';

import 'package:bungtemin_flutter/models/meeting_meta.dart';

void main() {
  group('MeetingMeta.fromJson', () {
    test('membaca role admin/PUK dan daftar KP & Pleno', () {
      final meta = MeetingMeta.fromJson({
        'success': true,
        'auth': {
          'role_label': 'Pengurus PUK',
          'can_create': true,
          'can_manage_all': true,
          'is_kp': false,
          'is_pleno': false,
          'kp_no': null,
          'pleno_id': null,
        },
        'default_plant': 'KRW #1',
        'default_tanggal': '2026-11-21',
        'kp_list': [
          {'id': 1, 'Noreg': '00111111', 'Nama': 'Budi', 'KP': '3', 'Lokasi': 'HO'},
        ],
        'pleno_list': [
          {'id': 9, 'Noreg': '00222222', 'Nama': 'Sari', 'KP': 3},
        ],
        'member_count': 0,
        'min_member': 5,
      });

      expect(meta.canManageAll, isTrue);
      expect(meta.isAdminOrPuk, isTrue);
      expect(meta.canSeePleno, isTrue);
      expect(meta.kpNo, 0);
      expect(meta.kpList.single.kp, 3);
      expect(meta.plenoList.single.nama, 'Sari');
      expect(meta.minMember, 5);
    });

    test('anggota biasa tidak melihat grup Pleno dan tidak bisa membuat', () {
      final meta = MeetingMeta.fromJson({
        'success': true,
        'auth': {
          'role_label': 'Anggota Serikat',
          'can_create': false,
          'can_manage_all': false,
          'is_kp': false,
          'is_pleno': false,
        },
      });

      expect(meta.canCreate, isFalse);
      expect(meta.canSeePleno, isFalse);
      expect(meta.kpList, isEmpty);
      expect(meta.defaultPlant, 'KRW #1');
    });

    test('role KP: kp_no terbaca dan boleh melihat Pleno', () {
      final meta = MeetingMeta.fromJson({
        'auth': {
          'can_create': 1,
          'is_kp': true,
          'kp_no': '7',
        },
      });
      expect(meta.isKp, isTrue);
      expect(meta.kpNo, 7);
      expect(meta.canSeePleno, isTrue);
      expect(meta.canCreate, isTrue);
    });
  });
}
