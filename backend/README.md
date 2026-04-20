# 🚀 SUSEMON Backend API

Backend API untuk aplikasi SUSEMON (Suhu dan Kelembapan Server Monitoring) - Smart Server Monitoring System dengan AI.

## 📋 Fitur

- ✅ RESTful API dengan Express.js
- ✅ MySQL Database
- ✅ JWT Authentication
- ✅ WebSocket untuk real-time updates
- ✅ AI Prediction (Moving Average + Z-score)
- ✅ Sensor data management
- ✅ Notification system
- ✅ CORS enabled

## 🛠️ Tech Stack

- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: MySQL
- **WebSocket**: ws
- **Authentication**: JWT (jsonwebtoken)
- **ORM**: mysql2 (Promise-based)

## 📦 Installation

### 1. Install Dependencies

```bash
cd "susemon backend"
npm install
```

### 2. Setup Database

Pastikan MySQL sudah running, lalu jalankan:

```bash
npm run init-db
```

Script ini akan:
- Create database `susemon_db`
- Create 6 tables (users, sensor_nodes, sensor_data, notifications, ai_predictions, system_logs)
- Insert sample data
- Create 2 default users

### 3. Configure Environment

Copy `.env.example` ke `.env` dan sesuaikan:

```env
PORT=3000
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=
DB_NAME=susemon_db
```

### 4. Start Server

**Development mode (with nodemon):**
```bash
npm run dev
```

**Production mode:**
```bash
npm start
```

Server akan running di:
- HTTP API: `http://localhost:3000`
- WebSocket: `ws://localhost:3001`

## 📡 API Endpoints

### Authentication

#### POST `/api/auth/login`
Login dengan IP Address dan Access Code

**Request:**
```json
{
  "ip_address": "127.0.0.1",
  "access_code": "ADMIN123"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Login berhasil",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "ip_address": "127.0.0.1",
      "name": "Admin Local"
    }
  }
}
```

#### GET `/api/auth/verify`
Verify JWT token (requires Bearer token)

### Sensors

#### GET `/api/sensors/nodes`
Get all sensor nodes with latest data

**Headers:** `Authorization: Bearer <token>`

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "node_id": "A1",
      "node_name": "Node Sensor A1",
      "location": "Rack Server Utama",
      "current_temp": 28.5,
      "current_humidity": 65.2,
      "current_status": "AMAN"
    }
  ]
}
```

#### GET `/api/sensors/latest`
Get latest data from all nodes

#### GET `/api/sensors/data/:node_id?period=24h&limit=20`
Get sensor data history

**Query params:**
- `period`: 24h, 7d, 30d
- `limit`: number of records

#### POST `/api/sensors/data`
Add new sensor data (from LoRa gateway)

**Request:**
```json
{
  "node_id": "A1",
  "temperature": 28.5,
  "humidity": 65.2
}
```

#### GET `/api/sensors/statistics?period=24h`
Get statistics (avg, max, min, counts)

### AI Prediction

#### GET `/api/ai/prediction/:node_id`
Get AI prediction for specific node

**Response:**
```json
{
  "success": true,
  "data": {
    "node_id": "A1",
    "current_temp": 28.5,
    "predicted_temp": "29.2",
    "moving_average": "28.7",
    "z_score": "0.45",
    "risk_level": "LOW",
    "confidence": 91,
    "trend": "increasing"
  }
}
```

#### GET `/api/ai/analysis`
Get AI analysis for all nodes

### Notifications

#### GET `/api/notifications?limit=20&unread_only=false`
Get notifications

#### GET `/api/notifications/unread-count`
Get unread notification count

#### PUT `/api/notifications/:id/read`
Mark notification as read

## 🔌 WebSocket

Connect to `ws://localhost:3001` untuk real-time updates.

**Message Types:**

1. **Connection**
```json
{
  "type": "connection",
  "message": "Connected to SUSEMON WebSocket server",
  "timestamp": "2026-04-18T10:30:00.000Z"
}
```

2. **Sensor Update** (every 3 seconds)
```json
{
  "type": "sensor_update",
  "data": [
    {
      "node_id": "A1",
      "temperature": 28.5,
      "humidity": 65.2,
      "status": "AMAN",
      "node_name": "Node Sensor A1",
      "location": "Rack Server Utama"
    }
  ],
  "timestamp": "2026-04-18T10:30:00.000Z"
}
```

## 🗄️ Database Schema

### Tables

1. **users** - User authentication
2. **sensor_nodes** - Sensor node configuration
3. **sensor_data** - Sensor readings
4. **notifications** - System notifications
5. **ai_predictions** - AI prediction results
6. **system_logs** - System logs

### Default Users

| IP Address | Access Code | Name |
|------------|-------------|------|
| 127.0.0.1 | ADMIN123 | Admin Local |
| 192.168.1.100 | SUSEMON2026 | Admin Network |

## 🧪 Testing

### Test Health Check
```bash
curl http://localhost:3000/api/health
```

### Test Login
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"ip_address":"127.0.0.1","access_code":"ADMIN123"}'
```

### Test Get Nodes (with token)
```bash
curl http://localhost:3000/api/sensors/nodes \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

## 📊 AI Algorithm

Backend menggunakan algoritma sederhana untuk prediksi:

1. **Moving Average**: Rata-rata 10 data terakhir
2. **Z-Score**: Deteksi anomali berdasarkan standar deviasi
3. **Linear Trend**: Prediksi suhu 30 menit kedepan

**Risk Levels:**
- `HIGH`: Z-score > 2.5 (Confidence: 94%)
- `MEDIUM`: Z-score > 1.5 (Confidence: 87%)
- `LOW`: Z-score < 1.5 (Confidence: 91%)

## 🔧 Development

### Project Structure
```
susemon backend/
├── src/
│   ├── config/
│   │   └── database.js          # Database connection
│   ├── controllers/
│   │   ├── authController.js    # Authentication logic
│   │   ├── sensorController.js  # Sensor CRUD
│   │   ├── aiController.js      # AI prediction
│   │   └── notificationController.js
│   ├── middleware/
│   │   └── authMiddleware.js    # JWT verification
│   ├── models/                  # (Future: Sequelize models)
│   ├── routes/
│   │   ├── index.js            # Main router
│   │   ├── authRoutes.js
│   │   ├── sensorRoutes.js
│   │   ├── aiRoutes.js
│   │   └── notificationRoutes.js
│   ├── services/               # (Future: Business logic)
│   ├── utils/
│   │   └── initDatabase.js     # Database initialization
│   └── server.js               # Main server file
├── .env                        # Environment variables
├── .env.example               # Environment template
├── package.json
└── README.md
```

## 🚀 Deployment

### Production Checklist

- [ ] Set `NODE_ENV=production`
- [ ] Use strong `JWT_SECRET`
- [ ] Configure proper database credentials
- [ ] Enable HTTPS
- [ ] Set up process manager (PM2)
- [ ] Configure firewall
- [ ] Set up monitoring
- [ ] Enable database backups

### PM2 Deployment

```bash
npm install -g pm2
pm2 start src/server.js --name susemon-api
pm2 save
pm2 startup
```

## 📝 License

MIT License - PBL-TRPL412 Politeknik Negeri Bali

## 👥 Team

- **Project ID**: PBL-TRPL412
- **Institution**: Politeknik Negeri Bali
- **Program**: TRPL 4C Malam

---

**Status**: ✅ Production Ready
**Version**: 1.0.0
**Last Update**: 18 April 2026
