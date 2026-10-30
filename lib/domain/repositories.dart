// Antarmuka repository. UI hanya mengenal berkas ini, tidak pernah Firebase.
// Implementasi: data/dummy (flavor dummy) dan data/firebase (flavor firebase).
import 'models.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class AuthRepository {
  Stream<AppUser?> authState();
  Future<void> signIn(String email, String password); // melempar AuthFailure
  Future<void> signOut();
}

abstract class NotificationRepository {
  /// Meminta izin dan menyimpan token FCM milik pengguna. Mengembalikan true bila diizinkan.
  Future<bool> requestPermission(String uid);
  Future<void> removeToken(String uid);
}

abstract class DeviceRepository {
  Stream<SensorReading?> watchSensor(String deviceId);
  Stream<DeviceStatus?> watchStatus(String deviceId);
  Stream<List<PumpState>> watchPumps(String deviceId);
  Stream<DeviceSettings> watchSettings(String deviceId);
}

abstract class CommandRepository {
  /// Mengembalikan id perintah unik. Server memvalidasi dan memperbarui status.
  Future<String> sendPump(String deviceId, String pumpId, {required bool on, int durasiDetik = 0});
  Future<String> sendMode(String deviceId, OperatingMode mode);
  Stream<Command?> watchCommand(String deviceId, String commandId);
}

abstract class LogRepository {
  Stream<List<WateringLogEntry>> watchLatest(String deviceId, {int limit = 20});
  Future<List<WateringLogEntry>> fetchBefore(String deviceId, int beforeWaktu, {int limit = 20});
}

abstract class AlertRepository {
  Stream<List<AlertItem>> watchAlerts(String deviceId, {int limit = 50});
  Stream<int> watchSeenAt(String uid);
  Future<void> markSeen(String uid, int atMs);
}

abstract class PlantRepository {
  Stream<PlantSnapshot?> watchPlant(String deviceId, int tingkat);
  Stream<Prediction?> watchPrediction(String deviceId);
}
