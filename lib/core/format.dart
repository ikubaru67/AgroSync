import 'dart:math' as math;

const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String _p2(int n) => n.toString().padLeft(2, '0');

/// Angka dengan koma desimal ala Indonesia. Null ditampilkan sebagai "-".
String fmtNum(double? v, [int digits = 1]) =>
    v == null ? '-' : v.toStringAsFixed(digits).replaceAll('.', ',');

/// Waktu disimpan sebagai epoch milidetik UTC, tampil sesuai zona waktu HP.
String hhmm(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_p2(t.hour)}.${_p2(t.minute)}';
}

String ago(int ms, DateTime now) {
  final s = math.max(0, (now.millisecondsSinceEpoch - ms) ~/ 1000);
  if (s < 60) return '$s detik lalu';
  if (s < 3600) return '${(s / 60).round()} menit lalu';
  if (s < 86400) return '${(s / 3600).round()} jam lalu';
  return '${(s / 86400).round()} hari lalu';
}

String dayLabel(int ms, DateTime now) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  final d = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  return '${_hari[t.weekday - 1]}, ${t.day} ${_bulan[t.month - 1]}';
}

String dateShort(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_hari[t.weekday - 1]}, ${t.day} ${_bulan[t.month - 1]}';
}

String durLabel(int seconds) {
  if (seconds < 60) return '$seconds detik';
  final m = seconds ~/ 60, s = seconds % 60;
  return s == 0 ? '$m menit' : '$m mnt $s dtk';
}

String countdown(int seconds) => '${seconds ~/ 60}:${_p2(seconds % 60)}';
