class CameraModel {
  final String id;
  final String name;
  final String streamUrl;
  final bool isActive;

  const CameraModel({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.isActive,
  });

  factory CameraModel.fromJson(Map<String, dynamic> json) {
    return CameraModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Camera',
      streamUrl: json['stream_url']?.toString() ?? '',
      isActive: json['is_active'] == true || json['is_active'] == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'stream_url': streamUrl,
      'is_active': isActive,
    };
  }

  CameraModel copyWith({
    String? id,
    String? name,
    String? streamUrl,
    bool? isActive,
  }) {
    return CameraModel(
      id: id ?? this.id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      isActive: isActive ?? this.isActive,
    );
  }
}
