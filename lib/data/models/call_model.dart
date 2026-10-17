class CallModel {
  final String id;
  final String roomId;
  final String callerId;
  final String receiverId;
  final String callType; // 'voice' | 'video'
  final String status; // 'ringing', 'answered', 'declined', 'busy', 'missed', 'ended', 'failed'
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CallModel({
    required this.id,
    required this.roomId,
    required this.callerId,
    required this.receiverId,
    required this.callType,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isVideo => callType == 'video';

  /// True jika panggilan berhasil terhubung (memiliki durasi percakapan atau status answered/ended dengan durasi)
  bool get isConnected =>
      durationSeconds > 0 ||
      status == 'answered' ||
      (status == 'ended' && durationSeconds > 0);

  /// Format durasi percakapan yang ramah pengguna (mis. "02:45" atau "1:05:20")
  String get formattedDuration {
    if (durationSeconds <= 0) return '00:00';
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutesStr:$secondsStr';
    }
    return '$minutesStr:$secondsStr';
  }

  /// Label deskripsi status panggilan berdasarkan perspektif pengguna saat ini (pemanggil vs penerima)
  String getDisplayStatus(bool isCaller) {
    if (isConnected) {
      if (durationSeconds > 0) {
        return 'Terhubung • $formattedDuration';
      }
      return 'Terhubung';
    }

    switch (status) {
      case 'declined':
        return isCaller ? 'Panggilan ditolak' : 'Ditolak';
      case 'busy':
        return 'Sedang sibuk';
      case 'missed':
        return isCaller ? 'Panggilan dibatalkan' : 'Panggilan tak terjawab';
      case 'failed':
        return 'Panggilan gagal';
      case 'ringing':
        return isCaller ? 'Memanggil...' : 'Panggilan masuk...';
      default:
        return status;
    }
  }

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: json['id'] as String,
      roomId: json['room_id'] as String? ?? '',
      callerId: json['caller_id'] as String? ?? '',
      receiverId: json['receiver_id'] as String? ?? '',
      callType: json['call_type'] as String? ?? 'voice',
      status: json['status'] as String? ?? 'ended',
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'] as String)
          : null,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'caller_id': callerId,
      'receiver_id': receiverId,
      'call_type': callType,
      'status': status,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
