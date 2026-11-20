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

## 3 Jalur Media & Penyimpanan
1. **SharePoint (`bungtemin.net`)** — Akses langsung dokumen & media SharePoint TMMIN.
2. **NUDB (`https://nudb.bungtemin.net`) → SharePoint & Google Drive Bungtemin** — `/api/ubdrive/*` (SharePoint) dan `/api/gdrive/*` + `/gdrive/file/:id` (upload & streaming video Reels/Story besar dengan HTTP Range via OAuth2 `bungtemin@gmail.com`).
3. **Dev Imageproxy (`https://dev.bungtemin.net`) → Google Drive Bungtemin** — Proxy gambar cepat dengan Vercel Edge CDN Cache 1 tahun (`immutable`), resize/thumbnail/WebP on-the-fly (`/api/drive/:id`, `/api/drive/upload`, `/api/drive/list`, `/api/bingkai`, `/api/drive/health`) via OAuth2 `bungtemin@gmail.com` (folder `Bungtemin/images` & `Bungtemin/bingkai`).

## Lisensi
Kode boleh **dilihat**, tetapi **tidak boleh dipakai ulang** (source-available, all rights reserved). Lihat [LICENSE](LICENSE).
