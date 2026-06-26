/**
 * SUSEMON - Gateway v1.1
 * Hardware : TTGO LORA32 T22_V1.1 (ESP32 + SX1276)
 * Fungsi   : LoRa ↔ MQTT Bridge (menggantikan Dragino TX yang lemah)
 *
 * Alur:
 *   Uplink  : Node LoRa TX → Gateway RX → WiFi → MQTT broker → Backend
 *   Downlink: Backend → MQTT → Gateway → LoRa TX → Node
 *
 * Pin TTGO LORA32 T22_V1.1:
 *   LoRa SS   → GPIO 18
 *   LoRa RST  → GPIO 14
 *   LoRa DIO0 → GPIO 26
 *   LoRa SCK  → GPIO 5
 *   LoRa MISO → GPIO 19
 *   LoRa MOSI → GPIO 27
 *   OLED SDA  → GPIO 4  (jika ada)
 *   OLED SCL  → GPIO 15 (jika ada)
 */

#include <SPI.h>
#include <LoRa.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include <vector>

// ── WiFi ──────────────────────────────────────────────────────────────────────
#define WIFI_SSID    "IoT_Susemon"
#define WIFI_PASS    "12345678"

// ── MQTT ──────────────────────────────────────────────────────────────────────
#define MQTT_SERVER  "10.130.1.206"
#define MQTT_PORT    1883
#define MQTT_USER    "susemon"
#define MQTT_PASS    "susemon123"
#define MQTT_CLIENT  "ttgo-gateway"
#define TOPIC_UP     "sensor/data"
#define TOPIC_DOWN   "sensor/ai_result"

// ── Pin LoRa — TTGO LORA32 T22_V1.1 ─────────────────────────────────────────
#define LORA_SCK   5
#define LORA_MISO  19
#define LORA_MOSI  27
#define LORA_SS    18
#define LORA_RST   14
#define LORA_DIO0  26

// ── LoRa Parameter ────────────────────────────────────────────────────────────
#define LORA_BAND      915E6
#define LORA_SF        7       // sama dengan node uplink SF7
#define LORA_BW        125E3
#define LORA_CR        5
#define LORA_TXPOWER   20
#define LORA_SYNCWORD  0x12
#define LORA_PREAMBLE  8

WiFiClient   wifiClient;
PubSubClient mqtt(wifiClient);

int  upCount  = 0;
int  downCount = 0;
bool loraReady = false;

// ── Buffer Queue untuk Offline ───────────────────────────────────────────────
std::vector<String> msgBuffer;
const int MAX_BUFFER_SIZE = 100; // Simpan hingga 100 data (~15 menit offline)

// ── NTP Helper ────────────────────────────────────────────────────────────────
String getISO8601Timestamp() {
  time_t now;
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("[NTP] Gagal mengambil waktu");
    return "";
  }
  char buffer[25];
  // Format: YYYY-MM-DDTHH:MM:SSZ (UTC)
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(buffer);
}

// ── MQTT callback — terima downlink dari backend ──────────────────────────────
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String msg = "";
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  Serial.printf("[MQTT DOWN] %s\n", msg.c_str());

  // TX via LoRa ke node
  LoRa.idle();
  delay(10);
  LoRa.beginPacket();
  LoRa.print(msg);
  LoRa.endPacket(true);
  delay(50);
  LoRa.receive();

  downCount++;
  Serial.printf("[LoRa TX] #%d downlink sent\n", downCount);
}

// ── WiFi connect ──────────────────────────────────────────────────────────────
void connectWiFi() {
  Serial.printf("[WiFi] Connecting to %s", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  int retry = 0;
  while (WiFi.status() != WL_CONNECTED && retry < 30) {
    delay(500); Serial.print("."); retry++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WiFi] OK — IP: %s\n", WiFi.localIP().toString().c_str());
    // Inisialisasi NTP setelah koneksi WiFi berhasil (UTC)
    configTime(0, 0, "pool.ntp.org", "time.nist.gov");
    Serial.println("[NTP] Jam disinkronkan ke UTC");
  } else {
    Serial.println("\n[WiFi] FAILED");
  }
}

// ── MQTT connect ──────────────────────────────────────────────────────────────
void connectMQTT() {
  while (!mqtt.connected()) {
    Serial.print("[MQTT] Connecting...");
    if (mqtt.connect(MQTT_CLIENT, MQTT_USER, MQTT_PASS)) {
      mqtt.subscribe(TOPIC_DOWN, 1); // Subscribe dengan QoS 1
      Serial.printf("OK — subscribed to %s (QoS 1)\n", TOPIC_DOWN);
    } else {
      Serial.printf("FAILED rc=%d, retry 3s\n", mqtt.state());
      delay(3000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("========================================");
  Serial.println("  SUSEMON Gateway v1.1");
  Serial.println("  Hardware: TTGO LORA32 T22_V1.1");
  Serial.println("  LoRa → WiFi → MQTT Bridge (QoS 1 + Buffer)");
  Serial.println("========================================");

  // Init LoRa
  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);

  if (!LoRa.begin(LORA_BAND)) {
    Serial.println("[LoRa] INIT FAILED!");
    while (true) delay(1000);
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
  Serial.printf("[LoRa] Ready | %.0fMHz SF%d Sync=0x%02X\n",
                LORA_BAND/1E6, LORA_SF, LORA_SYNCWORD);

  // Init WiFi + MQTT
  connectWiFi();
  mqtt.setServer(MQTT_SERVER, MQTT_PORT);
  mqtt.setCallback(mqttCallback);
  mqtt.setBufferSize(512);
  connectMQTT();

  Serial.println("[GW] Gateway ready — listening LoRa...");
  Serial.println("----------------------------------------");
}

void loop() {
  // Maintain MQTT
  if (!mqtt.connected()) {
    if (WiFi.status() != WL_CONNECTED) connectWiFi();
    connectMQTT();
  }
  mqtt.loop();

  // Cek uplink LoRa dari node
  int pktSize = LoRa.parsePacket();
  if (pktSize > 0) {
    String raw = "";
    while (LoRa.available()) raw += (char)LoRa.read();
    int rssi = LoRa.packetRssi();
    raw.trim();

    Serial.printf("[LoRa RX] RSSI=%d size=%d: %s\n", rssi, pktSize, raw.c_str());

    // Validasi JSON
    StaticJsonDocument<256> doc;
    if (deserializeJson(doc, raw) == DeserializationError::Ok && doc.containsKey("node_id")) {
      // Tambah RSSI ke payload
      doc["rssi"] = rssi;
      
      // Tambah timestamp UTC
      String ts = getISO8601Timestamp();
      if (ts.length() > 0) {
        doc["timestamp"] = ts;
      }

      String payload;
      serializeJson(doc, payload);

      // Simpan ke buffer queue jika memori masih cukup
      if (msgBuffer.size() >= MAX_BUFFER_SIZE) {
        msgBuffer.erase(msgBuffer.begin()); // Buang data tertua jika penuh (FIFO)
      }
      msgBuffer.push_back(payload);
      Serial.printf("[GW] Data disimpan di buffer. Ukuran queue: %d/%d\n", msgBuffer.size(), MAX_BUFFER_SIZE);
    } else {
      Serial.printf("[LoRa RX] Invalid JSON: %s\n", raw.c_str());
    }

    LoRa.receive();
  }

  // Proses dan kirim antrean data jika MQTT terhubung
  if (mqtt.connected() && !msgBuffer.empty()) {
    Serial.printf("[GW] Memproses %d data dalam antrean...\n", msgBuffer.size());
    while (!msgBuffer.empty() && mqtt.connected()) {
      String payload = msgBuffer.front();
      
      // Kirim data ke broker
      if (mqtt.publish(TOPIC_UP, payload.c_str())) {
        upCount++;
        Serial.printf("[MQTT UP] #%d berhasil dikirim: %s\n", upCount, payload.c_str());
        msgBuffer.erase(msgBuffer.begin()); // Hapus dari antrean jika sukses
      } else {
        Serial.println("[MQTT UP] Gagal mengirim, antrean ditahan.");
        break; // Berhenti memproses antrean, coba lagi iterasi berikutnya
      }
      delay(50); // Delay singkat untuk kestabilan transmisi
    }
  }

  delay(5);
}
