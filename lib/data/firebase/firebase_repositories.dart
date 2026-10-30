import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';

// Implementasi Firebase. Mengikuti kontrak data (dokumen bagian 4.2) yang
// BELUM disepakati dengan backend: bila skema berubah, cukup ubah berkas ini.

DatabaseReference _dev(String id, String path) => FirebaseDatabase.instance.ref('devices/$id/$path');

Stream<Map<String, dynamic>?> _watchMap(DatabaseReference r) => r.onValue.map((e) => asMap(e.snapshot.value));

class FirebaseAuthRepository implements AuthRepository {
  final _auth = FirebaseAuth.instance;

  @override
  Stream<AppUser?> authState() => _auth.authStateChanges().asyncMap((u) async {
        if (u == null) return null;
        String? deviceId;
        try {
          final snap = await FirebaseDatabase.instance.ref('users/${u.uid}/deviceId').get();
          deviceId = asStr(snap.value);
        } catch (_) {}
        return AppUser(uid: u.uid, email: u.email ?? '-', deviceId: deviceId);
      });

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' => 'Email atau kata sandi salah.',
        'invalid-email' => 'Alamat email belum benar. Contoh: nama@email.com',
        'network-request-failed' => 'Tidak ada koneksi internet. Periksa Wi-Fi atau data seluler Anda.',
        'too-many-requests' => 'Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi.',
        'user-disabled' => 'Akun ini dinonaktifkan. Hubungi tim AgroSync.',
        _ => 'Gagal masuk. Coba lagi sebentar lagi.',
      });
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

class FirebaseNotificationRepository implements NotificationRepository {
  DatabaseReference _tokenRef(String uid, String token) =>
      FirebaseDatabase.instance.ref('users/$uid/fcmTokens/${token.hashCode.abs()}');

  @override
  Future<bool> requestPermission(String uid) async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    final ok = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!ok) return false;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _tokenRef(uid, token).set({'token': token, 'platform': 'android', 'diperbarui': ServerValue.timestamp});
    }
    return true;
  }

  @override
  Future<void> removeToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _tokenRef(uid, token).remove();
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {/* gagal hapus token tidak boleh menghalangi keluar */}
  }
}

class FirebaseDeviceRepository implements DeviceRepository {
  @override
  Stream<SensorReading?> watchSensor(String id) => _watchMap(_dev(id, 'sensor')).map(SensorReading.fromMap);

  @override
  Stream<DeviceStatus?> watchStatus(String id) => _watchMap(_dev(id, 'status')).map(DeviceStatus.fromMap);

  /// Daftar pompa dibangun dari kunci node /pompa, jadi jumlah pompa bisa berubah tanpa rilis ulang.
  @override
  Stream<List<PumpState>> watchPumps(String id) => _watchMap(_dev(id, 'pompa')).map((m) {
        if (m == null) return <PumpState>[];
        final keys = m.keys.toList()..sort();
        return [for (final k in keys) PumpState.fromMap(k, asMap(m[k]))];
      });

  @override
  Stream<DeviceSettings> watchSettings(String id) => _watchMap(_dev(id, 'pengaturan')).map(DeviceSettings.fromMap);
}

class FirebaseCommandRepository implements CommandRepository {
  Future<String> _push(String deviceId, Map<String, Object?> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw const AuthFailure('Sesi berakhir. Silakan masuk lagi.');
    // push() menghasilkan id unik, sehingga perintah tidak bisa ganda.
    final ref = _dev(deviceId, 'perintah').push();
    await ref.set({...data, 'dibuatOleh': uid, 'dibuatPada': ServerValue.timestamp, 'status': 'menunggu'});
    return ref.key!;
  }

  @override
  Future<String> sendPump(String deviceId, String pumpId, {required bool on, int durasiDetik = 0}) =>
      _push(deviceId, {'tipe': 'pompa', 'target': pumpId, 'nilai': on ? 'nyala' : 'mati', 'durasiDetik': durasiDetik});

  @override
  Future<String> sendMode(String deviceId, OperatingMode mode) =>
      _push(deviceId, {'tipe': 'mode', 'target': 'mode', 'nilai': mode.name});

  @override
  Stream<Command?> watchCommand(String deviceId, String commandId) =>
      _watchMap(_dev(deviceId, 'perintah/$commandId')).map((m) => Command.fromMap(commandId, m));
}

class FirebaseLogRepository implements LogRepository {
  List<WateringLogEntry> _parse(DataSnapshot s) {
    final out = <WateringLogEntry>[];
    for (final c in s.children) {
      final e = WateringLogEntry.fromMap(c.key ?? '', asMap(c.value));
      if (e != null) out.add(e);
    }
    out.sort((a, b) => b.waktu.compareTo(a.waktu)); // terbaru di atas
    return out;
  }

  @override
  Stream<List<WateringLogEntry>> watchLatest(String deviceId, {int limit = 20}) =>
      _dev(deviceId, 'log').orderByChild('waktu').limitToLast(limit).onValue.map((e) => _parse(e.snapshot));

  // Perilaku kursor endBefore + limitToLast diverifikasi saat implementasi (dokumen 4.5).
  @override
  Future<List<WateringLogEntry>> fetchBefore(String deviceId, int beforeWaktu, {int limit = 20}) async {
    final snap = await _dev(deviceId, 'log').orderByChild('waktu').endBefore(beforeWaktu).limitToLast(limit).get();
    return _parse(snap);
  }
}

class FirebaseAlertRepository implements AlertRepository {
  @override
  Stream<List<AlertItem>> watchAlerts(String deviceId, {int limit = 50}) =>
      _dev(deviceId, 'alert').orderByChild('waktu').limitToLast(limit).onValue.map((e) {
        final out = <AlertItem>[];
        for (final c in e.snapshot.children) {
          final a = AlertItem.fromMap(c.key ?? '', asMap(c.value));
          if (a != null) out.add(a);
        }
        out.sort((a, b) => b.waktu.compareTo(a.waktu));
        return out;
      });

  DatabaseReference _seen(String uid) => FirebaseDatabase.instance.ref('users/$uid/alertDilihatSampai');

  @override
  Stream<int> watchSeenAt(String uid) => _seen(uid).onValue.map((e) => asInt(e.snapshot.value) ?? 0);

  @override
  Future<void> markSeen(String uid, int atMs) => _seen(uid).set(atMs);
}

class FirebasePlantRepository implements PlantRepository {
  @override
  Stream<PlantSnapshot?> watchPlant(String deviceId, int tingkat) =>
      _watchMap(_dev(deviceId, 'tanaman/tingkat$tingkat')).map((m) => PlantSnapshot.fromMap(tingkat, m));

  @override
  Stream<Prediction?> watchPrediction(String deviceId) => _watchMap(_dev(deviceId, 'prediksi')).map(Prediction.fromMap);
}
