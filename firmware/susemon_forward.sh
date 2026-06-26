#!/bin/sh
# SUSEMON - Bidirectional LoRa-MQTT bridge untuk Dragino LG02
# Uplink  : /var/iot/receive/ → MQTT sensor/data
# Downlink: MQTT sensor/ai_result → /var/iot/push/ → lg02_pkt_fwd TX LoRa SF9

SERVER="10.130.1.206"
PORT="1883"
USER="susemon"
PASS="susemon123"
TOPIC_UP="sensor/data"
TOPIC_DOWN="sensor/ai_result"
RECV_DIR="/var/iot/receive"
PUSH_DIR="/var/iot/push"

LORA_FREQ="915000000"
LORA_DATR="SF7BW125"
LORA_CODR="4/5"

logger "[SUSEMON] Bridge started — UP:$TOPIC_UP DOWN:$TOPIC_DOWN DATR:$LORA_DATR"

# ── Downlink subscriber dengan auto-restart ───────────────────────────────────
start_sub() {
    mosquitto_sub -h $SERVER -p $PORT -u $USER -P $PASS -q 1 -t $TOPIC_DOWN | while read LINE; do
        [ -z "$LINE" ] && continue
        logger "[SUSEMON] Downlink RX: $LINE"
        HEX=$(echo -n "$LINE" | hexdump -v -e '/1 "%02x"')
        TXPKT=$(printf '{"txpk":{"freq":%s,"datr":"%s","codr":"%s","data":"%s"}}' \
            "$LORA_FREQ" "$LORA_DATR" "$LORA_CODR" "$HEX")
        FNAME="$PUSH_DIR/dl_$(date +%s)"
        echo "$TXPKT" > "$FNAME"
        logger "[SUSEMON] Downlink TX queued: $FNAME"
    done
    logger "[SUSEMON] Subscriber disconnected, restart in 5s..."
    sleep 5
}

# Loop subscriber dengan auto-restart
while true; do
    start_sub
done &

# ── Uplink: /var/iot/receive/ → MQTT ─────────────────────────────────────────
while true; do
    for f in $RECV_DIR/*; do
        [ -f "$f" ] || continue
        DATA=$(cat "$f")
        [ -z "$DATA" ] && rm -f "$f" && continue

        # Tambahkan timestamp UTC dari gateway untuk kestabilan histori meski delay/offline
        TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        DATA_WITH_TS=$(echo "$DATA" | sed "s/}$/,\"timestamp\":\"$TS\"}/")

        mosquitto_pub -h $SERVER -p $PORT -u $USER -P $PASS -q 1 -t $TOPIC_UP -m "$DATA_WITH_TS"
        if [ $? -eq 0 ]; then
            logger "[SUSEMON] Uplink: $DATA_WITH_TS"
            rm -f "$f"
        fi
    done
    sleep 3
done
