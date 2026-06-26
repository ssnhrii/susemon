"""
SUSEMON AI Engine v2.1
Metode: Moving Average, EWMA, Z-score, Linear Trend, Isolation Forest
Kalibrasi untuk data server room: interval 10 detik, suhu stabil 24-35°C
"""
import math
import numpy as np
from sklearn.ensemble import IsolationForest
from typing import List, Dict, Any


# ── Statistik ─────────────────────────────────────────────────────────────────

def moving_average(values: List[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def ewma(values: List[float], alpha: float = 0.2) -> float:
    """alpha=0.2 lebih smooth dari 0.3 — lebih baik untuk data stabil"""
    if not values:
        return 0.0
    result = values[0]
    for v in values[1:]:
        result = alpha * v + (1 - alpha) * result
    return result


def std_dev(values: List[float]) -> float:
    if len(values) < 2:
        return 0.0
    avg = moving_average(values)
    return math.sqrt(sum((v - avg) ** 2 for v in values) / len(values))


def z_score(value: float, avg: float, std: float) -> float:
    return (value - avg) / std if std > 0.01 else 0.0


def linear_trend(values: List[float]) -> float:
    n = len(values)
    if n < 2:
        return 0.0
    x_mean = (n - 1) / 2
    y_mean = moving_average(values)
    num = sum((i - x_mean) * (values[i] - y_mean) for i in range(n))
    den = sum((i - x_mean) ** 2 for i in range(n))
    return num / den if den != 0 else 0.0


def isolation_forest_score(readings: List[Dict]) -> float:
    """
    IF hanya reliable jika data punya variasi cukup.
    Data homogen (server room stabil) → return 0.2 (tidak anomali).
    """
    if len(readings) < 15:
        return 0.3
    X = np.array([[r["temperature"], r["humidity"]] for r in readings])
    temp_std = float(np.std(X[:, 0]))
    hum_std  = float(np.std(X[:, 1]))

    # Data terlalu homogen — IF tidak reliable
    if temp_std < 0.5 and hum_std < 2.5:
        return 0.2

    clf = IsolationForest(n_estimators=100, contamination=0.05, random_state=42)
    clf.fit(X)
    raw = clf.score_samples(X[-1].reshape(1, -1))[0]
    score = float(1 - (raw + 0.5))
    return max(0.0, min(0.85, score))  # cap 0.85


def _parse_ts(ts) -> float:
    from datetime import datetime, timezone
    if hasattr(ts, 'timestamp'):
        return ts.timestamp()
    s = str(ts)[:19]
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(s, fmt).replace(tzinfo=timezone.utc).timestamp()
        except Exception:
            continue
    return 0.0


# ── Main Analyzer ─────────────────────────────────────────────────────────────

def analyze_node(readings: List[Dict], thresholds: Dict = None) -> Dict[str, Any]:
    """
    readings: list {temperature, humidity, timestamp} — oldest first
    """
    if thresholds is None:
        thresholds = {}

    temp_warning = thresholds.get("temp_warning", 35.0)
    temp_danger  = thresholds.get("temp_danger",  40.0)
    hum_warning  = thresholds.get("hum_warning",  80.0)
    hum_danger   = thresholds.get("hum_danger",   85.0)

    if not readings or len(readings) < 3:
        return {
            "anomaly_detected": False, "overheating_risk": False,
            "risk_level": "LOW", "confidence": 0,
            "current_temp": 0.0, "current_humidity": 0.0,
            "avg_temp": 0.0, "ewma_temp": 0.0, "predicted_temp": 0.0,
            "z_score_temp": 0.0, "z_score_humidity": 0.0,
            "isolation_forest_score": 0.3, "trend_per_hour": 0.0,
            "trend_direction": "stable", "methods_used": [], "insights": [],
            "signal_count": 0,
        }

    temps  = [float(r["temperature"]) for r in readings]
    hums   = [float(r["humidity"])    for r in readings]
    latest     = temps[-1]
    latest_hum = hums[-1]

    # ── Trend per jam dari timestamp aktual ──────────────────────────────────
    try:
        ts0 = _parse_ts(readings[0]["timestamp"])
        ts1 = _parse_ts(readings[-1]["timestamp"])
        span_h = (ts1 - ts0) / 3600.0 if ts1 > ts0 else 0.0
        if span_h > 0:
            # readings-1 step dalam span_h jam
            mult = min((len(readings) - 1) / span_h, 360)  # max 1/10s equiv
        else:
            mult = 360
    except Exception:
        mult = 360

    # ── Statistik ──────────────────────────────────────────────────────────
    avg_temp  = moving_average(temps)
    std_temp  = std_dev(temps)
    ewma_temp = ewma(temps)
    z_t       = z_score(latest, avg_temp, std_temp)
    trend     = linear_trend(temps)
    trend_h   = trend * mult

    avg_hum  = moving_average(hums)
    std_hum  = std_dev(hums)
    z_h      = z_score(latest_hum, avg_hum, std_hum)

    # ── Deteksi sinyal ────────────────────────────────────────────────────
    # Threshold langsung — paling reliable
    above_danger  = latest >= temp_danger  or latest_hum >= hum_danger
    above_warning = latest >= temp_warning or latest_hum >= hum_warning

    # Z-score — threshold 2.5σ lebih konservatif dari 2.0σ
    z_temp_anom = abs(z_t) > 2.5
    z_hum_anom  = abs(z_h) > 2.5

    # EWMA deviation — deteksi pergeseran gradual
    ewma_dev = abs(latest - ewma_temp) > max(2.0 * std_temp, 0.5) if std_temp > 0.1 else False

    # Trend cepat — >3°C/jam (konservatif, sebelumnya 2.0)
    rapid = trend_h > 3.0

    # Isolation Forest — hanya jika data punya variasi
    if_score  = isolation_forest_score(readings) if len(readings) >= 15 else 0.3
    if_anomaly = if_score > 0.75 and len(readings) >= 15

    signals = [above_danger, z_temp_anom, z_hum_anom, ewma_dev, rapid, if_anomaly]
    signal_count = sum(1 for s in signals if s)

    # ── Confidence ────────────────────────────────────────────────────────
    # Berbasis data quantity + signal quality
    data_factor = min(len(readings) / 50, 1.0)  # makin banyak data → makin percaya

    if signal_count == 0:
        # Normal — confidence tinggi proporsional dengan data
        base = 65 + int(data_factor * 25)
        # Kurangi jika mendekati threshold warning
        margin_temp = temp_warning - latest
        margin_hum  = hum_warning  - latest_hum
        if margin_temp < 5 or margin_hum < 5:
            base -= 10  # mendekati warning → kurang yakin AMAN
        confidence = max(55, min(92, base))
    else:
        # Anomali — bobot sinyal
        w = 0
        if above_danger:  w += 40
        if above_warning and not above_danger: w += 20
        if z_temp_anom:   w += 15
        if z_hum_anom:    w += 10
        if ewma_dev:       w += 12
        if rapid:          w += 10
        if if_anomaly:     w += 13
        confidence = max(60, min(98, 55 + w))

    # ── Status ────────────────────────────────────────────────────────────
    # Butuh minimal 2 sinyal ATAU threshold terlampaui langsung
    anomaly_detected = signal_count >= 2 or above_danger
    overheating_risk = latest >= temp_danger or (rapid and latest >= temp_warning - 2)

    if above_danger or overheating_risk or signal_count >= 4:
        risk_level = "HIGH"
    elif above_warning or signal_count >= 2:
        risk_level = "MEDIUM"
    else:
        risk_level = "LOW"

    # ── Prediksi 30 menit ─────────────────────────────────────────────────
    # 30 menit = span_h * 6 jika mult reliable, else trend * 18 (10s interval)
    predicted_temp = round(ewma_temp + trend * 18, 2)

    # ── Insights ──────────────────────────────────────────────────────────
    insights = []
    if above_danger:
        insights.append(f"Suhu {latest}°C / Lembap {latest_hum}% melewati batas kritis")
    if overheating_risk and not above_danger:
        insights.append(f"Risiko overheating: suhu {latest}°C naik cepat")
    if rapid:
        insights.append(f"Tren naik cepat: +{trend_h:.1f}°C/jam")
    if z_temp_anom:
        insights.append(f"Suhu abnormal secara statistik (z={z_t:.2f}σ)")
    if ewma_dev:
        insights.append(f"Deviasi dari tren normal: {latest - ewma_temp:+.2f}°C")
    if if_anomaly:
        insights.append(f"Pola tidak biasa terdeteksi (skor: {if_score:.2f})")
    if z_hum_anom:
        insights.append(f"Kelembapan tidak normal: {latest_hum:.1f}% (z={z_h:.2f}σ)")
    if above_warning and not above_danger:
        insights.append(f"Mendekati batas: suhu {latest}°C (warning ≥{temp_warning}°C)")

    methods = ["moving_average", "ewma", "z_score", "linear_trend"]
    if len(readings) >= 15:
        methods.append("isolation_forest")

    return {
        "anomaly_detected":       anomaly_detected,
        "overheating_risk":       overheating_risk,
        "risk_level":             risk_level,
        "confidence":             confidence,
        "current_temp":           round(latest, 2),
        "current_humidity":       round(latest_hum, 2),
        "avg_temp":               round(avg_temp, 2),
        "ewma_temp":              round(ewma_temp, 2),
        "predicted_temp":         predicted_temp,
        "z_score_temp":           round(z_t, 3),
        "z_score_humidity":       round(z_h, 3),
        "isolation_forest_score": round(if_score, 3),
        "trend_per_hour":         round(trend_h, 2),
        "trend_direction":        "increasing" if trend > 0.02 else "decreasing" if trend < -0.02 else "stable",
        "methods_used":           methods,
        "insights":               insights,
        "signal_count":           signal_count,
    }
