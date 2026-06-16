# 📡 GeoGuard - Documentación de API

## API REST Reference

---

## 🔐 Autenticación

GeoGuard utiliza autenticación basada en tokens (DRF TokenAuth).

### Obtener Token

**Endpoint:** `POST /api/auth/login/`

```json
// Request
{
  "email": "usuario@email.com",
  "password": "contraseña123"
}

// Response 200
{
  "token": "9944b09199c62bcf9418ad846dd0e4bbdfc6ee4b",
  "user": {
    "id": 1,
    "email": "usuario@email.com",
    "full_name": "Juan Pérez",
    "phone": "+591 70000000",
    "is_admin": false
  }
}

// Response 401
{
  "error": "Credenciales inválidas"
}
```

### Registrar Usuario

**Endpoint:** `POST /api/auth/register/`

```json
// Request
{
  "full_name": "Juan Pérez",
  "email": "usuario@email.com",
  "password": "contraseña123",
  "phone": "+591 70000000"  // opcional
}

// Response 201
{
  "token": "9944b09199c62bcf9418ad846dd0e4bbdfc6ee4b",
  "user": {
    "id": 1,
    "email": "usuario@email.com",
    "full_name": "Juan Pérez"
  }
}
```

### Cerrar Sesión

**Endpoint:** `POST /api/auth/logout/`

```
Headers:
  Authorization: Token 9944b09199c62bcf9418ad846dd0e4bbdfc6ee4b

// Response 200
{
  "message": "Sesión cerrada exitosamente"
}
```

### Usar Token en Requests

Incluir en todas las peticiones autenticadas:

```
Headers:
  Authorization: Token 9944b09199c62bcf9418ad846dd0e4bbdfc6ee4b
  Content-Type: application/json
```

---

## 👶 Niños (Children)

### Listar Niños

**Endpoint:** `GET /api/monitoring/children/`

Retorna solo los niños del tutor autenticado.

```json
// Response 200
{
  "count": 2,
  "results": [
    {
      "id": 1,
      "full_name": "María García",
      "birth_date": "2019-05-15",
      "photo": "https://storage.googleapis.com/bucket/children/1/photo.jpg",
      "notes": "Alérgica al maní",
      "is_in_safe_zone": true,
      "last_known_location": {
        "latitude": -17.7833,
        "longitude": -63.1821,
        "timestamp": "2025-01-15T10:30:00Z"
      },
      "device": {
        "id": 1,
        "identifier": "TRACK-001",
        "battery_level": 85,
        "is_active": true,
        "last_seen": "2025-01-15T10:30:00Z"
      },
      "safe_zones": [1, 2],
      "created_at": "2025-01-01T00:00:00Z"
    }
  ]
}
```

### Crear Niño

**Endpoint:** `POST /api/monitoring/children/`

```json
// Request (multipart/form-data para incluir foto)
{
  "full_name": "María García",
  "birth_date": "2019-05-15",
  "photo": <archivo>,  // opcional
  "notes": "Alérgica al maní"  // opcional
}

// Response 201
{
  "id": 1,
  "full_name": "María García",
  ...
}
```

### Obtener Niño

**Endpoint:** `GET /api/monitoring/children/{id}/`

### Actualizar Niño

**Endpoint:** `PATCH /api/monitoring/children/{id}/`

### Eliminar Niño

**Endpoint:** `DELETE /api/monitoring/children/{id}/`

---

## 📍 Dispositivos (Devices)

### Listar Dispositivos

**Endpoint:** `GET /api/monitoring/devices/`

```json
// Response 200
{
  "count": 1,
  "results": [
    {
      "id": 1,
      "identifier": "TRACK-001",
      "child": 1,
      "is_active": true,
      "battery_level": 85,
      "last_latitude": -17.7833,
      "last_longitude": -63.1821,
      "last_seen": "2025-01-15T10:30:00Z",
      "created_at": "2025-01-01T00:00:00Z"
    }
  ]
}
```

### Registrar Dispositivo

**Endpoint:** `POST /api/monitoring/devices/`

```json
// Request
{
  "identifier": "TRACK-001",
  "child": 1  // ID del niño a vincular
}

// Response 201
{
  "id": 1,
  "identifier": "TRACK-001",
  "child": 1,
  "pairing_code": "ABC123"  // código para vincular desde tracker
}
```

### Vincular Dispositivo (desde Tracker)

**Endpoint:** `POST /api/monitoring/devices/pair/`

```json
// Request
{
  "pairing_code": "ABC123",
  "device_info": {
    "model": "Samsung Galaxy A12",
    "os_version": "Android 12"
  }
}

// Response 200
{
  "device_id": 1,
  "child_id": 1,
  "token": "tracker-specific-token"
}
```

### Actualizar Ubicación (desde Tracker)

**Endpoint:** `POST /api/monitoring/devices/{id}/update_location/`

```json
// Request
{
  "latitude": -17.7833,
  "longitude": -63.1821,
  "accuracy": 10.5,
  "altitude": 416.0,
  "speed": 0.0,
  "battery_level": 84,
  "timestamp": "2025-01-15T10:35:00Z"
}

// Response 200
{
  "status": "ok",
  "is_in_safe_zone": true,
  "alerts_generated": []
}
```

### Envío por Lotes (Batch)

**Endpoint:** `POST /api/monitoring/devices/{id}/batch_locations/`

```json
// Request
{
  "locations": [
    {
      "latitude": -17.7833,
      "longitude": -63.1821,
      "accuracy": 10.5,
      "battery_level": 85,
      "timestamp": "2025-01-15T10:30:00Z"
    },
    {
      "latitude": -17.7834,
      "longitude": -63.1822,
      "accuracy": 8.0,
      "battery_level": 84,
      "timestamp": "2025-01-15T10:31:00Z"
    }
  ]
}

// Response 200
{
  "processed": 2,
  "alerts_generated": 0
}
```

---

## 🗺️ Zonas Seguras (Safe Zones)

### Listar Zonas

**Endpoint:** `GET /api/monitoring/safe-zones/`

```json
// Response 200
{
  "count": 2,
  "results": [
    {
      "id": 1,
      "name": "Kinder San José",
      "zone_type": "polygon",
      "center_latitude": -17.7833,
      "center_longitude": -63.1821,
      "radius": null,
      "polygon_coordinates": [
        {"lat": -17.7830, "lng": -63.1825},
        {"lat": -17.7830, "lng": -63.1815},
        {"lat": -17.7840, "lng": -63.1815},
        {"lat": -17.7840, "lng": -63.1825}
      ],
      "color": "#4CAF50",
      "is_active": true,
      "children": [1, 2],
      "created_at": "2025-01-01T00:00:00Z"
    },
    {
      "id": 2,
      "name": "Casa",
      "zone_type": "circle",
      "center_latitude": -17.7900,
      "center_longitude": -63.1900,
      "radius": 50.0,
      "polygon_coordinates": null,
      "color": "#2196F3",
      "is_active": true,
      "children": [1],
      "created_at": "2025-01-02T00:00:00Z"
    }
  ]
}
```

### Crear Zona Circular

**Endpoint:** `POST /api/monitoring/safe-zones/`

```json
// Request
{
  "name": "Casa",
  "zone_type": "circle",
  "center_latitude": -17.7900,
  "center_longitude": -63.1900,
  "radius": 50.0,
  "color": "#2196F3",
  "children": [1]
}

// Response 201
{
  "id": 2,
  "name": "Casa",
  ...
}
```

### Crear Zona Poligonal

**Endpoint:** `POST /api/monitoring/safe-zones/`

```json
// Request
{
  "name": "Kinder San José",
  "zone_type": "polygon",
  "center_latitude": -17.7835,  // centro calculado
  "center_longitude": -63.1820,
  "polygon_coordinates": [
    {"lat": -17.7830, "lng": -63.1825},
    {"lat": -17.7830, "lng": -63.1815},
    {"lat": -17.7840, "lng": -63.1815},
    {"lat": -17.7840, "lng": -63.1825}
  ],
  "color": "#4CAF50",
  "children": [1, 2]
}

// Response 201
{
  "id": 1,
  ...
}
```

### Verificar Punto en Zona

**Endpoint:** `POST /api/monitoring/safe-zones/{id}/check_point/`

```json
// Request
{
  "latitude": -17.7835,
  "longitude": -63.1820
}

// Response 200
{
  "is_inside": true,
  "zone_name": "Kinder San José"
}
```

---

## 🔔 Alertas (Alerts)

### Listar Alertas

**Endpoint:** `GET /api/monitoring/alerts/`

Parámetros opcionales:
- `status`: `pending`, `acknowledged`, `resolved`
- `child`: ID del niño
- `start_date`: Fecha inicio (ISO 8601)
- `end_date`: Fecha fin (ISO 8601)

```json
// Response 200
{
  "count": 5,
  "results": [
    {
      "id": 1,
      "child": {
        "id": 1,
        "full_name": "María García"
      },
      "alert_type": "zone_exit",
      "message": "María García salió de la zona 'Kinder San José'",
      "latitude": -17.7845,
      "longitude": -63.1830,
      "status": "pending",
      "is_acknowledged": false,
      "acknowledged_at": null,
      "created_at": "2025-01-15T10:35:00Z",
      "safe_zone": {
        "id": 1,
        "name": "Kinder San José"
      }
    }
  ]
}
```

### Reconocer Alerta

**Endpoint:** `POST /api/monitoring/alerts/{id}/acknowledge/`

```json
// Response 200
{
  "id": 1,
  "status": "acknowledged",
  "is_acknowledged": true,
  "acknowledged_at": "2025-01-15T10:40:00Z"
}
```

### Resolver Alerta

**Endpoint:** `POST /api/monitoring/alerts/{id}/resolve/`

```json
// Request (opcional)
{
  "resolution_notes": "Niño recogido por el padre"
}

// Response 200
{
  "id": 1,
  "status": "resolved",
  "resolved_at": "2025-01-15T10:45:00Z"
}
```

---

## 📊 Analytics y Reportes

### Estadísticas de Movimiento

**Endpoint:** `GET /api/monitoring/analytics/movement_stats/`

Parámetros:
- `child_id`: ID del niño (requerido)
- `start_date`: Fecha inicio
- `end_date`: Fecha fin

```json
// Response 200
{
  "child_id": 1,
  "period": {
    "start": "2025-01-01T00:00:00Z",
    "end": "2025-01-15T23:59:59Z"
  },
  "total_locations": 1500,
  "unique_days": 15,
  "average_locations_per_day": 100,
  "zone_time": {
    "Kinder San José": "120:30:00",
    "Casa": "180:45:00"
  }
}
```

### Estadísticas de Alertas

**Endpoint:** `GET /api/monitoring/analytics/alert_stats/`

```json
// Response 200
{
  "period": "2025-01",
  "total_alerts": 25,
  "by_type": {
    "zone_exit": 15,
    "zone_entry": 8,
    "low_battery": 2
  },
  "by_status": {
    "pending": 3,
    "acknowledged": 10,
    "resolved": 12
  },
  "average_response_time": "00:05:30"
}
```

### Resumen del Dashboard

**Endpoint:** `GET /api/monitoring/analytics/dashboard_summary/`

```json
// Response 200
{
  "children": {
    "total": 10,
    "in_zone": 8,
    "out_of_zone": 2
  },
  "devices": {
    "total": 10,
    "active": 9,
    "online": 8
  },
  "alerts": {
    "today": 5,
    "this_week": 15,
    "pending": 3
  },
  "safe_zones": 12,
  "location_updates_today": 850,
  "recent_alerts": [
    {
      "id": 1,
      "child_name": "María García",
      "alert_type": "zone_exit",
      "message": "...",
      "status": "pending",
      "created_at": "2025-01-15T10:35:00Z"
    }
  ]
}
```

### Exportar Reporte

**Endpoint:** `GET /api/monitoring/reports/export/`

Parámetros:
- `report_type`: `summary`, `alerts`, `movement_history`
- `format`: `json`, `csv`
- `start_date`: Fecha inicio
- `end_date`: Fecha fin
- `child_id`: ID del niño (opcional)

```bash
# Ejemplo
GET /api/monitoring/reports/export/?report_type=alerts&format=csv&start_date=2025-01-01

# Response: archivo CSV descargable
```

---

## 🔄 WebSocket - Ubicación en Tiempo Real

### Conexión

```javascript
const ws = new WebSocket('wss://api.geoguard.app/ws/locations/?token=YOUR_TOKEN');

ws.onopen = () => {
  // Suscribirse a niños
  ws.send(JSON.stringify({
    type: 'subscribe',
    child_ids: [1, 2, 3]
  }));
};
```

### Mensajes Recibidos

**Actualización de ubicación:**
```json
{
  "type": "location_update",
  "child_id": 1,
  "data": {
    "latitude": -17.7833,
    "longitude": -63.1821,
    "accuracy": 10.5,
    "battery_level": 85,
    "is_in_safe_zone": true,
    "timestamp": "2025-01-15T10:35:00Z"
  }
}
```

**Nueva alerta:**
```json
{
  "type": "alert",
  "child_id": 1,
  "data": {
    "id": 1,
    "alert_type": "zone_exit",
    "message": "María García salió de la zona segura",
    "latitude": -17.7845,
    "longitude": -63.1830,
    "created_at": "2025-01-15T10:35:00Z"
  }
}
```

**Estado de dispositivo:**
```json
{
  "type": "device_status",
  "child_id": 1,
  "data": {
    "device_id": 1,
    "is_online": true,
    "battery_level": 84,
    "last_seen": "2025-01-15T10:36:00Z"
  }
}
```

### Ping/Pong (Keep-alive)

```json
// Enviar cada 30 segundos
{"type": "ping"}

// Respuesta
{"type": "pong"}
```

---

## 📋 Códigos de Estado HTTP

| Código | Significado |
|--------|-------------|
| 200 | OK - Solicitud exitosa |
| 201 | Created - Recurso creado |
| 204 | No Content - Eliminación exitosa |
| 400 | Bad Request - Datos inválidos |
| 401 | Unauthorized - Token inválido/ausente |
| 403 | Forbidden - Sin permisos |
| 404 | Not Found - Recurso no existe |
| 429 | Too Many Requests - Rate limit |
| 500 | Internal Server Error |

## 🚫 Rate Limiting

- Límite general: 100 requests/minuto
- Actualización de ubicación: 10 requests/segundo por dispositivo
- Login: 5 intentos/minuto

---

*Versión API: 1.0*
*Última actualización: Enero 2025*
