/**
 * SUSEMON - Node Sensor v2.5
 * Hardware : LILYGO T3 V1.6.1 (ESP32-PICO-D4 + SX1276 + OLED built-in)
 * Sensor   : DHT22
 * Gateway  : Dragino LG02 (Full Gateway — ANT-1 RX, ANT-2 TX)
 *
 * Alur FULL LoRa (tanpa WiFi):
 *   Uplink  : DHT22 → LoRa TX → Dragino ANT-1 → MQTT → Backend → AI
 *   Downlink: Backend → MQTT → Dragino ANT-2 → LoRa RX → Node
 *
 * LoRa Config (sinkron dengan Dragino LG02):
 *   Freq      : 915 MHz
 *   SF        : 7
 *   BW        : 125 kHz
 *   CR        : 4/5
 *   SyncWord  : 0x12 (= 18 di UI Dragino)
 *   TxPower   : 20 dBm
 *   Preamble  : 8
 *
 * Wiring T3 V1.6.1:
 *   DHT22 DATA  -> GPIO 13
 *   LED Hijau   -> GPIO 2   (AMAN)
 *   LED Kuning  -> GPIO 4   (WASPADA)
 *   LED Merah   -> GPIO 15  (BERBAHAYA)
 *   LED Biru    -> GPIO 25  (TX LoRa aktif)
 *   Buzzer      -> GPIO 14
 *   OLED SDA    -> GPIO 21
 *   OLED SCL    -> GPIO 22
 *   LoRa RST    -> GPIO 23
 *
 * Uplink  : {"node_id":"TA11","temperature":28.5,"humidity":62.0}
 * Downlink: {"node_id":"TA11","status":"AMAN","risk":"LOW","confidence":91}
 */

#include <SPI.h>
#include <LoRa.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <DHT.h>
#include <ArduinoJson.h>

// ── Konfigurasi ───────────────────────────────────────────────────────────────
#define NODE_ID          "TA11"
#define SEND_INTERVAL    10000   // Kirim data setiap 10 detik
#define DOWNLINK_TIMEOUT 120000  // 2 menit timeout downlink
#define DHT_RETRY_MAX    3
#define FW_VERSION       "v2.5"

// ── Pin LoRa — LILYGO T3 V1.6.1 ─────────────────────────────────────────────
#define LORA_SCK   5
#define LORA_MISO  19
#define LORA_MOSI  27
#define LORA_SS    18
#define LORA_RST   23
#define LORA_DIO0  26

// ── LoRa Parameter — WAJIB sinkron dengan Dragino LG02 ───────────────────────
#define LORA_BAND      915E6   // 915 MHz
#define LORA_SF        7       // Spreading Factor 7
#define LORA_BW        125E3   // Bandwidth 125 kHz
#define LORA_CR        5       // Coding Rate 4/5
#define LORA_TXPOWER   20      // TX Power 20 dBm
#define LORA_SYNCWORD  0x12    // Sync Word 18
#define LORA_PREAMBLE  8       // Preamble length

// ── Pin DHT22 ─────────────────────────────────────────────────────────────────
#define DHT_PIN   13
#define DHT_TYPE  DHT22

// ── Pin LED & Buzzer ──────────────────────────────────────────────────────────
#define LED_HIJAU   2
#define LED_KUNING  4
#define LED_MERAH   15
#define LED_BIRU    25
#define BUZZER_PIN  14

// ── OLED ──────────────────────────────────────────────────────────────────────
#define OLED_SDA  21
#define OLED_SCL  22

DHT dht(DHT_PIN, DHT_TYPE);
Adafruit_SSD1306 display(128, 64, &Wire, -1);

float  temperature   = 0.0;
float  humidity      = 0.0;
int    txCount       = 0;
int    failCount     = 0;
bool   loraReady     = false;
String aiStatus      = "MENUNGGU";
String aiRisk        = "-";
int    aiConf        = 0;
int    lastRssi      = 0;
unsigned long lastDownlink = 0;
unsigned long lastSend     = 0;

void setup() {
  Serial.begin(115200);
  pinMode(LED_HIJAU,  OUTPUT);
  pinMode(LED_KUNING, OUTPUT);
  pinMode(LED_MERAH,  OUTPUT);
  pinMode(LED_BIRU,   OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  testLED();

  Wire.begin(OLED_SDA, OLED_SCL);
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("[OLED] Gagal");
  }
  showSplash();

  dht.begin();
  delay(2000);

  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);

  if (!LoRa.begin(LORA_BAND)) {
    showError("LoRa GAGAL");
    buzzerError();
    while (true) delay(1000);
  }

  LoRa.setSpreadingFactor(LORA_SF);
  LoRa.setSignalBandwidth(LORA_BW);
  LoRa.setCodingRate4(LORA_CR);
  LoRa.setTxPower(LORA_TXPOWER);
  LoRa.setSyncWord(LORA_SYNCWORD);
  LoRa.setPreambleLength(LORA_PREAMBLE);
  LoRa.enableCrc();

  loraReady = true;
  Serial.printf("[NODE] %s ready | LoRa %.0fMHz SF%d BW%.0fk Sync=0x%02X\n",
                NODE_ID, LORA_BAND/1E6, LORA_SF, LORA_BW/1E3, LORA_SYNCWORD);

  // TX SF7, RX SF7 — downlink dari TTGO Gateway (bukan Dragino)
  LoRa.setSpreadingFactor(7);
  LoRa.receive();
  Serial.println("[LoRa] RX mode SF7 aktif");

  buzzerBeep(1, 100);
  setLEDWaiting();
}

void loop() {
  unsigned long now = millis();

  // Cek downlink dari Dragino setiap iterasi
  int pktSize = LoRa.parsePacket();
  if (pktSize > 0) {
    Serial.printf("[RX] Paket masuk size=%d\n", pktSize);
    receiveDownlink();
    LoRa.receive();
  }

  // Kirim data setiap SEND_INTERVAL
  if (now - lastSend >= SEND_INTERVAL) {
    lastSend = now;
    if (readSensor()) {
      sendRawData();
    }
    updateDisplay();
  }

  // Timeout downlink
  if (aiStatus != "MENUNGGU" && (now - lastDownlink > DOWNLINK_TIMEOUT)) {
    Serial.println("[NODE] Downlink timeout");
    updateDisplay();
  }

  delay(5);
}

// ── Baca sensor ───────────────────────────────────────────────────────────────
bool readSensor() {
  for (int i = 0; i < DHT_RETRY_MAX; i++) {
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    if (!isnan(t) && !isnan(h)) {
      temperature = t;
      humidity    = h;
      Serial.printf("[DHT] %.2fC  %.2f%%\n", t, h);
      return true;
    }
    delay(500);
  }
  failCount++;
  Serial.println("[DHT] Gagal baca");
  return false;
}

// ── TX uplink via LoRa ────────────────────────────────────────────────────────
void sendRawData() {
  if (!loraReady) return;

  StaticJsonDocument<96> doc;
  doc["node_id"]     = NODE_ID;
  doc["temperature"] = round(temperature * 100.0) / 100.0;
  doc["humidity"]    = round(humidity    * 100.0) / 100.0;

  String payload;
  serializeJson(doc, payload);

  LoRa.idle();
  delay(10);

  // TX SF7 — uplink cepat
  LoRa.setSpreadingFactor(7);
  digitalWrite(LED_BIRU, HIGH);
  LoRa.beginPacket();
  LoRa.print(payload);
  LoRa.endPacket(true);
  delay(50);
  digitalWrite(LED_BIRU, LOW);

  // Switch ke SF7 untuk RX downlink dari TTGO Gateway
  LoRa.setSpreadingFactor(7);
  LoRa.receive();
  txCount++;
  Serial.printf("[TX] #%d %s\n", txCount, payload.c_str());
}

// ── RX downlink dari Dragino ──────────────────────────────────────────────────
void receiveDownlink() {
  String raw = "";
  while (LoRa.available()) raw += (char)LoRa.read();
  lastRssi = LoRa.packetRssi();
  raw.trim();
  Serial.printf("[RX] RSSI=%d: %s\n", lastRssi, raw.c_str());

  if (raw.length() == 0) return;

  // Decode hex jika bukan JSON langsung (format Dragino lg02_pkt_fwd)
  String jsonStr = raw;
  if (!raw.startsWith("{")) {
    String decoded = "";
    bool ok = true;
    for (int i = 0; i + 1 < (int)raw.length(); i += 2) {
      if (!isxdigit(raw[i]) || !isxdigit(raw[i+1])) { ok = false; break; }
      decoded += (char)strtol(raw.substring(i, i+2).c_str(), nullptr, 16);
    }
    if (ok && decoded.startsWith("{")) {
      jsonStr = decoded;
      Serial.printf("[RX] Decoded: %s\n", jsonStr.c_str());
    }
  }

  StaticJsonDocument<192> doc;
  if (deserializeJson(doc, jsonStr) != DeserializationError::Ok) {
    Serial.println("[RX] JSON error");
    return;
  }

  const char* targetNode = doc["node_id"];
  // Terima jika node_id cocok ATAU broadcast "ALL" dari gateway
  bool isForMe = targetNode &&
                 (String(targetNode) == NODE_ID || String(targetNode) == "ALL");
  if (!isForMe) return;

  String prev   = aiStatus;
  String rawSt  = doc["status"] | "AMAN";
  aiRisk        = doc["risk"]   | "LOW";
  aiConf        = doc["confidence"] | 0;
  lastDownlink  = millis();

  // Deteksi status khusus dari gateway
  if (rawSt == "BACKEND_OFF") {
    aiStatus = "BACKEND_OFF";
    Serial.println("[NODE] Backend offline — menunggu...");
    showSystemStatus("BACKEND", "OFFLINE");
    setLEDWaiting();
    return;
  }
  if (rawSt == "GATEWAY_OFF") {
    aiStatus = "GATEWAY_OFF";
    Serial.println("[NODE] Gateway offline — menunggu...");
    showSystemStatus("GATEWAY", "OFFLINE");
    setLEDWaiting();
    return;
  }

  // Status normal dari AI
  aiStatus = rawSt;
  Serial.printf("[AI] %s | %s | %d%% | RSSI=%d\n",
                aiStatus.c_str(), aiRisk.c_str(), aiConf, lastRssi);
  applyAIStatus(prev);
  updateDisplay();
}

// ── Apply status AI ke LED & Buzzer ──────────────────────────────────────────
void applyAIStatus(String prev) {
  digitalWrite(LED_HIJAU,  LOW);
  digitalWrite(LED_KUNING, LOW);
  digitalWrite(LED_MERAH,  LOW);

  if (aiStatus == "AMAN") {
    digitalWrite(LED_HIJAU, HIGH);
    if (prev == "WASPADA" || prev == "BERBAHAYA") buzzerBeep(1, 80);
  } else if (aiStatus == "WASPADA") {
    digitalWrite(LED_KUNING, HIGH);
    if (prev != "WASPADA") buzzerBeep(2, 150);
  } else if (aiStatus == "BERBAHAYA") {
    digitalWrite(LED_MERAH, HIGH);
    buzzerAlert();
  }
}

void setLEDWaiting() {
  digitalWrite(LED_HIJAU,  LOW);
  digitalWrite(LED_KUNING, LOW);
  digitalWrite(LED_MERAH,  LOW);
  for (int i = 0; i < 2; i++) {
    digitalWrite(LED_BIRU, HIGH); delay(100);
    digitalWrite(LED_BIRU, LOW);  delay(100);
  }
}

// ── Tampilkan status sistem (backend/gateway off) di OLED ────────────────────
void showSystemStatus(const char* system, const char* st) {
  display.clearDisplay();

  // Header tipis
  display.fillRect(0, 0, 128, 12, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(2, 2);
  display.print("SUSEMON  " NODE_ID);
  display.setTextColor(SSD1306_WHITE);

  // Icon seru besar di tengah
  display.setTextSize(3);
  display.setCursor(52, 16);
  display.print("!");
  display.setTextSize(1);

  // Pesan status
  display.setCursor(0, 42);
  display.print(system);
  display.print(" OFFLINE");

  // Tetap tampilkan sensor
  display.setCursor(0, 54);
  display.print("T:");
  display.print(String(temperature, 1));
  display.print("C  H:");
  display.print(String((int)humidity));
  display.print("%");

  display.display();
}

void updateDisplay() {
  bool isTimeout = (aiStatus != "MENUNGGU") &&
                   (millis() - lastDownlink > DOWNLINK_TIMEOUT);

  // Jika status offline khusus, pakai layar khusus
  if (aiStatus == "BACKEND_OFF") { showSystemStatus("BACKEND", ""); return; }
  if (aiStatus == "GATEWAY_OFF") { showSystemStatus("GATEWAY", ""); return; }

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  // ── Header (baris 0-11) ────────────────────────────────────────────────────
  display.fillRect(0, 0, 128, 11, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(2, 2);
  display.print("SUSEMON ");
  display.print(NODE_ID);
  // Dot blink kanan atas (indikator aktif)
  static bool blink = false; blink = !blink;
  if (blink) display.fillRect(119, 2, 7, 7, SSD1306_WHITE);
  else       display.fillRect(119, 2, 7, 7, SSD1306_BLACK);
  display.setTextColor(SSD1306_WHITE);

  // ── Suhu besar — textSize 3, setiap char = 18px lebar, 24px tinggi ────────
  // Baris Y=13, tinggi char = 24px → batas bawah Y=37
  // Format: "36.7*C" — tanda derajat pakai char khusus, C pisah kecil
  String tempStr = String(temperature, 1);  // "36.7"
  // Lebar total: jumlah char × 18px
  int tempPx = tempStr.length() * 18;       // misal "36.7" = 4 char = 72px
  int tempX  = (128 - tempPx - 18) / 2;     // sisakan 18px untuk "°C"
  if (tempX < 0) tempX = 0;

  display.setTextSize(3);
  display.setCursor(tempX, 13);
  display.print(tempStr);

  // "°C" di kanan — pakai textSize 1 agar tidak kepotong
  display.setTextSize(1);
  display.setCursor(tempX + tempPx + 2, 14);
  display.print((char)247);   // karakter ° di font Adafruit GFX
  display.setCursor(tempX + tempPx + 2, 22);
  display.print("C");

  // ── Baris tengah: Humid + TX + RSSI (Y=38) ────────────────────────────────
  display.setTextSize(1);
  display.setCursor(0, 38);
  display.print("H:");
  display.print((int)humidity);
  display.print("%");

  display.setCursor(48, 38);
  display.print("TX:");
  display.print(txCount);

  if (lastRssi != 0) {
    display.setCursor(86, 38);
    display.print(lastRssi);
    display.print("dB");
  }

  // ── Garis pemisah (Y=48) ──────────────────────────────────────────────────
  display.drawLine(0, 48, 127, 48, SSD1306_WHITE);

  // ── Status AI (Y=52) ──────────────────────────────────────────────────────
  display.setCursor(0, 52);
  if (aiStatus == "MENUNGGU") {
    display.print("Menunggu AI...");
  } else if (isTimeout) {
    display.print(aiStatus);
    display.print(" (timeout)");
  } else {
    // "AMAN 91% LOW" atau "BERBAHAYA 85% HIGH !!"
    display.print(aiStatus);
    display.print(" ");
    display.print(aiConf);
    display.print("% ");
    display.print(aiRisk);
    if (aiStatus == "BERBAHAYA") {
      display.print(" !!");
    }
  }

  display.display();
}

void showSplash() {
  display.clearDisplay();

  // Logo area — kotak rounded
  display.fillRect(0, 0, 128, 12, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(20, 2);
  display.print("SUSEMON  NODE " NODE_ID);
  display.setTextColor(SSD1306_WHITE);

  // Nama besar
  display.setTextSize(2);
  display.setCursor(8, 16);
  display.print("SUSEMON");
  display.setTextSize(1);

  // Garis tipis
  display.drawLine(8, 32, 120, 32, SSD1306_WHITE);

  // Info singkat
  display.setCursor(8, 36);
  display.print("LoRa 915MHz  SF7");
  display.setCursor(8, 46);
  display.print("SyncWord: 0x12");
  display.setCursor(8, 56);
  display.print(FW_VERSION "  PBL-TRPL412");

  display.display();
  delay(2000);
}

void showError(String msg) {
  display.clearDisplay();
  display.fillRect(0, 0, 128, 12, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(2, 2);
  display.print("ERROR  NODE " NODE_ID);
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(2);
  display.setCursor(50, 18);
  display.print("X");
  display.setTextSize(1);
  display.setCursor(4, 44);
  display.print(msg);
  display.display();
}

// ── LED & Buzzer ──────────────────────────────────────────────────────────────
void testLED() {
  int leds[] = {LED_HIJAU, LED_KUNING, LED_MERAH, LED_BIRU};
  for (int i = 0; i < 4; i++) { digitalWrite(leds[i], HIGH); delay(200); digitalWrite(leds[i], LOW); }
}

void buzzerBeep(int n, int ms) {
  for (int i = 0; i < n; i++) {
    digitalWrite(BUZZER_PIN, HIGH); delay(ms);
    digitalWrite(BUZZER_PIN, LOW);
    if (i < n-1) delay(100);
  }
}

void buzzerAlert() {
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER_PIN, HIGH); delay(300);
    digitalWrite(BUZZER_PIN, LOW);  delay(150);
  }
}

void buzzerError() {
  digitalWrite(BUZZER_PIN, HIGH); delay(1000);
  digitalWrite(BUZZER_PIN, LOW);
}
