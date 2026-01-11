#include <Wire.h>
#include <WiFi.h>
#include <FirebaseESP32.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

// Network Configuration
const char* ssid = "ITIDA";
const char* password = "12345678";

// Firebase Configuration
const char* dbHost = "stem-53cdc-default-rtdb.firebaseio.com";
const char* dbSecret = "UlqdAaYSCRjTcqFBRVW0df1Y513SLgoJ2vuZ2lZO";

// HC-SR04 Ultrasonic Sensor Pin Configuration
#define PIN_TRIGGER 5
#define PIN_ECHO 18

// Firebase connection objects
FirebaseData fbData;
FirebaseConfig fbConfig;
FirebaseAuth fbAuth;

// MPU6050 accelerometer/gyroscope sensor
Adafruit_MPU6050 imu;

// Data transmission timing control
unsigned long previousMillis = 0;
const unsigned long transmissionDelay = 2000; // 2-second interval

void setup() {
  Serial.begin(115200);
  
  // Configure ultrasonic sensor I/O pins
  pinMode(PIN_TRIGGER, OUTPUT);
  pinMode(PIN_ECHO, INPUT);
  
  // Establish WiFi connection
  Serial.print("Establishing WiFi connection");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connection established!");
  Serial.print("Device IP: ");
  Serial.println(WiFi.localIP());
  
  // Initialize IMU sensor
  if (!imu.begin()) {
    Serial.println("MPU6050 initialization failed");
    while (1) {
      delay(10);
    }
  }
  Serial.println("MPU6050 initialized successfully!");
  
  // Set IMU sensor parameters
  imu.setAccelerometerRange(MPU6050_RANGE_8_G);
  imu.setGyroRange(MPU6050_RANGE_500_DEG);
  imu.setFilterBandwidth(MPU6050_BAND_21_HZ);
  
  // Initialize Firebase connection
  fbConfig.host = dbHost;
  fbConfig.signer.tokens.legacy_token = dbSecret;
  
  Firebase.begin(&fbConfig, &fbAuth);
  Firebase.reconnectWiFi(true);
  
  Serial.println("Initialization complete!");
}

void loop() {
  unsigned long currentMillis = millis();
  
  // Transmit sensor data at regular intervals
  if (currentMillis - previousMillis >= transmissionDelay) {
    previousMillis = currentMillis;
    
    // Retrieve IMU sensor readings
    sensors_event_t accel, gyro, temperature;
    imu.getEvent(&accel, &gyro, &temperature);
    
    // Measure distance using ultrasonic sensor
    float distanceMeasurement = measureDistance();
    
    // Display readings on serial monitor
    Serial.println("\n----- Sensor Data -----");
    Serial.printf("Accel - X: %.2f, Y: %.2f, Z: %.2f m/s²\n", 
                  accel.acceleration.x, accel.acceleration.y, accel.acceleration.z);
    Serial.printf("Gyro - X: %.2f, Y: %.2f, Z: %.2f rad/s\n", 
                  gyro.gyro.x, gyro.gyro.y, gyro.gyro.z);
    Serial.printf("Temp: %.2f °C\n", temperature.temperature);
    Serial.printf("Distance: %.2f cm\n", distanceMeasurement);
    
    // Upload data to Firebase database
    uploadSensorData(accel, gyro, temperature, distanceMeasurement);
  }
}

float measureDistance() {
  // Reset trigger pin
  digitalWrite(PIN_TRIGGER, LOW);
  delayMicroseconds(2);
  
  // Transmit ultrasonic pulse (10μs)
  digitalWrite(PIN_TRIGGER, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TRIGGER, LOW);
  
  // Measure echo response time
  long echoTime = pulseIn(PIN_ECHO, HIGH, 30000); // 30ms maximum wait
  
  // Convert time to distance (cm)
  float distanceInCm = echoTime * 0.034 / 2;
  
  // Validate measurement (return 0 if invalid)
  if (echoTime == 0 || distanceInCm > 400) {
    return 0;
  }
  
  return distanceInCm;
}

void uploadSensorData(sensors_event_t &accel, sensors_event_t &gyro, 
                      sensors_event_t &temperature, float distance) {
  // Generate timestamp for data point
  String dataTimestamp = String(millis());
  
  // Upload accelerometer measurements
  Firebase.setFloat(fbData, "/Car1/accelerometer/x", accel.acceleration.x);
  Firebase.setFloat(fbData, "/Car1/accelerometer/y", accel.acceleration.y);
  Firebase.setFloat(fbData, "/Car1/accelerometer/z", accel.acceleration.z);
  
  // Upload gyroscope measurements
  Firebase.setFloat(fbData, "/Car1/gyroscope/x", gyro.gyro.x);
  Firebase.setFloat(fbData, "/Car1/gyroscope/y", gyro.gyro.y);
  Firebase.setFloat(fbData, "/Car1/gyroscope/z", gyro.gyro.z);
  
  // Upload temperature reading
  Firebase.setFloat(fbData, "/Car1/temperature", temperature.temperature);
  
  // Upload distance measurement
  Firebase.setFloat(fbData, "/Car1/distance", distance);
  
  // Upload timestamp
  Firebase.setString(fbData, "/Car1/lastUpdate", dataTimestamp);
  
  // Verify successful upload
  if (fbData.httpCode() == 200) {
    Serial.println("✓ Firebase upload successful!");
  } else {
    Serial.println("✗ Firebase error: " + fbData.errorReason());
  }
}
