from pydantic import BaseModel, field_validator
from datetime import datetime
from typing import Optional, List, Any


# ── Auth ──────────────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    ip_address: str
    access_code: str

class LoginResponse(BaseModel):
    success: bool
    message: str
    data: Optional[dict] = None


# ── Sensor ────────────────────────────────────────────────────────────────────

class SensorDataIn(BaseModel):
    node_id: str
    temperature: float
    humidity: float

    @field_validator('temperature')
    @classmethod
    def validate_temp(cls, v):
        if not (-40 <= v <= 125):
            raise ValueError(f'Suhu {v} di luar range sensor (-40 s/d 125°C)')
        return round(v, 2)

    @field_validator('humidity')
    @classmethod
    def validate_hum(cls, v):
        if not (0 <= v <= 100):
            raise ValueError(f'Kelembapan {v} di luar range (0-100%)')
        return round(v, 2)

    @field_validator('node_id')
    @classmethod
    def validate_node_id(cls, v):
        import re
        if not re.match(r'^[A-Za-z0-9_\-]{1,20}$', v):
            raise ValueError('node_id hanya boleh alfanumerik, dash, underscore (max 20 karakter)')
        return v

class SensorReading(BaseModel):
    id: int
    node_id: str
    temperature: float
    humidity: float
    status: str
    timestamp: datetime
    node_name: Optional[str] = None
    location: Optional[str] = None

class SensorNode(BaseModel):
    id: int
    node_id: str
    node_name: str
    location: str
    is_active: bool
    current_temp: Optional[float] = None
    current_humidity: Optional[float] = None
    current_status: Optional[str] = None


# ── Notification ──────────────────────────────────────────────────────────────

class Notification(BaseModel):
    id: int
    node_id: Optional[str] = None
    title: str
    message: str
    type: str
    is_read: bool
    created_at: datetime
    node_name: Optional[str] = None
    location: Optional[str] = None


# ── AI ────────────────────────────────────────────────────────────────────────

class AiAnalysisResult(BaseModel):
    node_id: str
    node_name: Optional[str] = None
    location: Optional[str] = None
    anomaly_detected: bool
    overheating_risk: bool
    risk_level: str
    confidence: int
    current_temp: Optional[float] = None
    current_humidity: Optional[float] = None
    avg_temp: Optional[float] = None
    ewma_temp: Optional[float] = None
    predicted_temp: Optional[float] = None
    z_score_temp: Optional[float] = None
    z_score_humidity: Optional[float] = None
    isolation_forest_score: Optional[float] = None
    trend_per_hour: Optional[float] = None
    trend_direction: Optional[str] = None
    methods_used: List[str] = []
    insights: List[str] = []
    signal_count: int = 0
    status: Optional[str] = None

class AiSummary(BaseModel):
    global_status: str
    anomaly_count: int
    overheat_count: int
    hottest_node: Optional[str]
    hottest_temp: float
    active_nodes: int
    stats_24h: dict


# ── Generic response ──────────────────────────────────────────────────────────

class ApiResponse(BaseModel):
    success: bool
    message: Optional[str] = None
    data: Optional[Any] = None
