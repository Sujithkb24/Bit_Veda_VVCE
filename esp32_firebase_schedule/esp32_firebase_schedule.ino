#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <WiFi.h>
#include <time.h>

const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* firestoreProjectId = "YOUR_PROJECT_ID";
const char* firestoreApiKey = "YOUR_WEB_API_KEY";
const String deviceId = "ESP32_001";

const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 19800;
const int daylightOffset_sec = 0;

unsigned long lastPollTime = 0;
const unsigned long pollIntervalMs = 10000;
String lastResponseBody = "";

struct ContainerSchedule {
  String containerId;
  int dosePerTime;
  String scheduleTimes[3];
  int timeCount;
  String endDate;
  bool active;
};

ContainerSchedule schedules[2];

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
    Serial.println("\nWiFi connected");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWiFi connection failed");
  }
}

void setupTimeSync() {
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  struct tm timeinfo;
  if (getLocalTime(&timeinfo)) {
    Serial.printf(
      "Time synced: %02d:%02d:%02d\n",
      timeinfo.tm_hour,
      timeinfo.tm_min,
      timeinfo.tm_sec
    );
  }
}

String getDeviceScheduleUrl() {
  return "https://firestore.googleapis.com/v1/projects/" +
      String(firestoreProjectId) +
      "/databases/(default)/documents/dispenser_status/" +
      deviceId +
      "?key=" +
      String(firestoreApiKey);
}

String fetchDeviceSchedule() {
  if (WiFi.status() != WL_CONNECTED) return "";

  HTTPClient http;
  String response = "";

  http.begin(getDeviceScheduleUrl());
  const int statusCode = http.GET();
  if (statusCode > 0) {
    response = http.getString();
    Serial.printf("Schedule fetch status: %d\n", statusCode);
  } else {
    Serial.printf("Schedule fetch failed: %d\n", statusCode);
  }
  http.end();

  return response;
}

String readStringField(JsonObject fields, const char* key) {
  if (!fields.containsKey(key)) return "";
  if (fields[key].containsKey("stringValue")) {
    return fields[key]["stringValue"].as<String>();
  }
  if (fields[key].containsKey("timestampValue")) {
    return fields[key]["timestampValue"].as<String>();
  }
  return "";
}

int readIntField(JsonObject fields, const char* key) {
  if (!fields.containsKey(key)) return 0;
  if (fields[key].containsKey("integerValue")) {
    return String(fields[key]["integerValue"].as<const char*>()).toInt();
  }
  return 0;
}

bool readBoolField(JsonObject fields, const char* key) {
  if (!fields.containsKey(key)) return false;
  if (fields[key].containsKey("booleanValue")) {
    return fields[key]["booleanValue"].as<bool>();
  }
  return false;
}

void clearSchedules() {
  for (int i = 0; i < 2; i++) {
    schedules[i].containerId = String(i + 1);
    schedules[i].dosePerTime = 0;
    schedules[i].timeCount = 0;
    schedules[i].endDate = "";
    schedules[i].active = false;
    for (int j = 0; j < 3; j++) {
      schedules[i].scheduleTimes[j] = "";
    }
  }
}

void parseContainer(JsonObject mapValue, int index) {
  if (index < 0 || index > 1) return;

  JsonObject fields = mapValue["mapValue"]["fields"];
  schedules[index].containerId = readStringField(fields, "containerId");
  schedules[index].dosePerTime = readIntField(fields, "dosePerTime");
  schedules[index].endDate = readStringField(fields, "endDate");
  schedules[index].active = readBoolField(fields, "active");
  schedules[index].timeCount = 0;

  if (fields.containsKey("scheduleTimes")) {
    JsonArray values = fields["scheduleTimes"]["arrayValue"]["values"];
    for (int i = 0; i < values.size() && i < 3; i++) {
      schedules[index].scheduleTimes[i] = values[i]["stringValue"].as<String>();
      schedules[index].timeCount++;
    }
  }
}

void parseSchedulePayload(String json) {
  if (json.isEmpty()) return;

  StaticJsonDocument<4096> doc;
  DeserializationError error = deserializeJson(doc, json);
  if (error) {
    Serial.printf("JSON parse error: %s\n", error.c_str());
    return;
  }

  clearSchedules();

  if (!doc.containsKey("fields")) {
    Serial.println("No fields in Firestore response");
    return;
  }

  JsonObject rootFields = doc["fields"];
  if (!rootFields.containsKey("scheduleConfig")) {
    Serial.println("No scheduleConfig found");
    return;
  }

  JsonObject scheduleFields =
      rootFields["scheduleConfig"]["mapValue"]["fields"];
  JsonObject containers =
      scheduleFields["containers"]["mapValue"]["fields"];

  if (containers.containsKey("1")) {
    parseContainer(containers["1"], 0);
  }
  if (containers.containsKey("2")) {
    parseContainer(containers["2"], 1);
  }

  printSchedules();
}

void printSchedules() {
  Serial.println("\n=== Current device schedules ===");
  for (int i = 0; i < 2; i++) {
    Serial.printf("Container %s\n", schedules[i].containerId.c_str());
    Serial.printf("Active: %s\n", schedules[i].active ? "true" : "false");
    Serial.printf("Dose: %d\n", schedules[i].dosePerTime);
    Serial.printf("End date: %s\n", schedules[i].endDate.c_str());
    for (int j = 0; j < schedules[i].timeCount; j++) {
      Serial.printf("  Time %d: %s\n", j + 1, schedules[i].scheduleTimes[j].c_str());
    }
  }
  Serial.println("===============================\n");
}

bool matchesCurrentMinute(const String& scheduleTime) {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return false;

  const int hour = scheduleTime.substring(0, 2).toInt();
  const int minute = scheduleTime.substring(3, 5).toInt();
  return timeinfo.tm_hour == hour && timeinfo.tm_min == minute;
}

void dispenseMedication(const ContainerSchedule& schedule) {
  Serial.println("=== DISPENSE ===");
  Serial.printf("Container: %s\n", schedule.containerId.c_str());
  Serial.printf("Dose count: %d\n", schedule.dosePerTime);
  Serial.println("================");

  // Add motor control here.
}

void checkDispenseWindows() {
  for (int i = 0; i < 2; i++) {
    if (!schedules[i].active) continue;

    for (int j = 0; j < schedules[i].timeCount; j++) {
      if (matchesCurrentMinute(schedules[i].scheduleTimes[j])) {
        dispenseMedication(schedules[i]);
        delay(60000);
        return;
      }
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  clearSchedules();
  setupWiFi();
  setupTimeSync();

  String initialPayload = fetchDeviceSchedule();
  parseSchedulePayload(initialPayload);
  lastResponseBody = initialPayload;
}

void loop() {
  const unsigned long now = millis();

  if (now - lastPollTime >= pollIntervalMs) {
    lastPollTime = now;

    String payload = fetchDeviceSchedule();
    if (!payload.isEmpty() && payload != lastResponseBody) {
      Serial.println("Schedule updated from Firestore");
      parseSchedulePayload(payload);
      lastResponseBody = payload;
    }
  }

  checkDispenseWindows();
  delay(1000);
}
