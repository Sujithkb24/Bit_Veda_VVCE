import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationSchedule {
  final String id;
  final String deviceId;
  final String containerId;
  final int dosePerTime;
  final List<String> scheduleTimes;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicationSchedule({
    required this.id,
    required this.deviceId,
    required this.containerId,
    required this.dosePerTime,
    required this.scheduleTimes,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'containerId': containerId,
      'dosePerTime': dosePerTime,
      'scheduleTimes': scheduleTimes,
      'endDate':
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
      'current_time':
          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}',
    };
  }

  static DateTime _readDate(dynamic value, DateTime fallback) {
    if (value == null) return fallback;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? fallback;
    return fallback;
  }

  factory MedicationSchedule.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final now = DateTime.now();
    return MedicationSchedule(
      id: id,
      deviceId: data['deviceId'] ?? '',
      containerId: data['containerId'] ?? '',
      dosePerTime: data['dosePerTime'] ?? 1,
      scheduleTimes: List<String>.from(data['scheduleTimes'] ?? const []),
      endDate: _readDate(
        data['endDate'],
        now.add(const Duration(days: 30)),
      ),
      createdAt: _readDate(data['createdAt'], now),
      updatedAt: _readDate(data['updatedAt'], now),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'containerId': containerId,
      'dosePerTime': dosePerTime,
      'scheduleTimes': scheduleTimes,
      'endDate': endDate,
      'updatedAt': Timestamp.now(),
    };
  }

  MedicationSchedule copyWith({
    String? id,
    String? deviceId,
    String? containerId,
    int? dosePerTime,
    List<String>? scheduleTimes,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicationSchedule(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      containerId: containerId ?? this.containerId,
      dosePerTime: dosePerTime ?? this.dosePerTime,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
