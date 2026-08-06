/// Status siklus hidup satu trip UNTUK HARI INI. Direset ke [scheduled]
/// setiap hari baru (dibandingkan lewat [UserTrip.activeDate]) -- lihat
/// TripMonitorService untuk logika transisinya. Disimpan di DB (bukan
/// Map di memori) supaya bertahan lintas restart app dan tidak memicu
/// notifikasi/pesan Guardian duplikat.
enum TripStatus {
  scheduled,        // belum ada trigger apa pun hari ini
  arrivedAuto,       // GPS mendeteksi masuk radius tujuan -> auto check-in terkirim
  arrivedConfirmed,  // pengguna menekan "Ya, Sudah Sampai" secara manual
  delayedWarned,     // sudah lewat jam+grace, notifikasi konfirmasi lokal sudah tampil, menunggu respons
  delayedAlerted,    // tidak direspons dalam batas waktu -> sudah eskalasi ke Guardian
  snoozed;           // pengguna menekan "Tunda", evaluasi ulang setelah snoozedUntil

  static TripStatus fromJson(String? value) {
    return TripStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TripStatus.scheduled,
    );
  }
}

class TripZone {
  final String label;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  const TripZone({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 150,
  });

  factory TripZone.fromJson(Map<String, dynamic> json) {
    return TripZone(
      label: json['label'] as String? ?? 'Tujuan',
      latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: json['radius'] as int? ?? 150,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'lat': latitude,
      'lng': longitude,
      'radius': radiusMeters,
    };
  }
}

class TripGuardianPermission {
  final String id;
  final String guardianId;
  final String? guardianName;
  final int delayMinutes;

  const TripGuardianPermission({
    required this.id,
    required this.guardianId,
    this.guardianName,
    this.delayMinutes = 0,
  });

  factory TripGuardianPermission.fromJson(Map<String, dynamic> json) {
    return TripGuardianPermission(
      id: json['id'] as String? ?? '',
      guardianId: json['guardian_id'] as String,
      guardianName: json['profiles']?['display_name'] as String? ??
          json['profiles']?['username'] as String?,
      delayMinutes: json['delay_minutes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'guardian_id': guardianId,
      'delay_minutes': delayMinutes,
    };
  }
}

class UserTrip {
  final String id;
  final String userId;
  final String title;
  final String? originLabel;
  final TripZone destinationZone;
  final String? expectedTime; // HH:mm format
  final int gracePeriodMinutes;
  final bool isActive;
  final List<TripGuardianPermission> guardians;
  final DateTime createdAt;

  /// Hari perulangan (1=Senin ... 7=Minggu, ISO weekday). Kosong berarti
  /// berlaku setiap hari.
  final List<int> recurrenceDays;

  /// Status siklus HARI INI. Lihat catatan [activeDate] -- status ini
  /// hanya valid selama [activeDate] == hari ini; kalau tidak, harus
  /// diperlakukan sebagai [TripStatus.scheduled] (hari baru, mulai lagi).
  final TripStatus status;
  final DateTime? activeDate;
  final DateTime? lastTriggeredAt;
  final DateTime? snoozedUntil;

  const UserTrip({
    required this.id,
    required this.userId,
    required this.title,
    this.originLabel,
    required this.destinationZone,
    this.expectedTime,
    this.gracePeriodMinutes = 30,
    this.isActive = true,
    this.guardians = const [],
    required this.createdAt,
    this.recurrenceDays = const [],
    this.status = TripStatus.scheduled,
    this.activeDate,
    this.lastTriggeredAt,
    this.snoozedUntil,
  });

  /// Compatibility getter for activeDays
  List<int> get activeDays => recurrenceDays.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : recurrenceDays;

  /// True kalau trip ini seharusnya dievaluasi HARI INI berdasarkan
  /// [recurrenceDays]. List kosong = berlaku setiap hari.
  bool get isScheduledForToday {
    if (recurrenceDays.isEmpty) return true;
    return recurrenceDays.contains(DateTime.now().weekday);
  }

  /// Status efektif -- otomatis "reset" ke scheduled kalau [activeDate]
  /// bukan hari ini.
  TripStatus get effectiveStatus {
    if (activeDate == null) return TripStatus.scheduled;
    final now = DateTime.now();
    final isSameDay = activeDate!.year == now.year &&
        activeDate!.month == now.month &&
        activeDate!.day == now.day;
    return isSameDay ? status : TripStatus.scheduled;
  }

  factory UserTrip.fromJson(Map<String, dynamic> json) {
    final destination = TripZone(
      label: json['destination_label'] as String? ?? 'Tujuan',
      latitude: (json['destination_lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['destination_lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: json['radius_meters'] as int? ?? 150,
    );

    final guardiansList = (json['trip_guardians'] as List<dynamic>?)
            ?.map((g) => TripGuardianPermission.fromJson(g as Map<String, dynamic>))
            .toList() ??
        const [];

    final rawRecurrence = json['recurrence_days'] as List<dynamic>? ?? json['active_days'] as List<dynamic>?;
    final parsedRecurrence = rawRecurrence != null
        ? rawRecurrence.map((e) => (e as num).toInt()).toList()
        : const <int>[];

    return UserTrip(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Rute',
      originLabel: json['origin_label'] as String?,
      destinationZone: destination,
      expectedTime: json['expected_time'] as String?,
      gracePeriodMinutes: json['grace_period_minutes'] as int? ?? 30,
      isActive: json['is_active'] as bool? ?? true,
      guardians: guardiansList,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      recurrenceDays: parsedRecurrence,
      status: TripStatus.fromJson(json['status'] as String?),
      activeDate: json['active_date'] != null
          ? DateTime.tryParse(json['active_date'] as String)
          : null,
      lastTriggeredAt: json['last_triggered_at'] != null
          ? DateTime.tryParse(json['last_triggered_at'] as String)
          : null,
      snoozedUntil: json['snoozed_until'] != null
          ? DateTime.tryParse(json['snoozed_until'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'origin_label': originLabel,
      'destination_label': destinationZone.label,
      'destination_lat': destinationZone.latitude,
      'destination_lng': destinationZone.longitude,
      'radius_meters': destinationZone.radiusMeters,
      'expected_time': expectedTime,
      'grace_period_minutes': gracePeriodMinutes,
      'is_active': isActive,
      'recurrence_days': recurrenceDays,
    };
  }

  String get activeDaysLabel {
    final days = activeDays;
    if (days.length == 7) return 'Setiap Hari';
    if (days.length == 5 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5)) {
      return 'Senin - Jumat';
    }
    if (days.length == 2 &&
        days.contains(6) &&
        days.contains(7)) {
      return 'Sabtu - Minggu';
    }
    const dayNames = {
      1: 'Sen',
      2: 'Sel',
      3: 'Rab',
      4: 'Kam',
      5: 'Jum',
      6: 'Sab',
      7: 'Min',
    };
    final sorted = List<int>.from(days)..sort();
    return sorted.map((d) => dayNames[d] ?? '').join(', ');
  }
}

class CheckInPayload {
  final String tripId;
  final String destinationLabel;
  final String arrivalTimestamp;
  final int batteryPercentage;
  final bool isAutomated;
  final bool isDelayedAlert;

  const CheckInPayload({
    required this.tripId,
    required this.destinationLabel,
    required this.arrivalTimestamp,
    this.batteryPercentage = 100,
    this.isAutomated = true,
    this.isDelayedAlert = false,
  });

  factory CheckInPayload.fromJson(Map<String, dynamic> json) {
    return CheckInPayload(
      tripId: json['trip_id'] as String? ?? '',
      destinationLabel: json['destination_label'] as String? ?? 'Tujuan',
      arrivalTimestamp: json['arrival_timestamp'] as String? ?? '',
      batteryPercentage: json['battery_percentage'] as int? ?? 100,
      isAutomated: json['is_automated'] as bool? ?? true,
      isDelayedAlert: json['is_delayed_alert'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'auto_checkin',
      'trip_id': tripId,
      'destination_label': destinationLabel,
      'arrival_timestamp': arrivalTimestamp,
      'battery_percentage': batteryPercentage,
      'is_automated': isAutomated,
      'is_delayed_alert': isDelayedAlert,
    };
  }
}
