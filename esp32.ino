#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <HardwareSerial.h>
#include <time.h>
#include <ArduinoJson.h>

// ------------------- Wi-Fi credentials -------------------
const char* ssid = "Calm Down";
const char* password = "s72s7272";

// ------------------- Firebase credentials -------------------
#define API_KEY "AIzaSyBjJ3LRwrFSgLFKV9rqH55we0svsAYhB3Q"
#define DATABASE_URL "https://watt-wizard-c0833.firebaseio.com/"
#define FIREBASE_PROJECT_ID "watt-wizard-c0833"
#define ESP32_AUTH_EMAIL "ahsan@gmail.com"
#define ESP32_AUTH_PASSWORD "12345678"

// ------------------- Firebase objects -------------------
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
String user_uid;

// ------------------- Pins -------------------
#define CURRENT_SENSOR_PIN 34
#define VOLTAGE_SENSOR_PIN 35
#define RELAY1 13  // Fan
#define RELAY2 27  // Light 1
#define RELAY3 14  // Light 2
#define RELAY4 26  // Socket

// ------------------- Sensor calibration -------------------
const float CURRENT_SENSOR_ZERO_POINT_MV = 1650;
const float CURRENT_SENSOR_SENSITIVITY_MV_PER_A = 66;
const float VOLTAGE_SENSOR_CALIBRATION_FACTOR = (25.0 / 3.0);
const float ADC_MAX_READING = 4095.0;
const float ADC_REF_VOLTAGE = 3.3;

// ------------------- Device tracking -------------------
struct Device {
  String id;
  String name;
  int relayPin;
  bool currentState;
  bool previousState;
  unsigned long lastStateChange;
  float estimatedPower; // Watts when ON
  unsigned long totalOnTime; // Total time device has been ON (ms)
  unsigned long sessionStartTime; // When current ON session started
};

Device devices[4] = {
  {"fan_01", "Fan", RELAY1, false, false, 0, 75.0, 0, 0},
  {"light_01", "Light 1", RELAY2, false, false, 0, 60.0, 0, 0},
  {"light_02", "Light 2", RELAY3, false, false, 0, 60.0, 0, 0},
  {"socket_01", "Socket", RELAY4, false, false, 0, 100.0, 0, 0}
};

// ------------------- Raspberry Pi UART -------------------
HardwareSerial SerialPi(1);
#define TX_PIN 17
#define RX_PIN 16

// ------------------- Timing -------------------
unsigned long lastSensorUpdate = 0;
unsigned long lastDeviceUpdate = 0;
unsigned long lastHistoryLog = 0;
const unsigned long SENSOR_UPDATE_INTERVAL = 5000;  // 5 seconds
const unsigned long DEVICE_UPDATE_INTERVAL = 2000;  // 2 seconds
const unsigned long HISTORY_LOG_INTERVAL = 60000;   // 1 minute

// ------------------- Token status callback -------------------
void tokenStatusCallback(TokenInfo info) {
  if (info.status == token_status_ready && auth.token.uid.length() > 0) {
    user_uid = auth.token.uid.c_str();
    Serial.print("Authenticated user UID: ");
    Serial.println(user_uid);
  }
  Serial.printf("Token Status: %d\n", info.status);
  Serial.printf("Token Error: %s\n", info.error.message.c_str());
}

// ------------------- Get timestamp -------------------
String getTimestamp() {
  time_t now;
  time(&now);
  return String(now);
}

// ------------------- Upload device state change -------------------
void uploadDeviceStateChange(Device& device, bool newState) {
  String timestamp = getTimestamp();
  String device_history_path = "power_data/" + user_uid + "/device_history";
  
  FirebaseJson content;
  content.set("fields/device_id/stringValue", device.id);
  content.set("fields/device_name/stringValue", device.name);
  content.set("fields/state/booleanValue", newState);
  content.set("fields/timestamp/integerValue", timestamp);
  content.set("fields/estimated_power/doubleValue", device.estimatedPower);
  
  // Calculate session duration if turning OFF
  if (!newState && device.sessionStartTime > 0) {
    unsigned long sessionDuration = millis() - device.sessionStartTime;
    content.set("fields/session_duration_ms/integerValue", (int)sessionDuration);
    content.set("fields/session_duration_hours/doubleValue", sessionDuration / 3600000.0);
  }
  
  Serial.println("Uploading device state change to: " + device_history_path);
  if (Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "(default)", device_history_path.c_str(), content.raw())) {
    Serial.println("Device state change logged successfully for " + device.name);
  } else {
    Serial.println("Failed to log device state change: " + fbdo.errorReason());
  }
}

// ------------------- Upload device status -------------------
void uploadDeviceStatus() {
  for (int i = 0; i < 4; i++) {
    Device& device = devices[i];
    String device_status_path = "power_data/" + user_uid + "/device_status/" + device.id;
    
    FirebaseJson content;
    content.set("fields/device_name/stringValue", device.name);
    content.set("fields/state/booleanValue", device.currentState);
    content.set("fields/estimated_power/doubleValue", device.estimatedPower);
    content.set("fields/total_on_time_hours/doubleValue", device.totalOnTime / 3600000.0);
    content.set("fields/last_updated/integerValue", getTimestamp());
    
    if (device.currentState && device.sessionStartTime > 0) {
      unsigned long currentSessionTime = millis() - device.sessionStartTime;
      content.set("fields/current_session_duration_hours/doubleValue", currentSessionTime / 3600000.0);
    } else {
      content.set("fields/current_session_duration_hours/doubleValue", 0.0);
    }
    
    if (Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "(default)", device_status_path.c_str(), content.raw(), "")) {
      Serial.println("Device status updated for " + device.name);
    } else {
      Serial.println("Failed to update device status for " + device.name + ": " + fbdo.errorReason());
    }
  }
}

// ------------------- Upload sensor readings -------------------
void uploadSensorReadings(float voltage, float current, float totalPower) {
  String timestamp = getTimestamp();
  
  // Live sensor data
  String sensor_live_path = "power_data/" + user_uid + "/sensor_live/current";
  FirebaseJson liveContent;
  liveContent.set("fields/voltage/doubleValue", voltage);
  liveContent.set("fields/current_a/doubleValue", current);
  liveContent.set("fields/total_power_watts/doubleValue", totalPower);
  liveContent.set("fields/timestamp/integerValue", timestamp);
  
  // Calculate individual device estimated power
  float totalEstimatedPower = 0;
  for (int i = 0; i < 4; i++) {
    if (devices[i].currentState) {
      totalEstimatedPower += devices[i].estimatedPower;
    }
  }
  liveContent.set("fields/estimated_total_power/doubleValue", totalEstimatedPower);
  liveContent.set("fields/power_efficiency/doubleValue", totalEstimatedPower > 0 ? (totalPower / totalEstimatedPower) * 100 : 0);
  
  if (Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "(default)", sensor_live_path.c_str(), liveContent.raw(), "")) {
    Serial.println("Live sensor data updated successfully!");
  } else {
    Serial.println("Failed to update live sensor data: " + fbdo.errorReason());
  }
}

// ------------------- Upload historical data -------------------
void uploadHistoricalData(float voltage, float current, float totalPower) {
  String timestamp = getTimestamp();
  String sensor_history_path = "power_data/" + user_uid + "/sensor_history";
  
  FirebaseJson content;
  content.set("fields/voltage/doubleValue", voltage);
  content.set("fields/current_a/doubleValue", current);
  content.set("fields/total_power_watts/doubleValue", totalPower);
  content.set("fields/timestamp/integerValue", timestamp);
  
  // Add device states at this moment
  for (int i = 0; i < 4; i++) {
    String deviceStateField = "fields/" + devices[i].id + "_state/booleanValue";
    content.set(deviceStateField, devices[i].currentState);
  }
  
  if (Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "(default)", sensor_history_path.c_str(), content.raw())) {
    Serial.println("Historical data logged successfully!");
  } else {
    Serial.println("Failed to log historical data: " + fbdo.errorReason());
  }
}

void setup() {
  Serial.begin(115200);
  SerialPi.begin(9600, SERIAL_8N1, RX_PIN, TX_PIN);

  // Initialize relay pins
  for (int i = 0; i < 4; i++) {
    pinMode(devices[i].relayPin, OUTPUT);
    digitalWrite(devices[i].relayPin, HIGH); // OFF state
  }

  WiFi.begin(ssid, password);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected to Wi-Fi!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // Configure time
  configTime(0, 0, "pool.ntp.org");
  
  // Wait for time synchronization
  Serial.print("Waiting for time sync");
  while (time(nullptr) < 1000000000) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nTime synchronized!");

  // Firebase configuration
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  config.token_status_callback = tokenStatusCallback;
  config.timeout.serverResponse = 60 * 1000;

  auth.user.email = ESP32_AUTH_EMAIL;
  auth.user.password = ESP32_AUTH_PASSWORD;

  Serial.println("Starting Firebase...");
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Wait for authentication
  Serial.print("Waiting for Firebase authentication");
  while (!Firebase.ready() || auth.token.uid.length() == 0) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nFirebase authenticated!");
  
  // Initialize timing
  lastSensorUpdate = millis();
  lastDeviceUpdate = millis();
  lastHistoryLog = millis();
}

void loop() {
  if (!Firebase.ready() || user_uid.length() == 0) {
    Serial.println("Firebase not ready or user not authenticated.");
    delay(5000);
    return;
  }

  unsigned long currentTime = millis();
  
  // Read and update device states
  if (currentTime - lastDeviceUpdate >= DEVICE_UPDATE_INTERVAL) {
    for (int i = 0; i < 4; i++) {
      Device& device = devices[i];
      
      // Read device status from Firebase
      String device_path = "users/" + user_uid + "/devices/" + device.id;
      bool newState = false;
      
      if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "(default)", device_path.c_str())) {
        FirebaseJson payload;
        payload.setJsonData(fbdo.payload());
        FirebaseJsonData jsonData;
        if (payload.get(jsonData, "fields/status/booleanValue")) {
          newState = jsonData.boolValue;
        }
      }
      
      // Update relay
      digitalWrite(device.relayPin, newState ? LOW : HIGH);
      
      // Track state changes
      if (newState != device.currentState) {
        device.previousState = device.currentState;
        device.currentState = newState;
        device.lastStateChange = currentTime;
        
        if (newState) {
          // Device turned ON
          device.sessionStartTime = currentTime;
          Serial.println(device.name + " turned ON");
        } else {
          // Device turned OFF
          if (device.sessionStartTime > 0) {
            unsigned long sessionDuration = currentTime - device.sessionStartTime;
            device.totalOnTime += sessionDuration;
            Serial.println(device.name + " turned OFF after " + String(sessionDuration / 1000.0) + " seconds");
          }
          device.sessionStartTime = 0;
        }
        
        // Log state change to Firebase
        uploadDeviceStateChange(device, newState);
      }
      
      // Update total ON time for currently running devices
      if (device.currentState && device.sessionStartTime > 0) {
        // Device is currently ON, no need to update totalOnTime yet as it's still running
      }
    }
    
    // Upload device status
    uploadDeviceStatus();
    lastDeviceUpdate = currentTime;
  }
  
  // Read and upload sensor data
  if (currentTime - lastSensorUpdate >= SENSOR_UPDATE_INTERVAL) {
    // Read sensors
    float raw_current_adc = analogRead(CURRENT_SENSOR_PIN);
    float current_mv = (raw_current_adc / ADC_MAX_READING) * ADC_REF_VOLTAGE * 1000;
    float current_a = (current_mv - CURRENT_SENSOR_ZERO_POINT_MV) / CURRENT_SENSOR_SENSITIVITY_MV_PER_A;
    current_a = max(0.0f, current_a); // Ensure non-negative

    float raw_voltage_adc = analogRead(VOLTAGE_SENSOR_PIN);
    float voltage_v_at_adc = (raw_voltage_adc / ADC_MAX_READING) * ADC_REF_VOLTAGE;
    float voltage_v = voltage_v_at_adc * VOLTAGE_SENSOR_CALIBRATION_FACTOR;

    float total_power_watts = voltage_v * current_a;

    Serial.printf("\n=== SENSOR READINGS ===\n");
    Serial.printf("Voltage: %.3f V\n", voltage_v);
    Serial.printf("Current: %.3f A\n", current_a);
    Serial.printf("Total Power: %.3f W\n", total_power_watts);

    // Calculate estimated power from devices
    float estimated_power = 0;
    for (int i = 0; i < 4; i++) {
      if (devices[i].currentState) {
        estimated_power += devices[i].estimatedPower;
      }
    }
    Serial.printf("Estimated Power: %.3f W\n", estimated_power);
    Serial.printf("Power Efficiency: %.1f%%\n", estimated_power > 0 ? (total_power_watts / estimated_power) * 100 : 0);
    Serial.println("========================");

    // Upload live sensor data
    uploadSensorReadings(voltage_v, current_a, total_power_watts);
    
    // Send data to Raspberry Pi
    String dataToPi = String("CURRENT_A:") + String(current_a, 3) +
                      String(";VOLTAGE_V:") + String(voltage_v, 3) +
                      String(";POWER_W:") + String(total_power_watts, 3);
    SerialPi.println(dataToPi);
    
    lastSensorUpdate = currentTime;
  }
  
  // Log historical data periodically
  if (currentTime - lastHistoryLog >= HISTORY_LOG_INTERVAL) {
    // Read current sensor values for history
    float raw_current_adc = analogRead(CURRENT_SENSOR_PIN);
    float current_mv = (raw_current_adc / ADC_MAX_READING) * ADC_REF_VOLTAGE * 1000;
    float current_a = max(0.0f, (current_mv - CURRENT_SENSOR_ZERO_POINT_MV) / CURRENT_SENSOR_SENSITIVITY_MV_PER_A);

    float raw_voltage_adc = analogRead(VOLTAGE_SENSOR_PIN);
    float voltage_v_at_adc = (raw_voltage_adc / ADC_MAX_READING) * ADC_REF_VOLTAGE;
    float voltage_v = voltage_v_at_adc * VOLTAGE_SENSOR_CALIBRATION_FACTOR;

    float total_power_watts = voltage_v * current_a;
    
    uploadHistoricalData(voltage_v, current_a, total_power_watts);
    lastHistoryLog = currentTime;
  }

  delay(100); // Small delay to prevent overwhelming the system
}
