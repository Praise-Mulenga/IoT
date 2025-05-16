/*
 * Environmental Monitoring System with Firebase Integration
 * 
 * Features:
 * - Reads temperature and humidity from DHT11 sensor
 * - Displays data on 16x2 LCD
 * - Syncs data with Firebase Realtime Database
 * - Supports manual override from Firebase
 * - Comprehensive error handling
 * 
 * Hardware Connections:
 * - DHT11: Pin 27 (DATA), 3.3V, GND
 * - LCD: RS=12, EN=14, D4=26, D5=25, D6=33, D7=32
 */

#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <DHT.h>
#include <LiquidCrystal.h>
#include "addons/TokenHelper.h"  // Required for Firebase token handling

// ================= HARDWARE CONFIGURATION =================
#define DHTPIN 27        // GPIO pin connected to DHT11 data pin
#define DHTTYPE DHT11    // DHT sensor type (DHT11 or DHT22)
DHT dht(DHTPIN, DHTTYPE); // Initialize DHT sensor

// LCD interface pins (4-bit parallel mode)
const int rs = 12, en = 14, d4 = 26, d5 = 25, d6 = 33, d7 = 32;
LiquidCrystal lcd(rs, en, d4, d5, d6, d7);

// ================= NETWORK CONFIGURATION =================
#define WIFI_SSID "MulengaTheGreat"  // Your WiFi network name
//#define WIFI_PASSWORD "praise@2025" // I removed my password to my network but can easily be used if I put it back

// ================= FIREBASE CONFIGURATION =================
#define FIREBASE_HOST "https://enviromental-monitor-ad43d-default-rtdb.firebaseio.com/"
#define API_KEY "AIzaSyCnDaQNTEvpAcdSKYj00e9qUMNrh_5Rj-k"
#define DEVICE_ID "esp32_001"       // Unique identifier for this device
#define STUDENT_NAME "PRAISE MULENGA" // My name for device identification

// ================= SYSTEM OBJECTS =================
FirebaseData fbdo;      // Firebase data object for transfers
FirebaseAuth auth;      // Firebase authentication object
FirebaseConfig config;  // Firebase configuration object

// ================= SYSTEM STATE STRUCTURE =================
struct SystemState {
  // Sensor data
  float temp = 0;             // Current temperature in °C
  float hum = 0;              // Current humidity in %
  
  // System status
  bool firebaseOverride = false; // Manual control flag
  String status = "Booting...";  // System status message
  unsigned long lastOverrideTime = 0; // Timestamp of last override
  bool wifiConnected = false;    // WiFi connection status
  bool firebaseConnected = false; // Firebase connection status
} systemState;

// ================= TIMING VARIABLES =================
unsigned long lastSensorUpdate = 0;    // Last sensor read time
unsigned long lastFirebaseCheck = 0;   // Last Firebase sync time
unsigned long lastDisplayUpdate = 0;   // Last LCD update time
const unsigned long SENSOR_INTERVAL = 2000;     // Read sensor every 2s
const unsigned long FIREBASE_CHECK_INTERVAL = 5000; // Check Firebase every 5s
const unsigned long OVERRIDE_TIMEOUT = 30000;   // 30s manual override timeout

// ================= FUNCTION PROTOTYPES =================
void connectToWiFi();                  // Handle WiFi connection
void authenticateFirebase();           // Firebase authentication
void waitForFirebaseReady();           // Wait for Firebase connection
void initializeDatabase();             // Setup Firebase data structure
void readSensorData();                 // Read from DHT sensor
void updateLCD();                      // Update LCD display
void updateLCDStatus(String message);  // Show status message on LCD
void checkFirebaseUpdates();           // Check for Firebase changes
void startManualOverride(FirebaseJson &json); // Enable manual control
void endManualOverride();              // Disable manual control
void updateFirebaseData(float temp, float hum); // Send data to Firebase
void handleSensorError();              // Handle sensor read errors

// ================= MAIN SETUP =================
void setup() {
  // Initialize serial communication for debugging
  Serial.begin(115200);
  Serial.println("Starting system initialization...");
  
  // Initialize LCD display
  lcd.begin(16, 2);
  lcd.print(systemState.status);
  
  // Initialize DHT sensor
  dht.begin();
  Serial.println("DHT sensor initialized");

  // Connect to WiFi network
  connectToWiFi();

  // Configure Firebase connection
  config.api_key = API_KEY;
  config.database_url = FIREBASE_HOST;
  config.token_status_callback = tokenStatusCallback; // Use built-in token helper

  // Authenticate with Firebase (anonymous sign-in)
  authenticateFirebase();

  // Initialize Firebase connection
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true); // Automatically reconnect if connection drops

  // Wait until Firebase is ready
  waitForFirebaseReady();

  // Set up initial database structure
  initializeDatabase();

  // System ready
  systemState.status = "System Ready";
  updateLCD();
  Serial.println("System initialization complete");
}

// ================= MAIN LOOP =================
void loop() {
  unsigned long currentMillis = millis(); // Get current time

  // Read sensor data at regular intervals
  if (currentMillis - lastSensorUpdate >= SENSOR_INTERVAL) {
    lastSensorUpdate = currentMillis;
    readSensorData();
  }

  // Check for Firebase updates
  if (currentMillis - lastFirebaseCheck >= FIREBASE_CHECK_INTERVAL && Firebase.ready()) {
    lastFirebaseCheck = currentMillis;
    checkFirebaseUpdates();
  }

  // Automatically end manual override after timeout
  if (systemState.firebaseOverride && 
      currentMillis - systemState.lastOverrideTime >= OVERRIDE_TIMEOUT) {
    endManualOverride();
  }

  // Update LCD display regularly
  if (currentMillis - lastDisplayUpdate >= 500) {
    updateLCD();
    lastDisplayUpdate = currentMillis;
  }
}

// ================= WIFI CONNECTION =================
void connectToWiFi() {
  systemState.status = "WiFi Connecting";
  updateLCD();
  
  WiFi.begin(WIFI_SSID /*, WIFI_PASSWORD*/); // Start WiFi connection, and can easily connect to a network with a password by uncommenting the WIFI_PASSWORD
  Serial.print("Connecting to WiFi");
  
  // Attempt connection with timeout
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
    updateLCDStatus("Attempt " + String(attempts)); // Show progress on LCD
  }
  
  // Check connection result
  if (WiFi.status() == WL_CONNECTED) {
    systemState.wifiConnected = true;
    systemState.status = "WiFi Connected";
    Serial.println("\nConnected! IP: " + WiFi.localIP().toString());
  } else {
    systemState.status = "WiFi Failed";
    Serial.println("\nConnection failed");
    ESP.restart(); // Restart if can't connect
  }
  updateLCD();
}

// ================= FIREBASE AUTHENTICATION =================
void authenticateFirebase() {
  systemState.status = "Firebase Auth";
  updateLCD();
  Serial.println("Signing in anonymously...");
  
  // Attempt anonymous sign-in
  if (Firebase.signUp(&config, &auth, "", "")) {
    systemState.status = "Auth Success";
    Serial.println("Anonymous sign-in successful");
  } else {
    systemState.status = "Auth Failed: " + String(config.signer.signupError.message.c_str());
    Serial.println("Anonymous sign-in failed: " + String(config.signer.signupError.message.c_str()));
  }
  updateLCD();
}

// ================= FIREBASE CONNECTION WAIT =================
void waitForFirebaseReady() {
  systemState.status = "Firebase Init";
  updateLCD();
  while (!Firebase.ready()) {
    delay(500);
    Serial.print("-");
    lcd.setCursor(0, 1);
    lcd.print("Status: " + String(Firebase.ready() ? "OK" : "Waiting"));
  }
}

// ================= DATABASE INITIALIZATION =================
void initializeDatabase() {
  if (Firebase.ready()) {
    // Create devices node with initialization flag
    String path = String("/sensors/devices/") + DEVICE_ID + "/initialized";
    Firebase.RTDB.setBool(&fbdo, path, true);
    
    // Set device metadata
    unsigned long timestamp = millis() / 1000;
    FirebaseJson meta;
    meta.set("gp", 27); // GPIO pin used
    meta.set("lo", timestamp); // Last online timestamp
    meta.set("st", "DHT11"); // Sensor type
    meta.set("stu", STUDENT_NAME); // Student name
    
    path = String("/sensors/") + DEVICE_ID + "/meta";
    Firebase.RTDB.setJSON(&fbdo, path, &meta);
    
    // Additional metadata
    FirebaseJson metadata;
    metadata.set("last_online", timestamp);
    metadata.set("sensor_type", "DHT11");
    metadata.set("student", STUDENT_NAME);
    path = String("/sensors/") + DEVICE_ID + "/metadata";
    Firebase.RTDB.setJSON(&fbdo, path, &metadata);

    // Initialize current data structure
    FirebaseJson current;
    current.set("hum", 0); // Initial humidity
    current.set("temp", 0); // Initial temperature
    current.set("timestamp", timestamp);
    path = String("/sensors/") + DEVICE_ID + "/current";
    Firebase.RTDB.setJSON(&fbdo, path, &current);
  }
}

// ================= SENSOR READING =================
void readSensorData() {
  // Read temperature and humidity from DHT sensor
  float temp = dht.readTemperature();
  float hum = dht.readHumidity();
  Serial.println("Reading DHT sensor...");

  // Check if readings are valid
  if (!isnan(temp) && !isnan(hum)) {
    Serial.printf("Sensor readings - Temp: %.1f°C, Hum: %.1f%%\n", temp, hum);
    
    // Only update local values if not in manual override mode
    if (!systemState.firebaseOverride) {
      systemState.temp = temp;
      systemState.hum = hum;
    }
    
    // Send data to Firebase
    updateFirebaseData(temp, hum);
  } else {
    Serial.println("Sensor error! Failed to read DHT sensor.");
    systemState.status = "Sensor Error!";
    updateLCD();
    handleSensorError();
  }
}

// ================= LCD DISPLAY UPDATE =================
void updateLCD() {
  lcd.clear();
  
  // Line 1: Temperature and Humidity values
  lcd.setCursor(0, 0);
  lcd.print("T:");
  lcd.print(systemState.temp, 1); // Show temperature with 1 decimal
  lcd.print("C H:");
  lcd.print(systemState.hum, 1);  // Show humidity with 1 decimal
  lcd.print("%");
  
  // Line 2: System status indicators
  lcd.setCursor(0, 1);
  lcd.print("Mode:");
  lcd.print(systemState.firebaseOverride ? "Manual" : "Auto  "); // Operation mode
  lcd.print(" W:");
  lcd.print(systemState.wifiConnected ? "Y" : "N"); // WiFi status
  lcd.print(" F:");
  lcd.print(systemState.firebaseConnected ? "Y" : "N"); // Firebase status
}

// ================= LCD STATUS MESSAGE =================
void updateLCDStatus(String message) {
  lcd.setCursor(0, 0);
  lcd.print(message.substring(0, 16)); // Ensure message fits on first line
  lcd.setCursor(0, 1);
  lcd.print("                "); // Clear second line
}

// ================= FIREBASE UPDATE CHECK =================
void checkFirebaseUpdates() {
  String path = String("/sensors/") + DEVICE_ID + "/current";
  
  // Get current data from Firebase
  if (Firebase.RTDB.getJSON(&fbdo, path)) {
    FirebaseJson json;
    json = fbdo.jsonObject();
    FirebaseJsonData result;
    
    // Check for manual override flag
    if (json.get(result, "override") && result.to<bool>()) {
      startManualOverride(json);
    }
  } else {
    Serial.println("Firebase read failed: " + fbdo.errorReason());
  }
}

// ================= MANUAL OVERRIDE HANDLING =================
void startManualOverride(FirebaseJson &json) {
  FirebaseJsonData result;
  systemState.firebaseOverride = true;
  systemState.lastOverrideTime = millis();
  systemState.status = "Manual Control";
  
  // Get override values from Firebase
  if (json.get(result, "temp")) systemState.temp = result.to<float>();
  if (json.get(result, "hum")) systemState.hum = result.to<float>();
  
  Serial.println("Manual override activated");
  updateLCD();
}

void endManualOverride() {
  systemState.firebaseOverride = false;
  systemState.status = "";
  
  // Clear override flag in Firebase
  String path = String("/sensors/") + DEVICE_ID + "/current/override";
  Firebase.RTDB.setBool(&fbdo, path, false);
  
  Serial.println("Manual override ended");
}

// ================= FIREBASE DATA SYNC =================
void updateFirebaseData(float temp, float hum) {
  if (Firebase.ready()) {
    unsigned long timestamp = millis() / 1000;
    String path;
    
    // Update temperature value
    path = String("/sensors/") + DEVICE_ID + "/current/temp";
    if (!Firebase.RTDB.setFloat(&fbdo, path, temp)) {
      Serial.println("Temp update failed: " + fbdo.errorReason());
    }
    
    // Update humidity value
    path = String("/sensors/") + DEVICE_ID + "/current/hum";
    if (!Firebase.RTDB.setFloat(&fbdo, path, hum)) {
      Serial.println("Humidity update failed: " + fbdo.errorReason());
    }
    
    // Update timestamp
    path = String("/sensors/") + DEVICE_ID + "/current/timestamp";
    if (!Firebase.RTDB.setInt(&fbdo, path, timestamp)) {
      Serial.println("Timestamp update failed: " + fbdo.errorReason());
    }

    // Update last online time in metadata
    path = String("/sensors/") + DEVICE_ID + "/metadata/last_online";
    Firebase.RTDB.setInt(&fbdo, path, timestamp);
  }
}

// ================= SENSOR ERROR HANDLING =================
void handleSensorError() {
  if (Firebase.ready()) {
    // Log error to Firebase
    FirebaseJson error;
    error.set("timestamp", millis() / 1000);
    error.set("error", "Sensor read failed");
    String path = String("/sensors/") + DEVICE_ID + "/errors";
    Firebase.RTDB.pushJSON(&fbdo, path, &error);
  }
}
