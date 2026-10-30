# AgroSync (Flutter, MVP v0.1)

Aplikasi pemilik hidroponik rumahan: pantau pH, EC/TDS, level air, suhu, kelembapan;
status 4 pompa; kontrol manual; watering log; pusat peringatan; kartu tanaman dan rekomendasi.
Mengikuti dokumen *AgroSync Rancangan Aplikasi Mobile* (M1-M8, E1). Bahasa antarmuka: Indonesia.
Aplikasi hanya membaca status dari Firebase dan mengirim permintaan perintah; keputusan penyiraman ada di server.

## Status (jujur)
Kode ini **belum pernah dikompilasi atau dijalankan** (Flutter SDK tidak tersedia di lingkungan penulisan).
Harapkan beberapa galat kecil pada `flutter analyze` / `flutter run` pertama. Mohon dilaporkan agar diperbaiki.

## Setup pertama
```bash
cd flutter_app
flutter create --platforms=android --org id.ac.mercubuana --project-name agrosync .
rm -f test/widget_test.dart lib/main.dart   # contoh bawaan flutter create; kita memakai main_dummy/main_firebase
flutter pub get
flutter analyze && flutter test
```
`flutter create` membuat folder `android/`. Setelah itu, di `android/app/build.gradle(.kts)` set `minSdk` minimal 23
(syarat Firebase) dan di `AndroidManifest.xml` tambahkan izin `INTERNET` dan `POST_NOTIFICATIONS` (Android 13+).

## Menjalankan
| Flavor | Perintah | Butuh Firebase |
|---|---|---|
| Dummy (E1) | `flutter run -t lib/main_dummy.dart` | Tidak |
| Firebase | `flutter run -t lib/main_firebase.dart` | Ya |

Flavor dummy: login sudah terisi (`sari@email.com` / `agrosync123`). Di **Pengaturan > Mode data dummy**
bisa memilih skenario Normal, Waspada, Bahaya, Perangkat mati, riwayat kosong, dan perangkat tidak merespons.
Pompa nutrisi/dosing ditolak saat skenario Bahaya (interlock level air); perintah ulang < 30 detik ditolak.

## Menyambung Firebase (flavor firebase)
1. Buat project Firebase **uji**; aktifkan Authentication (Email/Password), Realtime Database, Cloud Messaging.
2. Daftarkan app Android, unduh `google-services.json` ke `android/app/` (sudah di `.gitignore`), lalu ikuti
   langkah plugin Google Services Gradle (atau pakai `flutterfire configure`).
3. Terapkan `database.rules.json` (Firebase Console > Realtime Database > Rules, atau `firebase deploy --only database`).
   Ini aturan arah dari dokumen 6.3; **validasi enum/durasi dan tes Emulator belum ditulis**.
4. Isi data awal (akun dibuat tim di Console): `/users/{uid}/deviceId`, `/deviceMembers/{deviceId}/{uid} = true`,
   dan node `/devices/{deviceId}/...` sesuai kontrak (dokumen 4.2).

## Struktur
```
lib/
  main_dummy.dart / main_firebase.dart   dua titik masuk = dua flavor
  app.dart  providers.dart               MaterialApp.router, provider Riverpod, CommandController
  core/       tema (Poppins+Inter, WCAG AA), router (go_router), widget bersama, format
  domain/     models.dart (fromMap defensif) + repositories.dart (antarmuka)
  data/
    dummy/    DummyBackend: meniru server (validasi perintah, jeda, interlock, skenario)
    firebase/ implementasi Firebase; satu-satunya tempat yang mengenal bentuk data Firebase
  features/   auth, dashboard (beranda, detail sensor, shell), kontrol, riwayat, tanaman, peringatan, pengaturan
```
UI tidak pernah menyentuh Firebase langsung; semua lewat repository.

## Pemetaan fitur
M1 login/sesi: `features/auth` · M2 dashboard + offline (>2 menit): `dashboard` · M3 status pompa: Beranda/Kontrol ·
M4 mode + perintah (menunggu/diterima/selesai/ditolak/kedaluwarsa 30 dtk, id unik via `push()`): `kontrol` + `CommandController` ·
M5 log (20 per halaman, kursor waktu): `riwayat` · M6 pusat peringatan + badge belum dibaca: `peringatan` ·
M7/M8 kartu tanaman dan rekomendasi (state "belum tersedia"): `tanaman` · E1: `data/dummy`.

## Belum dikerjakan / keputusan terbuka
- **Notifikasi push penuh:** izin + penyimpanan/penghapusan token FCM sudah ada. **Belum:** `flutter_local_notifications`
  (notifikasi saat aplikasi di latar depan), channel Android bahaya/waspada, deep link dari ketukan notifikasi (go_router), refresh token.
- **Foto tanaman:** sumber foto belum diputuskan (dokumen 5.4). Saat ini placeholder gambar; path berawalan `http` memakai `Image.network`
  (butuh URL privat bertoken, belum ada `cached_network_image`).
- Usulan tambahan ke kontrak data: `pompa/{id}/endsAt` (untuk hitung mundur), `status/kelembapan`, dan `alert/*/pesan` berbahasa Indonesia.
- Kunci kebijakan versi paket (`pubspec.lock`), CI GitHub Actions, Crashlytics, tes widget per keadaan layar, dan tes aturan keamanan Emulator.
- Mode gelap dan ukuran teks (fitur tambahan A1) tidak termasuk MVP.
