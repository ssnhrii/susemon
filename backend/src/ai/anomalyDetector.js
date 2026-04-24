/**
 * SUSEMON AI Engine
 * Metode: Moving Average, EWMA, Z-score, Isolation Forest (manual JS)
 * Multi-parameter: suhu + kelembapan kombinasi
 */

// ── Moving Average ────────────────────────────────────────────────────────────

function movingAverage(values) {
  if (!values.length) return 0;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

// ── EWMA (Exponentially Weighted Moving Average) ──────────────────────────────

function ewma(values, alpha = 0.3) {
  if (!values.length) return 0;
  let result = values[0];
  for (let i = 1; i < values.length; i++) {
    result = alpha * values[i] + (1 - alpha) * result;
  }
  return result;
}

// ── Standard Deviation ────────────────────────────────────────────────────────

function stdDev(values) {
  if (values.length < 2) return 0;
  const avg = movingAverage(values);
  const variance = values.reduce((sum, v) => sum + Math.pow(v - avg, 2), 0) / values.length;
  return Math.sqrt(variance);
}

// ── Z-score ───────────────────────────────────────────────────────────────────

function zScore(value, avg, std) {
  if (std === 0) return 0;
  return (value - avg) / std;
}

// ── Linear Trend ──────────────────────────────────────────────────────────────

function linearTrend(values) {
  const n = values.length;
  if (n < 2) return 0;
  // Least squares slope
  const xMean = (n - 1) / 2;
  const yMean = movingAverage(values);
  let num = 0, den = 0;
  for (let i = 0; i < n; i++) {
    num += (i - xMean) * (values[i] - yMean);
    den += Math.pow(i - xMean, 2);
  }
  return den === 0 ? 0 : num / den;
}

// ── Isolation Forest (simplified, pure JS) ───────────────────────────────────
// Menggunakan random partitioning untuk mendeteksi outlier

class IsolationTree {
  constructor(data, maxDepth, depth = 0) {
    this.size = data.length;
    if (depth >= maxDepth || data.length <= 1) {
      this.isLeaf = true;
      return;
    }
    // Pilih feature dan split point secara random
    const featureIdx = Math.floor(Math.random() * data[0].length);
    const vals = data.map(d => d[featureIdx]);
    const min = Math.min(...vals);
    const max = Math.max(...vals);
    if (min === max) { this.isLeaf = true; return; }

    this.featureIdx = featureIdx;
    this.splitVal   = min + Math.random() * (max - min);
    this.isLeaf     = false;

    const left  = data.filter(d => d[featureIdx] < this.splitVal);
    const right = data.filter(d => d[featureIdx] >= this.splitVal);
    this.left  = new IsolationTree(left,  maxDepth, depth + 1);
    this.right = new IsolationTree(right, maxDepth, depth + 1);
  }

  pathLength(point, depth = 0) {
    if (this.isLeaf) return depth + _c(this.size);
    if (point[this.featureIdx] < this.splitVal) {
      return this.left.pathLength(point, depth + 1);
    }
    return this.right.pathLength(point, depth + 1);
  }
}

// Average path length untuk BST dengan n nodes
function _c(n) {
  if (n <= 1) return 0;
  return 2 * (Math.log(n - 1) + 0.5772156649) - (2 * (n - 1) / n);
}

class IsolationForest {
  constructor(nTrees = 50, sampleSize = 20) {
    this.nTrees     = nTrees;
    this.sampleSize = sampleSize;
    this.trees      = [];
  }

  fit(data) {
    this.trees = [];
    const maxDepth = Math.ceil(Math.log2(this.sampleSize));
    for (let i = 0; i < this.nTrees; i++) {
      // Random subsample
      const sample = [];
      const n = Math.min(this.sampleSize, data.length);
      const indices = new Set();
      while (indices.size < n) indices.add(Math.floor(Math.random() * data.length));
      indices.forEach(idx => sample.push(data[idx]));
      this.trees.push(new IsolationTree(sample, maxDepth));
    }
  }

  anomalyScore(point) {
    if (!this.trees.length) return 0.5;
    const avgPath = this.trees.reduce((sum, t) => sum + t.pathLength(point), 0) / this.trees.length;
    const c = _c(this.sampleSize);
    if (c === 0) return 0.5;
    return Math.pow(2, -avgPath / c);
  }

  // score > 0.6 = anomali, > 0.7 = anomali kuat
  isAnomaly(point, threshold = 0.6) {
    return this.anomalyScore(point) > threshold;
  }
}

// ── Main Analyzer ─────────────────────────────────────────────────────────────

/**
 * Analisis lengkap untuk satu node
 * @param {Array} readings - [{temperature, humidity, timestamp}]
 * @param {Object} thresholds - {tempWarning, tempDanger, humWarning, humDanger}
 * @returns {Object} hasil analisis
 */
function analyzeNode(readings, thresholds = {}) {
  const {
    tempWarning = 35,
    tempDanger  = 40,
    humWarning  = 70,
    humDanger   = 80,
  } = thresholds;

  if (!readings || readings.length < 3) {
    return {
      status: 'INSUFFICIENT_DATA',
      anomaly_detected: false,
      overheating_risk: false,
      confidence: 0,
      methods_used: [],
    };
  }

  const temps = readings.map(r => parseFloat(r.temperature));
  const hums  = readings.map(r => parseFloat(r.humidity));
  const latest = temps[temps.length - 1];
  const latestHum = hums[hums.length - 1];

  // ── Statistik dasar ──
  const avgTemp  = movingAverage(temps);
  const stdTemp  = stdDev(temps);
  const ewmaTemp = ewma(temps);
  const zTemp    = zScore(latest, avgTemp, stdTemp);
  const trend    = linearTrend(temps);

  const avgHum   = movingAverage(hums);
  const stdHum   = stdDev(hums);
  const zHum     = zScore(latestHum, avgHum, stdHum);

  // ── Threshold check ──
  const thresholdAnomaly = latest >= tempDanger || latestHum >= humDanger;
  const thresholdWarning = latest >= tempWarning || latestHum >= humWarning;

  // ── Z-score anomaly ──
  const zAnomalyTemp = Math.abs(zTemp) > 2.0;
  const zAnomalyHum  = Math.abs(zHum)  > 2.0;

  // ── EWMA deviation ──
  const ewmaDeviation = Math.abs(latest - ewmaTemp) > (2 * stdTemp);

  // ── Isolation Forest (multi-parameter) ──
  let ifScore = 0.5;
  let ifAnomaly = false;
  if (readings.length >= 10) {
    const points = readings.map(r => [
      parseFloat(r.temperature),
      parseFloat(r.humidity),
    ]);
    const forest = new IsolationForest(30, Math.min(20, readings.length));
    forest.fit(points);
    ifScore   = forest.anomalyScore([latest, latestHum]);
    ifAnomaly = ifScore > 0.6;
  }

  // ── Trend analysis ──
  const trendPerHour = trend * 12; // asumsi data per 5 menit
  const rapidIncrease = trendPerHour > 2.0; // naik > 2°C/jam

  // ── Gabungkan semua sinyal ──
  const signals = [
    thresholdAnomaly,
    zAnomalyTemp,
    zAnomalyHum,
    ewmaDeviation,
    ifAnomaly,
    rapidIncrease,
  ];
  const signalCount = signals.filter(Boolean).length;

  // Confidence berdasarkan jumlah sinyal yang aktif
  let confidence = 50 + signalCount * 8;
  confidence = Math.min(confidence, 98);

  const anomalyDetected = signalCount >= 2 || thresholdAnomaly;
  const overheatingRisk = latest >= tempDanger || (rapidIncrease && latest >= tempWarning);

  // ── Risk level ──
  let riskLevel = 'LOW';
  if (latest >= tempDanger || signalCount >= 4) riskLevel = 'HIGH';
  else if (latest >= tempWarning || signalCount >= 2) riskLevel = 'MEDIUM';

  // ── Prediksi 30 menit ke depan ──
  // 30 menit = 6 interval (asumsi 5 menit/interval)
  const predictedTemp = ewmaTemp + (trend * 6);

  // ── Insight teks ──
  const insights = [];
  if (thresholdAnomaly)  insights.push(`Suhu ${latest}°C melebihi batas kritis ${tempDanger}°C`);
  if (rapidIncrease)     insights.push(`Tren naik cepat: +${trendPerHour.toFixed(1)}°C/jam`);
  if (zAnomalyTemp)      insights.push(`Z-score suhu tinggi: ${zTemp.toFixed(2)}`);
  if (ifAnomaly)         insights.push(`Isolation Forest score: ${ifScore.toFixed(3)}`);
  if (ewmaDeviation)     insights.push(`Deviasi EWMA signifikan`);
  if (zAnomalyHum)       insights.push(`Kelembapan anomali: ${latestHum.toFixed(1)}%`);

  return {
    anomaly_detected: anomalyDetected,
    overheating_risk: overheatingRisk,
    risk_level: riskLevel,
    confidence: Math.round(confidence),
    current_temp: latest,
    current_humidity: latestHum,
    avg_temp: parseFloat(avgTemp.toFixed(2)),
    ewma_temp: parseFloat(ewmaTemp.toFixed(2)),
    predicted_temp: parseFloat(predictedTemp.toFixed(2)),
    z_score_temp: parseFloat(zTemp.toFixed(3)),
    z_score_humidity: parseFloat(zHum.toFixed(3)),
    isolation_forest_score: parseFloat(ifScore.toFixed(3)),
    trend_per_hour: parseFloat(trendPerHour.toFixed(2)),
    trend_direction: trend > 0.05 ? 'increasing' : trend < -0.05 ? 'decreasing' : 'stable',
    methods_used: ['moving_average', 'ewma', 'z_score', readings.length >= 10 ? 'isolation_forest' : null, 'linear_trend'].filter(Boolean),
    insights,
    signal_count: signalCount,
  };
}

module.exports = { analyzeNode, movingAverage, ewma, stdDev, zScore, linearTrend, IsolationForest };
