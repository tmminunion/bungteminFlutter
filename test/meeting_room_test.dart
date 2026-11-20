import 'package:bungtemin_flutter/models/meeting_item.dart';
import 'package:bungtemin_flutter/models/meeting_room.dart';
import 'package:flutter_test/flutter_test.dart';

MeetingItem _item(String kategori) => MeetingItem(
      id: 1,
      kodeMeeting: 'MTG-1',
      judul: 'Judul',
      kategori: kategori,
      tanggal: '2026-11-20',
      jamMulai: '10:00',
      tempat: 'Ruang',
      status: 'planning',
      kpNama: '-',
      plenoNama: '-',
      totalPeserta: 0,
      totalHadir: 0,
    );

void main() {
  group('MeetingItem.segment (pembagian seperti router organisasi web)', () {
    test('memetakan kategori ke PUK, KP, Pleno, Anggota', () {
      expect(_item('Rapat PUK').segment, 0);
      expect(_item('Rapat KP').segment, 1);
      expect(_item('Rapat Pleno').segment, 2);
      expect(_item('Rapat Member').segment, 3);
    });
  });

  group('MeetingRoomData.fromJson', () {
    final json = <String, dynamic>{
      'success': true,
      'can_manage': true,
      'can_change_status': 1,
      'meeting': {
        'id': 7,
        'uuid': 'abc-123',
        'judul': 'Rapat Anggota Karwitang',
        'kategori': 'Rapat Member',
        'status': 'ongoing',
        'pesertas': [
          {
            'id': 1,
            'nama': 'BUDI',
            'noreg': '00012345',
            'status_kehadiran': 'hadir',
          },
          {
            'id': 2,
            'nama': 'SITI',
            'noreg': '00054321',
            'status_kehadiran': 'pending',
          },
        ],
        'notulens': [
          {'id': 9, 'topik': 'Aspirasi', 'keputusan': 'Tindak lanjut KP'},
        ],
      },
      'stats': {
        'total_peserta': 2,
        'total_hadir': 1,
        'total_pending': 1,
        'total_izin': 0,
        'total_sakit': 0,
      },
      'progress': {
        'absensi_ok': true,
        'voice_ok': true,
        'resume_ok': false,
        'galeri_ok': false,
        'completed_tabs': 2,
        'percent': 50,
        'missing': ['Resume', 'Galeri Foto'],
        'is_ready_for_review': false,
      },
      'foto_dokumentasi_url': 'https://bungtemin.net/uploads/meeting/foto.jpg',
    };

    test('membaca peserta, notulen, progress, dan hak owner', () {
      final r = MeetingRoomData.fromJson(json);
      expect(r.id, 7);
      expect(r.pesertas.length, 2);
      expect(r.pesertas.first.statusKehadiran, 'hadir');
      expect(r.notulens.single.keputusan, 'Tindak lanjut KP');
      expect(r.totalHadir, 1);
      expect(r.canManage, isTrue);
      expect(r.canChangeStatus, isTrue);
      expect(r.progress.completedTabs, 2);
      expect(r.progress.missing, ['Resume', 'Galeri Foto']);
      expect(r.progress.minResumeWords, 30);
      expect(r.fotoUrl, endsWith('foto.jpg'));
      expect(r.qrData, 'meeting:abc-123');
    });

    test('non-owner tidak mendapat hak kelola (kamera disembunyikan)', () {
      final r = MeetingRoomData.fromJson({
        ...json,
        'can_manage': false,
        'can_change_status': false,
      });
      expect(r.canManage, isFalse);
      expect(r.canChangeStatus, isFalse);
    });
  });
}
