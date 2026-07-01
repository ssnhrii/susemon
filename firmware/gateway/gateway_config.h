// Auto-generated oleh start_susemon.bat — DO NOT EDIT MANUAL
// Regenerate: jalankan start_susemon.bat di laptop baru
// Generated: 01/07/2026 14:03:10,09
#ifndef GATEWAY_CONFIG_H
#define GATEWAY_CONFIG_H

// WiFi — ubah sesuai jaringan lokal Anda
#define WIFI_SSID_DEFAULT    "IoT_Susemon"
#define WIFI_PASS_DEFAULT    "12345678"

// MQTT Server — HiveMQ Cloud Cluster (Secure SSL/TLS)
#define MQTT_SERVER_DEFAULT  "7df6c70556054ac4a953adf4a8e3b970.s1.eu.hivemq.cloud"
#define MQTT_PORT_DEFAULT    8883
#define MQTT_USER_DEFAULT    "susemonmqtt"
#define MQTT_PASS_DEFAULT    "ZkxJsPkXJVr86@v"

// Topics — Lintas Jaringan
#define TOPIC_UP_DEFAULT     "sensor/data"
#define TOPIC_DOWN_DEFAULT   "sensor/ai_result"

// Health check endpoint — kosong karena beda jaringan (fallback via MQTT)
#define BACKEND_HEALTH_URL   ""
#define BACKEND_IP           ""
#define BACKEND_PORT         3000

#endif // GATEWAY_CONFIG_H
