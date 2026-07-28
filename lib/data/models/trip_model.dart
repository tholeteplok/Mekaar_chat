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
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
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
  });

  factory UserTrip.fromJson(Map<String, dynamic> json) {
    final destination = TripZone(
      label: json['destination_label'] as String? ?? 'Tujuan',
      latitude: (json['destination_lat'] as num).toDouble(),
      longitude: (json['destination_lng'] as num).toDouble(),
      radiusMeters: json['radius_meters'] as int? ?? 150,
    );

    final guardiansList = (json['trip_guardians'] as List<dynamic>?)
            ?.map((g) => TripGuardianPermission.fromJson(g as Map<String, dynamic>))
            .toList() ??
        const [];

    return UserTrip(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      originLabel: json['origin_label'] as String?,
      destinationZone: destination,
      expectedTime: json['expected_time'] as String?,
      gracePeriodMinutes: json['grace_period_minutes'] as int? ?? 30,
      isActive: json['is_active'] as bool? ?? true,
      guardians: guardiansList,
      createdAt: DateTime.parse(json['created_at'] as String),
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
    };
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
