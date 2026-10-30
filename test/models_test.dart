import 'package:agrosync/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

// Uji kontrak data: field hilang atau bertipe salah tidak boleh membuat aplikasi crash.
void main() {
  test('SensorReading mem-parse contoh data dokumen 4.7', () {
    final s = SensorReading.fromMap({'ph': 6.1, 'ec': 1.6, 'tds': 800, 'levelAir': 'cukup', 'suhu': 27.5, 'kelembapan': 68, 'updatedAt': 1793059200000})!;
    expect(s.ph, 6.1);
    expect(s.tds, 800.0);
    expect(s.levelAir, LevelAir.cukup);
    expect(s.updatedAt, 1793059200000);
  });

  test('field bertipe salah atau hilang menjadi null, bukan crash', () {
    final s = SensorReading.fromMap({'ph': 'enam', 'levelAir': 'penuh'})!;
    expect(s.ph, isNull);
    expect(s.suhu, isNull);
    expect(s.levelAir, LevelAir.unknown);
  });

  test('enum tidak dikenal menjadi unknown', () {
    expect(parseSeverity('aneh'), Severity.unknown);
    expect(parseCommandStatus(null), CommandStatus.unknown);
    expect(parseSeverity('sensor_error'), Severity.sensorError);
  });

  test('PumpState dibangun dari kunci node', () {
    final p = PumpState.fromMap('nutrisi', {'status': 'mati', 'pemicu': 'jadwal'});
    expect(p.id, 'nutrisi');
    expect(p.on, isFalse);
    expect(p.pemicu, Pemicu.jadwal);
  });

  test('log tanpa waktu dibuang, bukan crash', () {
    expect(WateringLogEntry.fromMap('x', {'pompa': 'galon'}), isNull);
    expect(WateringLogEntry.fromMap('y', {'waktu': 100, 'pompa': 'galon'})!.aksi, 'nyala');
  });

  test('Command.isActive hanya untuk menunggu dan diterima', () {
    expect(Command.fromMap('c', {'status': 'menunggu'})!.isActive, isTrue);
    expect(Command.fromMap('c', {'status': 'selesai'})!.isActive, isFalse);
  });
}
