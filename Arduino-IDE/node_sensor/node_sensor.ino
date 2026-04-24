/**
 * SUSEMON - Node Sensor v2.0
 * Hardware : LILYGO T3 V1.6.1 (ESP32-PICO-D4 + SX1276 + OLED built-in)
 * Sensor   : DHT22
 * Kirim data MENTAH, terima status AI via downlink
 *
 * Wiring T3 V1.6.1:
 *   DHT22 DATA  -> GPIO 13
 *   LED Hijau   -> GPIO 2   (AMAN dari AI)
 *   LED Kuning  -> GPIO 4   (WASPADA dari AI)
 *   LED Merah   -> GPIO 15  (BERBAHAYA dari AI)
 *   LED Biru    -> GPIO 25  (TX LoRa aktif)
 *   Buzzer      -> GPIO 14
 *   OLED SDA    -> GPIO 21  (built-in)
 *   OLED SCL    -> GPIO 22  (built-in)
 *   LoRa RST    -> GPIO 23  (built-in)
 *
 * Uplink  : {"node_id":"A1","temperature":28.5,"humidity":62.0}
 * Downlink: {"node_id":"A1","status":"AMAN","risk":"LOW","confidence":91}
 */

#include <SPI.h>
#include <LoRa.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <DHT.h>
#include <ArduinoJson.h>

// ── Konfigurasi ───────────────────────────────────────────────────────────────
#define NODE_ID          "A1"
#define SEND_INTERVAL    5000    // Kirim data setiap 5 detik
#define DOWNLINK_TIMEOUT 60000   // 60 detik — toleransi jika backend lambat
#define DHT_RETRY_MAX    3

// ── Pin LoRa — LILYGO T3 V1.6.1 (SX1276) ────────────────────────────────────
// Datasheet T3 V1.6.1: IO23=RST, IO18=SS, IO5=SCK, IO27=MOSI, IO19=MISO, IO26=DIO0
#define LORA_SCK   5
#define LORA_MISO  19
#define LORA_MOSI  27
#define LORA_SS    18
#define LORA_RST   23
#define LORA_DIO0  26
#define LORA_BAND  923E6

// ── Pin DHT22 — T3 V1.6.1 ────────────────────────────────────────────────────
// GPIO13 aman (tidak konflik LoRa/OLED/Flash)
#define DHT_PIN   13
#define DHT_TYPE  DHT22

// ── Pin LED & Buzzer — T3 V1.6.1 ─────────────────────────────────────────────
// HINDARI: GPIO12 (boot strapping), GPIO34/35/36/39 (input only)
#define LED_HIJAU   2   // GPIO2  — AMAN
#define LED_KUNING  4   // GPIO4  — WASPADA
#define LED_MERAH   15  // GPIO15 — BERBAHAYA
#define LED_BIRU    25  // GPIO25 — TX LoRa aktif
#define BUZZER_PIN  14  // GPIO14 — Buzzer

// ── OLED — T3 V1.6.1 built-in ────────────────────────────────────────────────
// SDA=21, SCL=22 (sesuai pinout resmi T3 V1.6.1)
#define OLED_SDA  21
#define OLED_SCL  22

DHT dht(DHT_PIN, DHT_TYPE);
Adafruit_SSD1306 display(128, 64, &Wire, -1);

float  temperature = 0.0;
float  humidity    = 0.0;
int    txCount     = 0;
int    failCount   = 0;
bool   loraReady   = false;

String aiStatus  = "MENUNGGU";
String aiRisk    = "-";
int    aiConf    = 0;
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
  delay(2000); // DHT22 butuh waktu stabilisasi

  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);

  if (!LoRa.begin(LORA_BAND)) {
    showError("LoRa GAGAL");
    buzzerError();
    while (true) delay(1000);
  }

  LoRa.setSpreadingFactor(7);
  LoRa.setSignalBandwidth(125E3);
  LoRa.setCodingRate4(5);
  LoRa.setTxPower(20);
  LoRa.enableCrc();

  loraReady = true;
  Serial.printf("[NODE] %s siap | LoRa %.0fMHz\n", NODE_ID, LORA_BAND / 1E6);
  buzzerBeep(1, 100);
  setLEDWaiting();
}

void loop() {
  unsigned long now = millis();

  // Kirim data mentah setiap SEND_INTERVAL
  if (now - lastSend >= SEND_INTERVAL) {
    lastSend = now;
    if (readSensor()) {
      sendRawData();
    }
    updateDisplay();
  }

  // Cek downlink dari Gateway (hasil AI)
  int pktSize = LoRa.parsePacket();
  if (pktSize > 0) {
    receiveDownlink();
  }

  // Timeout: jika lama tidak ada downlink, tampilkan status terakhir + tanda offline
  // TIDAK reset ke MENUNGGU agar LED tidak berubah-ubah
  if (aiStatus != "MENUNGGU" && (now - lastDownlink > DOWNLINK_TIMEOUT)) {
    // Hanya log warning, LED & status tetap seperti terakhir
    Serial.println("[NODE] Downlink timeout — menunggu koneksi kembali...");
    // Tandai di OLED bahwa koneksi terputus tapi status tetap
    updateDisplay(); // akan tampilkan "(offline)" di OLED
  }
}

// ── Baca sensor dengan retry ──────────────────────────────────────────────────
bool readSensor() {
  for (int i = 0; i < DHT_RETRY_MAX; i++) {
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    if (!isnan(t) && !isnan(h)) {
      temperature = t;
      humidity    = h;
      Serial.printf("[DHT] Raw: %.2f C  %.2f%%\n", t, h);
      return true;
    }
    delay(500);
  }
  failCount++;
  Serial.println("[DHT] Gagal baca setelah retry");
  return false;
}

// ── Kirim data MENTAH via LoRa ────────────────────────────────────────────────
void sendRawData() {
  if (!loraReady) return;

  StaticJsonDocument<96> doc;
  doc["node_id"]     = NODE_ID;
  doc["temperature"] = round(temperature * 100.0) / 100.0;
  doc["humidity"]    = round(humidity * 100.0) / 100.0;

  String payload;
  serializeJson(doc, payload);

  digitalWrite(LED_BIRU, HIGH);
  LoRa.beginPacket();
  LoRa.print(payload);
  LoRa.endPacket();
  delay(100);
  digitalWrite(LED_BIRU, LOW);

  // Kembali ke mode receive untuk terima downlink
  LoRa.receive();

  txCount++;
  Serial.printf("[TX] #%d %s\n", txCount, payload.c_str());
}

// ── Terima downlink (hasil AI dari Backend) ───────────────────────────────────
void receiveDownlink() {
  String raw = "";
  while (LoRa.available()) raw += (char)LoRa.read();
  Serial.printf("[RX] Downlink: %s\n", raw.c_str());

  StaticJsonDocument<128> doc;
  if (deserializeJson(doc, raw) != DeserializationError::Ok) {
    Serial.println("[RX] JSON error");
    return;
  }

  // Filter: hanya proses downlink untuk node ini
  const char* targetNode = doc["node_id"];
  if (!targetNode || String(targetNode) != NODE_ID) return;

  String prev = aiStatus;
  aiStatus = doc["status"] | "AMAN";
  aiRisk   = doc["risk"]   | "LOW";
  aiConf   = doc["confidence"] | 0;
  lastDownlink = millis();

  Serial.printf("[AI] Status=%s Risk=%s Conf=%d%%\n",
                aiStatus.c_str(), aiRisk.c_str(), aiConf);

  applyAIStatus(prev);
  updateDisplay();
}

// ── Terapkan status AI ke LED & Buzzer ────────────────────────────────────────
void applyAIStatus(String prev) {
  digitalWrite(LED_HIJAU,  LOW);
  digitalWrite(LED_KUNING, LOW);
  digitalWrite(LED_MERAH,  LOW);

  if (aiStatus == "AMAN") {
    digitalWrite(LED_HIJAU, HIGH);
    if (prev == "WASPADA" || prev == "BERBAHAYA") {
      buzzerBeep(1, 80); // 1 beep pendek: kembali aman
    }
  } else if (aiStatus == "WASPADA") {
    digitalWrite(LED_KUNING, HIGH);
    if (prev != "WASPADA") {
      buzzerBeep(2, 150); // 2 beep: masuk waspada
    }
  } else if (aiStatus == "BERBAHAYA") {
    digitalWrite(LED_MERAH, HIGH);
    buzzerAlert(); // 3 beep panjang: berbahaya
  }
}

// ── LED waiting (belum ada status AI) ────────────────────────────────────────
void setLEDWaiting() {
  digitalWrite(LED_HIJAU,  LOW);
  digitalWrite(LED_KUNING, LOW);
  digitalWrite(LED_MERAH,  LOW);
  for (int i = 0; i < 2; i++) {
    digitalWrite(LED_BIRU, HIGH); delay(100);
    digitalWrite(LED_BIRU, LOW);  delay(100);
  }
}

// ── OLED ──────────────────────────────────────────────────────────────────────
void updateDisplay() {
  bool isOffline = (aiStatus != "MENUNGGU") &&
                   (millis() - lastDownlink > DOWNLINK_TIMEOUT);

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  display.setTextSize(1);
  display.setCursor(0, 0);
  display.print("SUSEMON  Node ");
  display.println(NODE_ID);
  display.drawLine(0, 9, 127, 9, SSD1306_WHITE);

  display.setTextSize(2);
  display.setCursor(0, 13);
  display.printf("%.1f", temperature);
  display.setTextSize(1);
  display.setCursor(72, 16);
  display.println("C RAW");

  display.setTextSize(1);
  display.setCursor(0, 32);
  display.printf("Hum: %.1f%% RAW", humidity);

  display.setCursor(0, 42);
  display.print("AI: ");
  if (aiStatus == "MENUNGGU") {
    display.print("Menunggu...");
  } else if (isOffline) {
    display.print(aiStatus);
    display.print(" (offline)");
  } else {
    display.print(aiStatus);
    if (aiConf > 0) display.printf(" %d%%", aiConf);
  }

  display.setCursor(0, 54);
  display.printf("TX:%d Fail:%d", txCount, failCount);

  display.display();
}

void showSplash() {
  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(10, 5);
  display.println("SUSEMON");
  display.setTextSize(1);
  display.setCursor(5, 32);
  display.print("Node ");
  display.println(NODE_ID);
  display.setCursor(5, 46);
  display.println("Raw Data Mode");
  display.display();
  delay(2000);
}

void showError(String msg) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 20);
  display.println("ERROR:");
  display.println(msg);
  display.display();
}

// ── LED & Buzzer helpers ──────────────────────────────────────────────────────
void testLED() {
  int leds[] = {LED_HIJAU, LED_KUNING, LED_MERAH, LED_BIRU};
  for (int i = 0; i < 4; i++) {
    digitalWrite(leds[i], HIGH); delay(200);
    digitalWrite(leds[i], LOW);
  }
}

void buzzerBeep(int n, int ms) {
  for (int i = 0; i < n; i++) {
    digitalWrite(BUZZER_PIN, HIGH); delay(ms);
    digitalWrite(BUZZER_PIN, LOW);
    if (i < n - 1) delay(100);
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
