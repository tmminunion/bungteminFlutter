# bungteminFlutter

Eksperimen aplikasi mobile **PUK SP LEM SPSI PT. TMMIN** menggunakan **Flutter (Material 3)** — dikembangkan di Termux dan dibangun otomatis di **GitHub Actions** (APK + Play Store AAB 16 KB aligned).

## Fitur Awal
- **Login & Mode Preview Noreg** (`btapi/User/login/`, `Idcard/api/me`, `Idcard/api/member/...`)
- **Beranda** (Ringkasan statistik meeting + feed Stories dari `btapi/Media/stories`)
- **KTA Digital 3D Flip** (Animasi flip native 60–120fps, normalisasi jabatan `KP`/`PLENO`/`PUK`/`ANGGOTA`, modal QR presensi `qr_flutter`)
- **Agenda Meeting** (`btapi/Meeting/index` dengan filter kategori & detail sheet)

## Alur Kerja
1. Edit kode di Termux (`/data/data/com.termux/files/home/bungteminFlutter`) — tanpa build lokal.
2. `git push origin main` untuk menjalankan `flutter analyze`, `flutter test`, `flutter build apk --release`, `flutter build appbundle --release`, publish GitHub Release, dan mengirim APK ke Telegram.
