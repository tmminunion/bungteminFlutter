import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bungtemin_flutter/core/bungtemin_crypto.dart';
import 'package:bungtemin_flutter/core/session_store.dart';
import 'package:bungtemin_flutter/features/auth/login_screen.dart';
import 'package:bungtemin_flutter/features/feed/tabfeed_screen.dart';
import 'package:bungtemin_flutter/features/kta/kta_tab.dart';
import 'package:bungtemin_flutter/features/lapor/lapor_screen.dart';
import 'package:bungtemin_flutter/features/meeting/meeting_tab.dart';
import 'package:bungtemin_flutter/features/news/news_tab.dart';
import 'package:bungtemin_flutter/features/pintar/pintar_buku_screen.dart';
import 'package:bungtemin_flutter/features/pintar/training_screen.dart';
import 'package:bungtemin_flutter/features/pintar/training_ticket_screen.dart';
import 'package:bungtemin_flutter/features/pretest/pretest_screen.dart';
import 'package:bungtemin_flutter/features/quiz/quiz_screen.dart';
import 'package:bungtemin_flutter/features/scanner/scanner_screen.dart';
import 'package:bungtemin_flutter/features/struktur/struktur_screen.dart';
import 'package:bungtemin_flutter/features/shell/main_shell.dart';
import 'package:bungtemin_flutter/features/tonton/tonton_screen.dart';
import 'package:bungtemin_flutter/features/tutorial/tutorial_screen.dart';
import 'package:bungtemin_flutter/models/aspirasi_item.dart';
import 'package:bungtemin_flutter/models/bungtemin_menu.dart';
import 'package:bungtemin_flutter/models/kta_member.dart';
import 'package:bungtemin_flutter/models/meeting_item.dart';
import 'package:bungtemin_flutter/models/news_item.dart';
import 'package:bungtemin_flutter/models/tonton_video.dart';
import 'package:bungtemin_flutter/models/training_item.dart';
import 'package:bungtemin_flutter/services/bungtemin_api.dart';
import 'package:bungtemin_flutter/services/fcm_service.dart';

void main() {
  group('KtaMember.normalizeJob', () {
    test('normalizes truncated KOORDIN variants to KP', () {
      expect(KtaMember.normalizeJob('KOORDIN'), 'KP');
      expect(KtaMember.normalizeJob('KOORDINATOR PLENO'), 'KP');
      expect(KtaMember.normalizeJob('kordin'), 'KP');
      expect(KtaMember.normalizeJob('kp'), 'KP');
      expect(KtaMember.normalizeJob('Pleno'), 'PLENO');
      expect(KtaMember.normalizeJob('Member'), 'ANGGOTA');
      expect(KtaMember.normalizeJob(''), 'ANGGOTA');
    });
  });

  group('SessionStore.formatNoreg8', () {
    test('pads numeric noreg to 8 digits', () {
      expect(SessionStore.formatNoreg8('415024'), '00415024');
      expect(SessionStore.formatNoreg8('0009953'), '00009953');
      expect(SessionStore.formatNoreg8(''), '');
    });
  });

  group('BungteminMenu & NewsItem parsing', () {
    test('parses NewMenu sections with requiresLogin objects', () {
      const sample = '''
      {
        "value": [
          {
            "items": [
              {"label":"Berita","icon":"assets/icon/1.png","routerLink":"/news","requiresLogin":false},
              {"label":"Pintar","icon":"assets/icon/4.png","routerLink":{"loggedIn":"/training","loggedOut":"/login"},"requiresLogin":true}
            ]
          }
        ]
      }
      ''';
      final parsed = BungteminApi.parseMenuJson(sample);
      expect(parsed.length, 2);
      expect(parsed[0].label, 'Berita');
      expect(parsed[0].requiresLogin, isFalse);
      expect(parsed[1].label, 'Pintar');
      expect(parsed[1].route, '/training');
      expect(parsed[1].requiresLogin, isTrue);
      expect(BungteminMenuItem.defaults.length, 22);
    });

    test('parses WordPress internal and Blogger external news', () {
      final wp = NewsItem.fromWordPress({
        'id': 927,
        'date': '2026-10-22T10:20:37',
        'featured_media': 930,
        'title': {'rendered': 'TMMIN Union &#8211; Sarasehan 2026'},
        'content': {'rendered': '<p>Konten berita resmi.</p>'},
        'link': 'https://bungtemin.net/news/test',
      });
      expect(wp.isInternal, isTrue);
      expect(wp.title, 'TMMIN Union – Sarasehan 2026');
      expect(wp.imageUrl, 'https://bungtemin.net/btapi/img/thumb/930');

      final ext = NewsItem.fromBlogger({
        'id': '66200',
        'published': '2026-08-08T19:16:09+07:00',
        'title': 'Berita Eksternal FSP LEM',
        'content': '<p><img src="https://example.com/a.jpg" />Isi eksternal</p>',
        'url': 'https://www.fsplemspsi.or.id/test.html',
      });
      expect(ext.isInternal, isFalse);
      expect(ext.imageUrl, 'https://example.com/a.jpg');
      expect(ext.plainBody, contains('Isi eksternal'));

      final encoded = NewsItem.encodeList([wp, ext]);
      final decoded = NewsItem.decodeList(encoded);
      expect(decoded.length, 2);
      expect(decoded[0].title, wp.title);
      expect(decoded[0].imageUrl, wp.imageUrl);
      expect(decoded[1].isInternal, isFalse);
    });

    testWidgets('NewsTab renders cached news immediately without blank loading',
        (tester) async {
      const sample = NewsItem(
        id: '927',
        title: 'Berita Cache Instan',
        excerpt: 'Ringkasan berita dari cache lokal.',
        contentHtml: '<p>Konten</p>',
        plainBody: 'Konten',
        imageUrl: '',
        dateIso: '2026-10-22T10:20:37',
        linkUrl: 'https://bungtemin.net/news/test',
        isInternal: true,
      );
      SharedPreferences.setMockInitialValues({
        'bt_internal_news_cache': NewsItem.encodeList([sample]),
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: NewsTab()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Berita Cache Instan'), findsOneWidget);
    });
  });

  testWidgets('TutorialScreen renders onboarding slides and skip action',
      (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TutorialScreen(onComplete: () => completed = true),
      ),
    );

    expect(find.text('01 · SELAMAT DATANG'), findsOneWidget);
    expect(find.text('Lewati'), findsOneWidget);
    await tester.tap(find.text('Lewati'));
    expect(completed, isTrue);
  });

  testWidgets('LoginScreen hides Microsoft SSO by default and shows when enabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          onAuthenticated: (_) {},
          initialSsoEnabled: false,
        ),
      ),
    );

    expect(find.text('Bungtemin'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Login Microsoft'), findsNothing);
    expect(find.text('Kirim OTP WA'), findsOneWidget);
    expect(find.text('Preview Noreg'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          onAuthenticated: (_) {},
          initialSsoEnabled: true,
        ),
      ),
    );
    expect(find.text('Login Microsoft'), findsOneWidget);
  });

  testWidgets('KtaTab renders MUNAS design front, back, and 2-side mode',
      (tester) async {
    const sampleSession = UserSession(
      noreg: '00415024',
      nama: 'NUNU FATULAH',
      job: 'KP',
      token: '',
    );
    const sampleMember = KtaMember(
      id: 1,
      noreg: '00415024',
      nama: 'NUNU FATULAH',
      job: 'KP',
      ktaNumber: '00415024',
      lokasi: 'Karawang',
      plant: 'PLANT 1',
      dept: 'PROD',
      divisi: 'BODY',
      berlaku: '31-12-2027',
      aktif: true,
      avatarUrl: '',
      qrProfil: 'profil:00415024',
      tempatLahir: 'Karawang',
      tglLahir: '01-01-1990',
      agama: 'Islam',
      alamat: 'Karawang Barat',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KtaTab(
            session: sampleSession,
            initialMember: sampleMember,
          ),
        ),
      ),
    );

    expect(find.text('NUNU FATULAH'), findsOneWidget);
    expect(find.text('SP LEM SPSI PT. TMMIN'), findsOneWidget);
    expect(find.text('AKTIF'), findsOneWidget);
    expect(find.text('2 Sisi'), findsOneWidget);

    await tester.ensureVisible(find.text('2 Sisi'));
    await tester.tap(find.text('2 Sisi'));
    await tester.pumpAndSettle();
    expect(find.text('TAMPAK DEPAN'), findsOneWidget);
    expect(find.text('TAMPAK BELAKANG'), findsOneWidget);
    expect(find.text('Di-generate oleh bungtemin.net'), findsOneWidget);
  });

  testWidgets('Home has no bottom NavigationBar while TabFeed has Aurora tabbar',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainShellScreen(
          session: null,
          onAuthenticated: (_) {},
          onLogout: () {},
          onOpenTutorial: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Masuk untuk akses KTA & Training'), findsOneWidget);
    final hasKtaCardBg = tester.widgetList<Container>(find.byType(Container)).any(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).image?.image ==
                  const AssetImage('assets/card/bg.png'),
        );
    expect(hasKtaCardBg, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: TabFeedScreen(
          session: null,
          onRequireLogin: (_, __) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Linimasa'), findsOneWidget);
    expect(find.text('Reels'), findsOneWidget);
    expect(find.text('Notif'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });

  test('BungteminCrypto encrypts and decrypts Noreg AES-256 URL-safe', () {
    final cipher = BungteminCrypto.encrypt('00415024');
    expect(cipher, isNotEmpty);
    expect(cipher.contains('+'), isFalse);
    expect(cipher.contains('/'), isFalse);
    expect(BungteminCrypto.decrypt('profil:$cipher'), '00415024');
    expect(BungteminCrypto.decrypt('userid:00415024'), '00415024');
  });

  testWidgets('ScannerScreen displays BTScan Digital QR card & scan button',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScannerScreen(
          session: const UserSession(
            noreg: '00415024',
            nama: 'NUNU FATULAH',
            job: 'ANGGOTA',
            token: '',
          ),
          onRequireLogin: (_, __) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('BTScan Digital'), findsOneWidget);
    expect(find.text('QR Identitas Terenkripsi'), findsOneWidget);
    expect(find.text('Mulai Scan QR Code'), findsOneWidget);
    expect(find.text('Input / Tempel Kode QR Manual'), findsNothing);
  });

  group('Tonton module', () {
    test('TontonVideo.fromJson parses WordPress playlist payload & infers category',
        () {
      final video = TontonVideo.fromJson({
        'id': 829,
        'title': 'TMMIN Company Profil',
        'content': '<p>Dokumentasi resmi PT TMMIN &amp; SPSI</p>',
        'playlist_id': 'ydeng12Yv5M',
      });
      expect(video.id, '829');
      expect(video.videoId, 'ydeng12Yv5M');
      expect(video.title, 'TMMIN Company Profil');
      expect(video.description, 'Dokumentasi resmi PT TMMIN & SPSI');
      expect(video.category, 'TMMIN');
      expect(
        video.thumbnailHq,
        'https://img.youtube.com/vi/ydeng12Yv5M/hqdefault.jpg',
      );
      expect(video.youtubeUrl, 'https://youtu.be/ydeng12Yv5M');
    });

    testWidgets('TontonScreen renders YouTube-style feed chips & search filter',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      const sampleVideos = [
        TontonVideo(
          id: '1',
          videoId: 'ydeng12Yv5M',
          title: 'TMMIN Company Profil',
          description: 'Profil resmi perusahaan',
          category: 'TMMIN',
        ),
        TontonVideo(
          id: '2',
          videoId: 'abc123XYZ00',
          title: 'Mars SP LEM SPSI',
          description: 'Lagu perjuangan serikat',
          category: 'Mars',
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: TontonScreen(initialVideos: sampleVideos),
        ),
      );
      await tester.pump();

      expect(find.text('Tonton'), findsOneWidget);
      expect(find.text('SPSI TV'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('TMMIN Company Profil'), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        const Color(0xFF0B0F19),
      );

      await tester.tap(find.text('Mars'));
      await tester.pump();
      expect(find.text('Mars SP LEM SPSI'), findsOneWidget);
      expect(find.text('TMMIN Company Profil'), findsNothing);
    });
  });

  testWidgets('StrukturScreen renders periods, search filter, and member cards',
      (tester) async {
    const rawStruktur = '''
    {
      "value": [
        {
          "0": {
            "periode": "2024 - 2027",
            "tag": "STRUKTUR PUK",
            "anggota": [
              {"no": 1, "nama": "KETUA UMUM", "job": "Ketua PUK", "image": "", "level": "top"},
              {"no": 2, "nama": "BUDI SANTOSO", "job": "Sekretaris PUK", "image": "", "level": "high"}
            ]
          },
          "1": {
            "periode": "2021 - 2024",
            "tag": "DEMISIONER",
            "anggota": [
              {"no": 1, "nama": "KETUA LAMA", "job": "Ketua", "image": "", "level": "top"}
            ]
          }
        }
      ]
    }
    ''';
    final groups = BungteminApi.parseStrukturJson(rawStruktur);
    expect(groups.length, 2);
    expect(groups.first.cleanedTag, 'STRUKTUR');
    expect(groups.first.anggota.first.cleanedJob, 'Ketua');

    await tester.pumpWidget(
      MaterialApp(
        home: StrukturScreen(initialGroups: groups),
      ),
    );
    await tester.pump();

    expect(find.text('Struktur Kepengurusan'), findsOneWidget);
    expect(find.text('Masa Bakti 2024 - 2027'), findsOneWidget);
    expect(find.text('KETUA UMUM'), findsOneWidget);
    expect(find.text('BUDI SANTOSO'), findsOneWidget);
    expect(find.text('SEKRETARIS'), findsOneWidget);
  });

  group('FcmService PushPayload migration', () {
    test('builds global and per-noreg FCM topics matching bungteminAPP', () {
      expect(
        PushPayload.buildUserTopics('00415024'),
        ['news', 'feeds', '00415024', 'noreg_00415024'],
      );
      expect(PushPayload.buildUserTopics(null), ['news', 'feeds']);
    });

    test('resolves push notification routes consistently', () {
      const feedNotif = PushPayload(
        type: 'feedkoment',
        pageId: '123',
        url: '',
        title: 'Komentar Baru',
        body: 'Ada balasan',
      );
      const urlNotif = PushPayload(
        type: 'meeting',
        pageId: '',
        url: '/tonton',
        title: 'Video Baru',
        body: 'Cek Tonton',
      );

      expect(feedNotif.resolveTargetRoute(), '/tabfeed');
      expect(urlNotif.resolveTargetRoute(), '/tonton');
    });
  });

  group('Hallo PUK (Lapor / Aspirasi) module', () {
    test('AspirasiTicket serializes and deserializes history list', () {
      final sample = AspirasiTicket(
        id: 'ASP-123456AB',
        kategori: 'lapor',
        kategoriLabel: 'Lapor Ketenagakerjaan',
        nama: 'NUNU FATULAH',
        noreg: '00415024',
        bagian: 'UNDERBODY',
        judul: 'Perbaikan Ventilasi Area',
        isi: 'Mohon pengecekan exhaust fan.',
        hasAttachment: true,
        createdAtIso: '2026-11-16T10:30:00.000Z',
        status: 'Terkirim',
      );
      final encoded = AspirasiTicket.encodeList([sample]);
      final decoded = AspirasiTicket.decodeList(encoded);
      expect(decoded.length, 1);
      expect(decoded.first.id, 'ASP-123456AB');
      expect(decoded.first.judul, 'Perbaikan Ventilasi Area');
      expect(decoded.first.hasAttachment, isTrue);
    });

    testWidgets('LaporScreen renders 3 aspirasi cards and opens form modal',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: LaporScreen(
            session: UserSession(
              noreg: '00415024',
              nama: 'NUNU FATULAH',
              job: 'KP',
              token: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ruang Aspirasi & Laporan'), findsOneWidget);
      expect(find.text('Lapor Ketenagakerjaan'), findsOneWidget);
      expect(find.text('Usul...!!! Bukan Usil'), findsOneWidget);
      expect(find.text('Nanya Dong...!!!'), findsOneWidget);
      final laporHeaderRect = tester.getRect(
        find.text('Ruang Aspirasi & Laporan'),
      );
      final firstCardRect = tester.getRect(find.text('Lapor Ketenagakerjaan'));
      expect(laporHeaderRect.bottom, lessThan(firstCardRect.top));

      await tester.tap(find.text('Buat Laporan'));
      await tester.pumpAndSettle();
      expect(find.text('Judul / Topik Utama *'), findsOneWidget);
      expect(find.text('Uraian Lengkap *'), findsOneWidget);
      expect(find.text('Kirim Buat Laporan'), findsOneWidget);
    });
  });

  group('Pintar & Pusat Training module', () {
    test('TrainingTicketItem maps API status CheckIn and QR payload identically',
        () {
      final activeTicket = TrainingTicketItem.fromApiOrCache({
        'id': 11,
        'idnya': 'pleno-nov-2026',
        'nama': 'NUNU FATULAH',
        'noreg': '00415024',
        'Kode': 'tikabsensiABC123',
        'status': 'CheckIn',
        'event': {
          'namaAcara': 'Training Kaderisasi Pleno',
          'tanggalAcara': '2026-11-20',
        },
      });
      expect(activeTicket.used, isFalse);
      expect(activeTicket.qrPayload, 'untukabsen:tikabsensiABC123');
      expect(activeTicket.eventNama, 'Training Kaderisasi Pleno');
      expect(activeTicket.formattedTanggal, '20 November 2026');
    });

    testWidgets(
        'TrainingScreen computes totalBelum & totalTiket badges matching bungteminAPP',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      const sampleTrainings = [
        TrainingEventItem(
          id: 1,
          eventSlug: 'evt-1',
          namaAcara: 'Training Pleno 1',
          tanggalAcara: '2026-11-20',
          tempat: 'Ruang Rapat PUK',
        ),
        TrainingEventItem(
          id: 2,
          eventSlug: 'evt-2',
          namaAcara: 'Training Pleno 2',
          tanggalAcara: '2026-11-25',
          tempat: 'Karawang Plant 1',
        ),
      ];
      const sampleTickets = [
        TrainingTicketItem(
          id: 10,
          eventSlug: 'evt-1',
          nama: 'NUNU FATULAH',
          noreg: '00415024',
          token: 'tikabsensi999',
          used: false,
          eventNama: 'Training Pleno 1',
          tgl: '2026-11-20',
        ),
      ];

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(
            size: Size(360, 800),
            padding: EdgeInsets.only(top: 36),
          ),
          child: MaterialApp(
            home: TrainingScreen(
              initialTrainings: sampleTrainings,
              initialTickets: sampleTickets,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pusat Training'), findsOneWidget);
      expect(find.text('Tiket (1)'), findsOneWidget);
      expect(find.text('1. Jadwal Belajar'), findsOneWidget);
      expect(find.text('1.1 Agenda Bulan Ini'), findsOneWidget);
      expect(find.text('Pleno'), findsOneWidget);
      expect(find.text('Tiket Saya'), findsOneWidget);

      final statsRect = tester.getRect(find.text('Training Tersedia'));
      final ticketStatsRect = tester.getRect(find.text('Tiket Terdaftar'));
      final firstMenuRect = tester.getRect(find.text('1. Jadwal Belajar'));
      expect(statsRect.bottom, lessThan(firstMenuRect.top));
      expect(ticketStatsRect.bottom, lessThan(firstMenuRect.top));
    });

    testWidgets('TrainingTicketScreen flips card to show QR code',
        (tester) async {
      const sampleTickets = [
        TrainingTicketItem(
          id: 10,
          eventSlug: 'evt-1',
          nama: 'NUNU FATULAH',
          noreg: '00415024',
          token: 'tikabsensi999',
          used: false,
          eventNama: 'Training Pleno 1',
          tgl: '2026-11-20',
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainingTicketScreen(initialTickets: sampleTickets),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TIKET AKTIF'), findsOneWidget);
      expect(find.text('#tikabsensi999'), findsNothing);
      expect(find.text('Ketuk Kartu Untuk Tampilkan QR'), findsOneWidget);

      await tester.tap(find.text('Ketuk Kartu Untuk Tampilkan QR'));
      await tester.pumpAndSettle();
      expect(find.text('SCAN QR KEHADIRAN'), findsOneWidget);
    });

    testWidgets('PintarBukuScreen lists UU documents and filters by search',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(
            size: Size(360, 800),
            padding: EdgeInsets.only(top: 36),
          ),
          child: MaterialApp(
            home: PintarBukuScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Buku Pintar SPSI'), findsOneWidget);
      expect(find.text('UU NOMOR 13 TAHUN 2003'), findsOneWidget);
      expect(find.text('UU NOMOR 21 TAHUN 2000'), findsOneWidget);
      final subtitleRect = tester.getRect(
        find.text('Kumpulan undang-undang & referensi ketenagakerjaan offline'),
      );
      final searchRect = tester.getRect(find.byType(TextField));
      expect(subtitleRect.bottom, lessThan(searchRect.top));
    });
  });

  group('Login guards for protected member features', () {
    test('enforces requiresLogin on protected NewMenu routes even if API sends false',
        () {
      const sample = '''
      {
        "value": [
          {
            "items": [
              {"label":"Berita","icon":"assets/icon/1.png","routerLink":"/news","requiresLogin":false},
              {"label":"Cerita","icon":"assets/icon/2.png","routerLink":"/tabfeed/feed","requiresLogin":false},
              {"label":"Hallo PUK","icon":"assets/icon/3.png","routerLink":"/lapor","requiresLogin":false},
              {"label":"Meeting","icon":"assets/icon/23.png","routerLink":"/meeting","requiresLogin":false},
              {"label":"BTapp","icon":"assets/icon/12.png","routerLink":"/aplikasi","requiresLogin":false},
              {"label":"BTScan","icon":"assets/icon/9.png","routerLink":"/scanner","requiresLogin":false},
              {"label":"MyArs","icon":"assets/icon/15.png","routerLink":"/aplikasi/absensi/tiketlist","requiresLogin":false},
              {"label":"Quiz","icon":"assets/icon/14.png","routerLink":"/quiz/lobby","requiresLogin":false},
              {"label":"Pretest","icon":"assets/icon/17.png","routerLink":"/pretest/lobby","requiresLogin":false},
              {"label":"Bucat","icon":"assets/icon/18.png","routerLink":"/aplikasi/note","requiresLogin":false},
              {"label":"Kodawari","icon":"assets/icon/20.png","routerLink":"/aplikasi/todo","requiresLogin":false},
              {"label":"Bubabe","icon":"assets/icon/16.png","routerLink":"/struktur","requiresLogin":false}
            ]
          }
        ]
      }
      ''';
      final parsed = BungteminApi.parseMenuJson(sample);
      final byLabel = {for (final m in parsed) m.label: m};

      expect(byLabel['Berita']!.requiresLogin, isFalse);
      expect(byLabel['Bucat']!.requiresLogin, isFalse);
      expect(byLabel['Kodawari']!.requiresLogin, isFalse);
      expect(byLabel['Bubabe']!.route, '/bubabe');

      for (final protectedLabel in const [
        'Cerita',
        'Hallo PUK',
        'Meeting',
        'BTapp',
        'BTScan',
        'MyArs',
        'Quiz',
        'Pretest',
      ]) {
        expect(
          byLabel[protectedLabel]!.requiresLogin,
          isTrue,
          reason: '$protectedLabel must require login',
        );
      }

      final defaultByLabel = {
        for (final m in BungteminMenuItem.defaults) m.label: m,
      };
      for (final protectedLabel in const [
        'Cerita',
        'Hallo PUK',
        'Meeting',
        'BTapp',
        'BTScan',
        'MyArs',
        'Quiz',
        'Pretest',
      ]) {
        expect(defaultByLabel[protectedLabel]!.requiresLogin, isTrue);
      }
    });

    testWidgets(
        'MainShellScreen prompts LoginScreen when tapping protected menus while logged out',
        (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      for (final label in const [
        'Cerita',
        'Hallo PUK',
        'Meeting',
        'BTapp',
        'BTScan',
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('menu-$label'),
            home: MainShellScreen(
              session: null,
              onAuthenticated: (_) {},
              onLogout: () {},
              onOpenTutorial: () {},
            ),
          ),
        );
        await tester.pump();
        await tester.ensureVisible(find.text(label));
        await tester.pump();
        await tester.tap(find.text(label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(
          find.textContaining('membutuhkan akun anggota'),
          findsOneWidget,
        );
      }
    });

    testWidgets(
        'MainShellScreen prompts LoginScreen for MyArs, Quiz, and Pretest in Lainnya sheet',
        (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      for (final label in const ['MyArs', 'Quiz', 'Pretest']) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('more-$label'),
            home: MainShellScreen(
              session: null,
              onAuthenticated: (_) {},
              onLogout: () {},
              onOpenTutorial: () {},
            ),
          ),
        );
        await tester.pump();

        await tester.ensureVisible(find.text('Lainnya'));
        await tester.pump();
        await tester.tap(find.text('Lainnya'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.ensureVisible(find.text(label));
        await tester.pump();
        await tester.tap(find.text(label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(
          find.textContaining('membutuhkan akun anggota'),
          findsOneWidget,
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('more-search'),
          home: MainShellScreen(
            session: null,
            onAuthenticated: (_) {},
            onLogout: () {},
            onOpenTutorial: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Lainnya'));
      await tester.pump();
      await tester.tap(find.text('Lainnya'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(find.byType(TextField), 'Kodawari');
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(GridView).last,
          matching: find.text('Kodawari'),
        ),
        findsOneWidget,
      );
      expect(find.text('MyArs'), findsNothing);
    });

    testWidgets(
        'QuizLobbyScreen and PretestLobbyScreen block direct access without UserSession',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(home: QuizLobbyScreen(session: null)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Login Anggota Diperlukan'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(home: PretestLobbyScreen(session: null)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Login Anggota Diperlukan'), findsOneWidget);
    });
  });

  testWidgets('MeetingTab splits PUK, KP, Pleno and Anggota tabs like web router',
      (tester) async {
    const sampleSession = UserSession(
      noreg: '00415024',
      nama: 'NUNU FATULAH',
      job: 'KP',
      token: '',
    );
    const sampleData = MeetingDashboardData(
      total: 4,
      scheduled: 1,
      ongoing: 1,
      completed: 0,
      roleLabel: 'Koordinator Pleno',
      pctHadir: 80,
      meetings: [
        MeetingItem(
          id: 3,
          kodeMeeting: 'MTG-PUK-01',
          judul: 'Rapat Bulanan PUK',
          kategori: 'Rapat PUK',
          tanggal: '2026-11-19',
          jamMulai: '10:00',
          tempat: 'Ruang Rapat PUK',
          status: 'planning',
          kpNama: '-',
          plenoNama: '-',
          totalPeserta: 15,
          totalHadir: 0,
        ),
        MeetingItem(
          id: 4,
          kodeMeeting: 'MTG-KP-01',
          judul: 'Rapat Koordinasi KP',
          kategori: 'Rapat KP',
          tanggal: '2026-11-21',
          jamMulai: '09:00',
          tempat: 'Ruang Rapat PUK',
          status: 'planning',
          kpNama: 'WAHYONO',
          plenoNama: '-',
          totalPeserta: 22,
          totalHadir: 0,
        ),
        MeetingItem(
          id: 1,
          kodeMeeting: 'MTG-PLENO-01',
          judul: 'Rapat Koordinasi Pleno November',
          kategori: 'Rapat Pleno',
          tanggal: '2026-11-20',
          jamMulai: '13:00',
          tempat: 'Ruang Rapat PUK',
          status: 'ongoing',
          kpNama: 'WAHYONO',
          plenoNama: 'KARWITANG',
          totalPeserta: 20,
          totalHadir: 16,
        ),
        MeetingItem(
          id: 2,
          kodeMeeting: 'MTG-ANGGOTA-01',
          judul: 'Sosialisasi Anggota Karwitang',
          kategori: 'Rapat Member',
          tanggal: '2026-11-22',
          jamMulai: '16:00',
          tempat: 'Kantin Plant 1',
          status: 'planning',
          kpNama: 'WAHYONO',
          plenoNama: 'KARWITANG',
          totalPeserta: 10,
          totalHadir: 0,
        ),
      ],
    );

    tester.view.physicalSize = const Size(430, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MeetingTab(
            session: sampleSession,
            initialSegment: 0,
            lockSegment: true,
            initialData: sampleData,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 4-tab switcher dihilangkan; segment awal 0 menampilkan Rapat PUK.
    expect(find.text('PUK (1)'), findsNothing);
    expect(find.text('Rapat Bulanan PUK'), findsOneWidget);
    expect(find.text('Rapat Koordinasi KP'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MeetingTab(
            session: sampleSession,
            initialSegment: 1,
            lockSegment: true,
            initialData: sampleData,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rapat Koordinasi KP'), findsOneWidget);
    expect(find.text('Rapat Bulanan PUK'), findsNothing);
  });

  testWidgets('Tapping Bubabe opens BubabeScreen even if NewMenu cache has /struktur',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const menuWithStrukturForBubabe = '''
    {
      "value": [
        {
          "items": [
            {"label":"Berita","icon":"assets/icon/1.png","routerLink":"/news","requiresLogin":false},
            {"label":"Cerita","icon":"assets/icon/2.png","routerLink":"/tabfeed/feed","requiresLogin":false},
            {"label":"Tonton","icon":"assets/icon/13.png","routerLink":"/tonton","requiresLogin":false},
            {"label":"Pintar","icon":"assets/icon/4.png","routerLink":"/training","requiresLogin":true},
            {"label":"Hallo PUK","icon":"assets/icon/3.png","routerLink":"/lapor","requiresLogin":false},
            {"label":"Meeting","icon":"assets/icon/23.png","routerLink":"/meeting","requiresLogin":false},
            {"label":"BTapp","icon":"assets/icon/12.png","routerLink":"/aplikasi","requiresLogin":false},
            {"label":"Struktur","icon":"assets/icon/7.png","routerLink":"/struktur","requiresLogin":false},
            {"label":"Profil","icon":"assets/icon/8.png","routerLink":"/profil","requiresLogin":true},
            {"label":"BTScan","icon":"assets/icon/9.png","routerLink":"/scanner","requiresLogin":false},
            {"label":"Kalender","icon":"assets/icon/10.png","routerLink":"/kalender","requiresLogin":false},
            {"label":"Bubabe","icon":"assets/icon/16.png","routerLink":"/struktur","requiresLogin":false}
          ]
        }
      ]
    }
    ''';

    SharedPreferences.setMockInitialValues({
      'bt_menu_cache': menuWithStrukturForBubabe,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MainShellScreen(
          session: null,
          onAuthenticated: (_) {},
          onLogout: () {},
          onOpenTutorial: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.text('Lainnya'));
    await tester.pump();
    await tester.tap(find.text('Lainnya'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.ensureVisible(find.text('Bubabe'));
    await tester.pump();
    await tester.tap(find.text('Bubabe'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Bubabe · Bursa Barang Bekas'), findsOneWidget);
    expect(find.text('Struktur Kepengurusan'), findsNothing);
  });
}
