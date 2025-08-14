#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <HardwareSerial.h>
#include <time.h> // for timestamp

// ------------------- Wi-Fi credentials -------------------
const char* ssid = "Calm Down";
const char* password = "s72s7272";

// Firebase credentials
#define API_KEY "AIzaSyBjJ3LRwrFSgLFKV9rqH55we0svsAYhB3Q"
#define DATABASE_URL "https://watt-wizard-c0833.firebaseio.com/"
#define FIREBASE_PROJECT_ID "watt-wizard-c0833"
#define USER_EMAIL "ahsan@gmail.com"
#define USER_PASSWORD "12345678"

// ------------------- Firebase objects -------------------
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
String user_uid;

// ------------------- Pins -------------------
#define CURRENT_SENSOR_PIN 34
#define VOLTAGE_SENSOR_PIN 35
#define RELAY1 13
#define RELAY2 27
#define RELAY3 14
#define RELAY4 26

// ------------------- Sensor calibration -------------------
const float CURRENT_SENSOR_ZERO_POINT_MV = 1650;
const float CURRENT_SENSOR_SENSITIVITY_MV_PER_A = 66;
const float VOLTAGE_SENSOR_CALIBRATION_FACTOR = (25.0 / 3.0);
const float ADC_MAX_READING = 4095.0;
const float ADC_REF_VOLTAGE = 3.3;

// ------------------- Raspberry Pi UART -------------------
HardwareSerial SerialPi(1);
#define TX_PIN 17
#define RX_PIN 16

// ------------------- Token status callback -------------------
void tokenStatusCallback(TokenInfo info) {
  if (info.status == token_status_ready && auth.token.uid.length() > 0) {
    user_uid = auth.token.uid.c_str();
    Serial.print("Authenticated user UID: ");
    Serial.println(user_uid);
  }
  Serial.printf("Token Status: %d\n", info.status);
  Serial.printf("Token Error: %s\n", info.error.message.c_str());
  Serial.printf("Is Authenticated: %s\n", auth.token.uid.length() > 0 ? "true" : "false");
}

void setup() {
  Serial.begin(115200);
  SerialPi.begin(9600, SERIAL_8N1, RX_PIN, TX_PIN);

  pinMode(RELAY1, OUTPUT);
  pinMode(RELAY2, OUTPUT);
  pinMode(RELAY3, OUTPUT);
  pinMode(RELAY4, OUTPUT);

  digitalWrite(RELAY1, HIGH);
  digitalWrite(RELAY2, HIGH);
  digitalWrite(RELAY3, HIGH);
  digitalWrite(RELAY4, HIGH);

  WiFi.begin(ssid, password);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected to Wi-Fi!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // Time config (needed for timestamp)
  configTime(0, 0, "pool.ntp.org");

  // Firebase config
  config.api_key = API_KEY;
  config.token_status_callback = tokenStatusCallback;

  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;

  Serial.println("Starting Firebase...");
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.print("Waiting for Firebase and authentication");
  while (!Firebase.ready() || user_uid.length() == 0) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println("\nFirebase ready and authenticated!");
}

void loop() {
  if (Firebase.ready() && user_uid.length() > 0) {
    // Read sensors
    float raw_current_adc = analogRead(CURRENT_SENSOR_PIN);
    float current_mv = (raw_current_adc / ADC_MAX_READING) * ADC_REF_VOLTAGE * 1000;
    float current_a = (current_mv - CURRENT_SENSOR_ZERO_POINT_MV) / CURRENT_SENSOR_SENSITIVITY_MV_PER_A;

    float raw_voltage_adc = analogRead(VOLTAGE_SENSOR_PIN);
    float voltage_v_at_adc = (raw_voltage_adc / ADC_MAX_READING) * ADC_REF_VOLTAGE;
    float voltage_v = voltage_v_at_adc * VOLTAGE_SENSOR_CALIBRATION_FACTOR;

    float total_power_watts = voltage_v * current_a;

    Serial.printf("Raw Current ADC: %.0f, Current (A): %.3f\n", raw_current_adc, current_a);
    Serial.printf("Raw Voltage ADC: %.0f, Voltage (V): %.3f\n", raw_voltage_adc, voltage_v);
    Serial.printf("Total Power (W): %.3f\n", total_power_watts);

    // Prepare Firestore data
    String sensor_live_path = "sensor_data/" + user_uid + "/live";
    FirebaseJson content;
    content.set("voltage", String(voltage_v, 3));
    content.set("current_a", String(current_a, 3));
    content.set("total_power_watts", String(total_power_watts, 3));

    // New timestamp method
    time_t now = time(nullptr);
    content.set("timestamp", String(now).c_str());

    Serial.println("Uploading sensor data to: " + sensor_live_path);
    if (Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "", sensor_live_path.c_str(), content.raw())) {
      Serial.println("Sensor data uploaded successfully!");
    } else {
      Serial.print("Failed to upload sensor data: ");
      Serial.println(fbdo.errorReason());
    }

    // Send data to Pi
    String dataToPi = String("CURRENT_A:") + String(current_a, 3) +
                      ";VOLTAGE_V:" + String(voltage_v, 3) +
                      ";POWER_W:" + String(total_power_watts, 3);
    SerialPi.println(dataToPi);
    Serial.println("Sent to Pi: " + dataToPi);

    // Read control values
    auto readDeviceStatus = [&](const String& deviceId, int relayPin) {
      String device_path = "users/" + user_uid + "/devices/" + deviceId;
      bool status = false;
      Serial.println("Reading from: " + device_path);
      if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", device_path.c_str())) {
        FirebaseJson payload;
        payload.setJsonData(fbdo.payload());
        FirebaseJsonData jsonData;
        if (payload.get(jsonData, "fields/status/booleanValue")) {
          status = jsonData.boolValue;
          Serial.printf("%s status found: %s\n", deviceId.c_str(), status ? "ON" : "OFF");
        }
      } else {
        Serial.printf("Failed to read %s: %s\n", deviceId.c_str(), fbdo.errorReason());
      }
      digitalWrite(relayPin, status ? LOW : HIGH);
      return status;
    };

    bool fan_status = readDeviceStatus("fan_01", RELAY1);
    bool light1_status = readDeviceStatus("light_01", RELAY2);
    bool light2_status = readDeviceStatus("light_02", RELAY3);
    bool socket_status = readDeviceStatus("socket_01", RELAY4);

    Serial.println("=== RELAY STATUS ===");
    Serial.printf("Fan: %s\n", fan_status ? "ON" : "OFF");
    Serial.printf("Light1: %s\n", light1_status ? "ON" : "OFF");
    Serial.printf("Light2: %s\n", light2_status ? "ON" : "OFF");
    Serial.printf("Socket: %s\n", socket_status ? "ON" : "OFF");
    Serial.println("==================");

  } else {
    Serial.println("Firebase not ready or user not authenticated. Retrying...");
    Firebase.begin(&config, &auth);
  }

  delay(5000);
}
