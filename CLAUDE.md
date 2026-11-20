# bungteminFlutter Guidelines

- **DILARANG BUILD LOKAL DI TERMUX:** Flutter SDK dan Android Gradle tidak dijalankan di Termux lokal agar tidak membebani CPU/RAM HP.
- **BUILD OTOMATIS DI GITHUB ACTIONS:** Setiap `git push origin main` akan memicu `.github/workflows/build-flutter.yml` (`flutter analyze`, `flutter test`, `flutter build apk --release`, `flutter build appbundle --release`, publish GitHub Release, dan kirim APK ke Telegram).
- **Arsitektur Fitur:**
  - `lib/core/` — Tema Material 3 (Navy & Gold TMMIN), SessionStore (`SharedPreferences`)
  - `lib/models/` — Model data KTA, Meeting, Stories
  - `lib/services/` — HTTP client ke `https://bungtemin.net/btapi/...` & `Idcard/api/...`
  - `lib/features/` — Screen Auth, Main Shell, Home, KTA 3D Flip, Meeting
