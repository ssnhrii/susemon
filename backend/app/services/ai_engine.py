"""
SUSEMON AI Engine v2.1
Metode: Moving Average, EWMA, Z-score, Linear Trend, Isolation Forest
Kalibrasi untuk data server room: interval 10 detik, suhu stabil 24-35°C
"""
import math
import numpy as np
from datetime import datetime, timezone, timedelta
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


def adaptive_ewma(values: List[float], base_alpha: float = 0.2) -> float:
    """Adaptive EWMA: alpha meningkat jika terjadi perubahan baseline yang konsisten/cepat"""
    if not values:
        return 0.0
    result = values[0]
    consecutive_same_sign = 0
    last_sign = 0
    for v in values[1:]:
        diff = v - result
        abs_diff = abs(diff)
        
        # Tentukan tanda deviasi (abaikan noise sangat kecil < 0.05)
        current_sign = 1 if diff > 0.05 else -1 if diff < -0.05 else 0
        if current_sign == last_sign and current_sign != 0:
            consecutive_same_sign += 1
        else:
            consecutive_same_sign = 0
            last_sign = current_sign
            
        alpha = base_alpha
        # Jika deviasi besar (> 0.5°C), naikkan alpha
        if abs_diff > 0.5:
            alpha = min(0.6, base_alpha + 0.15 * (abs_diff - 0.5))
            
        # Jika terjadi pergeseran baseline permanen (deviasi searah >= 5x berturut-turut)
        if consecutive_same_sign >= 5:
            alpha = max(alpha, min(0.8, base_alpha + 0.1 * (consecutive_same_sign - 4)))
            
        result = alpha * v + (1 - alpha) * result
    return result


def holt_forecast(values: List[float], steps: float, alpha: float = 0.2, beta: float = 0.1) -> float:
    """Double Exponential Smoothing (Holt's Linear) untuk peramalan dengan tren"""
    if not values:
        return 0.0
    if len(values) < 2:
        return values[-1]
    
    level = values[0]
    trend = values[1] - values[0]
    
    for i in range(1, len(values)):
        val = values[i]
        last_level = level
        level = alpha * val + (1 - alpha) * (level + trend)
        trend = beta * (level - last_level) + (1 - beta) * trend
        
    return level + steps * trend


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


def fuzzy_decision_logic(temp_error: float, max_error: float, anomaly_score: float, data_factor: float = 1.0) -> (str, float):
    """
    Fuzzy Inference System (Mamdani/Sugeno-like) to determine risk level and confidence.
    
    Inputs:
    - temp_error: current_temp - temp_warning_adj
    - max_error: temp_danger_adj - temp_warning_adj (normalizes the temperature deviation)
    - anomaly_score: number of triggered anomaly signals (0 to 5)
    - data_factor: ratio of loaded data (lower data means lower confidence)
    
    Outputs:
    - risk_level: "LOW", "MEDIUM", or "HIGH"
    - confidence: float score between 50 and 98
    """
    # ── 1. Fuzzification ──
    # temp_error membership: Cool, Warm, Hot
    if max_error <= 0.1:
        max_error = 5.0
        
    # Cool: 1 at temp_error <= 0, 0 at temp_error >= max_error * 0.5
    u_cool = max(0.0, min(1.0, (max_error * 0.5 - temp_error) / (max_error * 0.5))) if temp_error > 0 else 1.0
    
    # Warm: triangle between 0 and max_error
    if temp_error <= 0:
        u_warm = 0.0
    elif temp_error <= max_error * 0.5:
        u_warm = temp_error / (max_error * 0.5)
    else:
        u_warm = max(0.0, (max_error - temp_error) / (max_error * 0.5))
        
    # Hot: 0 at temp_error <= max_error * 0.5, 1 at temp_error >= max_error
    u_hot = max(0.0, min(1.0, (temp_error - max_error * 0.5) / (max_error * 0.5))) if temp_error >= max_error * 0.5 else 0.0

    # anomaly_score membership: Normal (0-1), Suspicious (1-3), Critical (3-5)
    # Normal:
    u_normal = max(0.0, min(1.0, (2.0 - anomaly_score) / 2.0)) if anomaly_score > 0 else 1.0
    # Suspicious:
    if anomaly_score <= 1.0:
        u_suspicious = anomaly_score
    else:
        u_suspicious = max(0.0, (4.0 - anomaly_score) / 3.0)
    # Critical:
    u_critical = max(0.0, min(1.0, (anomaly_score - 1.0) / 2.0)) if anomaly_score >= 1.0 else 0.0

    # ── 2. Rule Evaluation & Defuzzification (Sugeno-like weighted output) ──
    # Rules define the target output centers for LOW (15-25), MEDIUM (40-75), HIGH (95)
    rules = [
        # (weight, target_center)
        (min(u_cool, u_normal), 15.0),
        (min(u_cool, u_suspicious), 25.0),
        (min(u_cool, u_critical), 45.0),
        (min(u_warm, u_normal), 40.0),
        (min(u_warm, u_suspicious), 55.0),
        (min(u_warm, u_critical), 75.0),
        (u_hot, 95.0)
    ]

    total_weight = 0.0
    weighted_sum = 0.0
    for weight, center in rules:
        weighted_sum += weight * center
        total_weight += weight

    if total_weight > 0.0:
        fuzzy_risk = weighted_sum / total_weight
    else:
        fuzzy_risk = 15.0 # default low

    # Determine risk_level and confidence based on fuzzy_risk
    if fuzzy_risk >= 70.0:
        risk_level = "HIGH"
    elif fuzzy_risk >= 35.0:
        risk_level = "MEDIUM"
    else:
        risk_level = "LOW"

    # Confidence calculation based on fuzzy risk, scaled by data_factor (range 60% - 98%)
    base_conf = 55.0 + (fuzzy_risk * 0.45)
    confidence = max(60.0, min(98.0, base_conf * (0.8 + 0.2 * data_factor)))
    
    return risk_level, round(confidence, 1)


def isolation_forest_score(readings: List[Dict]) -> float:
    """
    IF mendeteksi anomali multi-dimensi.
    Jika di awal deployment (data < 15), lakukan padding dengan data normal sintetis
    agar model tidak buta sejak awal.
    """
    if not readings:
        return 0.3

    X = np.array([[r["temperature"], r["humidity"]] for r in readings])
    
    if len(readings) < 15:
        # Pading data sintetis agar mencapai 15 data points
        avg_t = float(np.mean(X[:, 0])) if len(readings) > 0 else 27.0
        avg_h = float(np.mean(X[:, 1])) if len(readings) > 0 else 60.0
        
        # Generate synthetic points dengan seed statis agar deterministik
        np.random.seed(42)
        pad_size = 15 - len(readings)
        pad_t = np.random.normal(avg_t, 0.2, pad_size)
        pad_h = np.random.normal(avg_h, 1.0, pad_size)
        
        X_pad = np.column_stack((pad_t, pad_h))
        X = np.vstack((X_pad, X))

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

    temp_warning = float(thresholds.get("temp_warning", 35.0))
    temp_danger  = float(thresholds.get("temp_danger",  40.0))
    hum_warning  = float(thresholds.get("hum_warning",  80.0))
    hum_danger   = float(thresholds.get("hum_danger",   85.0))

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

    # ── Deteksi Seasonality (GMT+7) & Hysteresis Baseline ──
    try:
        latest_ts = readings[-1]["timestamp"]
        from datetime import datetime, timezone, timedelta
        if isinstance(latest_ts, str):
            try:
                dt = datetime.fromisoformat(latest_ts)
            except Exception:
                dt = datetime.now(timezone.utc)
        elif isinstance(latest_ts, datetime):
            dt = latest_ts
        else:
            dt = datetime.now(timezone.utc)
        
        # Konversi ke WIB (GMT+7) untuk waktu server room
        local_dt = dt.astimezone(timezone(timedelta(hours=7)))
    except Exception:
        from datetime import datetime, timezone, timedelta
        local_dt = datetime.now(timezone.utc).astimezone(timezone(timedelta(hours=7)))

    local_hour = local_dt.hour + local_dt.minute / 60.0
    
    # Model fluktuasi harian minimal — offset dikecilkan karena range threshold sudah sempit
    season_offset = math.cos((local_hour - 14) * math.pi / 12) * 0.5  # max ±0.5°C

    # Sesuaikan threshold dengan jam (seasonality aware)
    temp_warning_adj = temp_warning + season_offset
    temp_danger_adj  = temp_danger  + season_offset

    # ── De-seasonalize seluruh history data untuk statistik yang akurat ──
    deseason_temps = []
    for r in readings:
        try:
            r_ts = r["timestamp"]
            if isinstance(r_ts, str):
                try:
                    r_dt = datetime.fromisoformat(r_ts)
                except Exception:
                    r_dt = datetime.now(timezone.utc)
            elif isinstance(r_ts, datetime):
                r_dt = r_ts
            else:
                r_dt = datetime.now(timezone.utc)
            r_local = r_dt.astimezone(timezone(timedelta(hours=7)))
        except Exception:
            r_local = datetime.now(timezone.utc).astimezone(timezone(timedelta(hours=7)))
        r_hour = r_local.hour + r_local.minute / 60.0
        r_offset = math.cos((r_hour - 14) * math.pi / 12) * 0.5  # max ±0.5°C
        deseason_temps.append(float(r["temperature"]) - r_offset)

    latest_deseasonalized = latest - season_offset

    # ── Trend per jam dari timestamp aktual ──────────────────────────────────
    try:
        ts0 = _parse_ts(readings[0]["timestamp"])
        ts1 = _parse_ts(readings[-1]["timestamp"])
        span_h = (ts1 - ts0) / 3600.0 if ts1 > ts0 else 0.0
        if span_h > 0:
            mult = min((len(readings) - 1) / span_h, 360)  # max 1/10s equiv
        else:
            mult = 360
    except Exception:
        mult = 360

    # ── Statistik Seasonality-Aware ──────────────────────────────────────────
    avg_temp  = moving_average(temps)
    
    avg_deseason_temp = moving_average(deseason_temps)
    std_deseason_temp = std_dev(deseason_temps)
    
    # Batasi minimal std dev pada 0.2 untuk meminimalkan false positive ketika data sangat stabil
    z_t = z_score(latest_deseasonalized, avg_deseason_temp, max(std_deseason_temp, 0.2))
    
    # Rolling baseline EWMA adaptif dijalankan pada data deseasonalized
    ewma_temp = adaptive_ewma(deseason_temps)
    
    trend     = linear_trend(temps)
    trend_h   = trend * mult

    avg_hum  = moving_average(hums)
    std_hum  = std_dev(hums)
    z_h      = z_score(latest_hum, avg_hum, std_hum)

    # ── Deteksi sinyal ────────────────────────────────────────────────────
    # Threshold langsung — disesuaikan dengan seasonality
    above_danger  = latest >= temp_danger_adj  or latest_hum >= hum_danger
    above_warning = latest >= temp_warning_adj or latest_hum >= hum_warning

    # Z-score — threshold 2.5σ
    z_temp_anom = abs(z_t) > 2.5
    z_hum_anom  = abs(z_h) > 2.5

    # EWMA deviation — deteksi pergeseran gradual pada data deseasonalized
    ewma_dev = abs(latest_deseasonalized - ewma_temp) > max(2.0 * std_deseason_temp, 0.5) if std_deseason_temp > 0.1 else False

    # Trend cepat — >3°C/jam
    rapid = trend_h > 3.0

    # Isolation Forest — selalu aktif karena dibootstrap dengan synthetic data
    if_score  = isolation_forest_score(readings)
    if_anomaly = if_score > 0.75

    signals = [above_danger, z_temp_anom, z_hum_anom, ewma_dev, rapid, if_anomaly]
    signal_count = sum(1 for s in signals if s)

    # ── Confidence & Status (Fuzzy Logic Inference System) ─────────────────
    temp_error = latest - temp_warning_adj
    max_error = temp_danger_adj - temp_warning_adj
    data_factor = min(len(readings) / 50, 1.0)
    anomaly_score = float(signal_count)

    risk_level, confidence = fuzzy_decision_logic(temp_error, max_error, anomaly_score, data_factor)

    # ── Status ────────────────────────────────────────────────────────────
    anomaly_detected = (risk_level in ["MEDIUM", "HIGH"]) or above_danger or signal_count >= 2
    overheating_risk = (risk_level == "HIGH") or above_danger or (rapid and latest >= temp_warning_adj - 2)

    # ── Prediksi 30 menit (Hybrid Holt-Seasonal Forecasting) ──
    try:
        future_dt = local_dt + timedelta(minutes=30)
        future_hour = future_dt.hour + future_dt.minute / 60.0
        future_offset = math.cos((future_hour - 14) * math.pi / 12) * 1.0
        seasonality_change = future_offset - season_offset
    except Exception:
        seasonality_change = 0.0

    # Gunakan Holt's linear trend pada deseason_temps, lalu re-seasonalize dengan future_offset
    try:
        ts0 = _parse_ts(readings[0]["timestamp"])
        ts1 = _parse_ts(readings[-1]["timestamp"])
        span_s = ts1 - ts0
        if span_s > 0 and len(readings) > 1:
            dt_avg = span_s / (len(readings) - 1)
        else:
            dt_avg = 10.0
    except Exception:
        dt_avg = 10.0

    steps = 1800.0 / dt_avg if dt_avg > 1.0 else 180.0
    predicted_deseason = holt_forecast(deseason_temps, steps)
    predicted_temp = round(predicted_deseason + future_offset, 2)

    # ── Insights ──────────────────────────────────────────────────────────
    insights = []
    if latest >= temp_danger_adj:
        insights.append(f"Suhu {latest}°C melewati batas kritis disesuaikan ({temp_danger_adj:.1f}°C)")
    if latest_hum >= hum_danger:
        insights.append(f"Kelembapan {latest_hum}% melewati batas kritis ({hum_danger}%)")
    if overheating_risk and not (latest >= temp_danger_adj):
        insights.append(f"Risiko overheating: suhu {latest}°C naik cepat")
    if rapid:
        insights.append(f"Tren naik cepat: +{trend_h:.1f}°C/jam")
    if z_temp_anom:
        insights.append(f"Suhu abnormal secara statistik (z={z_t:.2f}σ)")
    if ewma_dev:
        insights.append(f"Deviasi dari tren normal: {latest_deseasonalized - ewma_temp:+.2f}°C")
    if if_anomaly:
        insights.append(f"Pola tidak biasa terdeteksi (skor: {if_score:.2f})")
    if z_hum_anom:
        insights.append(f"Kelembapan tidak normal: {latest_hum:.1f}% (z={z_h:.2f}σ)")
    if latest >= temp_warning_adj and latest < temp_danger_adj:
        insights.append(f"Mendekati batas: suhu {latest}°C (warning disesuaikan ≥{temp_warning_adj:.1f}°C)")

    methods = ["moving_average", "ewma", "z_score", "linear_trend", "isolation_forest"]

    return {
        "anomaly_detected":       anomaly_detected,
        "overheating_risk":       overheating_risk,
        "risk_level":             risk_level,
        "confidence":             confidence,
        "current_temp":           round(latest, 2),
        "current_humidity":       round(latest_hum, 2),
        "avg_temp":               round(avg_temp, 2),
        "ewma_temp":              round(ewma_temp + season_offset, 2), # kembalikan dalam bentuk raw/seasonal untuk display
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
