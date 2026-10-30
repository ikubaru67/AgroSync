import 'package:flutter/material.dart';

import '../domain/models.dart';

/// Nama dan penjelasan pompa. Daftar pompa sendiri dibangun dari data /pompa,
/// jadi id yang belum dikenal tetap tampil dengan nama bawaan.
class PumpInfo {
  const PumpInfo(this.name, this.desc, this.icon);
  final String name, desc;
  final IconData icon;
}

PumpInfo pumpInfo(String id) => switch (id) {
      'galon' => const PumpInfo('Pompa Galon', 'Mengisi air bersih dari galon', Icons.water_drop_rounded),
      'dosing' => const PumpInfo('Pompa Dosing', 'Mengatur pH (tingkat keasaman) air', Icons.tune_rounded),
      'nutrisi' => const PumpInfo('Pompa Nutrisi', 'Menambah pupuk cair untuk tanaman', Icons.science_rounded),
      'airpump' => const PumpInfo('Pompa Udara', 'Memberi oksigen ke dalam air', Icons.air_rounded),
      _ => PumpInfo('Pompa ${id.isEmpty ? '-' : id[0].toUpperCase() + id.substring(1)}', 'Pompa tambahan', Icons.settings_rounded),
    };

String pemicuLabel(Pemicu p) => switch (p) {
      Pemicu.otomatis => 'Otomatis',
      Pemicu.manual => 'Manual',
      Pemicu.jadwal => 'Jadwal',
      Pemicu.unknown => '-',
    };

IconData pemicuIcon(Pemicu p) => switch (p) {
      Pemicu.otomatis => Icons.autorenew_rounded,
      Pemicu.manual => Icons.touch_app_rounded,
      Pemicu.jadwal => Icons.schedule_rounded,
      Pemicu.unknown => Icons.help_outline_rounded,
    };
