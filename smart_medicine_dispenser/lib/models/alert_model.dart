// lib/models/alert_model.dart
// This class represents one alert sent by your IoT device

import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String id;
  final String userId;
  final String deviceId;
  final String type;      // MISSED_DOSE, LOW_PILLS, BATTERY_LOW, etc.
  final String message;
  final String severity;  // HIGH, MEDIUM, LOW
  final DateTime timestamp;
  final bool isRead;

  AlertModel({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.type,
    required this.message,
    required this.severity,
    required this.timestamp,
    required this.isRead,
  });

  // Convert Firestore document → AlertModel object
  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlertModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      deviceId: data['deviceId'] ?? '',
      type: data['type'] ?? 'UNKNOWN',
      message: data['message'] ?? '',
      severity: data['severity'] ?? 'LOW',
      // Firestore stores timestamps as Timestamp objects — convert to DateTime
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  // Convert AlertModel → Map (for writing to Firestore)
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'deviceId': deviceId,
      'type': type,
      'message': message,
      'severity': severity,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }
}