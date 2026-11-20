import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bungtemin_flutter/core/bungtemin_crypto.dart';
import 'package:bungtemin_flutter/core/session_store.dart';
import 'package:bungtemin_flutter/features/myars/myars_absensi_detail_screen.dart';
import 'package:bungtemin_flutter/features/myars/myars_tiket_detail_screen.dart';
import 'package:bungtemin_flutter/features/myars/myars_tiket_list_screen.dart';
import 'package:bungtemin_flutter/features/scanner/scanner_screen.dart';
import 'package:bungtemin_flutter/models/myars_models.dart';
import 'package:bungtemin_flutter/services/myars_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MyArs Models & Helpers (bungteminAPP parity)', () {
    test('resolveActiveNoreg returns empty when null and pads 8 digits', () {
      expect(MyArsService.resolveActiveNoreg(null), '');
      const shortSession = UserSession(
        noreg: '415024',
        nama: 'NUNU FATULAH',
        job: 'Anggota',
        token: 'tok',
      );
      expect(MyArsService.resolveActiveNoreg(shortSession), '00415024');
    });

    test('MyArsTicket generates exact QR JSON {n, r, c} and formats divisi/date',
        () {
      final ticket = MyArsTicket.fromJson(<String, dynamic>{
        'id': 8259,
        'idnya': 'BTvm1tVQajRX',
        'nama': 'NUNU FATULAH',
        'noreg': '00415024',
        'KP': 9,
        'Acara': 'UNION DEVELOPMENT 11 OKTO 2025',
        'tanggal': '2025-10-11',
        'jam_masuk': '09:28',
        'jam_keluar': '00:00',
        'kategori': 'MUSNIK2024',
        'komisi': 'B',
        'divisi': 'Press & Welding Production Division',
        'plant': 'KRW',
        'Kode': 'Absensi1760149670914nLr8',
        'status': 'CheckIn',
      });

      expect(ticket.isCheckIn, isTrue);
      expect(
        jsonDecode(ticket.qrCodePayload),
        <String, dynamic>{
          'n': 'NUNU FATULAH',
          'r': '00415024',
          'c': 'Absensi1760149670914nLr8',
        },
      );
      expect(
        MyArsTicket.formatDivisi('Press & Welding Production Division'),
        'Press & Welding Pr...',
      );
      expect(MyArsTicket.formatDate('2025-10-11'), '11 Oct 2025');
      expect(
        MyArsTicket.formatDate('2025-10-11', slashNumeric: true),
        '11/10/2025',
      );
      expect(ticket.matchesQuery('musnik2024'), isTrue);
      expect(ticket.matchesQuery('nLr8'), isTrue);
      expect(ticket.matchesQuery('tidakada'), isFalse);
    });

    test('MyArsEventDetail calculates exact percentasi & progress', () {
      final detail = MyArsEventDetail.fromJson(<String, dynamic>{
        'status': 'success',
        'event': <String, dynamic>{
          'id': 1,
          'namaAcara': 'Rakernit 2025',
          'jumlahPeserta': 40,
          'event_slug': 'slug-1',
        },
        'data': List.generate(
          10,
          (i) => <String, dynamic>{
            'id': i + 1,
            'noreg': '0041502$i',
            'nama': 'Peserta $i',
          },
        ),
      });

      expect(detail.percentasiText, '25.00');
      expect(detail.percentasiProgress, 0.25);

      const zeroTarget = MyArsEventDetail(
        status: 'success',
        message: '',
        peserta: 0,
        sudah: 0,
        belum: 0,
        persentase: 0,
        event: null,
        data: [],
      );
      expect(zeroTarget.percentasiText, '0.00');
      expect(zeroTarget.percentasiProgress, 0.0);
    });
  });

  group('MyArsService API & Offline Cache', () {
    test('getTiketByUser & getTiketById cache locally and parse pagination',
        () async {
      final mockClient = MockClient((req) async {
        if (req.url.path == '/btapi/MyEvent/tiket/00415024') {
          return http.Response(
            jsonEncode({
              'success': true,
              'meta': {'page': 1, 'per_page': 10, 'total': 12, 'last_page': 2},
              'data': [
                {
                  'id': 8259,
                  'idnya': 'BTvm1',
                  'nama': 'NUNU FATULAH',
                  'noreg': '00415024',
                  'Acara': 'UNION DEVELOPMENT',
                  'tanggal': '2025-10-11',
                  'jam_masuk': '09:28',
                  'kategori': 'MUSNIK2024',
                  'komisi': 'B',
                  'Kode': 'KODE-1',
                  'status': 'CheckIn',
                }
              ],
            }),
            200,
          );
        }
        if (req.url.path == '/btapi/MyEvent/tiketbyid/8259') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 8259,
                'idnya': 'BTvm1',
                'nama': 'NUNU FATULAH',
                'noreg': '00415024',
                'Acara': 'UNION DEVELOPMENT',
                'tanggal': '2025-10-11',
                'jam_masuk': '09:28',
                'divisi': 'Stamping Production Division',
                'Kode': 'KODE-1',
                'status': 'CheckIn',
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = MyArsService(
        client: mockClient,
        enablePresenceWs: false,
      );
      final page1 = await service.getTiketByUser('00415024', page: 1);
      expect(page1.success, isTrue);
      expect(page1.lastPage, 2);
      expect(page1.items.length, 1);
      expect(page1.items.first.acara, 'UNION DEVELOPMENT');

      await service.saveLocalTiketList('00415024', page1.items);
      final cached = await service.loadLocalTiketByNoreg('00415024');
      expect(cached.length, 1);
      expect(cached.first.kode, 'KODE-1');

      final ticket = await service.getTiketById('8259', noreg: '00415024');
      expect(ticket, isNotNull);
      expect(ticket!.nama, 'NUNU FATULAH');
    });

    test('processEventScannerQr routes untukabsen, profil, dt & default',
        () async {
      final calls = <Map<String, dynamic>>[];
      final mockClient = MockClient((req) async {
        calls.add(<String, dynamic>{
          'path': req.url.path,
          'body': jsonDecode(req.body),
        });
        if (req.url.path == '/absensi/kirimAbsen') {
          return http.Response(
            jsonEncode({
              'status': true,
              'data': {'kode': 'DT-999'},
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'status': true, 'kode': 'OK-123'}),
          200,
        );
      });

      const session = UserSession(
        noreg: '00415024',
        nama: 'NUNU FATULAH',
        job: 'Panitia',
        token: 'jwt-token',
      );
      final service = MyArsService(
        client: mockClient,
        enablePresenceWs: false,
      );

      final r1 = await service.processEventScannerQr(
        rawQr: 'untukabsen:TKT-1',
        eventSlug: 'ev-slug',
        session: session,
      );
      expect(r1.success, isTrue);
      expect(r1.message, 'Kode: OK-123');
      expect(calls[0]['path'], '/api/absensitiket');
      expect((calls[0]['body'] as Map)['id'], 'TKT-1');

      final encryptedNoreg = BungteminCrypto.encrypt('09406483');
      final r2 = await service.processEventScannerQr(
        rawQr: 'profil:$encryptedNoreg',
        eventSlug: 'ev-slug',
        session: session,
      );
      expect(r2.success, isTrue);
      expect(calls[1]['path'], '/api/absensiuser');
      expect((calls[1]['body'] as Map)['id'], '09406483');
      expect((calls[1]['body'] as Map)['event'], 'ev-slug');

      final r3 = await service.processEventScannerQr(
        rawQr: 'dt:BARCODE-77',
        eventSlug: 'ev-slug',
        session: session,
      );
      expect(r3.success, isTrue);
      expect(r3.message, 'Kode: DT-999');
      expect(calls[2]['path'], '/absensi/kirimAbsen');
      expect((calls[2]['body'] as Map)['barcode'], 'BARCODE-77');
    });

    test('makeEvent posts payload to /btapi/MyEvent/create', () async {
      Map<String, dynamic>? captured;
      final mockClient = MockClient((req) async {
        captured = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'success': true,
            'message': 'Acara berhasil dibuat',
            'data': {
              'id': 200,
              'namaAcara': 'Rapat Koordinasi Unit',
              'jumlahPeserta': 50,
              'event_slug': 'BTnewslug',
            },
          }),
          200,
        );
      });

      final service = MyArsService(
        client: mockClient,
        enablePresenceWs: false,
      );
      final res = await service.makeEvent(
        acara: 'Rapat Koordinasi Unit',
        jumlah: 50,
        session: const UserSession(
          noreg: '00415024',
          nama: 'NUNU FATULAH',
          job: 'Pengurus',
          token: '',
        ),
      );

      expect(res.success, isTrue);
      expect(captured?['acara'], 'Rapat Koordinasi Unit');
      expect(captured?['jumlah'], 50);
      expect(res.event?.eventSlug, 'BTnewslug');
    });
  });

  group('MyArs Screens Widget Tests', () {
    testWidgets('MyArsTiketListScreen filters & opens E-Pass QR detail',
        (tester) async {
      final tickets = [
        MyArsTicket.fromJson({
          'id': 101,
          'idnya': 'ev-1',
          'nama': 'NUNU FATULAH',
          'noreg': '00415024',
          'Acara': 'UNION DEVELOPMENT 2025',
          'tanggal': '2025-10-11',
          'jam_masuk': '09:28',
          'kategori': 'MUSNIK2024',
          'komisi': 'B',
          'divisi': 'Press & Welding Production Division',
          'Kode': 'Absensi123',
          'status': 'CheckIn',
        }),
        MyArsTicket.fromJson({
          'id': 102,
          'idnya': 'ev-2',
          'nama': 'NUNU FATULAH',
          'noreg': '00415024',
          'Acara': 'RAKERNIT PUK SP LEM',
          'tanggal': '2025-09-01',
          'jam_masuk': '08:00',
          'kategori': 'RAKER',
          'komisi': 'A',
          'divisi': 'Engine Division',
          'Kode': 'Absensi456',
          'status': 'Hadir',
        }),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MyArsTiketListScreen(
            session: null,
            initialTickets: tickets,
          ),
        ),
      );

      expect(find.text('Riwayat Tiket Saya'), findsOneWidget);
      expect(find.text('2 Tiket'), findsOneWidget);
      expect(find.text('UNION DEVELOPMENT 2025'), findsOneWidget);
      expect(find.text('RAKERNIT PUK SP LEM'), findsOneWidget);

      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('RAKERNIT PUK SP LEM'));
      await tester.pumpAndSettle();

      expect(find.byType(MyArsTiketDetailScreen), findsOneWidget);
      expect(find.text('E-PASS KEHADIRAN'), findsOneWidget);
      expect(find.text('Scan QR untuk verifikasi kehadiran'), findsOneWidget);
    });

    testWidgets('MyArsAbsensiDetailScreen shows attendance rate & participants',
        (tester) async {
      final mockClient = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'status': 'success',
            'message': 'OK',
            'event': {
              'id': 184,
              'namaAcara': 'Refresh Organisasi',
              'tempat': 'Bukit Daolong, Sentul',
              'tanggalAcara': '2026-11-05 00:00:00',
              'jumlahPeserta': 4,
              'event_slug': 'BTrefresh',
            },
            'data': [
              {
                'id': 501,
                'idnya': 'BTrefresh',
                'nama': 'TRI AZIS',
                'noreg': '09406483',
                'tanggal': '2026-11-05',
                'jam_masuk': '08:15',
                'divisi': 'Engine Div',
                'plant': 'Sunter',
                'Kode': 'K-501',
                'status': 'CheckIn',
              }
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MyArsAbsensiDetailScreen(
            eventSlug: 'BTrefresh',
            service: MyArsService(client: mockClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Refresh Organisasi'), findsOneWidget);
      expect(find.text('25.00%'), findsWidgets);
      expect(find.text('TRI AZIS'), findsOneWidget);
      expect(find.text('1 / 4 Orang'), findsOneWidget);
    });
  });

  group('QR Absensi & Scanner Compatibility', () {
    test('parseBtScanQr recognizes all Bungtemin QR absensi formats', () {
      final direct = parseBtScanQr('absensi:event_123');
      expect(direct.kind, BtScanKind.eventAbsensi);
      expect(direct.payload, 'event_123');

      final qrImgUrl =
          parseBtScanQr('https://bungtemin.net/gambar/qrcode/absensi:event_123');
      expect(qrImgUrl.kind, BtScanKind.eventAbsensi);
      expect(qrImgUrl.payload, 'event_123');

      final encodedUrl = parseBtScanQr(
          'https://bungtemin.net/gambar/qrcode/absensi%3Aevent_456');
      expect(encodedUrl.kind, BtScanKind.eventAbsensi);
      expect(encodedUrl.payload, 'event_456');

      final camUrl =
          parseBtScanQr('https://bungtemin.net/absensi/camera/BTrefresh');
      expect(camUrl.kind, BtScanKind.eventAbsensi);
      expect(camUrl.payload, 'BTrefresh');

      final tiket = parseBtScanQr('untukabsen:AbsensiXYZ');
      expect(tiket.kind, BtScanKind.eventTiket);
      expect(tiket.payload, 'AbsensiXYZ');

      final epass =
          parseBtScanQr('{"n":"BUDI","r":"00415024","c":"AbsensiXYZ"}');
      expect(epass.kind, BtScanKind.epassJson);
      expect(epass.payload, '00415024');
    });

    test('processEventScannerQr routes untukabsen to /api/absensitiket & falls back to web gate', () async {
      final visitedUrls = <String>[];
      final mockClient = MockClient((req) async {
        visitedUrls.add(req.url.toString());
        if (req.url.path == '/api/absensitiket') {
          return http.Response(
            jsonEncode({'status': true, 'kode': 'TKT-OK'}),
            200,
          );
        }
        if (req.url.path == '/api/absensiuser') {
          return http.Response(
            jsonEncode({'status': false, 'message': 'User tidak terdaftar'}),
            404,
          );
        }
        if (req.url.path == '/camera/absensi/kirimAbsen') {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'already': false,
              'tiket': 'ABS-999',
              'message': 'Presensi berhasil masuk event!',
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final service = MyArsService(client: mockClient, enablePresenceWs: false);
      const session = UserSession(
        noreg: '00415024',
        nama: 'NUNU FATULAH',
        job: 'Pengurus',
        token: 'tok',
      );

      final tiketRes = await service.processEventScannerQr(
        rawQr: 'untukabsen:REG-001',
        eventSlug: 'BTrefresh',
        session: session,
      );
      expect(tiketRes.success, isTrue);
      expect(visitedUrls.any((u) => u.endsWith('/api/absensitiket')), isTrue);

      final epassRes = await service.processEventScannerQr(
        rawQr: '{"n":"BUDI","r":"00415024","c":"AbsensiXYZ"}',
        eventSlug: 'BTrefresh',
        session: session,
      );
      expect(epassRes.success, isTrue);
      expect(epassRes.kode, 'ABS-999');
      expect(
        visitedUrls.any((u) => u.endsWith('/camera/absensi/kirimAbsen')),
        isTrue,
      );
    });
  });
}
