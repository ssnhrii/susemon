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
    connectMQTT();
  }
  mqttClient.loop();

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

// Helper: gambar ikon sinyal WiFi (3 bar)
void drawWifiIcon(int x, int y, bool ok) {
  if (ok) {
    display.drawCircle(x+4, y+7, 7, SSD1306_WHITE);
    display.drawCircle(x+4, y+7, 4, SSD1306_WHITE);
    display.fillCircle(x+4, y+7, 1, SSD1306_WHITE);
    // Hapus bagian bawah lingkaran agar terlihat seperti ikon WiFi
    display.fillRect(x, y+7, 9, 4, SSD1306_BLACK);
  } else {
    // X untuk tidak terhubung
    display.drawLine(x, y, x+6, y+6, SSD1306_WHITE);
    display.drawLine(x+6, y, x, y+6, SSD1306_WHITE);
  }
}

// Helper: gambar ikon MQTT (titik + gelombang)
void drawMqttIcon(int x, int y, bool ok) {
  if (ok) {
    display.fillCircle(x+3, y+5, 2, SSD1306_WHITE);
    display.drawLine(x+5, y+3, x+8, y+1, SSD1306_WHITE);
    display.drawLine(x+5, y+5, x+9, y+5, SSD1306_WHITE);
    display.drawLine(x+5, y+7, x+8, y+9, SSD1306_WHITE);
  } else {
    display.drawLine(x, y+2, x+8, y+8, SSD1306_WHITE);
    display.drawLine(x+8, y+2, x, y+8, SSD1306_WHITE);
  }
}

void updateDisplay() {
  display.clearDisplay();

  // ── Header bar ──
  display.fillRect(0, 0, 128, 13, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(3, 3);
  display.print("SUSEMON");
  display.setCursor(55, 3);
  display.print("GATEWAY");
  // Indikator live (titik kecil berkedip)
  static bool blink = false;
  blink = !blink;
  if (blink) display.fillCircle(122, 6, 3, SSD1306_BLACK);
  else       display.drawCircle(122, 6, 3, SSD1306_BLACK);
  display.setTextColor(SSD1306_WHITE);

  // ── Status WiFi & MQTT ──
  display.setCursor(2, 16);
  display.print("WiFi");
  display.setCursor(2, 25);
  if (wifiOk) {
    display.print(WiFi.SSID().substring(0, 10));
  } else {
    display.print("--");
  }

  // Separator vertikal
  display.drawLine(63, 14, 63, 36, SSD1306_WHITE);

  display.setCursor(67, 16);
  display.print("MQTT");
  display.setCursor(67, 25);
  display.print(mqttOk ? "Connected" : "Offline");

  // Status dot
  display.fillCircle(58, 19, 3, wifiOk  ? SSD1306_WHITE : SSD1306_BLACK);
  if (!wifiOk) display.drawCircle(58, 19, 3, SSD1306_WHITE);
  display.fillCircle(122, 19, 3, mqttOk ? SSD1306_WHITE : SSD1306_BLACK);
  if (!mqttOk) display.drawCircle(122, 19, 3, SSD1306_WHITE);

  // ── Divider ──
  display.drawLine(0, 37, 127, 37, SSD1306_WHITE);

  // ── Data sensor terakhir ──
  display.setCursor(2, 40);
  display.print("Node:");
  display.print(lastNodeId);

  display.setCursor(2, 50);
  display.setTextSize(1);
  // Suhu besar
  display.setTextSize(1);
  display.print("T:");
  display.setTextSize(2);
  display.setCursor(14, 47);
  display.printf("%.1f", lastTemp);
  display.setTextSize(1);
  display.setCursor(50, 47);
  display.print("C");

  // Kelembapan
  display.setCursor(65, 47);
  display.print("H:");
  display.setCursor(77, 47);
  display.setTextSize(2);
  display.printf("%.0f", lastHum);
  display.setTextSize(1);
  display.setCursor(113, 47);
  display.print("%");

  // ── Footer: statistik ──
  display.drawLine(0, 58, 127, 58, SSD1306_WHITE);
  display.setCursor(0, 60);
  display.printf("RX:%d TX:%d Lost:%d RSSI:%d", rxCount, txCount, lostCount, lastRssi);

  display.display();
}

void showSplash() {
  display.clearDisplay();

  // Border luar
  display.drawRect(0, 0, 128, 64, SSD1306_WHITE);
  display.drawRect(2, 2, 124, 60, SSD1306_WHITE);

  // Judul besar
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(14, 8);
  display.println("SUSEMON");

  // Garis tengah
  display.drawLine(10, 28, 118, 28, SSD1306_WHITE);

  display.setTextSize(1);
  display.setCursor(18, 33);
  display.println("LoRa  Gateway");
  display.setCursor(10, 45);
  display.println("PBL-TRPL412  v2.0");
  display.setCursor(22, 55);
  display.println("Inisialisasi...");

  display.display();
  delay(2500);
}

void showStatus(String msg) {
  display.clearDisplay();

  // Header
  display.fillRect(0, 0, 128, 13, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(3, 3);
  display.print("SUSEMON GATEWAY");
  display.setTextColor(SSD1306_WHITE);

  // Loading bar animasi
  static int barW = 0;
  barW = (barW + 8) % 128;
  display.drawRect(0, 50, 128, 8, SSD1306_WHITE);
  display.fillRect(0, 50, barW, 8, SSD1306_WHITE);

  display.setCursor(4, 20);
  display.println(msg);

  display.display();
}

void showError(String msg) {
  display.clearDisplay();

  // Header merah (inverted)
  display.fillRect(0, 0, 128, 13, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(3, 3);
  display.print("!! ERROR !!");
  display.setTextColor(SSD1306_WHITE);

  // Border
  display.drawRect(0, 15, 128, 49, SSD1306_WHITE);

  display.setCursor(4, 22);
  display.println(msg);

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
