/**
 * SUSEMON - Gateway v2.0
 * Hardware : TTGO LORA32 T22_V1.1 (ESP32 + SX1276)
 * Fungsi   : LoRa <-> WiFi <-> MQTT Bridge + Backend Health Monitor
 *
 * AUTO-CONFIG IP:
 *   1. Baca dari flash (Preferences) jika sudah disimpan
 *   2. Fallback ke gateway_config.h (di-generate start_susemon.bat otomatis)
 *   3. Tahan BOOT button 3 detik -> AP mode, buka http://192.168.4.1 di browser
 *
 * INDIKATOR STATUS:
 *   LED HIJAU  (GPIO 2)  : Semua OK
 *   LED KUNING (GPIO 4)  : WiFi OK, MQTT/Backend offline
 *   LED MERAH  (GPIO 15) : WiFi terputus
 *
 * NOTIFIKASI KE NODE:
 *   Jika backend/MQTT offline -> broadcast LoRa ke semua node
 *   Node akan tampilkan "BACKEND OFF" / "GATEWAY OFF" di OLED
 */

#include <SPI.h>
#include <LoRa.h>
#include <WiFi.h>
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
#define BTN_BOOT    0

// ── LoRa Params (sinkron node_sensor.ino) ────────────────────────────────────
#define LORA_BAND      915E6
#define LORA_SF        7
#define LORA_BW        125E3
#define LORA_CR        5
#define LORA_TXPOWER   20
#define LORA_SYNCWORD  0x12
#define LORA_PREAMBLE  8

// ── Interval ──────────────────────────────────────────────────────────────────
#define HEALTH_CHECK_MS   10000
#define NOTIFY_OFFLINE_MS 30000
#define RECONNECT_MS       5000
#define MAX_BUFFER        100

// ── Runtime Config ────────────────────────────────────────────────────────────
Preferences prefs;
String cfgWifiSsid, cfgWifiPass;
String cfgMqttServer, cfgMqttUser, cfgMqttPass;
int    cfgMqttPort;
String cfgTopicUp, cfgTopicDown, cfgBackendUrl;

WiFiClient   wifiClient;
PubSubClient mqtt(wifiClient);
WebServer    webServer(80);

std::vector<String> msgBuffer;
int  upCount = 0, downCount = 0;
bool loraReady = false;
bool backendOk = false;
bool mqttOk    = false;

enum GwStatus { GW_OK, GW_MQTT_OFF, GW_BACKEND_OFF, GW_WIFI_OFF };
GwStatus gwStatus     = GW_WIFI_OFF;
GwStatus lastGwStatus = GW_OK;

unsigned long lastHealthCheck   = 0;
unsigned long lastNotifyOffline = 0;
unsigned long lastReconnect     = 0;
unsigned long btnPressTime      = 0;

// ── Load Config ───────────────────────────────────────────────────────────────
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
  digitalWrite(LED_HIJAU,  LOW);
  digitalWrite(LED_KUNING, LOW);
  digitalWrite(LED_MERAH,  LOW);
  switch (s) {
    case GW_OK:          digitalWrite(LED_HIJAU,  HIGH); break;
    case GW_MQTT_OFF:
    case GW_BACKEND_OFF: digitalWrite(LED_KUNING, HIGH); break;
    case GW_WIFI_OFF:    digitalWrite(LED_MERAH,  HIGH); break;
  }
}

void blinkLED(int pin, int n, int ms) {
  for (int i = 0; i < n; i++) {
    digitalWrite(pin, HIGH); delay(ms);
    digitalWrite(pin, LOW);  delay(ms);
  }
}

// ── Timestamp UTC ─────────────────────────────────────────────────────────────
String getTimestamp() {
  time_t now; struct tm ti;
  if (!getLocalTime(&ti)) return "";
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &ti);
  return String(buf);
}

// ── MQTT Callback ─────────────────────────────────────────────────────────────
void mqttCallback(char* topic, byte* payload, unsigned int len) {
  String msg = "";
  for (unsigned int i = 0; i < len; i++) msg += (char)payload[i];
  Serial.printf("[MQTT down] %s\n", msg.c_str());
  LoRa.idle(); delay(10);
  LoRa.beginPacket();
  LoRa.print(msg);
  LoRa.endPacket(true);
  delay(50);
  LoRa.receive();
  downCount++;
}

// ── Broadcast status ke semua node via LoRa ───────────────────────────────────
// Format sinkron dengan receiveDownlink() di node_sensor.ino
// node_id="ALL" -> node akan proses jika node_id match atau "ALL"
void broadcastStatus(const char* statusStr, const char* risk) {
  StaticJsonDocument<96> doc;
  doc["node_id"]    = "ALL";
  doc["status"]     = statusStr;
  doc["risk"]       = risk;
  doc["confidence"] = 0;
  String payload; serializeJson(doc, payload);
  LoRa.idle(); delay(10);
  LoRa.beginPacket(); LoRa.print(payload); LoRa.endPacket(true);
  delay(100); LoRa.receive();
  Serial.printf("[BCAST] %s\n", payload.c_str());
}

// ── Health Check Backend ──────────────────────────────────────────────────────
bool checkBackend() {
  if (WiFi.status() != WL_CONNECTED) return false;
  HTTPClient hc;
  hc.begin(cfgBackendUrl);
  hc.setTimeout(3000);
  int code = hc.GET();
  hc.end();
  bool ok = (code == 200);
  if (!ok) Serial.printf("[HEALTH] Backend offline (HTTP %d)\n", code);
  return ok;
}

// ── WiFi Connect ──────────────────────────────────────────────────────────────
bool connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return true;
  Serial.printf("[WiFi] Connecting to %s...", cfgWifiSsid.c_str());
  WiFi.begin(cfgWifiSsid.c_str(), cfgWifiPass.c_str());
  for (int i = 0; i < 20; i++) {
    if (WiFi.status() == WL_CONNECTED) break;
    delay(500); Serial.print(".");
    blinkLED(LED_MERAH, 1, 200);
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WiFi] OK IP=%s\n", WiFi.localIP().toString().c_str());
    configTime(0, 0, "pool.ntp.org", "time.nist.gov");
    return true;
  }
  Serial.println("\n[WiFi] GAGAL");
  return false;
}

// ── MQTT Connect ──────────────────────────────────────────────────────────────
bool connectMQTT() {
  if (mqtt.connected()) return true;
  Serial.print("[MQTT] Connecting...");
  if (mqtt.connect("ttgo-gw", cfgMqttUser.c_str(), cfgMqttPass.c_str())) {
    mqtt.subscribe(cfgTopicDown.c_str(), 1);
    mqttOk = true;
    Serial.printf("OK\n");
    return true;
  }
  mqttOk = false;
  Serial.printf("FAIL rc=%d\n", mqtt.state());
  return false;
}

// ── AP Config Mode ────────────────────────────────────────────────────────────
void startAPMode() {
  Serial.println("[AP] Mode konfigurasi aktif");
  WiFi.softAP("SUSEMON-Gateway", "susemon123");
  Serial.printf("[AP] Konek ke WiFi 'SUSEMON-Gateway', buka http://%s\n",
    WiFi.softAPIP().toString().c_str());

  String form = String(
    "<!DOCTYPE html><html><head><meta charset='UTF-8'>"
    "<meta name='viewport' content='width=device-width,initial-scale=1'>"
    "<title>SUSEMON Config</title>"
    "<style>body{font-family:sans-serif;max-width:380px;margin:20px auto;"
    "padding:0 16px;background:#0a0e1a;color:#fff}"
    "h2{color:#00b4ff;margin-bottom:20px}"
    "label{font-size:11px;color:#8899aa;display:block;margin-top:12px}"
    "input{width:100%;padding:10px;margin-top:4px;background:#1a2235;"
    "border:1px solid #1e2d45;color:#fff;border-radius:8px;box-sizing:border-box}"
    "button{width:100%;padding:14px;margin-top:20px;background:#00b4ff;"
    "color:#fff;border:none;border-radius:8px;font-size:15px;"
    "font-weight:700;cursor:pointer}"
    ".info{font-size:11px;color:#8899aa;margin-top:16px}"
    "</style></head><body>"
    "<h2>SUSEMON Gateway</h2>"
    "<form method='POST' action='/save'>"
    "<label>WiFi SSID</label>"
    "<input name='ssid' value='{SSID}'>"
    "<label>WiFi Password</label>"
    "<input name='pass' type='password' placeholder='kosong = tidak berubah'>"
    "<label>MQTT / Backend Server IP</label>"
    "<input name='mqtt_ip' value='{MQTT_IP}' placeholder='192.168.x.x'>"
    "<label>MQTT Port</label>"
    "<input name='mqtt_pt' value='{MQTT_PT}'>"
    "<label>MQTT Username</label>"
    "<input name='mqtt_u' value='{MQTT_U}'>"
    "<label>MQTT Password</label>"
    "<input name='mqtt_p' type='password' placeholder='kosong = tidak berubah'>"
    "<button type='submit'>Simpan &amp; Restart</button>"
    "</form>"
    "<p class='info'>Setelah disimpan, gateway restart otomatis.</p>"
    "</body></html>"
  );
  form.replace("{SSID}",    cfgWifiSsid);
  form.replace("{MQTT_IP}", cfgMqttServer);
  form.replace("{MQTT_PT}", String(cfgMqttPort));
  form.replace("{MQTT_U}",  cfgMqttUser);

  webServer.on("/", HTTP_GET, [form]() {
    webServer.send(200, "text/html", form);
  });
  webServer.on("/save", HTTP_POST, []() {
    String s  = webServer.arg("ssid");    if (s.isEmpty())  s  = cfgWifiSsid;
    String p  = webServer.arg("pass");    if (p.isEmpty())  p  = cfgWifiPass;
    String mi = webServer.arg("mqtt_ip"); if (mi.isEmpty()) mi = cfgMqttServer;
    int    mp = webServer.arg("mqtt_pt").toInt(); if (mp == 0) mp = cfgMqttPort;
    String mu = webServer.arg("mqtt_u");  if (mu.isEmpty()) mu = cfgMqttUser;
    String mps= webServer.arg("mqtt_p");  if (mps.isEmpty())mps= cfgMqttPass;
    saveConfig(s, p, mi, mp, mu, mps);
    webServer.send(200, "text/html",
      "<html><body style='background:#0a0e1a;color:#fff;font-family:sans-serif;"
      "text-align:center;padding:60px'><h2 style='color:#00c853'>Tersimpan!</h2>"
      "<p>Restart dalam 3 detik...</p></body></html>");
    delay(3000); ESP.restart();
  });
  webServer.begin();

  unsigned long t0 = millis();
  while (millis() - t0 < 180000) { // 3 menit timeout
    webServer.handleClient();
    blinkLED(LED_KUNING, 1, 600);
    delay(600);
  }
  ESP.restart();
}

// ── Update Status & LED ───────────────────────────────────────────────────────
void updateStatus() {
  if (WiFi.status() != WL_CONNECTED) gwStatus = GW_WIFI_OFF;
  else if (!mqtt.connected())         gwStatus = GW_MQTT_OFF;
  else if (!backendOk)                gwStatus = GW_BACKEND_OFF;
  else                                gwStatus = GW_OK;
  setLED(gwStatus);
}

// ── Setup ─────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(300);
  pinMode(LED_HIJAU,  OUTPUT); pinMode(LED_KUNING, OUTPUT);
  pinMode(LED_MERAH,  OUTPUT); pinMode(BTN_BOOT, INPUT_PULLUP);
  blinkLED(LED_HIJAU, 3, 100);

  Serial.println("=== SUSEMON Gateway v2.0 ===");

  // Tahan BOOT saat power-on -> AP mode
  if (digitalRead(BTN_BOOT) == LOW) {
    delay(100);
    unsigned long t = millis();
    while (digitalRead(BTN_BOOT) == LOW && millis()-t < 3000)
      blinkLED(LED_KUNING, 1, 200);
    if (millis()-t >= 3000) {
      loadConfig(); startAPMode(); return;
    }
  }

  loadConfig();

  // Init LoRa
  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);
  if (!LoRa.begin(LORA_BAND)) {
    Serial.println("[LoRa] GAGAL!");
    while (true) { blinkLED(LED_MERAH, 5, 100); delay(1000); }
  }
  LoRa.setSpreadingFactor(LORA_SF);
  LoRa.setSignalBandwidth(LORA_BW);
  LoRa.setCodingRate4(LORA_CR);
  LoRa.setTxPower(LORA_TXPOWER);
  LoRa.setSyncWord(LORA_SYNCWORD);
  LoRa.setPreambleLength(LORA_PREAMBLE);
  LoRa.enableCrc();
  LoRa.receive();
  loraReady = true;
  Serial.printf("[LoRa] OK %.0fMHz SF%d 0x%02X\n",
    LORA_BAND/1E6, LORA_SF, LORA_SYNCWORD);

  mqtt.setServer(cfgMqttServer.c_str(), cfgMqttPort);
  mqtt.setCallback(mqttCallback);
  mqtt.setBufferSize(512);

  if (connectWiFi()) {
    connectMQTT();
    backendOk = checkBackend();
  }
  updateStatus();
  Serial.println("[GW] Siap.");
}

// ── Loop ──────────────────────────────────────────────────────────────────────
void loop() {
  unsigned long now = millis();

  // Cek BOOT button runtime
  if (digitalRead(BTN_BOOT) == LOW) {
    if (btnPressTime == 0) btnPressTime = now;
    if (now - btnPressTime > 3000) { startAPMode(); }
  } else { btnPressTime = 0; }

  // WiFi reconnect
  if (WiFi.status() != WL_CONNECTED) {
    if (now - lastReconnect > RECONNECT_MS) {
      lastReconnect = now; connectWiFi();
    }
    updateStatus(); delay(100); return;
  }

  // MQTT reconnect
  if (!mqtt.connected()) {
    if (now - lastReconnect > RECONNECT_MS) {
      lastReconnect = now; connectMQTT();
    }
  }
  mqtt.loop();

  // Health check
  if (now - lastHealthCheck > HEALTH_CHECK_MS) {
    lastHealthCheck = now;
    bool prev = backendOk;
    backendOk = checkBackend();
    if (backendOk != prev)
      Serial.printf("[STATUS] Backend: %s\n", backendOk?"ONLINE":"OFFLINE");
    updateStatus();
  }

  // Broadcast offline ke node
  if (gwStatus != GW_OK && loraReady &&
      now - lastNotifyOffline > NOTIFY_OFFLINE_MS) {
    lastNotifyOffline = now;
    if      (gwStatus == GW_BACKEND_OFF) broadcastStatus("BACKEND_OFF", "LOW");
    else if (gwStatus == GW_MQTT_OFF)    broadcastStatus("GATEWAY_OFF", "LOW");
  }

  // Terima uplink LoRa
  int pktSize = LoRa.parsePacket();
  if (pktSize > 0) {
    String raw = "";
    while (LoRa.available()) raw += (char)LoRa.read();
    int rssi = LoRa.packetRssi();
    raw.trim();
    Serial.printf("[LoRa up] RSSI=%d: %s\n", rssi, raw.c_str());

    StaticJsonDocument<256> doc;
    if (deserializeJson(doc, raw) == DeserializationError::Ok
        && doc.containsKey("node_id")) {
      doc["rssi"] = rssi;
      String ts = getTimestamp();
      if (ts.length() > 0) doc["timestamp"] = ts;
      String payload; serializeJson(doc, payload);
      if ((int)msgBuffer.size() >= MAX_BUFFER)
        msgBuffer.erase(msgBuffer.begin());
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
      } else { break; }
      delay(50);
    }
  }

  delay(5);
}
