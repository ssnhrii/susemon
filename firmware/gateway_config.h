// Auto-generated oleh start_susemon.bat — DO NOT EDIT MANUAL
// Jalankan start_susemon.bat di laptop baru untuk update IP otomatis
#ifndef GATEWAY_CONFIG_H
#define GATEWAY_CONFIG_H

// WiFi — ubah sesuai jaringan Anda
#define WIFI_SSID_DEFAULT    "IoT_Susemon"
#define WIFI_PASS_DEFAULT    "12345678"

// MQTT Server — akan di-overwrite start_susemon.bat dengan IP laptop
#define MQTT_SERVER_DEFAULT  "127.0.0.1"
#define MQTT_PORT_DEFAULT    1883
#define MQTT_USER_DEFAULT    "susemon"
#define MQTT_PASS_DEFAULT    "Susemon2026mqtt"

// Topics
#define TOPIC_UP_DEFAULT     "sensor/data"
#define TOPIC_DOWN_DEFAULT   "sensor/ai_result"

// Backend health check
#define BACKEND_HEALTH_URL   "http://127.0.0.1:3000/api/health"
#define BACKEND_IP           "127.0.0.1"
#define BACKEND_PORT         3000

#endif // GATEWAY_CONFIG_H
