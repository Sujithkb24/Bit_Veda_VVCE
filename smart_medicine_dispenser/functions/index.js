// functions/index.js

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onValueCreated }    = require("firebase-functions/v2/database");
const functions             = require("firebase-functions");
const admin                 = require("firebase-admin");

admin.initializeApp();

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 1: Send FCM push notification when a new Firestore alert is created
// Triggered by: anything writing to alerts/ collection (Cloud Function 2, app, etc.)
// ─────────────────────────────────────────────────────────────────────────────
exports.sendAlertNotification = onDocumentCreated(
  "alerts/{alertId}",
  async (event) => {
    const alert = event.data.data();

    const userDoc = await admin.firestore()
      .collection("users")
      .doc(alert.userId)
      .get();

    if (!userDoc.exists) return;

    const token = userDoc.data().fcmToken;
    if (!token) return;

    await admin.messaging().send({
      token: token,
      notification: {
        title: getNotificationTitle(alert.type),
        body:  alert.message || "New alert received",
      },
      data: {
        alertId: event.params.alertId,
        type:    alert.type     || "",
        severity: alert.severity || "LOW",
      },
    });

    console.log("FCM sent for alert:", event.params.alertId, "→ user:", alert.userId);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 2: ESP32 → Firestore bridge
// Triggered by: ESP32 writing a new child to /esp32_alerts/ in Realtime Database
// Writes a properly formatted alert doc to Firestore, then deletes the RTDB entry
// ─────────────────────────────────────────────────────────────────────────────
exports.onEsp32Alert = onValueCreated(
  {
    // Replace this URL with YOUR actual database URL from Firebase Console
    instance: "smart-medicine-dispenser-efa5b-default-rtdb",

    // Replace with your actual region from the URL above:
    // "us-central1" OR "europe-west1" OR "asia-southeast1"
    region: "asia-southeast1",

    ref: "/esp32_alerts/{alertKey}",
  },
  async (event) => {
    const data     = event.data.val();
    const alertKey = event.params.alertKey;

    console.log("ESP32 alert received:", alertKey, JSON.stringify(data));

    if (!data) {
      console.log("Empty payload — skipping");
      return;
    }

    const deviceId = data.deviceId || "ESP32_DISPENSER_01";

    const userId = await getUserIdForDevice(deviceId);
    if (!userId) {
      console.log("No user found for deviceId:", deviceId, "— skipping");
      await event.data.ref.remove();
      return;
    }

    await admin.firestore().collection("alerts").add({
      userId:           userId,
      deviceId:         deviceId,
      type:             data.type             || "UNKNOWN",
      message:          data.message          || "",
      severity:         data.severity         || "LOW",
      timestamp:        admin.firestore.FieldValue.serverTimestamp(),
      isRead:           false,
      containerNumber:  data.containerNumber  || 0,
      tabletsDispensed: data.tabletsDispensed || 0,
    });

    console.log("Firestore alert created for user:", userId);
    await event.data.ref.remove();
    console.log("RTDB entry cleaned up:", alertKey);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 3: HTTP endpoint — ESP32 polls this to fetch its dispensing schedule
// Usage: GET https://REGION-PROJECT.cloudfunctions.net/getSchedule?deviceId=ESP32_01
// ─────────────────────────────────────────────────────────────────────────────
exports.getSchedule = functions.https.onRequest(async (req, res) => {
  // Allow ESP32 to call this (no CORS issues from device HTTP clients)
  res.set("Access-Control-Allow-Origin", "*");

  try {
    const deviceId = req.query.deviceId;

    if (!deviceId) {
      return res.status(400).json({ error: "Missing deviceId query parameter" });
    }

    // Fetch all container schedules for this device
    const snapshot = await admin.firestore()
      .collection("schedules")
      .where("deviceId", "==", deviceId)
      .get();

    if (snapshot.empty) {
      return res.status(404).json({ error: "No schedules found for deviceId: " + deviceId });
    }

    // Return all containers as an array so ESP32 can handle multiple containers
    const schedules = snapshot.docs.map((doc) => ({
      id:            doc.id,
      containerId:   doc.data().containerId,
      dosePerTime:   doc.data().dosePerTime,
      scheduleTimes: doc.data().scheduleTimes,   // e.g. ["08:00", "14:00", "20:00"]
      endDate:       doc.data().endDate?.toDate?.()?.toISOString() || null,
    }));

    console.log("Schedule served for deviceId:", deviceId, "→", schedules.length, "containers");
    return res.status(200).json({ deviceId, schedules });

  } catch (e) {
    console.error("getSchedule error:", e);
    return res.status(500).json({ error: e.toString() });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Find the userId that owns a given deviceId
// Reads from Firestore users collection where dispenserDeviceId == deviceId
// ─────────────────────────────────────────────────────────────────────────────
async function getUserIdForDevice(deviceId) {
  const snapshot = await admin.firestore()
    .collection("users")
    .where("dispenserDeviceId", "==", deviceId)
    .limit(1)
    .get();

  if (snapshot.empty) return null;
  return snapshot.docs[0].id;   // document ID is the Firebase Auth UID
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Map alert type to a human-readable FCM notification title
// Matches the types your AlertCard widget already handles
// ─────────────────────────────────────────────────────────────────────────────
function getNotificationTitle(type) {
  const titles = {
    MISSED_DOSE:    "Missed Dose",
    LOW_PILLS:      "Low Pills Warning",
    BATTERY_LOW:    "Battery Low",
    DOSE_TAKEN:     "Dose Confirmed",
    JAM_DETECTED:   "Dispenser Jam Detected",
    DEVICE_OFFLINE: "Device Offline",
  };
  return titles[type] || "Medicine Alert";
}