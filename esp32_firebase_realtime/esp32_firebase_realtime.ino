// filepath: esp32_firebase_realtime/esp32_firebase_realtime.ino
// ESP32 Firebase Realtime Database Schedule Receiver
// This version uses Firebase Realtime Database (easier for IoT devices)

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>

// ============= CONFIGURATION =============
// WiFi Credentials
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// Firebase Realtime Database
// Get from Firebase Console -> Project Settings -> General
const char* firebaseHost = "YOUR_PROJECT_ID.firebaseio.com";  // e.g., "my-app.firebaseio.com"
const char* firebaseAuth = "YOUR_DATABASE_SECRET";  // Database secret

// Device ID (must match what's stored in Flutter app)
const String deviceId = "ESP-001";

// Polling interval (milliseconds)
const unsigned long POLL_INTERVAL = 10000;

// ============= GLOBAL VARIABLES =============
String lastScheduleJson = "";
unsigned long lastPollTime = 0;

// Schedule structure
struct MedicationSchedule {
  String id;
  int containerId;
  int dosePerTime;
  String scheduleTimes[3];
  bool enabled[3];
  String endDate;
  bool isValid;
};

MedicationSchedule currentSchedule;

// ============= WIFI SETUP =============
void setupWiFi() {
  Serial.println("Connecting to WiFi...");
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected!");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
  }
}

// ============= FIREBASE REALTIME DB =============
// Get schedule from Firebase Realtime Database
// IMPORTANT: Reads from dispenser_status/{deviceId} where Flutter pushes data
String getScheduleFromFirebase() {
  if (WiFi.status() != WL_CONNECTED) {
    return "";
  }

  HTTPClient http;
  // URL format: https://[project].firebaseio.com/dispenser_status/[deviceId].json?auth=[secret]
  // This is where Flutter app pushes the schedule data
  String url = String("https://") + firebaseHost + "/dispenser_status/" + deviceId + ".json?auth=" + firebaseAuth;
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  
  int httpCode = http.GET();
  String response = "";
  
  if (httpCode > 0) {
    response = http.getString();
    Serial.println("Firebase Response: " + response);
  } else {
    Serial.print("HTTP Error: ");
    Serial.println(httpCode);
  }
  
  http.end();
  return response;
}

// ============= PARSE SCHEDULE =============
void parseSchedule(String jsonString) {
  if (jsonString.isEmpty() || jsonString == "null") {
    Serial.println("No schedule found");
    currentSchedule.isValid = false;
    return;
  }

  StaticJsonDocument<1024> doc;
  DeserializationError error = deserializeJson(doc, jsonString);
  
  if (error) {
    Serial.print("JSON Error: ");
    Serial.println(error.c_str());
    return;
  }

  // Parse the Flutter-pushed structure:
  // {
  //   "scheduleConfig": {
  //     "containers": {
  //       "1": { "containerId": "1", "dosePerTime": 2, "scheduleTimes": ["08:00", "14:00", "20:00"], ... },
  //       "2": { ... }
  //     }
  //   },
  //   "currentSchedule": { ... }
  // }

  // Try to get currentSchedule first, then fall back to scheduleConfig.containers
  JsonObject scheduleData = nullptr;
  
  if (doc.containsKey("currentSchedule") && !doc["currentSchedule"].isNull()) {
    scheduleData = doc["currentSchedule"].as<JsonObject>();
    Serial.println("Using currentSchedule");
  } else if (doc.containsKey("scheduleConfig") && !doc["scheduleConfig"].isNull()) {
    JsonObject config = doc["scheduleConfig"].as<JsonObject>();
    if (config.containsKey("containers") && !config["containers"].isNull()) {
      JsonObject containers = config["containers"].as<JsonObject>();
      // Get first container (could be "1" or "2")
      JsonObject firstContainer = nullptr;
      for (JsonPair pair : containers) {
        firstContainer = pair.value().as<JsonObject>();
        break;
      }
      if (firstContainer != nullptr) {
        scheduleData = firstContainer;
        Serial.println("Using scheduleConfig.containers");
      }
    }
  }

  if (scheduleData == nullptr) {
    Serial.println("No valid schedule data found in JSON");
    currentSchedule.isValid = false;
    return;
  }

  // Extract containerId
  if (scheduleData.containsKey("containerId")) {
    String cid = scheduleData["containerId"].as<String>();
    currentSchedule.containerId = cid.toInt();
  } else {
    currentSchedule.containerId = 1;
  }

  // Extract dosePerTime
  if (scheduleData.containsKey("dosePerTime")) {
    currentSchedule.dosePerTime = scheduleData["dosePerTime"].as<int>();
  } else {
    currentSchedule.dosePerTime = 1;
  }

  // Extract endDate
  if (scheduleData.containsKey("endDate")) {
    currentSchedule.endDate = scheduleData["endDate"].as<String>();
  } else {
    currentSchedule.endDate = "";
  }

  // Parse schedule times array - format: ["08:00", "14:00", "20:00"]
  if (scheduleData.containsKey("scheduleTimes")) {
    JsonArray times = scheduleData["scheduleTimes"].as<JsonArray>();
    int i = 0;
    for (JsonVariant time : times) {
      if (i < 3) {
        currentSchedule.scheduleTimes[i] = time.as<String>();
        currentSchedule.enabled[i] = true;
        Serial.printf("Time %d: %s (enabled: yes)\n", i, 
          currentSchedule.scheduleTimes[i].c_str());
        i++;
      }
    }
    // Fill remaining slots as disabled
    for (int j = i; j < 3; j++) {
      currentSchedule.scheduleTimes[j] = "";
      currentSchedule.enabled[j] = false;
    }
  } else {
    currentSchedule.scheduleTimes[0] = "";
    currentSchedule.scheduleTimes[1] = "";
    currentSchedule.scheduleTimes[2] = "";
    currentSchedule.enabled[0] = false;
    currentSchedule.enabled[1] = false;
    currentSchedule.enabled[2] = false;
  }

  currentSchedule.isValid = true;
  Serial.println("Schedule parsed!");
  printSchedule();
}
  printSchedule();
}

// ============= PRINT SCHEDULE =============
void printSchedule() {
  Serial.println("\n=== MEDICATION SCHEDULE ===");
  Serial.printf("Container: %d\n", currentSchedule.containerId);
  Serial.printf("Dose: %d\n", currentSchedule.dosePerTime);
  Serial.printf("Times: %s, %s, %s\n", 
    currentSchedule.scheduleTimes[0].c_str(),
    currentSchedule.scheduleTimes[1].c_str(),
    currentSchedule.scheduleTimes[2].c_str());
  Serial.printf("End Date: %s\n", currentSchedule.endDate.c_str());
  Serial.println("===========================\n");
}

// ============= CHECK DISPENSE TIME =============
bool shouldDispenseNow() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return false;

  char now[6];
  sprintf(now, "%02d:%02d", timeinfo.tm_hour, timeinfo.tm_min);
  Serial.printf("Current: %s\n", now);

  for (int i = 0; i < 3; i++) {
    if (!currentSchedule.enabled[i] || currentSchedule.scheduleTimes[i].isEmpty()) 
      continue;
      
    String sched = currentSchedule.scheduleTimes[i];
    int h = sched.substring(0, 2).toInt();
    int m = sched.substring(3, 5).toInt();
    
    if (timeinfo.tm_hour == h && abs(timeinfo.tm_min - m) <= 1) {
      return true;
    }
  }
  return false;
}

// ============= DISPENSE =============
void dispense() {
  Serial.println(">>> DISPENSING MEDICATION <<<");
  Serial.printf("Container: %d, Dose: %d\n", 
    currentSchedule.containerId, 
    currentSchedule.dosePerTime);
  
  // TODO: Add motor control code here
  // Example: moveStepper(currentSchedule.containerId, currentSchedule.dosePerTime);
  
  // Update status in Firebase
  updateDispenserStatus();
  
  delay(60000); // Prevent re-trigger for 1 minute
}

// ============= UPDATE STATUS =============
void updateDispenserStatus() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String("https://") + firebaseHost + 
               "/dispenser_status/" + deviceId + ".json?auth=" + firebaseAuth;
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  
  StaticJsonDocument<256> doc;
  doc["deviceId"] = deviceId;
  doc["lastDispensedContainer"] = currentSchedule.containerId;
  doc["lastDoseDispensed"] = currentSchedule.dosePerTime;
  doc["status"] = "dispensed";
  doc["timestamp"] = millis();
  
  String payload;
  serializeJson(doc, payload);
  
  http.PUT(payload);
  http.end();
  
  Serial.println("Status updated in Firebase");
}

// ============= SETUP =============
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== ESP32 Firebase Schedule Receiver ===\n");
  
  setupWiFi();
  
  // Get initial schedule
  String json = getScheduleFromFirebase();
  parseSchedule(json);
  lastScheduleJson = json;
  
  Serial.println("Ready!\n");
}

// ============= LOOP =============
void loop() {
  unsigned long now = millis();
  
  // Poll Firebase
  if (now - lastPollTime >= POLL_INTERVAL) {
    lastPollTime = now;
    
    String json = getScheduleFromFirebase();
    if (json != lastScheduleJson && json != "null") {
      Serial.println("Schedule updated!");
      parseSchedule(json);
      lastScheduleJson = json;
    }
  }
  
  // Check dispense time
  if (currentSchedule.isValid && shouldDispenseNow()) {
    dispense();
  }
  
  delay(1000);
}