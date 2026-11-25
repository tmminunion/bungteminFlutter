# Standar Penambahan Menu Baru — Ekosistem Bungtemin (AdminPanel, BTadmin & bungteminFlutter)

Dokumen ini menjadi acuan wajib setiap kali menambahkan menu baru di aplikasi **bungteminFlutter** agar otomatis memiliki kontrol status **`ON` / `MAINT` / `OFF`** di **Admin Panel Web (`/adminpanel/appmenus`)** maupun **BTadmin (Menu Aplikasi Flutter)**.

---

## 1. Sumber Tunggal Katalog Menu (Backend PHP)

Semua menu mobile dikendalikan secara terpusat di:
- **`Nurani_sync/backups/bungtemin/core/classes/AppMenuConfig.php`** → method `defaultCatalog()`.

Setiap entri baru **wajib** memiliki struktur lengkap:
```php
[
    'key'           => 'nama_unik_snake_case', // ID permanen untuk toggle ON/MAINT/OFF
    'label'         => 'Nama Menu',            // Teks yang tampil di Home, AdminPanel & BTadmin
    'icon'          => 'assets/icon/XX.png',   // Path aset ikon di bungteminFlutter
    'route'         => '/rute-menu',           // Rute unik yang ditangani MainShell
    'requiresLogin' => true,                   // true jika wajib login anggota
    'group'         => 'main',                 // 'main' (grid utama Home) atau 'extra' (sheet Lainnya)
],
```

**Otomatis terhubung ke:**
1. **`GET /btapi/Menu/list`** → dibaca oleh `bungteminFlutter` (`BungteminApi.fetchMenus()`).
2. **`/adminpanel/appmenus`** → kontrol web Admin Panel (`ON`, `MAINT` + pesan kustom, `OFF`, pindah `main`/`extra`).
3. **`GET /btapi/AdminApp/home` & `POST /btapi/AdminApp/update_appmenu`** → kontrol native di aplikasi **BTadmin**.

> **Wajib deploy** `core/classes/AppMenuConfig.php` ke FTP (`python3 Nurani_sync/ftp_dev.py push core/classes/AppMenuConfig.php`) lalu verifikasi kemunculannya di `https://bungtemin.net/btapi/Menu/list`.

---

## 2. Integrasi di `bungteminFlutter`

Setelah ditambahkan di `AppMenuConfig.php`, lakukan 5 langkah berikut di repo `bungteminFlutter`:

1. **Fallback Offline (`lib/models/bungtemin_menu.dart`):**
   - Tambahkan entri yang sama persis di `BungteminMenuItem.defaults` (termasuk `group: 'main'` atau `'extra'`).
   - Jika `requiresLogin: true`, tambahkan prefix rutenya dan label huruf kecilnya di `BungteminMenuItem.requiresLoginFor(...)`.
2. **Routing & Kepatuhan Mode `ON` / `MAINT` / `OFF` (`lib/features/shell/main_shell.dart`):**
   - Pastikan semua klik dari Home masuk ke `_handleMenuTap(item)` (yang sudah otomatis memblokir `item.isOff` dan menampilkan dialog `item.isMaintenance`).
   - Tambahkan handler rute di `_executeMenuRoute(item)`.
   - Jika menu juga ditaruh di **Side Menu (`_BungteminDrawer`)** atau **Deep Link**, **wajib** cek status menu dari `BungteminApi().fetchMenus()` dan teruskan ke `_handleMenuTap(...)` saat status `isOff` atau `isMaintenance` agar kontrol AdminPanel/BTadmin tidak bisa dilewati.
   - Tambahkan deskripsi menu pada fungsi deskripsi fitur di `main_shell.dart`.
3. **Role & Hak Akses (jika khusus Pengurus):**
   - Jika menu mengikuti hak akses web `organisasi` (PUK / KP / Pleno), gunakan `fetchMeetingMeta()` / `Organisasi.php` untuk membatasi aksi sesuai role (`canManageAll`, `isKp`, `isPleno`).
4. **Update Unit Test (`test/widget_test.dart`):**
   - Perbarui jumlah ekspektasi `expect(BungteminMenuItem.defaults.length, <jumlah_baru>);` agar CI GitHub Actions tetap hijau.
5. **Verifikasi Akhir:**
   - Cek `GET https://bungtemin.net/btapi/Menu/list` memuat `key` menu baru dengan `mode: "online"`.
   - Uji ubah status menu ke `MAINT` dan `OFF` lewat **AdminPanel (`/adminpanel/appmenus`)** atau **BTadmin**, lalu pastikan Home dan Side Menu di `bungteminFlutter` mematuhinya.
