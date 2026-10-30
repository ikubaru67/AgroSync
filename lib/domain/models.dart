// Model domain. Format Firebase hanya dikenal lewat fabrik fromMap (defensif):
// field hilang atau bertipe salah menjadi null/nilai bawaan, tidak pernah crash.

Map<String, dynamic>? asMap(Object? v) =>
    v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : null;
double? asDouble(Object? v) => v is num ? v.toDouble() : null;
int? asInt(Object? v) => v is num ? v.toInt() : null;
String? asStr(Object? v) => v is String ? v : null;

enum Severity { normal, waspada, bahaya, sensorError, unknown }

Severity parseSeverity(Object? v) => switch (asStr(v)) {
      'normal' => Severity.normal,
      'waspada' => Severity.waspada,
      'bahaya' => Severity.bahaya,
      'sensor_error' => Severity.sensorError,
      _ => Severity.unknown,
    };

enum LevelAir { cukup, rendah, unknown }

LevelAir parseLevelAir(Object? v) => switch (asStr(v)) {
      'cukup' => LevelAir.cukup,
      'rendah' => LevelAir.rendah,
      _ => LevelAir.unknown,
    };

enum OperatingMode { otomatis, manual, unknown }

OperatingMode parseMode(Object? v) => switch (asStr(v)) {
      'otomatis' => OperatingMode.otomatis,
      'manual' => OperatingMode.manual,
      _ => OperatingMode.unknown,
    };

enum Pemicu { otomatis, manual, jadwal, unknown }

Pemicu parsePemicu(Object? v) => switch (asStr(v)) {
      'otomatis' => Pemicu.otomatis,
      'manual' => Pemicu.manual,
      'jadwal' => Pemicu.jadwal,
      _ => Pemicu.unknown,
    };

enum CommandStatus { menunggu, diterima, selesai, ditolak, kedaluwarsa, unknown }

CommandStatus parseCommandStatus(Object? v) => switch (asStr(v)) {
      'menunggu' => CommandStatus.menunggu,
      'diterima' => CommandStatus.diterima,
      'selesai' => CommandStatus.selesai,
      'ditolak' => CommandStatus.ditolak,
      'kedaluwarsa' => CommandStatus.kedaluwarsa,
      _ => CommandStatus.unknown,
    };

class AppUser {
  const AppUser({required this.uid, required this.email, required this.deviceId});
  final String uid;
  final String email;
  final String? deviceId;
}

class SensorReading {
  const SensorReading({this.ph, this.ec, this.tds, this.levelAir = LevelAir.unknown, this.suhu, this.kelembapan, this.updatedAt});
  final double? ph;
  final double? ec; // mS/cm
  final double? tds; // ppm
  final LevelAir levelAir;
  final double? suhu; // derajat C
  final double? kelembapan; // persen
  final int? updatedAt; // epoch ms UTC

  static SensorReading? fromMap(Map<String, dynamic>? m) => m == null
      ? null
      : SensorReading(
          ph: asDouble(m['ph']),
          ec: asDouble(m['ec']),
          tds: asDouble(m['tds']),
          levelAir: parseLevelAir(m['levelAir']),
          suhu: asDouble(m['suhu']),
          kelembapan: asDouble(m['kelembapan']),
          updatedAt: asInt(m['updatedAt']),
        );
}

/// Status dibaca dari server (/status). Aplikasi tidak menghitung ulang.
class DeviceStatus {
  const DeviceStatus({this.ph = Severity.unknown, this.ec = Severity.unknown, this.levelAir = Severity.unknown, this.suhu = Severity.unknown, this.kelembapan = Severity.unknown, this.keseluruhan = Severity.unknown, this.pesan, this.updatedAt});
  final Severity ph, ec, levelAir, suhu, kelembapan, keseluruhan;
  final String? pesan;
  final int? updatedAt;

  static DeviceStatus? fromMap(Map<String, dynamic>? m) => m == null
      ? null
      : DeviceStatus(
          ph: parseSeverity(m['ph']),
          ec: parseSeverity(m['ec']),
          levelAir: parseSeverity(m['levelAir']),
          suhu: parseSeverity(m['suhu']),
          kelembapan: parseSeverity(m['kelembapan']),
          keseluruhan: parseSeverity(m['keseluruhan']),
          pesan: asStr(m['pesan']),
          updatedAt: asInt(m['updatedAt']),
        );
}

class PumpState {
  const PumpState({required this.id, this.on = false, this.lastOn, this.pemicu = Pemicu.unknown, this.endsAt});
  final String id; // kunci node, mis. galon, dosing, nutrisi, airpump
  final bool on;
  final int? lastOn;
  final Pemicu pemicu;
  final int? endsAt; // usulan tambahan: kapan pompa berhenti sendiri

  static PumpState fromMap(String id, Map<String, dynamic>? m) => PumpState(
        id: id,
        on: asStr(m?['status']) == 'menyala',
        lastOn: asInt(m?['lastOn']),
        pemicu: parsePemicu(m?['pemicu']),
        endsAt: asInt(m?['endsAt']),
      );
}

class DeviceSettings {
  const DeviceSettings({this.mode = OperatingMode.unknown, this.phMin = 5.5, this.phMax = 6.5, this.ecMin = 1.2, this.ecMax = 2.0});
  final OperatingMode mode;
  final double phMin, phMax, ecMin, ecMax;

  static DeviceSettings fromMap(Map<String, dynamic>? m) => DeviceSettings(
        mode: parseMode(m?['mode']),
        phMin: asDouble(m?['phMin']) ?? 5.5,
        phMax: asDouble(m?['phMax']) ?? 6.5,
        ecMin: asDouble(m?['ecMin']) ?? 1.2,
        ecMax: asDouble(m?['ecMax']) ?? 2.0,
      );
}

class Command {
  const Command({required this.id, required this.tipe, required this.target, required this.nilai, this.durasiDetik, this.status = CommandStatus.menunggu, this.alasan, this.dibuatPada});
  final String id;
  final String tipe; // pompa | mode
  final String target; // id pompa, atau "mode"
  final String nilai; // nyala | mati | otomatis | manual
  final int? durasiDetik;
  final CommandStatus status;
  final String? alasan;
  final int? dibuatPada;

  bool get isActive => status == CommandStatus.menunggu || status == CommandStatus.diterima;

  Command copyWith({CommandStatus? status, String? alasan}) => Command(
        id: id, tipe: tipe, target: target, nilai: nilai, durasiDetik: durasiDetik,
        status: status ?? this.status, alasan: alasan ?? this.alasan, dibuatPada: dibuatPada,
      );

  static Command? fromMap(String id, Map<String, dynamic>? m) => m == null
      ? null
      : Command(
          id: id,
          tipe: asStr(m['tipe']) ?? 'pompa',
          target: asStr(m['target']) ?? '',
          nilai: asStr(m['nilai']) ?? '',
          durasiDetik: asInt(m['durasiDetik']),
          status: parseCommandStatus(m['status']),
          alasan: asStr(m['alasan']),
          dibuatPada: asInt(m['dibuatPada']),
        );
}

class WateringLogEntry {
  const WateringLogEntry({required this.id, required this.waktu, required this.pompa, this.aksi = 'nyala', this.durasiDetik, this.dosisMl, this.pemicu = Pemicu.unknown, this.perintahId, this.phSaat, this.ecSaat});
  final String id;
  final int waktu;
  final String pompa;
  final String aksi;
  final int? durasiDetik;
  final double? dosisMl;
  final Pemicu pemicu;
  final String? perintahId;
  final double? phSaat, ecSaat;

  static WateringLogEntry? fromMap(String id, Map<String, dynamic>? m) {
    final waktu = asInt(m?['waktu']);
    if (m == null || waktu == null) return null; // tanpa waktu tidak bisa diurutkan
    return WateringLogEntry(
      id: id, waktu: waktu, pompa: asStr(m['pompa']) ?? '-', aksi: asStr(m['aksi']) ?? 'nyala',
      durasiDetik: asInt(m['durasiDetik']), dosisMl: asDouble(m['dosisMl']),
      pemicu: parsePemicu(m['pemicu']), perintahId: asStr(m['perintahId']),
      phSaat: asDouble(m['phSaat']), ecSaat: asDouble(m['ecSaat']),
    );
  }
}

class AlertItem {
  const AlertItem({required this.id, required this.waktu, required this.jenis, required this.tingkat, this.pesan, this.sensor, this.nilai});
  final String id;
  final int waktu;
  final String jenis;
  final Severity tingkat; // waspada atau bahaya
  final String? pesan;
  final String? sensor; // ph | ec | levelAir | suhu | kelembapan
  final String? nilai;

  static AlertItem? fromMap(String id, Map<String, dynamic>? m) {
    final waktu = asInt(m?['waktu']);
    if (m == null || waktu == null) return null;
    final n = m['nilai'];
    return AlertItem(
      id: id, waktu: waktu, jenis: asStr(m['jenis']) ?? '-', tingkat: parseSeverity(m['tingkat']),
      pesan: asStr(m['pesan']), sensor: asStr(m['sensor']),
      nilai: n is num ? n.toString().replaceAll('.', ',') : asStr(n),
    );
  }
}

class PlantSnapshot {
  const PlantSnapshot({required this.tingkat, this.ukuran, this.jumlahDaun, this.gejalaKode, this.gejalaKeyakinan, this.fotoPath, this.fotoDiambil, this.updatedAt});
  final int tingkat;
  final double? ukuran; // luas kanopi (cm2); definisi final masih [TERBUKA]
  final int? jumlahDaun;
  final String? gejalaKode;
  final double? gejalaKeyakinan;
  final String? fotoPath;
  final int? fotoDiambil;
  final int? updatedAt;

  bool get hasAnalysis => ukuran != null || jumlahDaun != null || gejalaKode != null;

  static PlantSnapshot? fromMap(int tingkat, Map<String, dynamic>? m) {
    if (m == null) return null;
    final g = asMap(m['gejala']);
    return PlantSnapshot(
      tingkat: tingkat, ukuran: asDouble(m['ukuran']), jumlahDaun: asInt(m['jumlahDaun']),
      gejalaKode: asStr(g?['kode']), gejalaKeyakinan: asDouble(g?['keyakinan']),
      fotoPath: asStr(m['fotoPath']), fotoDiambil: asInt(m['fotoDiambil']), updatedAt: asInt(m['updatedAt']),
    );
  }
}

class Prediction {
  const Prediction({this.rekomendasiSiram, this.alasan, this.perkiraanPanen, this.dihitungPada, this.versiModel});
  final String? rekomendasiSiram;
  final String? alasan;
  final int? perkiraanPanen; // epoch ms
  final int? dihitungPada;
  final String? versiModel;

  static Prediction? fromMap(Map<String, dynamic>? m) => m == null
      ? null
      : Prediction(
          rekomendasiSiram: asStr(m['rekomendasiSiram']), alasan: asStr(m['alasan']),
          perkiraanPanen: asInt(m['perkiraanPanen']), dihitungPada: asInt(m['dihitungPada']),
          versiModel: asStr(m['versiModel']),
        );
}
