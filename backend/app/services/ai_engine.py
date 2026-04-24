"""
SUSEMON AI Engine — Python
Metode: Moving Average, EWMA, Z-score, Isolation Forest (scikit-learn)
"""
import math
import numpy as np
from sklearn.ensemble import IsolationForest
from typing import List, Dict, Any


# ── Statistik dasar ───────────────────────────────────────────────────────────

def moving_average(values: List[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def ewma(values: List[float], alpha: float = 0.3) -> float:
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
    variance = sum((v - avg) ** 2 for v in values) / len(values)
    return math.sqrt(variance)


def z_score(value: float, avg: float, std: float) -> float:
    return (value - avg) / std if std != 0 else 0.0


def linear_trend(values: List[float]) -> float:
    """Least squares slope"""
    n = len(values)
    if n < 2:
        return 0.0
    x_mean = (n - 1) / 2
    y_mean = moving_average(values)
    num = sum((i - x_mean) * (values[i] - y_mean) for i in range(n))
    den = sum((i - x_mean) ** 2 for i in range(n))
    return num / den if den != 0 else 0.0


# ── Isolation Forest ──────────────────────────────────────────────────────────

def isolation_forest_score(readings: List[Dict]) -> float:
    """Hitung anomaly score untuk reading terbaru menggunakan Isolation Forest"""
    if len(readings) < 10:
        return 0.5
    X = np.array([[r["temperature"], r["humidity"]] for r in readings])
    clf = IsolationForest(n_estimators=50, contamination=0.1, random_state=42)
    clf.fit(X)
    # Score untuk data terbaru (index -1)
    latest = X[-1].reshape(1, -1)
    raw_score = clf.score_samples(latest)[0]
    # Normalisasi ke 0-1 (semakin tinggi = semakin anomali)
    score = float(1 - (raw_score + 0.5))
    return max(0.0, min(1.0, score))


# ── Main Analyzer ─────────────────────────────────────────────────────────────

def analyze_node(readings: List[Dict], thresholds: Dict = None) -> Dict[str, Any]:
    """
    Analisis lengkap untuk satu node.
    readings: list of {temperature, humidity, timestamp} — oldest first
    """
    if thresholds is None:
        thresholds = {}

    temp_warning = thresholds.get("temp_warning", 35.0)
    temp_danger  = thresholds.get("temp_danger",  40.0)
    hum_warning  = thresholds.get("hum_warning",  70.0)
    hum_danger   = thresholds.get("hum_danger",   80.0)

    if not readings or len(readings) < 3:
        return {
            "status": "INSUFFICIENT_DATA",
            "anomaly_detected": False,
            "overheating_risk": False,
            "confidence": 0,
            "methods_used": [],
            "insights": [],
            "signal_count": 0,
        }

    temps  = [float(r["temperature"]) for r in readings]
    hums   = [float(r["humidity"])    for r in readings]
    latest = temps[-1]
    latest_hum = hums[-1]

    # ── Statistik ──
    avg_temp  = moving_average(temps)
    std_temp  = std_dev(temps)
    ewma_temp = ewma(temps)
    z_temp    = z_score(latest, avg_temp, std_temp)
    trend     = linear_trend(temps)

    avg_hum   = moving_average(hums)
    std_hum   = std_dev(hums)
    z_hum     = z_score(latest_hum, avg_hum, std_hum)

    # ── Sinyal deteksi ──
    threshold_anomaly = latest >= temp_danger or latest_hum >= hum_danger
    threshold_warning = latest >= temp_warning or latest_hum >= hum_warning
    z_anomaly_temp    = abs(z_temp) > 2.0
    z_anomaly_hum     = abs(z_hum)  > 2.0
    ewma_deviation    = abs(latest - ewma_temp) > (2 * std_temp) if std_temp > 0 else False
    trend_per_hour    = trend * 12  # asumsi interval 5 menit
    rapid_increase    = trend_per_hour > 2.0

    # ── Isolation Forest ──
    if_score   = isolation_forest_score(readings)
    if_anomaly = if_score > 0.6

    signals = [threshold_anomaly, z_anomaly_temp, z_anomaly_hum,
               ewma_deviation, if_anomaly, rapid_increase]
    signal_count = sum(1 for s in signals if s)

    # ── Confidence ──
    confidence = min(98, 50 + signal_count * 8)

    anomaly_detected = signal_count >= 2 or threshold_anomaly
    overheating_risk = latest >= temp_danger or (rapid_increase and latest >= temp_warning)

    # ── Risk level ──
    if latest >= temp_danger or signal_count >= 4:
        risk_level = "HIGH"
    elif latest >= temp_warning or signal_count >= 2:
        risk_level = "MEDIUM"
    else:
        risk_level = "LOW"

    # ── Prediksi 30 menit ──
    predicted_temp = ewma_temp + (trend * 6)

    # ── Insights ──
    insights = []
    if threshold_anomaly:
        insights.append(f"Suhu {latest}°C melebihi batas kritis {temp_danger}°C")
    if rapid_increase:
        insights.append(f"Tren naik cepat: +{trend_per_hour:.1f}°C/jam")
    if z_anomaly_temp:
        insights.append(f"Z-score suhu tinggi: {z_temp:.2f}")
    if if_anomaly:
        insights.append(f"Isolation Forest score: {if_score:.3f}")
    if ewma_deviation:
        insights.append("Deviasi EWMA signifikan")
    if z_anomaly_hum:
        insights.append(f"Kelembapan anomali: {latest_hum:.1f}%")

    methods = ["moving_average", "ewma", "z_score", "linear_trend"]
    if len(readings) >= 10:
        methods.append("isolation_forest")

    return {
        "anomaly_detected":       anomaly_detected,
        "overheating_risk":       overheating_risk,
        "risk_level":             risk_level,
        "confidence":             int(confidence),
        "current_temp":           round(latest, 2),
        "current_humidity":       round(latest_hum, 2),
        "avg_temp":               round(avg_temp, 2),
        "ewma_temp":              round(ewma_temp, 2),
        "predicted_temp":         round(predicted_temp, 2),
        "z_score_temp":           round(z_temp, 3),
        "z_score_humidity":       round(z_hum, 3),
        "isolation_forest_score": round(if_score, 3),
        "trend_per_hour":         round(trend_per_hour, 2),
        "trend_direction":        "increasing" if trend > 0.05 else "decreasing" if trend < -0.05 else "stable",
        "methods_used":           methods,
        "insights":               insights,
        "signal_count":           signal_count,
    }
