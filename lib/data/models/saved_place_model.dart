class SavedPlace {
  final String id; // e.g. 'home', 'office', 'campus'
  final String name; // e.g. 'Rumah', 'Kantor'
  final String iconName; // e.g. 'home', 'building', 'school'
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime updatedAt;

  const SavedPlace({
    required this.id,
    required this.name,
    required this.iconName,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.updatedAt,
  });

  factory SavedPlace.fromJson(Map<String, dynamic> json) {
    return SavedPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      iconName: json['icon_name'] as String? ?? 'bookmark',
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      address: json['address'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon_name': iconName,
      'lat': latitude,
      'lng': longitude,
      'address': address,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SavedPlace copyWith({
    String? id,
    String? name,
    String? iconName,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? updatedAt,
  }) {
    return SavedPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
