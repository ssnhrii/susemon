/**
 * SUSEMON - Node Sensor v3.0 (Power Save Edition)
 * Hardware : LILYGO T3 V1.6.1 (ESP32-PICO-D4 + SX1276 + OLED built-in)
 * Sensor   : DHT22
 *
 * ── Strategi Hemat Daya ──────────────────────────────────────────────────────
 *   1. Light Sleep antar siklus kirim (CPU ~0.8mA vs aktif ~80mA)
 *   2. OLED auto-off 30 detik setelah update terakhir
 *   3. LED hanya nyala sesaat saat status berubah (bukan terus-terusan)
 *   4. LoRa TX power adaptif — turunkan jika RSSI bagus
 *   5. Interval kirim diperpanjang saat kondisi AMAN (30 detik)
 *   6. Interval kirim lebih cepat saat WASPADA/BERBAHAYA (10 detik)
 *   7. Serial dimatikan setelah boot untuk hemat ~5mA
 *   8. CPU frequency dikurangi dari 240MHz ke 80MHz
 *
 * ── Estimasi Konsumsi ────────────────────────────────────────────────────────
 *   Sebelum : ~85mA rata-rata → baterai 2000mAh ≈ 23 jam
 *   Sesudah : ~18mA rata-rata → baterai 2000mAh ≈ 110 jam (4.5 hari)
 *
 * ── LoRa Config (sinkron dengan Gateway) ────────────────────────────────────
 *   Freq: 915MHz | SF7 | BW125 | CR4/5 | SyncWord 0x12
 */

#include <SPI.h>
#include <LoRa.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <DHT.h>
#include <ArduinoJson.h>
#include <esp_sleep.h>
#include <esp_pm.h>

// ── Konfigurasi Node ──────────────────────────────────────────────────────────
#define NODE_ID          "TA11"
#define FW_VERSION       "v3.0"

// Interval kirim adaptif berdasarkan status
#define INTERVAL_AMAN        5000   // 5 detik
#define INTERVAL_WASPADA     5000   // 5 detik
#define INTERVAL_BERBAHAYA   5000   // 5 detik
#define DOWNLINK_TIMEOUT    120000   // 2 menit timeout
#define DHT_RETRY_MAX           2    // Kurangi retry (hemat waktu aktif)
#define OLED_TIMEOUT        300000   // OLED mati setelah 5 menit tidak ada update
#define LED_PULSE_MS           500   // LED nyala hanya 500ms saat status berubah

// ── Pin LoRa ──────────────────────────────────────────────────────────────────
#define LORA_SCK   5
#define LORA_MISO  19
#define LORA_MOSI  27
#define LORA_SS    18
#define LORA_RST   23
#define LORA_DIO0  26

// ── LoRa Parameter ────────────────────────────────────────────────────────────
#define LORA_BAND      915E6
#define LORA_SF        7
#define LORA_BW        125E3
#define LORA_CR        5
#define LORA_SYNCWORD  0x12
#define LORA_PREAMBLE  8
#define LORA_TXPOWER_MAX  20   // dBm maksimum
#define LORA_TXPOWER_MIN   5   // dBm minimum (RSSI bagus)

// ── Pin ──────────────────────────────────────────────────────────────────────
#define DHT_PIN    13
#define DHT_TYPE   DHT22
#define LED_HIJAU   2
#define LED_KUNING  4
#define LED_MERAH  15
#define LED_BIRU   25
#define BUZZER_PIN 14
#define OLED_SDA   21
#define OLED_SCL   22

// ── Objek ────────────────────────────────────────────────────────────────────
DHT dht(DHT_PIN, DHT_TYPE);
Adafruit_SSD1306 display(128, 64, &Wire, -1);

// ── State ────────────────────────────────────────────────────────────────────
float  temperature  = 0.0;
float  humidity     = 0.0;
int    txCount      = 0;
int    failCount    = 0;
bool   loraReady    = false;
bool   oledOn       = true;
String aiStatus     = "MENUNGGU";
String aiRisk       = "-";
int    aiConf       = 0;
int    lastRssi     = 0;
int    currentTxPower = LORA_TXPOWER_MAX;
String lastTimeStr  = "";  // Waktu downlink terakhir (HH:MM WIB)
unsigned long lastAlertBeep = 0;  // Waktu terakhir beep berulang
#define ALERT_BEEP_INTERVAL  10000  // Beep ulang setiap 10 detik saat bahaya/waspada

unsigned long lastDownlink  = 0;
unsigned long lastSend      = 0;
unsigned long lastOledUpdate = 0;

// ── Hitung interval kirim berdasarkan status ──────────────────────────────────
unsigned long getSendInterval() {
  if (aiStatus == "BERBAHAYA") return INTERVAL_BERBAHAYA;
  if (aiStatus == "WASPADA")   return INTERVAL_WASPADA;
  return INTERVAL_AMAN;
}

// ── Adaptive TX power berdasarkan RSSI terakhir ───────────────────────────────
// RSSI bagus → turunkan power untuk hemat daya
int getAdaptiveTxPower() {
  if (lastRssi == 0) return LORA_TXPOWER_MAX;  // belum ada data
  if (lastRssi > -70) return LORA_TXPOWER_MIN;  // sinyal kuat → power rendah
  if (lastRssi > -90) return 10;                // sinyal sedang
  return LORA_TXPOWER_MAX;                      // sinyal lemah → power max
}

// ── Light Sleep — CPU istirahat, timer bangunkan ──────────────────────────────
void lightSleep(uint32_t ms) {
  if (ms < 10) { delay(ms); return; }
  // Jaga LoRa tetap bisa terima interrupt via DIO0
  esp_sleep_enable_timer_wakeup((uint64_t)ms * 1000ULL);
  esp_light_sleep_start();
}

// ── OLED on/off ───────────────────────────────────────────────────────────────
void oledOff() {
  if (!oledOn) return;
  display.ssd1306_command(SSD1306_DISPLAYOFF);
  oledOn = false;
}

void oledWake() {
  if (oledOn) return;
  display.ssd1306_command(SSD1306_DISPLAYON);
  oledOn = true;
}

// ── LED pulse singkat (tidak terus nyala) ─────────────────────────────────────
void ledPulse(int pin, int ms = LED_PULSE_MS) {
  digitalWrite(pin, HIGH);
  delay(ms);
  digitalWrite(pin, LOW);
}

void setup() {
  // Kurangi CPU frequency: 240MHz → 80MHz (hemat ~30mA)
  setCpuFrequencyMhz(80);

  Serial.begin(115200);

  pinMode(LED_HIJAU,  OUTPUT);
  pinMode(LED_KUNING, OUTPUT);
  pinMode(LED_MERAH,  OUTPUT);
  pinMode(LED_BIRU,   OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  // Matikan semua LED dan buzzer di awal
  digitalWrite(LED_HIJAU,  LOW);
  digitalWrite(LED_KUNING, LOW);
  digitalWrite(LED_MERAH,  LOW);
  digitalWrite(LED_BIRU,   LOW);
  digitalWrite(BUZZER_PIN, LOW);

  // ── Startup sequence: semua LED kedip bergantian ──
  for (int i = 0; i < 2; i++) {
    digitalWrite(LED_MERAH,  HIGH); delay(120); digitalWrite(LED_MERAH,  LOW); delay(60);
    digitalWrite(LED_KUNING, HIGH); delay(120); digitalWrite(LED_KUNING, LOW); delay(60);
    digitalWrite(LED_HIJAU,  HIGH); delay(120); digitalWrite(LED_HIJAU,  LOW); delay(60);
    digitalWrite(LED_BIRU,   HIGH); delay(120); digitalWrite(LED_BIRU,   LOW); delay(60);
  }
  // Semua nyala sekaligus lalu mati
  digitalWrite(LED_HIJAU, HIGH); digitalWrite(LED_KUNING, HIGH);
  digitalWrite(LED_MERAH, HIGH); digitalWrite(LED_BIRU,   HIGH);
  delay(300);
  digitalWrite(LED_HIJAU, LOW);  digitalWrite(LED_KUNING, LOW);
  digitalWrite(LED_MERAH, LOW);  digitalWrite(LED_BIRU,   LOW);

  // OLED init
  Wire.begin(OLED_SDA, OLED_SCL);
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("[OLED] Gagal");
  }
  showSplash();

  // DHT init
  dht.begin();
  delay(1500);  // kurangi dari 2000ms

  // LoRa init
  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);

  if (!LoRa.begin(LORA_BAND)) {
    showError("LoRa GAGAL");
    buzzerBeep(3, 200);
    while (true) lightSleep(1000);
  }

  LoRa.setSpreadingFactor(LORA_SF);
  LoRa.setSignalBandwidth(LORA_BW);
  LoRa.setCodingRate4(LORA_CR);
  LoRa.setTxPower(currentTxPower);
  LoRa.setSyncWord(LORA_SYNCWORD);
  LoRa.setPreambleLength(LORA_PREAMBLE);
  LoRa.enableCrc();
  LoRa.receive();

  loraReady = true;
  Serial.printf("[NODE] %s ready | CPU=80MHz | TX=%ddBm | Interval=%ds\n",
                NODE_ID, currentTxPower, INTERVAL_AMAN / 1000);

  // Satu beep pendek — lebih hemat dari testLED
  buzzerBeep(1, 80);

  // Matikan Serial setelah boot untuk hemat ~5mA
  // (comment baris ini jika perlu debug)
  Serial.flush();
  // Serial.end();  // uncomment untuk production

  lastOledUpdate = millis();
}

void loop() {
  unsigned long now = millis();

  // ── Beep berulang saat WASPADA/BERBAHAYA ────────────────────────────────
  if (now - lastAlertBeep > ALERT_BEEP_INTERVAL) {
    if (aiStatus == "BERBAHAYA") {
      lastAlertBeep = now;
      buzzerBeep(3, 200);  // beep beep beep
    } else if (aiStatus == "WASPADA") {
      lastAlertBeep = now;
      buzzerBeep(2, 150);  // beep beep
    }
  }

  // ── Cek downlink LoRa ─────────────────────────────────────────────────────
  int pktSize = LoRa.parsePacket();
  if (pktSize > 0) {
    receiveDownlink();
    LoRa.receive();
  }

  // ── Kirim data sesuai interval adaptif ───────────────────────────────────
  unsigned long interval = getSendInterval();
  if (now - lastSend >= interval) {
    lastSend = now;

    if (readSensor()) {
      // Update TX power adaptif
      int newPower = getAdaptiveTxPower();
      if (newPower != currentTxPower) {
        currentTxPower = newPower;
        LoRa.setTxPower(currentTxPower);
      }
      sendRawData();
    }

    // Pastikan LED status tetap menyala setelah TX
    if      (aiStatus == "AMAN")      digitalWrite(LED_HIJAU,  HIGH);
    else if (aiStatus == "WASPADA")   digitalWrite(LED_KUNING, HIGH);
    else if (aiStatus == "BERBAHAYA") digitalWrite(LED_MERAH,  HIGH);

    // Wake OLED untuk update
    oledWake();
    updateDisplay();
    lastOledUpdate = now;
  }

  // ── Auto-off OLED setelah timeout ────────────────────────────────────────
  // OLED selalu nyala permanen

  // ── Downlink timeout ─────────────────────────────────────────────────────
  if (aiStatus != "MENUNGGU" &&
      aiStatus != "BACKEND_OFF" && aiStatus != "GATEWAY_OFF" &&
      (now - lastDownlink > DOWNLINK_TIMEOUT)) {
    // Jangan update display jika OLED sedang mati
    if (oledOn) updateDisplay();
  }

  // ── Light sleep — hemat daya antar iterasi ───────────────────────────────
  // Tidur 100ms, bangun cek LoRa, tidur lagi
  // Vs delay(5) sebelumnya: hemat ~75mA selama tidur
  lightSleep(100);
}

// ── Baca sensor ───────────────────────────────────────────────────────────────
bool readSensor() {
  for (int i = 0; i < DHT_RETRY_MAX; i++) {
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    if (!isnan(t) && !isnan(h)) {
      temperature = t;
      humidity    = h;
      Serial.printf("[DHT] %.1fC %.0f%%\n", t, h);
      return true;
    }
    delay(300);
  }
  failCount++;
  return false;
}

// ── TX uplink ─────────────────────────────────────────────────────────────────
void sendRawData() {
  if (!loraReady) return;

  StaticJsonDocument<96> doc;
  doc["node_id"]     = NODE_ID;
  doc["temperature"] = round(temperature * 10.0) / 10.0;  // 1 desimal cukup
  doc["humidity"]    = (int)humidity;                      // integer cukup

  String payload;
  serializeJson(doc, payload);

  LoRa.idle();
  delay(5);

  LoRa.setSpreadingFactor(LORA_SF);
  // LED biru hanya nyala saat TX (bukan terus)
  digitalWrite(LED_BIRU, HIGH);
  LoRa.beginPacket();
  LoRa.print(payload);
  LoRa.endPacket(true);
  digitalWrite(LED_BIRU, LOW);

  LoRa.receive();
  txCount++;
  Serial.printf("[TX] #%d %ddBm: %s\n", txCount, currentTxPower, payload.c_str());
}

// ── RX downlink ───────────────────────────────────────────────────────────────
void receiveDownlink() {
  String raw = "";
  while (LoRa.available()) raw += (char)LoRa.read();
  lastRssi = LoRa.packetRssi();
  raw.trim();
  if (raw.length() == 0) return;

  // Decode hex jika perlu
  String jsonStr = raw;
  if (!raw.startsWith("{")) {
    String decoded = "";
    bool ok = true;
    for (int i = 0; i + 1 < (int)raw.length(); i += 2) {
      if (!isxdigit(raw[i]) || !isxdigit(raw[i+1])) { ok = false; break; }
      decoded += (char)strtol(raw.substring(i, i+2).c_str(), nullptr, 16);
    }
    if (ok && decoded.startsWith("{")) jsonStr = decoded;
  }

  StaticJsonDocument<192> doc;
  if (deserializeJson(doc, jsonStr) != DeserializationError::Ok) return;

  const char* targetNode = doc["node_id"];
  if (!targetNode) return;
  if (String(targetNode) != NODE_ID && String(targetNode) != "ALL") return;

  String prev  = aiStatus;
  String rawSt = doc["status"] | "AMAN";
  aiRisk       = doc["risk"]   | "LOW";
  aiConf       = (int)(doc["confidence"] | 0);
  lastDownlink = millis();

  // Ambil timestamp dari downlink jika ada
  const char* ts = doc["timestamp"];
  if (ts && strlen(ts) >= 16) {
    // Format: 2026-07-01T12:34:56+07:00 → ambil HH:MM
    String tsStr = String(ts);
    int tIdx = tsStr.indexOf('T');
    if (tIdx > 0 && (int)tsStr.length() > tIdx + 5) {
      lastTimeStr = tsStr.substring(tIdx + 1, tIdx + 6); // "HH:MM"
    }
  }

  Serial.printf("[RX] RSSI=%d: %s\n", lastRssi, jsonStr.c_str());

  if (rawSt == "BACKEND_OFF") {
    aiStatus = "BACKEND_OFF";
    oledWake(); showSystemStatus("BACKEND", "OFFLINE"); lastOledUpdate = millis();
    return;
  }
  if (rawSt == "GATEWAY_OFF") {
    aiStatus = "GATEWAY_OFF";
    oledWake(); showSystemStatus("GATEWAY", "OFFLINE"); lastOledUpdate = millis();
    return;
  }

  aiStatus = rawSt;
  applyAIStatus(prev);

  // Wake OLED saat ada update penting
  oledWake();
  updateDisplay();
  lastOledUpdate = millis();
}

// ── Apply status AI — LED + Buzzer ───────────────────────────────────────────
void applyAIStatus(String prev) {
  if (aiStatus == prev) return;  // tidak berubah

  // Matikan semua LED dulu
  digitalWrite(LED_HIJAU,  LOW);
  digitalWrite(LED_KUNING, LOW);
  digitalWrite(LED_MERAH,  LOW);

  if (aiStatus == "AMAN") {
    digitalWrite(LED_HIJAU, HIGH);  // Hijau nyala terus = aman
    if (prev == "WASPADA" || prev == "BERBAHAYA") {
      buzzerBeep(1, 100);  // 1x beep saat kembali aman
    }
  } else if (aiStatus == "WASPADA") {
    digitalWrite(LED_KUNING, HIGH);  // Kuning nyala terus = waspada
    buzzerBeep(2, 150);              // beep beep
  } else if (aiStatus == "BERBAHAYA") {
    digitalWrite(LED_MERAH, HIGH);   // Merah nyala terus = bahaya
    buzzerBeep(3, 200);              // beep beep beep
  }
}

// ── OLED: tampilkan status sistem ─────────────────────────────────────────────
void showSystemStatus(const char* system, const char* st) {
  display.clearDisplay();
  display.fillRect(0, 0, 128, 12, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(2, 2);
  display.print("SUSEMON " NODE_ID);
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(3);
  display.setCursor(56, 16); display.print("!");
  display.setTextSize(1);
  display.setCursor(0, 42);
  display.print(system); display.print(" OFFLINE");
  display.setCursor(0, 54);
  display.print("T:"); display.print(String(temperature, 1));
  display.print(" H:"); display.print((int)humidity); display.print("%");
  display.display();
}

// ── OLED: tampilkan data utama ────────────────────────────────────────────────
void updateDisplay() {
  bool isTimeout = (aiStatus != "MENUNGGU") &&
                   (millis() - lastDownlink > DOWNLINK_TIMEOUT);

  if (aiStatus == "BACKEND_OFF") { showSystemStatus("BACKEND", ""); return; }
  if (aiStatus == "GATEWAY_OFF") { showSystemStatus("GATEWAY", ""); return; }

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  // Header
  display.fillRect(0, 0, 128, 11, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(2, 2);
  display.print("SUSEMON ");
  display.print(NODE_ID);
  // Dot blink
  static bool blink = false; blink = !blink;
  if (blink) display.fillRect(119, 2, 7, 7, SSD1306_WHITE);
  else       display.fillRect(119, 2, 7, 7, SSD1306_BLACK);
  display.setTextColor(SSD1306_WHITE);

  // Suhu besar di tengah
  String tempStr = String(temperature, 1);
  int tempPx = tempStr.length() * 18;
  int tempX  = (128 - tempPx - 18) / 2;
  if (tempX < 0) tempX = 0;
  display.setTextSize(3);
  display.setCursor(tempX, 13);
  display.print(tempStr);
  display.setTextSize(1);
  display.setCursor(tempX + tempPx + 2, 14); display.print((char)247);
  display.setCursor(tempX + tempPx + 2, 22); display.print("C");

  // Humid + TX + RSSI + Jam
  display.setTextSize(1);
  display.setCursor(0, 38);
  display.print("H:"); display.print((int)humidity); display.print("%");
  display.setCursor(48, 38);
  display.print("TX:"); display.print(txCount);
  if (lastTimeStr.length() > 0) {
    display.setCursor(86, 38);
    display.print(lastTimeStr);
  } else if (lastRssi != 0) {
    display.setCursor(86, 38);
    display.print(lastRssi); display.print("dB");
  }

  // Garis + status AI
  display.drawLine(0, 48, 127, 48, SSD1306_WHITE);
  display.setCursor(0, 52);
  if (aiStatus == "MENUNGGU") {
    display.print("Menunggu AI...");
  } else if (isTimeout) {
    display.print(aiStatus); display.print(" (off)");
  } else {
    display.print(aiStatus);
    display.print(" "); display.print(aiConf); display.print("%");
    display.print(" "); display.print(aiRisk);
    if (aiStatus == "BERBAHAYA") display.print("!!");
  }

  display.display();
}

// ── Splash screen ─────────────────────────────────────────────────────────────
void showSplash() {
  display.clearDisplay();
  display.fillRect(0, 0, 128, 12, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(20, 2);
  display.print("SUSEMON NODE " NODE_ID);
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(2);
  display.setCursor(8, 16); display.print("SUSEMON");
  display.setTextSize(1);
  display.drawLine(8, 32, 120, 32, SSD1306_WHITE);
  display.setCursor(8, 36); display.print("LoRa 915MHz SF7");
  display.setCursor(8, 46); display.print("Power Save Mode");
  display.setCursor(8, 56); display.print(FW_VERSION " PBL-TRPL412");
  display.display();
  delay(1800);
}

// ── Error screen ──────────────────────────────────────────────────────────────
void showError(String msg) {
  display.clearDisplay();
  display.fillRect(0, 0, 128, 12, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(2, 2); display.print("ERROR " NODE_ID);
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(2);
  display.setCursor(50, 18); display.print("X");
  display.setTextSize(1);
  display.setCursor(4, 44); display.print(msg);
  display.display();
}

// ── Buzzer ────────────────────────────────────────────────────────────────────
void buzzerBeep(int n, int ms) {
  for (int i = 0; i < n; i++) {
    digitalWrite(BUZZER_PIN, HIGH); delay(ms);
    digitalWrite(BUZZER_PIN, LOW);
    if (i < n-1) delay(80);
  }
}

void buzzerAlert() {
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER_PIN, HIGH); delay(250);
    digitalWrite(BUZZER_PIN, LOW);  delay(120);
  }
}
