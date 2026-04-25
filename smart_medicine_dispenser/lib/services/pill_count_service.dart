// lib/services/pill_count_service.dart
//
// Handles all pill-count operations:
//   • Saving initial count + threshold
//   • Real-time stream for the dashboard
//   • Deducting pills when a dose alarm fires
//   • Writing a LOW_PILLS alert to Firestore when threshold is crossed
//
// FIRESTORE STRUCTURE
// ───────────────────
// pill_counts/{deviceId}_{containerId}
//   deviceId:      "ESP-001"
//   containerId:   "1"
//   currentCount:  45        ← decrements every dose
//   totalCount:    60        ← set by user when refilling
//   threshold:     10        ← alert fires at or below this value
//   lastUpdated:   Timestamp
//   lastDeducted:  Timestamp ← last time a dose was auto-deducted
//
// alerts/{autoId}
//   type:     "LOW_PILLS"
//   severity: "HIGH"
//   message:  "Container 1 is low: only 8 pills remaining (threshold: 10)"
//   ...

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pill_count_model.dart';

class PillCountService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _collection = 'pill_counts';

  // ── REAL-TIME STREAM ─────────────────────────────────────────────────────
  // Returns a live stream of ALL pill counts for a given device.
  // The dashboard calls this with StreamBuilder — UI rebuilds automatically.
  Stream<List<PillCount>> getPillCountsStream(String deviceId) {
    return _db
        .collection(_collection)
        .where('deviceId', isEqualTo: deviceId.trim())
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PillCount.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  // Single pill count for one container (one-time fetch)
  Future<PillCount?> getPillCount(String deviceId, String containerId) async {
    final docId = PillCount.docId(deviceId, containerId);
    final doc = await _db.collection(_collection).doc(docId).get();
    if (!doc.exists) return null;
    return PillCount.fromFirestore(doc.id, doc.data()!);
  }

  // ── SAVE / REFILL ────────────────────────────────────────────────────────
  // Called when the user:
  //   (a) first configures a container
  //   (b) refills the container and resets the count
  //
  // Parameters:
  //   totalCount  — total pills put in the container right now
  //   threshold   — how low before an alert fires (e.g. 10)
  //
  // currentCount is set equal to totalCount on save (fresh refill).
  Future<void> setInitialCount({
    required String deviceId,
    required String containerId,
    required String userId,
    required int totalCount,
    required int threshold,
  }) async {
    if (totalCount < 1) throw ArgumentError('totalCount must be ≥ 1');
    if (threshold < 1) throw ArgumentError('threshold must be ≥ 1');
    if (threshold >= totalCount) {
      throw ArgumentError('threshold must be less than totalCount');
    }

    final docId = PillCount.docId(deviceId, containerId);

    await _db.collection(_collection).doc(docId).set({
      'deviceId': deviceId.trim(),
      'containerId': containerId.trim(),
      'userId': userId,
      'currentCount': totalCount,  // starts full
      'totalCount': totalCount,
      'threshold': threshold,
      'lastUpdated': FieldValue.serverTimestamp(),
      'lastDeducted': null,
    }, SetOptions(merge: false));  // merge: false resets on refill
  }

  // Update only the threshold (without resetting the count)
  Future<void> updateThreshold({
    required String deviceId,
    required String containerId,
    required int threshold,
  }) async {
    final docId = PillCount.docId(deviceId, containerId);
    await _db.collection(_collection).doc(docId).update({
      'threshold': threshold,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // ── DEDUCT A DOSE ─────────────────────────────────────────────────────────
  // Called from alarmCallback() in alarm_service.dart when the alarm fires.
  // Also called from fetchAndScheduleFromCloud() for cloud-triggered schedules.
  //
  // Steps:
  //   1. Read current count
  //   2. Subtract dosePerTime (never go below 0)
  //   3. Write the new count back
  //   4. If new count ≤ threshold → write a LOW_PILLS alert to Firestore
  //
  // Returns the updated PillCount so the caller can log/display it.
  Future<PillCount?> deductDose({
    required String deviceId,
    required String containerId,
    required String userId,
    required int dosePerTime,
  }) async {
    final docId = PillCount.docId(deviceId, containerId);
    final docRef = _db.collection(_collection).doc(docId);

    // Use a Firestore transaction so concurrent deductions don't corrupt the count
    return await _db.runTransaction<PillCount?>((transaction) async {
      final snap = await transaction.get(docRef);

      if (!snap.exists) {
        // No pill count configured — skip silently
        print('PillCountService: no doc for $docId, skipping deduction');
        return null;
      }

      final pillCount = PillCount.fromFirestore(snap.id, snap.data()!);
      final newCount = (pillCount.currentCount - dosePerTime).clamp(0, pillCount.totalCount);

      // Write the updated count
      transaction.update(docRef, {
        'currentCount': newCount,
        'lastDeducted': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      final updated = pillCount.copyWith(
        currentCount: newCount,
        lastDeducted: DateTime.now(),
      );

      // ── THRESHOLD CHECK ────────────────────────────────────────────────
      // Only fire one alert per "low" event — check if we just crossed the
      // threshold (was above, now at or below) to avoid repeated alerts.
      final wasAbove = pillCount.currentCount > pillCount.threshold;
      final nowAtOrBelow = newCount <= pillCount.threshold;

      if (wasAbove && nowAtOrBelow && newCount > 0) {
        // Write alert — will appear in the existing real-time alerts stream
        final alertRef = _db.collection('alerts').doc();
        transaction.set(alertRef, {
          'userId': userId,
          'deviceId': deviceId,
          'type': 'LOW_PILLS',
          'severity': 'HIGH',
          'message':
              'Container $containerId is low: only $newCount pill(s) remaining '
              '(threshold: ${pillCount.threshold}). Please refill soon.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'containerId': containerId,
          'currentCount': newCount,
          'threshold': pillCount.threshold,
        });
        print('PillCountService: LOW_PILLS alert written for container $containerId');
      }

      if (newCount <= 0) {
        // Container empty — write a separate EMPTY alert
        final emptyRef = _db.collection('alerts').doc();
        transaction.set(emptyRef, {
          'userId': userId,
          'deviceId': deviceId,
          'type': 'LOW_PILLS',
          'severity': 'HIGH',
          'message':
              'Container $containerId is EMPTY. Please refill immediately.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'containerId': containerId,
          'currentCount': 0,
          'threshold': pillCount.threshold,
        });
      }

      return updated;
    });
  }

  // ── STATIC VERSION FOR BACKGROUND ISOLATE ────────────────────────────────
  // The alarm callback runs in a separate Dart isolate where you cannot
  // instantiate PillCountService normally (no BuildContext, no singleton).
  // This static method initialises its own Firestore reference.
  // Call it from alarmCallback() in alarm_service.dart.
  static Future<void> deductDoseStatic({
    required String deviceId,
    required String containerId,
    required String userId,
    required int dosePerTime,
  }) async {
    // Firebase must already be initialized by the isolate before calling this.
    // alarm_service.dart calls Firebase.initializeApp() first.
    final db = FirebaseFirestore.instance;
    final docId = PillCount.docId(deviceId, containerId);
    final docRef = db.collection('pill_counts').doc(docId);

    await db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      final current = (data['currentCount'] as num?)?.toInt() ?? 0;
      final total = (data['totalCount'] as num?)?.toInt() ?? 0;
      final threshold = (data['threshold'] as num?)?.toInt() ?? 5;
      final newCount = (current - dosePerTime).clamp(0, total);

      transaction.update(docRef, {
        'currentCount': newCount,
        'lastDeducted': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Threshold crossed → write alert
      if (current > threshold && newCount <= threshold && newCount > 0) {
        transaction.set(db.collection('alerts').doc(), {
          'userId': userId,
          'deviceId': deviceId,
          'type': 'LOW_PILLS',
          'severity': 'HIGH',
          'message':
              'Container $containerId is low: only $newCount pill(s) remaining '
              '(threshold: $threshold). Please refill soon.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'containerId': containerId,
          'currentCount': newCount,
          'threshold': threshold,
        });
      }

      if (newCount <= 0) {
        transaction.set(db.collection('alerts').doc(), {
          'userId': userId,
          'deviceId': deviceId,
          'type': 'LOW_PILLS',
          'severity': 'HIGH',
          'message': 'Container $containerId is EMPTY. Please refill immediately.',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'containerId': containerId,
          'currentCount': 0,
          'threshold': threshold,
        });
      }
    });
  }
}