import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/alert_model.dart';
import '../models/schedule_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AlertModel>> getAlertsStream(String userId) {
    return _db
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => AlertModel.fromFirestore(doc)).toList();
    });
  }

  Stream<int> getUnreadAlertCount(String userId) {
    return _db
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<DispenserStatus?> getDeviceStatusStream(String deviceId) {
    return _db
        .collection('dispenser_status')
        .doc(deviceId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return DispenserStatus.fromMap(doc.data()!);
    });
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(uid, doc.data()!);
  }

  Stream<UserModel?> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(uid, doc.data()!);
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  Future<void> saveFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({'fcmToken': token});
  }

  Future<void> markAlertAsRead(String alertId) async {
    await _db.collection('alerts').doc(alertId).update({'isRead': true});
  }

  Future<void> markAllAlertsAsRead(String userId) async {
    final unread = await _db
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteAlert(String alertId) async {
    await _db.collection('alerts').doc(alertId).delete();
  }

  Future<void> addTestAlert(String userId) async {
    final types = [
      {
        'type': 'MISSED_DOSE',
        'msg': 'Missed morning dose of Metformin 500mg',
        'sev': 'HIGH',
      },
      {
        'type': 'LOW_PILLS',
        'msg': 'Amlodipine compartment has only 3 pills left',
        'sev': 'MEDIUM',
      },
      {
        'type': 'BATTERY_LOW',
        'msg': 'Dispenser battery at 15%. Please charge.',
        'sev': 'MEDIUM',
      },
      {
        'type': 'DOSE_TAKEN',
        'msg': 'Evening dose taken successfully',
        'sev': 'LOW',
      },
      {
        'type': 'JAM_DETECTED',
        'msg': 'Mechanical jam detected in compartment 2',
        'sev': 'HIGH',
      },
    ];

    final random = DateTime.now().millisecondsSinceEpoch % types.length;
    final selected = types[random];

    await _db.collection('alerts').add({
      'userId': userId,
      'deviceId': 'ESP32_TEST',
      'type': selected['type'],
      'message': selected['msg'],
      'severity': selected['sev'],
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  String scheduleDocumentId(String deviceId, String containerId) {
    return '${deviceId.trim()}_container_${containerId.trim()}';
  }

  Future<MedicationSchedule> saveMedicationSchedule({
    required String userId,
    required String deviceId,
    required String containerId,
    required int dosePerTime,
    required List<String> scheduleTimes,
    required DateTime endDate,
  }) async {
    _validateScheduleRequest(deviceId, containerId);

    final docId = scheduleDocumentId(deviceId, containerId);
    final docRef = _db.collection('schedules').doc(docId);
    final existingDoc = await docRef.get();
    final normalizedTimes = _normalizeTimes(scheduleTimes);
    final now = Timestamp.now();

    await docRef.set({
      'userId': userId,
      'deviceId': deviceId.trim(),
      'containerId': containerId.trim(),
      'dosePerTime': dosePerTime,
      'scheduleTimes': normalizedTimes,
      'endDate': Timestamp.fromDate(endDate),
      'createdAt': existingDoc.exists
          ? (existingDoc.data()?['createdAt'] ?? now)
          : now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    await _pushSchedulesToDevice(deviceId.trim(), changedContainerId: containerId);

    final savedDoc = await docRef.get();
    return MedicationSchedule.fromFirestore(docId, savedDoc.data()!);
  }

  Stream<List<MedicationSchedule>> getSchedulesStream(String userId) {
    return _db
        .collection('schedules')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => _dedupeSchedules(snapshot.docs
            .map((doc) => MedicationSchedule.fromFirestore(doc.id, doc.data()))
            .toList()));
  }

  Stream<List<MedicationSchedule>> getSchedulesForDeviceStream(String deviceId) {
    return _db
        .collection('schedules')
        .where('deviceId', isEqualTo: deviceId)
        .snapshots()
        .map((snapshot) => _dedupeSchedules(snapshot.docs
            .map((doc) => MedicationSchedule.fromFirestore(doc.id, doc.data()))
            .toList()));
  }

  Future<MedicationSchedule> updateMedicationSchedule({
    required String scheduleId,
    required String deviceId,
    required String containerId,
    required int dosePerTime,
    required List<String> scheduleTimes,
    required DateTime endDate,
  }) async {
    final existingDoc = await _db.collection('schedules').doc(scheduleId).get();
    final userId = existingDoc.data()?['userId'] ?? '';

    final savedSchedule = await saveMedicationSchedule(
      userId: userId,
      deviceId: deviceId,
      containerId: containerId,
      dosePerTime: dosePerTime,
      scheduleTimes: scheduleTimes,
      endDate: endDate,
    );

    if (savedSchedule.id != scheduleId) {
      final oldDoc = _db.collection('schedules').doc(scheduleId);
      if (scheduleId != savedSchedule.id) {
        final oldData = await oldDoc.get();
        if (oldData.exists) {
          await oldDoc.delete();
        }
      }
    }

    return savedSchedule;
  }

  Future<void> deleteMedicationSchedule({
    required String scheduleId,
    required String deviceId,
    required String containerId,
  }) async {
    await _db.collection('schedules').doc(scheduleId).delete();

    await _pushSchedulesToDevice(deviceId);
  }

  Future<MedicationSchedule?> getMedicationSchedule(String scheduleId) async {
    final doc = await _db.collection('schedules').doc(scheduleId).get();
    if (!doc.exists) return null;
    return MedicationSchedule.fromFirestore(doc.id, doc.data()!);
  }

  Future<void> _pushSchedulesToDevice(
    String deviceId, {
    String? changedContainerId,
  }) async {
    if (deviceId.trim().isEmpty) {
      throw StateError(
        'Device ID is missing. Please set dispenserDeviceId for this user first.',
      );
    }

    final snapshot = await _db
        .collection('schedules')
        .where('deviceId', isEqualTo: deviceId.trim())
        .get();

    final schedules = _dedupeSchedules(snapshot.docs
        .map((doc) => MedicationSchedule.fromFirestore(doc.id, doc.data()))
        .toList());

    final containers = <String, dynamic>{};
    for (final schedule in schedules) {
      containers[schedule.containerId] = {
        'containerId': schedule.containerId,
        'dosePerTime': schedule.dosePerTime,
        'scheduleTimes': schedule.scheduleTimes,
        'endDate': Timestamp.fromDate(schedule.endDate),
        'updatedAt': Timestamp.fromDate(schedule.updatedAt),
        'active': true,
      };
    }

    final currentSchedule = changedContainerId != null
        ? schedules.where((item) => item.containerId == changedContainerId).firstOrNull
        : schedules.firstOrNull;

    final payload = <String, dynamic>{
      'deviceId': deviceId.trim(),
      'scheduleConfig': {
        'containers': containers,
        'lastUpdated': Timestamp.now(),
        'syncVersion': DateTime.now().millisecondsSinceEpoch,
      },
      'updatedAt': Timestamp.now(),
    };

    if (currentSchedule != null) {
      payload['currentSchedule'] = {
        'containerId': currentSchedule.containerId,
        'dosePerTime': currentSchedule.dosePerTime,
        'scheduleTimes': currentSchedule.scheduleTimes,
        'endDate': Timestamp.fromDate(currentSchedule.endDate),
        'lastUpdated': Timestamp.now(),
      };
    } else {
      payload['currentSchedule'] = FieldValue.delete();
    }

    await _db.collection('dispenser_status').doc(deviceId.trim()).set(
          payload,
          SetOptions(merge: true),
        );
    
   final rtdbPayload = {
  'deviceId': deviceId.trim(),
  'scheduleConfig': {
    'containers': containers.map((key, value) => MapEntry(key, {
      'containerId': value['containerId'],
      'dosePerTime': value['dosePerTime'],
      'scheduleTimes': value['scheduleTimes'],
      'endDate': (value['endDate'] as Timestamp).toDate().toIso8601String(),
      'updatedAt': (value['updatedAt'] as Timestamp).toDate().toIso8601String(),
      'active': value['active'],
    })),
    'lastUpdated': DateTime.now().toIso8601String(),
    'syncVersion': DateTime.now().millisecondsSinceEpoch,
  },
  'updatedAt': DateTime.now().toIso8601String(),
};

if (currentSchedule != null) {
  rtdbPayload['currentSchedule'] = {
    'containerId': currentSchedule.containerId,
    'dosePerTime': currentSchedule.dosePerTime,
    'scheduleTimes': currentSchedule.scheduleTimes,
    'endDate': currentSchedule.endDate.toIso8601String(),
    'lastUpdated': DateTime.now().toIso8601String(),
  };
}

await FirebaseDatabase.instance
    .ref('dispenser_status/${deviceId.trim()}')
    .set(rtdbPayload);

    
  }

  void _validateScheduleRequest(String deviceId, String containerId) {
    if (deviceId.trim().isEmpty) {
      throw StateError(
        'Device ID is empty. Add a dispenserDeviceId in the user profile before saving schedules.',
      );
    }

    if (containerId.trim().isEmpty) {
      throw StateError('Container ID is required.');
    }
  }

  List<String> _normalizeTimes(List<String> scheduleTimes) {
    final normalized = scheduleTimes
        .map((time) => time.trim())
        .where((time) => time.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return normalized;
  }

  List<MedicationSchedule> _dedupeSchedules(List<MedicationSchedule> schedules) {
    schedules.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final deduped = <String, MedicationSchedule>{};

    for (final schedule in schedules) {
      deduped.putIfAbsent(schedule.containerId, () => schedule);
    }

    final result = deduped.values.toList()
      ..sort((a, b) => a.containerId.compareTo(b.containerId));
    return result;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
