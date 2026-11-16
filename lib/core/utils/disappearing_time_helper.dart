/// Helper sentral konversi & pemformatan waktu pesan menghilang (Disappearing Messages).
/// Menangani konversi matematis antara Menit, Jam, dan Hari secara presisi,
/// memastikan pengguna menikmati kemudahan UI sementara kode mengurus seluruh konversi di balik layar.
enum DisappearingUnit {
  minute,
  hour,
  day,
}

extension DisappearingUnitExtension on DisappearingUnit {
  String get label {
    switch (this) {
      case DisappearingUnit.minute:
        return 'Menit';
      case DisappearingUnit.hour:
        return 'Jam';
      case DisappearingUnit.day:
        return 'Hari';
    }
  }
}

class DisappearingDuration {
  final int value;
  final DisappearingUnit unit;

  const DisappearingDuration(this.value, this.unit);

  /// Konversi nilai dan satuan ke total menit integer murni
  int toMinutes() {
    if (value <= 0) return 0;
    switch (unit) {
      case DisappearingUnit.minute:
        return value;
      case DisappearingUnit.hour:
        return value * 60;
      case DisappearingUnit.day:
        return value * 1440;
    }
  }

  /// Memetakan kembali total menit ke representasi (value, unit) paling manusiawi
  factory DisappearingDuration.fromMinutes(int totalMinutes) {
    if (totalMinutes <= 0) {
      return const DisappearingDuration(0, DisappearingUnit.hour);
    }
    if (totalMinutes % 1440 == 0) {
      return DisappearingDuration(totalMinutes ~/ 1440, DisappearingUnit.day);
    }
    if (totalMinutes % 60 == 0) {
      return DisappearingDuration(totalMinutes ~/ 60, DisappearingUnit.hour);
    }
    return DisappearingDuration(totalMinutes, DisappearingUnit.minute);
  }
}

class DisappearingTimeHelper {
  DisappearingTimeHelper._();

  /// Rekomendasi chip cepat adaptif untuk masing-masing satuan
  static List<int> quickPresetsFor(DisappearingUnit unit) {
    switch (unit) {
      case DisappearingUnit.minute:
        return const [5, 15, 30, 45];
      case DisappearingUnit.hour:
        return const [2, 6, 12, 48];
      case DisappearingUnit.day:
        return const [3, 7, 14, 30, 90];
    }
  }

  /// Batas nilai wajar per satuan
  static int maxFor(DisappearingUnit unit) {
    switch (unit) {
      case DisappearingUnit.minute:
        return 1440; // Maks 24 jam dalam menit
      case DisappearingUnit.hour:
        return 720; // Maks 30 hari dalam jam
      case DisappearingUnit.day:
        return 365; // Maks 1 tahun dalam hari
    }
  }

  /// Menjaga nilai berada dalam rentang valid (1 s.d. max)
  static int clampValue(int value, DisappearingUnit unit) {
    final max = maxFor(unit);
    if (value < 1) return 1;
    if (value > max) return max;
    return value;
  }

  /// Format teks durasi cerdas (*Smart Duration Formatter*)
  /// Menghasilkan teks ringkas dan elegan untuk label status di layar.
  static String format(int totalMinutes) {
    if (totalMinutes <= 0) return 'Mati';

    if (totalMinutes < 60) {
      return '$totalMinutes Menit';
    }

    if (totalMinutes % 1440 == 0) {
      final days = totalMinutes ~/ 1440;
      return '$days Hari';
    }

    if (totalMinutes % 60 == 0) {
      final hours = totalMinutes ~/ 60;
      return '$hours Jam';
    }

    // Jika ada kombinasi jam dan menit
    if (totalMinutes < 1440) {
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      return '$hours Jam $mins Menit';
    }

    // Jika ada kombinasi hari dan jam
    final days = totalMinutes ~/ 1440;
    final remainingHours = (totalMinutes % 1440) ~/ 60;
    if (remainingHours > 0) {
      return '$days Hari $remainingHours Jam';
    }
    return '$days Hari';
  }

  /// Deskripsi ramah untuk live feedback card saat pengguna mengatur waktu
  static String descriptionFor(int totalMinutes) {
    if (totalMinutes <= 0) {
      return 'Pesan disimpan selamanya tanpa batas waktu penghapusan.';
    }
    return 'Pesan baru akan otomatis terhapus untuk semua pihak setelah ${format(totalMinutes)} sejak pesan dikirim.';
  }
}
