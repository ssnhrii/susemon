/**
 * SUSEMON — LoRa Gateway
 * Hardware : LILYGO LORA32 T22_V1.1 (ESP32 + SX1276 + OLED built-in)
 * Display  : OLED SSD1306 128x64 (built-in)
 * Fungsi   : Terima data LoRa dari node → kirim ke server via MQTT (WiFi)
 *
 * Wiring T22_V1.1:
 *   OLED SDA → GPIO 4  (built-in T22_V1.1)
 *   OLED SCL → GPIO 15 (built-in T22_V1.1)
 *   LoRa RST → GPIO 14 (built-in T22_V1.1)
 *   LoRa SPI → SCK=5, MISO=19, MOSI=27, SS=18, DIO0=26
 *
 * Library (install via Library Manager):
 *   - LoRa by Sandeep Mistry
 *   - PubSubClient by Nick O'Leary
 *   - WiFiManager by tzapu
 *   - Adafruit SSD1306
 *   - Adafruit GFX Library
 *   - ArduinoJson by Benoit Blanchon
 *   - Preferences (built-in ESP32)
 */

#include <SPI.h>
#include <LoRa.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <WiFi.h>
#include <WiFiManager.h>
#include <WiFiUdp.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <time.h>

// ── Konfigurasi MQTT — lokal via WiFiManager ─────────────────────────────────
// IP server diisi via portal WiFiManager (192.168.4.1) saat pertama kali setup
#define MQTT_PORT      1883
#define MQTT_TOPIC     "sensor/data"
#define MQTT_TOPIC_AI  "sensor/ai_result"
#define MQTT_CLIENT_ID "susemon-gateway"
#define MQTT_USER      "susemon"
#define MQTT_PASS      "Susemon2026mqtt"

// ── Nama hotspot saat konfigurasi ─────────────────────────────────────────────
#define AP_NAME     "SUSEMON-Gateway"
#define AP_PASSWORD "susemon123"

// ── Penyimpanan konfigurasi di flash ──────────────────────────────────────────
Preferences prefs;
char mqttServer[40] = "";  // IP diisi via portal WiFiManager (192.168.4.1)

// ── Pin LoRa — LILYGO LORA32 T22_V1.1 (SX1276) ──────────────────────────────
// T22_V1.1: SCK=5, MISO=19, MOSI=27, SS=18, RST=14, DIO0=26
#define LORA_SCK       5
#define LORA_MISO      19
#define LORA_MOSI      27
#define LORA_SS        18
#define LORA_RST       14   // LORA32 T22_V1.1: RST = GPIO14
#define LORA_DIO0      26
#define LORA_BAND      923E6

// ── OLED — LORA32 T22_V1.1 built-in ─────────────────────────────────────────
// T22_V1.1: SDA=4, SCL=15 (berbeda dari T3 V1.6.1!)
#define OLED_SDA       4    // GPIO4  = SDA
#define OLED_SCL       15   // GPIO15 = SCL
#define SCREEN_WIDTH   128
#define SCREEN_HEIGHT  64
#define OLED_RESET     -1

// ── Objek ─────────────────────────────────────────────────────────────────────
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
WiFiClient       wifiClient;
PubSubClient     mqttClient(wifiClient);
WiFiUDP          udp;

#define UDP_BEACON_PORT  47808
#define UDP_TIMEOUT_MS   15000   // 15 detik tanpa beacon → coba reconnect

unsigned long lastBeaconMs = 0;
bool          beaconFound  = false;

// ── Variabel global ───────────────────────────────────────────────────────────
int    rxCount    = 0;
int    txCount    = 0;
int    lostCount  = 0;
String lastNodeId = "-";
float  lastTemp   = 0.0;
float  lastHum    = 0.0;
int    lastRssi   = 0;
bool   wifiOk     = false;
bool   mqttOk     = false;
unsigned long lastDisplayUpdate = 0;
unsigned long mqttFailStart     = 0;   // waktu mulai MQTT gagal
bool          mqttEverConnected = false; // pernah konek MQTT atau belum
#define MQTT_TIMEOUT_RESET  180000     // 3 menit gagal → reset WiFi

// ─────────────────────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  pinMode(38, INPUT_PULLUP); // IO38 untuk reset konfigurasi WiFi

  // OLED
  Wire.begin(OLED_SDA, OLED_SCL);
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("[OLED] Gagal inisialisasi");
  }
  showSplash();

  // Load konfigurasi MQTT dari flash
  prefs.begin("susemon", false);
  String savedMqtt = prefs.getString("mqtt_server", mqttServer);
  savedMqtt.toCharArray(mqttServer, sizeof(mqttServer));
  Serial.printf("[Config] MQTT Server: %s\n", mqttServer);

  // WiFiManager — auto-connect atau buka portal konfigurasi
  connectWiFi();

  // Sync waktu NTP (UTC+7 WIB)
  configTime(7 * 3600, 0, "pool.ntp.org", "time.nist.gov");
  showStatus("NTP sync...");
  delay(2000);

  // Mulai UDP listener untuk auto-detect IP backend
  udp.begin(UDP_BEACON_PORT);
  showStatus("Cari backend...");

  // Tunggu beacon dari backend (max 10 detik)
  unsigned long waitStart = millis();
  while (millis() - waitStart < 10000) {
    if (listenBeacon()) break;
    delay(200);
  }

  // MQTT
  connectMQTT();

  // LoRa
  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);

  if (!LoRa.begin(LORA_BAND)) {
    Serial.println("[LoRa] Gagal inisialisasi!");
    showError("LoRa GAGAL");
    while (true) { delay(1000); }
  }

  LoRa.setSpreadingFactor(7);
  LoRa.setSignalBandwidth(125E3);
  LoRa.setCodingRate4(5);
  LoRa.enableCrc();
  LoRa.receive();

  Serial.println("[Gateway] Siap menerima data LoRa");
  updateDisplay();
}

void loop() {
  // Reconnect WiFi jika putus
  if (WiFi.status() != WL_CONNECTED) {
    wifiOk = false;
    Serial.println("[WiFi] Putus, reconnect...");
    WiFi.reconnect();
    delay(5000);
    if (WiFi.status() == WL_CONNECTED) {
      wifiOk = true;
    }
  }

  // Tekan tombol IO38 selama 3 detik → reset konfigurasi WiFi
  if (digitalRead(38) == LOW) {
    delay(3000);
    if (digitalRead(38) == LOW) {
      Serial.println("[Config] Reset WiFi...");
      showStatus("Reset WiFi...");
      WiFiManager wm;
      wm.resetSettings();
      prefs.clear();
      delay(1000);
      ESP.restart();
    }
  }

  // Reconnect MQTT jika putus
  if (!mqttClient.connected()) {
    mqttOk = false;

    // Catat waktu mulai gagal
    if (mqttFailStart == 0) {
      mqttFailStart = millis();
      Serial.println("[MQTT] Mulai hitung timeout...");
    }

    // Jika sudah 3 menit tidak bisa konek MQTT → reset WiFi
    if (millis() - mqttFailStart >= MQTT_TIMEOUT_RESET) {
      Serial.println("[MQTT] Timeout 3 menit! Reset WiFi...");
      showStatus("MQTT timeout!\nReset WiFi...");
      delay(2000);
      WiFiManager wm;
      wm.resetSettings();
      prefs.clear();
      delay(500);
      ESP.restart();
    }

    // Tampilkan countdown di OLED
    unsigned long elapsed   = millis() - mqttFailStart;
    unsigned long remaining = (MQTT_TIMEOUT_RESET - elapsed) / 1000;
    Serial.printf("[MQTT] Gagal, reset dalam %lus\n", remaining);

    connectMQTT();
  } else {
    // MQTT konek — reset timer
    mqttOk           = true;
    mqttEverConnected = true;
    mqttFailStart    = 0;
  }
  mqttClient.loop();

  // Cek beacon UDP dari backend (auto-detect IP)
  if (listenBeacon()) {
    // IP backend mungkin berubah, reconnect MQTT jika perlu
    if (!mqttClient.connected()) {
      connectMQTT();
    }
  }

  // Cek paket LoRa masuk
  int packetSize = LoRa.parsePacket();
  if (packetSize > 0) {
    handleLoRaPacket(packetSize);
  }

  // Update display setiap 1 detik
  if (millis() - lastDisplayUpdate >= 1000) {
    lastDisplayUpdate = millis();
    updateDisplay();
  }
}

// ── Terima & proses paket LoRa ────────────────────────────────────────────────

void handleLoRaPacket(int packetSize) {
  String raw = "";
  while (LoRa.available()) {
    raw += (char)LoRa.read();
  }
  lastRssi = LoRa.packetRssi();
  rxCount++;

  Serial.printf("[LoRa] RX #%d RSSI=%d dBm: %s\n", rxCount, lastRssi, raw.c_str());

  // Parse JSON
  StaticJsonDocument<256> doc;
  DeserializationError err = deserializeJson(doc, raw);
  if (err) {
    Serial.printf("[JSON] Parse error: %s\n", err.c_str());
    lostCount++;
    return;
  }

  // Validasi field wajib
  if (!doc.containsKey("node_id") ||
      !doc.containsKey("temperature") ||
      !doc.containsKey("humidity")) {
    Serial.println("[JSON] Field tidak lengkap, paket diabaikan");
    lostCount++;
    return;
  }

  lastNodeId = doc["node_id"].as<String>();
  lastTemp   = doc["temperature"].as<float>();
  lastHum    = doc["humidity"].as<float>();

  // Tambahkan timestamp
  doc["timestamp"] = getISOTimestamp();

  // Kirim ke MQTT
  String payload;
  serializeJson(doc, payload);
  publishMQTT(payload);

  updateDisplay();
}

// ── Kirim downlink ke Node (hasil AI dari Backend) ────────────────────────────
// Dipanggil setelah backend memproses dan mengirim status balik via MQTT

void sendDownlink(String nodeId, String status, String risk, int confidence) {
  StaticJsonDocument<128> resp;
  resp["node_id"]    = nodeId;
  resp["status"]     = status;
  resp["risk"]       = risk;
  resp["confidence"] = confidence;

  String out;
  serializeJson(resp, out);

  // Kirim via LoRa ke node
  LoRa.beginPacket();
  LoRa.print(out);
  LoRa.endPacket();

  // Kembali ke mode receive setelah kirim downlink
  LoRa.receive();

  Serial.printf("[LoRa DL] -> %s: %s\n", nodeId.c_str(), out.c_str());
}

// ── Publish ke MQTT ───────────────────────────────────────────────────────────

void publishMQTT(const String& payload) {
  if (!mqttClient.connected()) {
    connectMQTT();
  }

  bool ok = mqttClient.publish(MQTT_TOPIC, payload.c_str(), false);
  if (ok) {
    txCount++;
    Serial.printf("[MQTT] TX #%d → '%s'\n", txCount, MQTT_TOPIC);
  } else {
    lostCount++;
    Serial.println("[MQTT] Gagal kirim!");
  }
}

// ── MQTT Callback (terima hasil AI dari Backend) ──────────────────────────────

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String msg = "";
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];

  Serial.printf("[MQTT RX] topic=%s msg=%s\n", topic, msg.c_str());

  if (String(topic) == MQTT_TOPIC_AI) {
    // Parse hasil AI dari backend
    StaticJsonDocument<128> doc;
    if (deserializeJson(doc, msg) != DeserializationError::Ok) return;

    String nodeId    = doc["node_id"].as<String>();
    String status    = doc["status"].as<String>();
    String risk      = doc["risk"].as<String>();
    int    confidence = doc["confidence"].as<int>();

    // Kirim downlink ke node via LoRa
    sendDownlink(nodeId, status, risk, confidence);
  }
}

// ── UDP Beacon — auto-detect IP backend ──────────────────────────────────────

bool listenBeacon() {
  int pktSize = udp.parsePacket();
  if (pktSize <= 0) return false;

  char buf[128] = {0};
  udp.read(buf, sizeof(buf) - 1);

  StaticJsonDocument<128> doc;
  if (deserializeJson(doc, buf) != DeserializationError::Ok) return false;
  if (!doc["susemon"].as<bool>()) return false;

  const char* ip = doc["ip"];
  if (!ip || strlen(ip) == 0) return false;

  // Cek apakah IP berubah
  if (String(ip) != String(mqttServer)) {
    strncpy(mqttServer, ip, sizeof(mqttServer));
    prefs.putString("mqtt_server", mqttServer);
    Serial.printf("[Beacon] Backend ditemukan: %s\n", mqttServer);
    // Reconnect MQTT dengan IP baru
    if (mqttClient.connected()) mqttClient.disconnect();
    mqttOk = false;
  }

  lastBeaconMs = millis();
  beaconFound  = true;
  return true;
}

// ── WiFi via WiFiManager ──────────────────────────────────────────────────────

void connectWiFi() {
  showStatus("Konfigurasi WiFi...");

  WiFiManager wm;

  // Parameter tambahan: IP MQTT Server
  WiFiManagerParameter mqttParam("mqtt", "IP Backend Server", mqttServer, 40);
  wm.addParameter(&mqttParam);

  // Callback saat konfigurasi selesai — simpan IP MQTT ke flash
  wm.setSaveParamsCallback([&]() {
    strncpy(mqttServer, mqttParam.getValue(), sizeof(mqttServer));
    prefs.putString("mqtt_server", mqttServer);
    Serial.printf("[Config] MQTT Server disimpan: %s\n", mqttServer);
  });

  // Tampilkan info di OLED
  display.clearDisplay();
  display.fillRect(0, 0, 128, 13, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(3, 3);
  display.print("SETUP  MODE");
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(2, 16);
  display.print("1. WiFi: ");
  display.println(AP_NAME);
  display.setCursor(2, 26);
  display.print("   Pass: susemon123");
  display.setCursor(2, 36);
  display.print("2. Buka: 192.168.4.1");
  display.setCursor(2, 46);
  display.print("3. Isi WiFi + IP");
  display.drawLine(0, 56, 128, 56, SSD1306_WHITE);
  display.setCursor(2, 58);
  display.print("Reset: tahan IO38");
  display.display();

  wm.setAPStaticIPConfig(IPAddress(192,168,4,1), IPAddress(192,168,4,1), IPAddress(255,255,255,0));
  wm.setConfigPortalTimeout(180); // 3 menit timeout

  // Auto-connect: jika sudah pernah konek, langsung connect
  // Jika belum/gagal, buka portal konfigurasi
  if (!wm.autoConnect(AP_NAME, AP_PASSWORD)) {
    Serial.println("[WiFi] Gagal konek, restart...");
    showError("WiFi Gagal\nRestart...");
    delay(3000);
    ESP.restart();
  }

  wifiOk = true;
  Serial.printf("[WiFi] Terhubung! IP: %s\n", WiFi.localIP().toString().c_str());

  // Update MQTT server dari parameter yang baru disimpan
  strncpy(mqttServer, mqttParam.getValue(), sizeof(mqttServer));
  if (strlen(mqttServer) > 0) {
    prefs.putString("mqtt_server", mqttServer);
  }
}

// ── MQTT ──────────────────────────────────────────────────────────────────────

void connectMQTT() {
  if (!wifiOk) return;
  showStatus("MQTT...");

  mqttClient.setServer(mqttServer, MQTT_PORT);
  mqttClient.setBufferSize(512);
  mqttClient.setCallback(mqttCallback);

  int retry = 0;
  while (!mqttClient.connected() && retry < 5) {
    Serial.printf("[MQTT] Menghubungkan ke %s:%d...\n", mqttServer, MQTT_PORT);

    bool ok = mqttClient.connect(MQTT_CLIENT_ID, MQTT_USER, MQTT_PASS);

    if (ok) {
      mqttOk = true;
      mqttClient.subscribe(MQTT_TOPIC_AI);
      Serial.println("[MQTT] Terhubung!");
      return;
    }

    Serial.printf("[MQTT] Gagal rc=%d, retry %d/5\n", mqttClient.state(), retry + 1);
    delay(2000);
    retry++;
  }
  mqttOk = false;
}

// ── OLED ──────────────────────────────────────────────────────────────────────

void updateDisplay() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  // ══ BARIS 1: Header ══
  display.fillRect(0, 0, 128, 11, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setCursor(2, 2);
  display.print("SUSEMON  GATEWAY");
  static bool blink = false; blink = !blink;
  display.fillRect(119, 2, 7, 7, blink ? SSD1306_BLACK : SSD1306_WHITE);
  display.setTextColor(SSD1306_WHITE);

  // ══ BARIS 2-6: Info ══
  display.drawLine(0, 12, 127, 12, SSD1306_WHITE);

  display.setCursor(0, 14);
  display.print("WiFi  : ");
  display.print(wifiOk ? WiFi.SSID().substring(0, 16) : "Offline");

  display.setCursor(0, 24);
  display.print("MQTT  : ");
  if (mqttOk) {
    display.print("Connected");
  } else if (mqttFailStart > 0) {
    unsigned long remaining = (MQTT_TIMEOUT_RESET - (millis() - mqttFailStart)) / 1000;
    display.print("Gagal  reset:");
    display.print(remaining);
    display.print("s");
  } else {
    display.print("Offline");
  }

  display.setCursor(0, 34);
  display.print("Server: ");
  if (strlen(mqttServer) > 0) {
    display.print(mqttServer);
    if (beaconFound) display.print(" *");
  } else {
    display.print("--");
  }

  display.drawLine(0, 43, 127, 43, SSD1306_WHITE);

  display.setCursor(0, 45);
  display.print("Node  : ");
  display.print(lastNodeId);
  display.print("  RSSI=");
  display.print(lastRssi);

  display.setCursor(0, 55);
  display.print("T:");
  display.print(String(lastTemp, 1));
  display.print("C  H:");
  display.print(String((int)lastHum));
  display.print("%  RX=");
  display.print(rxCount);

  display.display();
}

void showSplash() {
  display.clearDisplay();
  display.drawRect(0, 0, 128, 64, SSD1306_WHITE);
  display.drawRect(2, 2, 124, 60, SSD1306_WHITE);
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(14, 8);
  display.print("SUSEMON");
  display.drawLine(10, 28, 118, 28, SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(18, 33);
  display.print("LoRa  Gateway");
  display.setCursor(10, 43);
  display.print("LORA32 T22_V1.1");
  display.setCursor(22, 53);
  display.print("PBL-TRPL412 v2.0");
  display.display();
  delay(2500);
}

void showStatus(String msg) {
  display.clearDisplay();
  display.fillRect(0, 0, 128, 12, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(2, 2);
  display.print("SUSEMON GATEWAY");
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 18);
  display.print(msg);
  static int barW = 0;
  barW = (barW + 10) % 128;
  display.drawRect(0, 54, 128, 10, SSD1306_WHITE);
  display.fillRect(0, 54, barW, 10, SSD1306_WHITE);
  display.display();
}

void showError(String msg) {
  display.clearDisplay();
  display.fillRect(0, 0, 128, 12, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(2, 2);
  display.print("!! ERROR !!");
  display.setTextColor(SSD1306_WHITE);
  display.drawRect(0, 14, 128, 50, SSD1306_WHITE);
  display.setCursor(4, 20);
  display.print(msg);
  display.display();
}

// ── Timestamp ISO8601 WIB ─────────────────────────────────────────────────────

String getISOTimestamp() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return "2026-01-01T00:00:00+07:00";
  }
  char buf[30];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S+07:00", &timeinfo);
  return String(buf);
}
