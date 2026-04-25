// lib/models/user_model.dart

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final int age;
  final String bloodGroup;
  final String dispenserDeviceId;
  final String? fcmToken;      // Firebase Cloud Messaging token for push notifications
  final List<Medication> medications;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.age,
    required this.bloodGroup,
    required this.dispenserDeviceId,
    this.fcmToken,
    this.medications = const [],
  });

  // Convert Firestore document → UserModel
  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      age: data['age'] ?? 0,
      bloodGroup: data['bloodGroup'] ?? '',
      dispenserDeviceId: data['dispenserDeviceId'] ?? '',
      fcmToken: data['fcmToken'],
      medications: (data['medications'] as List<dynamic>? ?? [])
          .map((m) => Medication.fromMap(m as Map<String, dynamic>))
          .toList(),
    );
  }

  // Convert UserModel → Map (for writing to Firestore)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'age': age,
      'bloodGroup': bloodGroup,
      'dispenserDeviceId': dispenserDeviceId,
      'fcmToken': fcmToken,
      'medications': medications.map((m) => m.toMap()).toList(),
    };
  }
}

// Represents one medication the patient takes
class Medication {
  final String name;
  final String dosage;
  final List<String> times; // e.g., ["08:00", "14:00", "20:00"]

  Medication({
    required this.name,
    required this.dosage,
    required this.times,
  });

  factory Medication.fromMap(Map<String, dynamic> data) {
    return Medication(
      name: data['name'] ?? '',
      dosage: data['dosage'] ?? '',
      times: List<String>.from(data['times'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'dosage': dosage, 'times': times};
  }
}

// Represents the live status of the dispenser device
class DispenserStatus {
  final bool isOnline;
  final int batteryLevel;
  final int wifiStrength;
  final DateTime? lastDispensed;
  final DateTime? nextDose;
  final Map<String, int> pillsRemaining;

  DispenserStatus({
    required this.isOnline,
    required this.batteryLevel,
    required this.wifiStrength,
    this.lastDispensed,
    this.nextDose,
    this.pillsRemaining = const {},
  });

  factory DispenserStatus.fromMap(Map<String, dynamic> data) {
    return DispenserStatus(
      isOnline: data['isOnline'] ?? false,
      batteryLevel: data['batteryLevel'] ?? 0,
      wifiStrength: data['wifiStrength'] ?? -100,
      lastDispensed: data['lastDispensed'] != null
          ? (data['lastDispensed'] as dynamic).toDate()
          : null,
      nextDose: data['nextDose'] != null
          ? (data['nextDose'] as dynamic).toDate()
          : null,
      pillsRemaining: Map<String, int>.from(data['pillsRemaining'] ?? {}),
    );
  }
}