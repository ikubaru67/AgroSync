import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/dummy/dummy_backend.dart';
import 'domain/models.dart';
import 'domain/repositories.dart';

// Repository diisi di main_dummy.dart / main_firebase.dart lewat ProviderScope.overrides.
T _unset<T>() => throw UnimplementedError('Repository belum diisi di main_*.dart');
final authRepoProvider = Provider<AuthRepository>((ref) => _unset());
final notifRepoProvider = Provider<NotificationRepository>((ref) => _unset());
final deviceRepoProvider = Provider<DeviceRepository>((ref) => _unset());
final commandRepoProvider = Provider<CommandRepository>((ref) => _unset());
final logRepoProvider = Provider<LogRepository>((ref) => _unset());
final alertRepoProvider = Provider<AlertRepository>((ref) => _unset());
final plantRepoProvider = Provider<PlantRepository>((ref) => _unset());

/// Non-null hanya pada flavor dummy; dipakai untuk panel simulasi di Pengaturan.
final dummyBackendProvider = Provider<DummyBackend?>((ref) => null);

final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

final authUserProvider = StreamProvider<AppUser?>((ref) => ref.watch(authRepoProvider).authState());
final deviceIdProvider = Provider<String?>((ref) => ref.watch(authUserProvider).valueOrNull?.deviceId);

// Listener hanya hidup selama layar yang memakainya tampil (autoDispose).
final sensorProvider = StreamProvider.autoDispose<SensorReading?>((ref) {
  final id = ref.watch(deviceIdProvider);
  return id == null ? const Stream.empty() : ref.watch(deviceRepoProvider).watchSensor(id);
});
final statusProvider = StreamProvider.autoDispose<DeviceStatus?>((ref) {
  final id = ref.watch(deviceIdProvider);
  return id == null ? const Stream.empty() : ref.watch(deviceRepoProvider).watchStatus(id);
});
final pumpsProvider = StreamProvider.autoDispose<List<PumpState>>((ref) {
  final id = ref.watch(deviceIdProvider);
  return id == null ? const Stream.empty() : ref.watch(deviceRepoProvider).watchPumps(id);
});
final settingsProvider = StreamProvider.autoDispose<DeviceSettings>((ref) {
  final id = ref.watch(deviceIdProvider);
  return id == null ? const Stream.empty() : ref.watch(deviceRepoProvider).watchSettings(id);
});
final plantProvider = StreamProvider.autoDispose.family<PlantSnapshot?, int>((ref, tier) {
  final id = ref.watch(deviceIdProvider);
  return id == null ? const Stream.empty() : ref.watch(plantRepoProvider).watchPlant(id, tier);
});
final predictionProvider = StreamProvider.autoDispose<Prediction?>((ref) {
  final id = ref.watch(deviceIdProvider);
  return id == null ? const Stream.empty() : ref.watch(plantRepoProvider).watchPrediction(id);
});
final latestLogProvider = StreamProvider.autoDispose<List<WateringLogEntry>>((ref) {
  final id = ref.watch(deviceIdProvider);
  return id == null ? const Stream.empty() : ref.watch(logRepoProvider).watchLatest(id, limit: 20);
});
final alertSeenProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authUserProvider).valueOrNull?.uid;
  return uid == null ? const Stream.empty() : ref.watch(alertRepoProvider).watchSeenAt(uid);
});
final alertsLiveProvider = StreamProvider<List<AlertItem>>((ref) {
  final id = ref.watch(deviceIdProvider);
  return id == null ? const Stream.empty() : ref.watch(alertRepoProvider).watchAlerts(id);
});

/// Jumlah peringatan belum dibaca = alert lebih baru dari alertDilihatSampai.
final unreadAlertsProvider = Provider<int>((ref) {
  final seen = ref.watch(alertSeenProvider).valueOrNull ?? 0;
  final list = ref.watch(alertsLiveProvider).valueOrNull ?? const [];
  return list.where((a) => a.waktu > seen).length;
});

/// Perangkat dianggap offline bila data lebih lama dari 2 menit [ASUMSI] (FR-04).
const offlineAfter = Duration(minutes: 2);
final isOfflineProvider = Provider.autoDispose<bool>((ref) {
  final s = ref.watch(sensorProvider);
  if (!s.hasValue) return false;
  final t = s.value?.updatedAt;
  if (t == null) return true;
  final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
  return now.millisecondsSinceEpoch - t > offlineAfter.inMilliseconds;
});

enum NotifPermission { unknown, granted, denied }

class NotifPermissionController extends Notifier<NotifPermission> {
  @override
  NotifPermission build() => NotifPermission.unknown;

  Future<void> request() async {
    final uid = ref.read(authUserProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      final ok = await ref.read(notifRepoProvider).requestPermission(uid);
      state = ok ? NotifPermission.granted : NotifPermission.denied;
    } catch (_) {
      state = NotifPermission.denied;
    }
  }

  void skip() => state = NotifPermission.denied;
  void disable() => state = NotifPermission.denied;
}

final notifPermProvider = NotifierProvider<NotifPermissionController, NotifPermission>(NotifPermissionController.new);

/// Satu perintah aktif pada satu waktu. Status mengikuti server; kedaluwarsa
/// ditandai bila tidak ada respons dalam 30 detik [USULAN] (FR-07).
class CommandController extends Notifier<Command?> {
  StreamSubscription<Command?>? _sub;
  Timer? _expire;
  static const expireAfter = Duration(seconds: 30);

  @override
  Command? build() {
    ref.onDispose(() {
      _sub?.cancel();
      _expire?.cancel();
    });
    return null;
  }

  void _watch(String deviceId, String id, Command first) {
    _sub?.cancel();
    _expire?.cancel();
    state = first;
    _sub = ref.read(commandRepoProvider).watchCommand(deviceId, id).listen((c) {
      if (c != null) state = c;
    });
    _expire = Timer(expireAfter, () {
      final s = state;
      if (s != null && s.id == id && s.status == CommandStatus.menunggu) {
        state = s.copyWith(status: CommandStatus.kedaluwarsa);
      }
    });
  }

  Future<void> sendPump(String pumpId, {required bool on, int durasiDetik = 0}) async {
    final deviceId = ref.read(deviceIdProvider);
    if (deviceId == null) return;
    final id = await ref.read(commandRepoProvider).sendPump(deviceId, pumpId, on: on, durasiDetik: durasiDetik);
    _watch(deviceId, id, Command(id: id, tipe: 'pompa', target: pumpId, nilai: on ? 'nyala' : 'mati', durasiDetik: durasiDetik));
  }

  Future<void> sendMode(OperatingMode mode) async {
    final deviceId = ref.read(deviceIdProvider);
    if (deviceId == null) return;
    final id = await ref.read(commandRepoProvider).sendMode(deviceId, mode);
    _watch(deviceId, id, Command(id: id, tipe: 'mode', target: 'mode', nilai: mode.name));
  }

  void dismiss() => state = null;
}

final commandProvider = NotifierProvider<CommandController, Command?>(CommandController.new);

Future<void> signOut(WidgetRef ref) async {
  final user = ref.read(authUserProvider).valueOrNull;
  if (user != null) await ref.read(notifRepoProvider).removeToken(user.uid); // hapus token FCM saat logout
  ref.read(commandProvider.notifier).dismiss();
  await ref.read(authRepoProvider).signOut();
}
