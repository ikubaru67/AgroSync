import 'dart:async';
import 'dart:math' as math;

import '../../domain/models.dart';
import '../../domain/repositories.dart';

/// Nilai yang selalu punya nilai terkini dan bisa didengarkan (tanpa rxdart).
class Live<T> {
  Live(this._v);
  T _v;
  final _c = StreamController<T>.broadcast();
  T get value => _v;
  set value(T v) {
    _v = v;
    _c.add(v);
  }

  Stream<T> get stream async* {
    yield _v;
    yield* _c.stream;
  }
}

enum Scenario { normal, waspada, bahaya, offline }

const _min = 60 * 1000;
const _hr = 60 * _min;
int _now() => DateTime.now().millisecondsSinceEpoch;

/// Backend palsu untuk flavor dummy (E1). Meniru perilaku server: validasi
/// perintah, jeda antar perintah, interlock level air, dan skenario gagal.
class DummyBackend
    implements AuthRepository, NotificationRepository, DeviceRepository, CommandRepository, LogRepository, AlertRepository, PlantRepository {
  DummyBackend() {
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
  }

  Timer? _timer;
  void dispose() => _timer?.cancel();

  // ---- kendali simulasi (dipakai layar Pengaturan khusus dummy) ----
  final scenario = Live<Scenario>(Scenario.normal);
  final emptyLog = Live<bool>(false);
  final noResponse = Live<bool>(false);

  void setScenario(Scenario s) {
    scenario.value = s;
    _offlineAt = _now() - 5 * _min;
    _refresh();
  }

  void setEmptyLog(bool v) {
    emptyLog.value = v;
    _logs.value = List.of(_logs.value); // paksa emit ulang
  }

  // ---- data ----
  final _user = Live<AppUser?>(null);
  final _sensor = Live<SensorReading?>(null);
  final _status = Live<DeviceStatus?>(null);
  int _offlineAt = _now() - 5 * _min;

  late final _settings = Live<DeviceSettings>(const DeviceSettings(mode: OperatingMode.otomatis));
  final _pumps = Live<List<PumpState>>([
    PumpState(id: 'galon', lastOn: _now() - 9 * _hr, pemicu: Pemicu.otomatis),
    PumpState(id: 'dosing', lastOn: _now() - 3 * _hr, pemicu: Pemicu.otomatis),
    PumpState(id: 'nutrisi', lastOn: _now() - 6 * _hr, pemicu: Pemicu.jadwal),
    PumpState(id: 'airpump', on: true, lastOn: _now() - 40 * _min, pemicu: Pemicu.otomatis),
  ]);
  final _cmds = <String, Live<Command>>{};
  final _stoppedAt = <String, int>{};
  final _runTimers = <String, Timer>{};
  final _activeCmd = <String, Live<Command>>{};

  late final _logs = Live<List<WateringLogEntry>>(_seedLog());
  late final _alerts = Live<List<AlertItem>>(_seedAlerts());
  final _seen = Live<int>(_now() - 4 * _hr);

  void _refresh() {
    final s = scenario.value;
    final off = s == Scenario.offline;
    final t = off ? _offlineAt : _now();
    final bahaya = s == Scenario.bahaya;
    final waspada = s == Scenario.waspada;
    _sensor.value = SensorReading(
      ph: bahaya ? 7.4 : waspada ? 6.8 : 6.1,
      ec: bahaya ? 2.4 : 1.6,
      tds: bahaya ? 1200 : 800,
      levelAir: bahaya ? LevelAir.rendah : LevelAir.cukup,
      suhu: 27.5,
      kelembapan: 68,
      updatedAt: t,
    );
    final keseluruhan = bahaya ? Severity.bahaya : waspada ? Severity.waspada : Severity.normal;
    _status.value = DeviceStatus(
      ph: bahaya ? Severity.bahaya : waspada ? Severity.waspada : Severity.normal,
      ec: bahaya ? Severity.waspada : Severity.normal,
      levelAir: bahaya ? Severity.bahaya : Severity.normal,
      suhu: Severity.normal,
      kelembapan: Severity.normal,
      keseluruhan: keseluruhan,
      pesan: bahaya
          ? 'Air hampir habis dan pH terlalu tinggi. Segera ditangani.'
          : waspada
              ? 'pH sedikit tinggi. Periksa lagi dalam beberapa jam.'
              : 'Semua kondisi baik. Tidak perlu tindakan.',
      updatedAt: t,
    );
  }

  // ---- Auth ----
  @override
  Stream<AppUser?> authState() => _user.stream;

  @override
  Future<void> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!email.contains('@')) throw const AuthFailure('Alamat email belum benar. Contoh: nama@email.com');
    if (password.length < 6) throw const AuthFailure('Kata sandi salah. Coba lagi, atau hubungi tim AgroSync bila lupa.');
    _user.value = AppUser(uid: 'dummy-uid', email: email, deviceId: 'agrosync01');
  }

  @override
  Future<void> signOut() async => _user.value = null;

  @override
  Future<bool> requestPermission(String uid) async => true;
  @override
  Future<void> removeToken(String uid) async {}

  // ---- Device ----
  @override
  Stream<SensorReading?> watchSensor(String deviceId) => _sensor.stream;
  @override
  Stream<DeviceStatus?> watchStatus(String deviceId) => _status.stream;
  @override
  Stream<List<PumpState>> watchPumps(String deviceId) => _pumps.stream;
  @override
  Stream<DeviceSettings> watchSettings(String deviceId) => _settings.stream;

  // ---- Commands ----
  String _newId() => 'cmd-${_now() % 1000000}';

  @override
  Stream<Command?> watchCommand(String deviceId, String commandId) =>
      _cmds[commandId]?.stream ?? const Stream.empty();

  @override
  Future<String> sendMode(String deviceId, OperatingMode mode) async {
    final live = Live(Command(id: _newId(), tipe: 'mode', target: 'mode', nilai: mode.name, dibuatPada: _now()));
    _cmds[live.value.id] = live;
    unawaited(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      if (noResponse.value) {
        await Future<void>.delayed(const Duration(seconds: 3));
        live.value = live.value.copyWith(status: CommandStatus.kedaluwarsa);
        return;
      }
      _settings.value = DeviceSettings(mode: mode);
      live.value = live.value.copyWith(status: CommandStatus.selesai);
    }());
    return live.value.id;
  }

  @override
  Future<String> sendPump(String deviceId, String pumpId, {required bool on, int durasiDetik = 0}) async {
    final live = Live(Command(
      id: _newId(), tipe: 'pompa', target: pumpId, nilai: on ? 'nyala' : 'mati',
      durasiDetik: durasiDetik, dibuatPada: _now(),
    ));
    _cmds[live.value.id] = live;
    unawaited(_process(live));
    return live.value.id;
  }

  void _reject(Live<Command> c, String alasan) =>
      c.value = c.value.copyWith(status: CommandStatus.ditolak, alasan: alasan);

  Future<void> _process(Live<Command> c) async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final cmd = c.value;
    if (noResponse.value) {
      await Future<void>.delayed(const Duration(seconds: 3));
      c.value = cmd.copyWith(status: CommandStatus.kedaluwarsa);
      return;
    }
    final pump = cmd.target;
    if (cmd.nilai == 'mati') {
      _finishPump(pump, c);
      return;
    }
    if ((pump == 'nutrisi' || pump == 'dosing') && scenario.value == Scenario.bahaya) {
      return _reject(c, 'Level air rendah. Pompa ini ditahan agar tidak berjalan kering. Isi galon dulu.');
    }
    final stopped = _stoppedAt[pump];
    if (stopped != null && _now() - stopped < 30 * 1000) {
      return _reject(c, 'Jeda minimal 30 detik antar perintah untuk pompa yang sama. Coba lagi sebentar lagi.');
    }
    c.value = cmd.copyWith(status: CommandStatus.diterima);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final t = _now();
    final dur = cmd.durasiDetik ?? 30;
    _setPump(pump, (p) => PumpState(id: p.id, on: true, lastOn: t, pemicu: Pemicu.manual, endsAt: t + dur * 1000));
    _activeCmd[pump] = c;
    _runTimers[pump]?.cancel();
    _runTimers[pump] = Timer(Duration(seconds: dur), () => _finishPump(pump, null));
  }

  void _setPump(String id, PumpState Function(PumpState) f) =>
      _pumps.value = [for (final p in _pumps.value) p.id == id ? f(p) : p];

  void _finishPump(String pumpId, Live<Command>? stopCmd) {
    _runTimers.remove(pumpId)?.cancel();
    final p = _pumps.value.firstWhere((x) => x.id == pumpId);
    final t = _now();
    final started = _activeCmd.remove(pumpId);
    if (p.on) {
      final ran = math.max(1, ((t - (p.lastOn ?? t)) / 1000).round());
      _setPump(pumpId, (x) => PumpState(id: x.id, on: false, lastOn: x.lastOn, pemicu: x.pemicu));
      _stoppedAt[pumpId] = t;
      final s = _sensor.value;
      _logs.value = [
        WateringLogEntry(
          id: 'n$t', waktu: p.lastOn ?? t, pompa: pumpId, durasiDetik: ran,
          dosisMl: pumpId == 'nutrisi' ? (ran / 3).roundToDouble() : null, pemicu: Pemicu.manual,
          perintahId: started?.value.id ?? stopCmd?.value.id, phSaat: s?.ph, ecSaat: s?.ec,
        ),
        ..._logs.value,
      ];
    }
    if (started != null) started.value = started.value.copyWith(status: CommandStatus.selesai);
    if (stopCmd != null) stopCmd.value = stopCmd.value.copyWith(status: CommandStatus.selesai);
  }

  // ---- Log ----
  List<WateringLogEntry> _visible() => emptyLog.value ? const [] : _logs.value;

  @override
  Stream<List<WateringLogEntry>> watchLatest(String deviceId, {int limit = 20}) =>
      _logs.stream.map((_) => _visible().take(limit).toList());

  @override
  Future<List<WateringLogEntry>> fetchBefore(String deviceId, int beforeWaktu, {int limit = 20}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return _visible().where((e) => e.waktu < beforeWaktu).take(limit).toList();
  }

  // ---- Alert ----
  @override
  Stream<List<AlertItem>> watchAlerts(String deviceId, {int limit = 50}) => _alerts.stream;
  @override
  Stream<int> watchSeenAt(String uid) => _seen.stream;
  @override
  Future<void> markSeen(String uid, int atMs) async => _seen.value = atMs;

  // ---- Tanaman ----
  @override
  Stream<PlantSnapshot?> watchPlant(String deviceId, int tingkat) => Stream.value(
        tingkat == 1
            ? PlantSnapshot(
                tingkat: 1, ukuran: 142, jumlahDaun: 9, gejalaKode: 'tidak_ada', gejalaKeyakinan: 0.91,
                fotoPath: 'dummy://tingkat1', fotoDiambil: _now() - 25 * _min, updatedAt: _now() - 25 * _min)
            // Tingkat 2: foto gagal dimuat dan analisis kosong (menguji state kosong/galat).
            : PlantSnapshot(tingkat: 2, fotoPath: 'dummy://error', fotoDiambil: _now() - 25 * _min),
      );

  @override
  Stream<Prediction?> watchPrediction(String deviceId) => Stream.value(Prediction(
        rekomendasiSiram: 'Siram 5 menit sore ini',
        alasan: 'Daun mulai menyerap lebih banyak air karena suhu siang naik.',
        perkiraanPanen: _now() + 12 * 24 * _hr,
        dihitungPada: _now() - 2 * _hr,
        versiModel: 'dummy-0.1',
      ));

  // ---- seed ----
  static List<WateringLogEntry> _seedLog() {
    const pumps = ['airpump', 'nutrisi', 'galon', 'dosing'];
    const durs = [300, 60, 120, 30];
    final base = _now();
    return List.generate(52, (i) {
      final p = pumps[i % 4];
      final pemicu = i % 7 == 3 ? Pemicu.manual : (i % 5 == 4 ? Pemicu.jadwal : Pemicu.otomatis);
      return WateringLogEntry(
        id: 'l$i', waktu: base - ((i * 3.1 + 0.8) * _hr).round(), pompa: p, durasiDetik: durs[i % 4],
        dosisMl: p == 'nutrisi' ? 20 : (p == 'dosing' ? 5 : null), pemicu: pemicu,
        perintahId: pemicu == Pemicu.manual ? 'cmd-${1000 + i}' : null,
        phSaat: 6 + ((i * 7) % 5) / 10, ecSaat: 1.4 + ((i * 3) % 6) / 10,
      );
    });
  }

  static List<AlertItem> _seedAlerts() {
    final t = _now();
    return [
      AlertItem(id: 'a1', waktu: t - 25 * _min, jenis: 'level', tingkat: Severity.bahaya, pesan: 'Level air rendah', sensor: 'levelAir', nilai: 'rendah'),
      AlertItem(id: 'a2', waktu: t - 3 * _hr, jenis: 'ph', tingkat: Severity.waspada, pesan: 'pH di atas batas aman', sensor: 'ph', nilai: '6,8'),
      AlertItem(id: 'a3', waktu: t - 20 * _hr, jenis: 'ec', tingkat: Severity.waspada, pesan: 'Kepekatan nutrisi (EC) rendah', sensor: 'ec', nilai: '1,1 mS/cm'),
      AlertItem(id: 'a4', waktu: t - 30 * _hr, jenis: 'offline', tingkat: Severity.bahaya, pesan: 'Perangkat tidak mengirim data', sensor: null, nilai: null),
    ];
  }
}
