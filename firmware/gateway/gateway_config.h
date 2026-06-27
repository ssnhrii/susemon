// Auto-generated oleh start_susemon.bat — DO NOT EDIT MANUAL
// Regenerate: jalankan start_susemon.bat di laptop baru
// IP Ethernet: 10.130.1.206
#ifndef GATEWAY_CONFIG_H
#define GATEWAY_CONFIG_H

#define WIFI_SSID_DEFAULT    "IoT_Susemon"
#define WIFI_PASS_DEFAULT    "12345678"

#define MQTT_SERVER_DEFAULT  "10.130.1.206"
#define MQTT_PORT_DEFAULT    1883
#define MQTT_USER_DEFAULT    "susemon"
#define MQTT_PASS_DEFAULT    "susemon123"

#define TOPIC_UP_DEFAULT     "sensor/data"
#define TOPIC_DOWN_DEFAULT   "sensor/ai_result"

#define BACKEND_HEALTH_URL   "http://10.130.1.206:3000/api/health"
#define BACKEND_IP           "10.130.1.206"
#define BACKEND_PORT         3000

#endif // GATEWAY_CONFIG_H
