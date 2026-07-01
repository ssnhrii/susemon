/**
 * SUSEMON - Gateway v2.0
 * Hardware : TTGO LORA32 T22_V1.1 (ESP32 + SX1276)
 * Fungsi   : LoRa <-> WiFi <-> MQTT Bridge + Backend Health Monitor
 *
 * AUTO-CONFIG IP:
 *   1. Baca dari flash (Preferences) jika sudah disimpan
 *   2. Fallback ke gateway_config.h (di-generate start_susemon.bat otomatis)
 *   3. Tahan BOOT button 3 detik -> AP mode, buka http://192.168.4.1
 *
 * INDIKATOR STATUS LED:
 *   HIJAU  (GPIO 2)  : Semua OK (WiFi + MQTT + Backend)
 *   KUNING (GPIO 4)  : WiFi OK tapi MQTT/Backend offline
 *   MERAH  (GPIO 15) : WiFi terputus
 */

#include <SPI.h>
#include <LoRa.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <WebServer.h>
#include <time.h>
#include <vector>

#include "gateway_config.h"

// ── Pin ───────────────────────────────────────────────────────────────────────
#define LORA_SCK   5
#define LORA_MISO  19
#define LORA_MOSI  27
#define LORA_SS    18
#define LORA_RST   14
#define LORA_DIO0  26
#define LED_HIJAU   2
#define LED_KUNING  4
#define LED_MERAH   15
#define BTN_BOOT    38

// ── LoRa (sinkron dengan node_sensor.ino) ────────────────────────────────────
#define LORA_BAND      915E6
#define LORA_SF        7
#define LORA_BW        125E3
#define LORA_CR        5
#define LORA_TXPOWER   20
#define LORA_SYNCWORD  0x12
#define LORA_PREAMBLE  8

// ── Interval ──────────────────────────────────────────────────────────────────
#define HEALTH_CHECK_MS    10000
#define NOTIFY_OFFLINE_MS  30000
#define RECONNECT_MS        5000
#define MAX_BUFFER          100

// ── Config ────────────────────────────────────────────────────────────────────
Preferences prefs;
String cfgWifiSsid, cfgWifiPass;
String cfgMqttServer, cfgMqttUser, cfgMqttPass;
int    cfgMqttPort;
String cfgTopicUp, cfgTopicDown, cfgBackendUrl;

WiFiClient       wifiClient;
WiFiClientSecure wifiClientSecure;
PubSubClient     mqtt;
WebServer    webServer(80);
std::vector<String> msgBuffer;

int  upCount = 0, downCount = 0;
bool loraReady = false, backendOk = false;

enum GwStatus { GW_OK, GW_MQTT_OFF, GW_BACKEND_OFF, GW_WIFI_OFF };
GwStatus gwStatus = GW_WIFI_OFF, lastGwStatus = GW_OK;

unsigned long lastHealthCheck = 0, lastNotifyOffline = 0;
unsigned long lastReconnect = 0, btnPressTime = 0;
unsigned long lastMqttMsgTime = 0;
unsigned long lastNtpSync = 0;
#define NTP_RESYNC_MS  3600000  // Re-sync NTP setiap 1 jam

// ── Load config dari flash, fallback ke gateway_config.h ─────────────────────
void loadConfig() {
  prefs.begin("gw", false);
  cfgWifiSsid   = prefs.getString("ssid",    WIFI_SSID_DEFAULT);
  cfgWifiPass   = prefs.getString("pass",    WIFI_PASS_DEFAULT);
  cfgMqttServer = prefs.getString("mqtt_ip", MQTT_SERVER_DEFAULT);
  cfgMqttPort   = prefs.getInt   ("mqtt_pt", MQTT_PORT_DEFAULT);
  cfgMqttUser   = prefs.getString("mqtt_u",  MQTT_USER_DEFAULT);
  cfgMqttPass   = prefs.getString("mqtt_p",  MQTT_PASS_DEFAULT);
  cfgTopicUp    = prefs.getString("t_up",    TOPIC_UP_DEFAULT);
  cfgTopicDown  = prefs.getString("t_dn",    TOPIC_DOWN_DEFAULT);
  cfgBackendUrl = prefs.getString("bk_url",  BACKEND_HEALTH_URL);
  prefs.end();
  Serial.printf("[CFG] WiFi=%s MQTT=%s:%d\n",
    cfgWifiSsid.c_str(), cfgMqttServer.c_str(), cfgMqttPort);
}

void saveConfig(String ssid, String pass, String mqttSrv, int mqttPrt,
                String mqttUsr, String mqttPss) {
  prefs.begin("gw", false);
  prefs.putString("ssid",    ssid);
  prefs.putString("pass",    pass);
  prefs.putString("mqtt_ip", mqttSrv);
  prefs.putInt   ("mqtt_pt", mqttPrt);
  prefs.putString("mqtt_u",  mqttUsr);
  prefs.putString("mqtt_p",  mqttPss);
  prefs.putString("bk_url",  "http://" + mqttSrv + ":3000/api/health");
  prefs.end();
  Serial.println("[CFG] Disimpan ke flash.");
}

// ── LED ───────────────────────────────────────────────────────────────────────
void setLED(GwStatus s) {
  if (s == lastGwStatus) return;
  lastGwStatus = s;
  digitalWrite(LED_HIJAU, LOW); digitalWrite(LED_KUNING, LOW); digitalWrite(LED_MERAH, LOW);
  switch (s) {
    case GW_OK:          digitalWrite(LED_HIJAU,  HIGH); break;
    case GW_MQTT_OFF:
    case GW_BACKEND_OFF: digitalWrite(LED_KUNING, HIGH); break;
    case GW_WIFI_OFF:    digitalWrite(LED_MERAH,  HIGH); break;
  }
}

void blinkLED(int pin, int n, int ms) {
  for (int i = 0; i < n; i++) {
    digitalWrite(pin, HIGH); delay(ms); digitalWrite(pin, LOW); delay(ms);
  }
}

// ── Timestamp UTC+7 (WIB) ────────────────────────────────────────────────────
String getTimestamp() {
  struct tm ti;
  if (!getLocalTime(&ti)) return "";
  char buf[32]; strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S+07:00", &ti);
  return String(buf);
}

// ── MQTT callback — downlink dari backend ke node ────────────────────────────
void mqttCallback(char* topic, byte* payload, unsigned int len) {
  String msg = "";
  for (unsigned int i = 0; i < len; i++) msg += (char)payload[i];
  Serial.printf("[MQTT down] %s\n", msg.c_str());
  
  // Update status keaktifan backend via MQTT
  lastMqttMsgTime = millis();
  if (!backendOk) {
    backendOk = true;
    updateStatus();
    Serial.println("[STATUS] Backend: ONLINE (via MQTT Downlink)");
  }

  LoRa.idle(); delay(10);
  LoRa.beginPacket(); LoRa.print(msg); LoRa.endPacket(true);
  delay(50); LoRa.receive();
  downCount++;
}

// ── Broadcast status ke semua node via LoRa ───────────────────────────────────
void broadcastStatus(const char* statusStr, const char* risk) {
  StaticJsonDocument<96> doc;
  doc["node_id"] = "ALL"; doc["status"] = statusStr;
  doc["risk"] = risk;     doc["confidence"] = 0;
  String payload; serializeJson(doc, payload);
  LoRa.idle(); delay(10);
  LoRa.beginPacket(); LoRa.print(payload); LoRa.endPacket(true);
  delay(100); LoRa.receive();
  Serial.printf("[BCAST] %s\n", payload.c_str());
}

// ── Health check ──────────────────────────────────────────────────────────────
bool checkBackend() {
  if (WiFi.status() != WL_CONNECTED) return false;

  // Jika BACKEND_HEALTH_URL kosong (beda jaringan), skip HTTP check
  if (cfgBackendUrl.length() > 0) {
    HTTPClient hc; hc.begin(cfgBackendUrl); hc.setTimeout(2000);
    int code = hc.GET(); hc.end();
    if (code == 200) return true;
    Serial.printf("[HEALTH] Backend HTTP %d\n", code);
  }

  // Fallback: backend dianggap online jika ada MQTT downlink dalam 45 detik terakhir
  if (lastMqttMsgTime > 0 && (millis() - lastMqttMsgTime < 45000)) {
    return true;
  }

  // Jika MQTT terhubung ke HiveMQ dan tidak ada URL lokal, anggap backend online
  // selama MQTT broker sendiri terhubung (backend pakai broker yang sama)
  if (mqtt.connected() && cfgBackendUrl.length() == 0) {
    return true;
  }

  return false;
}

// ── WiFi connect ──────────────────────────────────────────────────────────────
bool connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return true;
  Serial.printf("[WiFi] Connecting to %s...", cfgWifiSsid.c_str());
  WiFi.begin(cfgWifiSsid.c_str(), cfgWifiPass.c_str());
  for (int i = 0; i < 20; i++) {
    if (WiFi.status() == WL_CONNECTED) break;
    delay(500); Serial.print("."); blinkLED(LED_MERAH, 1, 200);
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WiFi] OK IP=%s\n", WiFi.localIP().toString().c_str());
    configTime(7 * 3600, 0, "pool.ntp.org", "time.nist.gov"); // WIB UTC+7
    lastNtpSync = millis();
    // Tunggu NTP sync
    struct tm ti; int retry = 0;
    while (!getLocalTime(&ti) && retry++ < 10) delay(500);
    if (getLocalTime(&ti)) {
      char buf[32]; strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &ti);
      Serial.printf("[NTP] Sync OK: %s WIB\n", buf);
    }
    return true;
  }
  Serial.println("\n[WiFi] GAGAL"); return false;
}

// ── MQTT connect ──────────────────────────────────────────────────────────────
bool connectMQTT() {
  if (mqtt.connected()) return true;
  Serial.print("[MQTT] Connecting...");
  if (mqtt.connect("ttgo-gw", cfgMqttUser.c_str(), cfgMqttPass.c_str())) {
    mqtt.subscribe(cfgTopicDown.c_str(), 1);
    Serial.println("OK");  return true;
  }
  Serial.printf("FAIL rc=%d\n", mqtt.state()); return false;
}

// ── AP Config Mode (tahan BOOT 3 detik) ───────────────────────────────────────
void startAPMode() {
  Serial.println("[AP] Mode konfigurasi aktif");
  WiFi.softAP("Susemon_Gateway-Lora", "susemon123");
  Serial.printf("[AP] Buka http://%s\n", WiFi.softAPIP().toString().c_str());

  String form =
    "<!DOCTYPE html><html><head><meta charset='UTF-8'>"
    "<meta name='viewport' content='width=device-width,initial-scale=1'>"
    "<style>body{font-family:sans-serif;max-width:380px;margin:20px auto;padding:0 16px;background:#0a0e1a;color:#fff}"
    "h2{color:#00b4ff}label{font-size:11px;color:#8899aa;display:block;margin-top:12px}"
    "input{width:100%;padding:10px;margin-top:4px;background:#1a2235;border:1px solid #1e2d45;color:#fff;border-radius:8px;box-sizing:border-box}"
    "button{width:100%;padding:14px;margin-top:20px;background:#00b4ff;color:#fff;border:none;border-radius:8px;font-size:15px;font-weight:700;cursor:pointer}"
    "</style></head><body><h2>SUSEMON Gateway Config</h2>"
    "<form method='POST' action='/save'>"
    "<label>WiFi SSID</label><input name='ssid' value='{SSID}'>"
    "<label>WiFi Password</label><input name='pass' type='password' placeholder='kosong = tidak berubah'>"
    "<button type='submit'>Simpan &amp; Restart</button>"
    "</form></body></html>";
  form.replace("{SSID}", cfgWifiSsid);

  webServer.on("/", HTTP_GET, [form]() { webServer.send(200, "text/html", form); });
  webServer.on("/save", HTTP_POST, []() {
    String s  = webServer.arg("ssid"); if (s.isEmpty()) s = cfgWifiSsid;
    String p  = webServer.arg("pass"); if (p.isEmpty()) p = cfgWifiPass;
    saveConfig(s, p, cfgMqttServer, cfgMqttPort, cfgMqttUser, cfgMqttPass);
    webServer.send(200,"text/html","<html><body style='background:#0a0e1a;color:#fff;text-align:center;padding:60px'>"
      "<h2 style='color:#00c853'>Tersimpan!</h2><p>Restart dalam 3 detik...</p></body></html>");
    delay(3000); ESP.restart();
  });
  webServer.begin();

  unsigned long t0 = millis();
  while (millis() - t0 < 180000) {
    webServer.handleClient(); blinkLED(LED_KUNING, 1, 600); delay(600);
  }
  ESP.restart();
}

// ── Update status & LED ───────────────────────────────────────────────────────
void updateStatus() {
  if      (WiFi.status() != WL_CONNECTED) gwStatus = GW_WIFI_OFF;
  else if (!mqtt.connected())              gwStatus = GW_MQTT_OFF;
  else if (!backendOk)                     gwStatus = GW_BACKEND_OFF;
  else                                     gwStatus = GW_OK;
  setLED(gwStatus);
}

// ── Setup ─────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200); delay(300);
  pinMode(LED_HIJAU, OUTPUT); pinMode(LED_KUNING, OUTPUT);
  pinMode(LED_MERAH, OUTPUT); pinMode(BTN_BOOT, INPUT_PULLUP);
  blinkLED(LED_HIJAU, 3, 100);
  Serial.println("=== SUSEMON Gateway v2.0 ===");

  // Tahan BOOT saat power-on:
  // - >= 3 detik -> AP Mode (untuk setting custom WiFi & IP)
  // - >= 6 detik -> Reset preferences/flash config agar kembali ke gateway_config.h
  if (digitalRead(BTN_BOOT) == LOW) {
    delay(100); unsigned long t = millis();
    while (digitalRead(BTN_BOOT) == LOW) {
      unsigned long duration = millis() - t;
      if (duration < 3000) {
        blinkLED(LED_KUNING, 1, 150);
      } else if (duration < 6000) {
        blinkLED(LED_HIJAU, 1, 100);
      } else {
        blinkLED(LED_MERAH, 1, 50);
      }
    }
    unsigned long duration = millis() - t;
    if (duration >= 6000) {
      Serial.println("[CFG] Menghapus data flash preferences...");
      prefs.begin("gw", false);
      prefs.clear();
      prefs.end();
      Serial.println("[CFG] Reset berhasil! Menggunakan fallback gateway_config.h...");
      blinkLED(LED_MERAH, 5, 100);
      ESP.restart();
    } else if (duration >= 3000) {
      loadConfig();
      startAPMode();
      return;
    }
  }

  loadConfig();

  // Init LoRa
  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);
  if (!LoRa.begin(LORA_BAND)) {
    Serial.println("[LoRa] GAGAL!"); while (true) { blinkLED(LED_MERAH, 5, 100); delay(1000); }
  }
  LoRa.setSpreadingFactor(LORA_SF); LoRa.setSignalBandwidth(LORA_BW);
  LoRa.setCodingRate4(LORA_CR);     LoRa.setTxPower(LORA_TXPOWER);
  LoRa.setSyncWord(LORA_SYNCWORD);  LoRa.setPreambleLength(LORA_PREAMBLE);
  LoRa.enableCrc(); LoRa.receive();
  loraReady = true;
  Serial.printf("[LoRa] OK %.0fMHz SF%d 0x%02X\n", LORA_BAND/1E6, LORA_SF, LORA_SYNCWORD);

  // Deteksi dan konfigurasikan SSL/TLS jika menggunakan port secure (8883) atau domain HiveMQ Cloud
  if (cfgMqttPort == 8883 || cfgMqttServer.endsWith(".hivemq.cloud")) {
    wifiClientSecure.setInsecure(); // Mengabaikan verifikasi sertifikat root untuk memudahkan koneksi SSL
    mqtt.setClient(wifiClientSecure);
    Serial.println("[MQTT] Menggunakan Koneksi Aman (SSL/TLS - Port 8883)");
  } else {
    mqtt.setClient(wifiClient);
    Serial.println("[MQTT] Menggunakan Koneksi Standar (TCP - Port 1883)");
  }

  mqtt.setServer(cfgMqttServer.c_str(), cfgMqttPort);
  mqtt.setCallback(mqttCallback);
  mqtt.setBufferSize(512);

  if (connectWiFi()) { 
    connectMQTT(); 
    backendOk = checkBackend(); 
  } else {
    Serial.println("[WiFi] Gagal terhubung ke WiFi. Masuk ke AP Mode otomatis...");
    startAPMode();
  }
  updateStatus();
  Serial.println("[GW] Siap.");
}

// ── Loop ──────────────────────────────────────────────────────────────────────
void loop() {
  unsigned long now = millis();

  // BOOT button -> AP mode
  if (digitalRead(BTN_BOOT) == LOW) {
    if (btnPressTime == 0) btnPressTime = now;
    if (now - btnPressTime > 3000) startAPMode();
  } else { btnPressTime = 0; }

  // WiFi reconnect
  if (WiFi.status() != WL_CONNECTED) {
    if (now - lastReconnect > RECONNECT_MS) { lastReconnect = now; connectWiFi(); }
    updateStatus(); delay(100); return;
  }

  // MQTT reconnect
  if (!mqtt.connected()) {
    if (now - lastReconnect > RECONNECT_MS) { lastReconnect = now; connectMQTT(); }
  }
  mqtt.loop();

  // NTP re-sync setiap 1 jam
  if (WiFi.status() == WL_CONNECTED && now - lastNtpSync > NTP_RESYNC_MS) {
    lastNtpSync = now;
    configTime(7 * 3600, 0, "pool.ntp.org", "time.nist.gov");
    Serial.println("[NTP] Re-sync...");
  }

  // Health check backend
  if (now - lastHealthCheck > HEALTH_CHECK_MS) {
    lastHealthCheck = now;
    bool prev = backendOk; backendOk = checkBackend();
    if (backendOk != prev) Serial.printf("[STATUS] Backend: %s\n", backendOk?"ONLINE":"OFFLINE");
    updateStatus();
  }

  // Broadcast offline ke node
  if (gwStatus != GW_OK && loraReady && now - lastNotifyOffline > NOTIFY_OFFLINE_MS) {
    lastNotifyOffline = now;
    if      (gwStatus == GW_BACKEND_OFF) broadcastStatus("BACKEND_OFF", "LOW");
    else if (gwStatus == GW_MQTT_OFF)    broadcastStatus("GATEWAY_OFF", "LOW");
  }

  // Terima uplink LoRa dari node
  int pktSize = LoRa.parsePacket();
  if (pktSize > 0) {
    String raw = "";
    while (LoRa.available()) raw += (char)LoRa.read();
    int rssi = LoRa.packetRssi(); raw.trim();
    Serial.printf("[LoRa up] RSSI=%d: %s\n", rssi, raw.c_str());
    StaticJsonDocument<256> doc;
    if (deserializeJson(doc, raw) == DeserializationError::Ok && doc.containsKey("node_id")) {
      doc["rssi"] = rssi;
      String ts = getTimestamp(); if (ts.length() > 0) doc["timestamp"] = ts;
      String payload; serializeJson(doc, payload);
      if ((int)msgBuffer.size() >= MAX_BUFFER) msgBuffer.erase(msgBuffer.begin());
      msgBuffer.push_back(payload);
    }
    LoRa.receive();
  }

  // Kirim buffer ke MQTT
  if (mqtt.connected() && !msgBuffer.empty()) {
    while (!msgBuffer.empty() && mqtt.connected()) {
      if (mqtt.publish(cfgTopicUp.c_str(), msgBuffer.front().c_str())) {
        Serial.printf("[MQTT up] #%d %s\n", ++upCount, msgBuffer.front().c_str());
        msgBuffer.erase(msgBuffer.begin());
      } else break;
      delay(50);
    }
  }

  delay(5);
}
