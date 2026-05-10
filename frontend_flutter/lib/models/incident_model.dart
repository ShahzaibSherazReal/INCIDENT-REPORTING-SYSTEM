class IncidentModel {
  final String id;
  final DateTime createdAt;
  final String cameraId;
  final String incidentType;
  final double confidenceScore;
  final String snapshotUrl;
  final bool isFalsePositive;
  final bool operatorValidated;

  const IncidentModel({
    required this.id,
    required this.createdAt,
    required this.cameraId,
    required this.incidentType,
    required this.confidenceScore,
    required this.snapshotUrl,
    required this.isFalsePositive,
    this.operatorValidated = false,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.utc(1970),
      cameraId: json['camera_id']?.toString() ?? '',
      incidentType: json['incident_type']?.toString() ?? 'Unknown',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      snapshotUrl: json['snapshot_url']?.toString() ?? '',
      isFalsePositive: json['is_false_positive'] == true || json['is_false_positive'] == 'true',
      operatorValidated: json['operator_validated'] == true || json['operator_validated'] == 'true',
    );
  }
}
