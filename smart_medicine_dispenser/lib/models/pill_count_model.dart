// lib/models/pill_count_model.dart
//
// Represents the pill count state of ONE container on ONE device.
//
// Firestore path:
//   pill_counts/{deviceId}_{containerId}
//   e.g.  pill_counts/ESP-001_1   and   pill_counts/ESP-001_2

import 'package:cloud_firestore/cloud_firestore.dart';

class PillCount {
  final String id;           // Firestore doc ID = "{deviceId}_{containerId}"
  final String deviceId;
  final String containerId;
  final int currentCount;    // Pills remaining RIGHT NOW
  final int totalCount;      // Pills when the container was last refilled
  final int threshold;       // Alert fires when currentCount drops to this value
  final DateTime lastUpdated;
  final DateTime? lastDeducted; // When the last dose was automatically deducted

  PillCount({
    required this.id,
    required this.deviceId,
    required this.containerId,
    required this.currentCount,
    required this.totalCount,
    required this.threshold,
    required this.lastUpdated,
    this.lastDeducted,
  });

  // Percentage full — used for the progress bar
  double get percentFull =>
      totalCount > 0 ? (currentCount / totalCount).clamp(0.0, 1.0) : 0.0;

  // True when an alert should be shown
  bool get isBelowThreshold => currentCount <= threshold;

  // Urgency level for colour coding
  String get urgency {
    if (currentCount <= 0) return 'EMPTY';
    if (currentCount <= threshold) return 'CRITICAL';
    if (currentCount <= threshold * 2) return 'LOW';
    return 'OK';
  }

  factory PillCount.fromFirestore(String id, Map<String, dynamic> data) {
    return PillCount(
      id: id,
      deviceId: data['deviceId'] ?? '',
      containerId: data['containerId'] ?? '',
      currentCount: (data['currentCount'] as num?)?.toInt() ?? 0,
      totalCount: (data['totalCount'] as num?)?.toInt() ?? 0,
      threshold: (data['threshold'] as num?)?.toInt() ?? 5,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastDeducted: (data['lastDeducted'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'containerId': containerId,
      'currentCount': currentCount,
      'totalCount': totalCount,
      'threshold': threshold,
      'lastUpdated': Timestamp.now(),
      if (lastDeducted != null) 'lastDeducted': Timestamp.fromDate(lastDeducted!),
    };
  }

  PillCount copyWith({
    int? currentCount,
    int? totalCount,
    int? threshold,
    DateTime? lastDeducted,
  }) {
    return PillCount(
      id: id,
      deviceId: deviceId,
      containerId: containerId,
      currentCount: currentCount ?? this.currentCount,
      totalCount: totalCount ?? this.totalCount,
      threshold: threshold ?? this.threshold,
      lastUpdated: DateTime.now(),
      lastDeducted: lastDeducted ?? this.lastDeducted,
    );
  }

  // Stable document ID format used everywhere
  static String docId(String deviceId, String containerId) =>
      '${deviceId.trim()}_${containerId.trim()}';
}