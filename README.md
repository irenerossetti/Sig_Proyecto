# 🛡️ GeoGuard

## Sistema de Monitoreo Infantil Basado en Geolocalización

GeoGuard es una solución integral para el monitoreo en tiempo real de niños preescolares, diseñada para instituciones educativas y tutores en Santa Cruz de la Sierra, Bolivia.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Django](https://img.shields.io/badge/Django-5.1-green.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.10+-blue.svg)
![Next.js](https://img.shields.io/badge/Next.js-15-black.svg)

---

## 🎯 Problema que Resuelve

En Santa Cruz de la Sierra no existe una herramienta en tiempo real que avise cuando un niño preescolar sale del kinder. Los controles manuales son lentos y costosos. GeoGuard proporciona alertas tempranas para evitar pérdidas, accidentes o secuestros.

## ✨ Características Principales

### 📱 Aplicación del Tutor (Flutter)
- Dashboard con estado de todos los niños
- Mapa en tiempo real con ubicación actual
- Historial de movimientos
- Gestión de zonas seguras
- Notificaciones push instantáneas
- Reconocimiento de alertas

### 📍 Aplicación Tracker (Flutter)
- Rastreo GPS en segundo plano
- Geofencing local (respuesta < 1 segundo)
- Cola offline con SQLite
- Sincronización automática al reconectar
- Optimización de batería
- WebSocket para tiempo real

### 🖥️ Panel Web (Next.js)
- Dashboard administrativo
- Mapa interactivo con Leaflet
- Editor de zonas seguras (polígonos/círculos)
- Reportes y estadísticas
- Exportación CSV/JSON
- Gestión de usuarios

### 🔧 Backend (Django)
- API REST con Django REST Framework
- WebSocket para ubicaciones en tiempo real
- Autenticación por token
- Notificaciones push con Firebase
- Análisis espacial de geofencing
- Soporte PostgreSQL/PostGIS

---

## 🏗️ Arquitectura Cloud-Native

```
┌─────────────────────────────────────────────────────────────┐
│                         INTERNET                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ HTTPS (443)
                     │
        ┌────────────▼──────────────┐
        │    geoguard.site (DNS)    │
        └────────────┬──────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
┌────────────────┐      ┌────────────────┐
│   Cloud Run    │      │  VM Backend    │
│   (Next.js)    │◄─────┤   (Django)     │
│  geoguard-web  │ API  │  Daphne ASGI   │
│                │      │   Port 8000    │
└────────┬───────┘      └────────┬───────┘
         │                       │
         │                       │ Cloud SQL Proxy
         │              ┌────────▼───────┐
         │              │   Cloud SQL    │
         │              │  PostgreSQL    │
         │              │  + PostGIS     │
         │              └────────────────┘
         │
         │              ┌────────────────┐
         └──────────────►  Cloud Storage │
                        │  (Media Files) │
                        └────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      CLIENTES                               │
├─────────────────┬─────────────────┬─────────────────────────┤
│   App Tutor     │   App Tracker   │   Panel Web Admin       │
│   (Flutter)     │   (Flutter)     │   (Cloud Run)           │
│   - Dashboard   │   - GPS Track   │   - Next.js 15          │
│   - Alerts      │   - Geofencing  │   - TypeScript          │
│   - Push Notif  │   - Offline Q   │   - Leaflet Maps        │
└─────────────────┴─────────────────┴─────────────────────────┘
```

### ☁️ Ventajas de la Arquitectura Cloud

- **Escalabilidad Automática**: Cloud Run escala de 0 → N según demanda
- **Alta Disponibilidad**: Servicios gestionados con 99.9% SLA
- **Backups Automáticos**: Cloud SQL backups diarios + point-in-time recovery
- **HTTPS Automático**: Certificados SSL gestionados por Google
- **Optimización de Costos**: Paga solo por uso real (~$21/mes)
- **Separación de Responsabilidades**: Frontend, backend y DB en capas independientes

---

## 📁 Estructura del Proyecto

```
geoguard/
├── backend/                 # Django API
│   ├── accounts/           # Autenticación y usuarios
│   ├── monitoring/         # Modelos principales (Child, Device, SafeZone, Alert)
│   └── geoguard/          # Configuración Django
│
├── mobile/                  # App Flutter del Tutor
│   └── lib/
│       ├── core/           # Constantes, tema, router
│       └── features/       # Módulos (auth, monitoring)
│
├── tracker/                 # App Flutter Tracker
│   └── lib/
│       ├── core/           # Configuración
│       └── services/       # LocationService, GeofenceService, OfflineQueue
│
├── web/                     # Panel Next.js
│   ├── app/                # Rutas y páginas
│   ├── components/         # Componentes UI y mapas
│   └── lib/                # API, tipos, utilidades
│
└── docs/                    # Documentación
    ├── MANUAL_USUARIO.md
    ├── GUIA_INSTALACION.md
    └── API_REFERENCE.md
```

---

## 🚀 Inicio Rápido

### Requisitos Previos

- Python 3.10+
- Node.js 18+
- Flutter 3.10+
- PostgreSQL 14+ (opcional, SQLite para desarrollo)

### 1. Backend

```bash
cd backend

# Crear entorno virtual
python -m venv venv
source venv/bin/activate  # Linux/Mac
# o: venv\Scripts\activate  # Windows

# Instalar dependencias
pip install -r requirements.txt

# Configurar variables de entorno
cp .env.example .env
# Editar .env con tus valores

# Ejecutar migraciones
python manage.py migrate

# Crear superusuario
python manage.py createsuperuser

# Iniciar servidor
python manage.py runserver 0.0.0.0:8000
```

### 2. Panel Web

```bash
cd web

# Instalar dependencias
npm install

# Configurar variables
echo "NEXT_PUBLIC_API_URL=http://localhost:8000" > .env.local

# Iniciar en desarrollo
npm run dev
```

### 3. App Móvil (Tutor)

```bash
cd mobile

# Instalar dependencias
flutter pub get

# Ejecutar en emulador
flutter run
```

### 4. App Tracker

```bash
cd tracker

# Instalar dependencias
flutter pub get

# Ejecutar
flutter run
```

---

## 📖 Documentación

- [Manual de Usuario](docs/MANUAL_USUARIO.md) - Guía para tutores y administradores
- [Guía de Instalación](docs/GUIA_INSTALACION.md) - Instalación técnica detallada
- [Migración a Cloud](docs/CLOUD_MIGRATION.md) - **Arquitectura Cloud SQL + Cloud Run**
- [Despliegue en VM](docs/DESPLIEGUE_VM.md) - Deploy en Google Compute Engine
- [Referencia de API](docs/API_REFERENCE.md) - Documentación completa de endpoints

---

## 🔐 Seguridad

- Autenticación mediante tokens DRF
- HTTPS obligatorio en producción
- Datos sensibles cifrados
- CORS configurado estrictamente
- Rate limiting en endpoints críticos

---

## 🗺️ Funcionalidades GIS

### Zonas Seguras
- **Circulares**: Centro + radio en metros
- **Poligonales**: Múltiples vértices para formas personalizadas

### Geofencing
- **Servidor**: Análisis espacial con PostGIS
- **Local (Tracker)**: Algoritmo ray-casting para polígonos, Haversine para círculos
- **Tiempo de respuesta**: < 1 segundo para alertas locales

### Visualización
- Leaflet para mapas interactivos
- Dibujo de zonas con leaflet-draw
- Marcadores personalizados por estado

---

## 📊 Reportes

- Tendencia de alertas por período
- Distribución por tipo de alerta
- Estado de dispositivos
- Niveles de batería
- Exportación a CSV/JSON

---

## 🔔 Sistema de Alertas

| Tipo | Descripción | Notificación |
|------|-------------|--------------|
| Salida de zona | Niño abandona área segura | Push + Email |
| Entrada a zona | Niño ingresa a zona | Push |
| Batería baja | Tracker < 20% | Push |
| Dispositivo offline | Sin conexión > 5 min | Push |

---

## 🛠️ Tecnologías

### Backend
- Django 5.1
- Django REST Framework
- Django Channels (WebSocket)
- PostgreSQL + PostGIS
- Firebase Cloud Messaging

### Web
- Next.js 15
- React 19
- TypeScript
- Tailwind CSS
- Leaflet + react-leaflet
- Recharts

### Mobile
- Flutter 3.10+
- Riverpod (estado)
- GoRouter (navegación)
- Geolocator
- sqflite (offline)
- Firebase Messaging

---

## 🤝 Contribuir

1. Fork el repositorio
2. Crea una rama (`git checkout -b feature/nueva-funcionalidad`)
3. Commit cambios (`git commit -am 'Añade nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver [LICENSE](LICENSE) para más detalles.

---

## 👥 Equipo

Desarrollado como proyecto de Sistema de Información Geográfica para la Universidad.

---

## � Troubleshooting

### 502 Bad Gateway en Producción

Si el sitio web muestra error 502:

1. **Verificar servicios**:
```bash
sudo systemctl status geoguard-backend
sudo systemctl status geoguard-web
sudo systemctl status nginx
```

2. **Problema común**: Si `geoguard-web` está crasheando con "Permission denied" al cambiar directorio:
```bash
# Editar el archivo de servicio
sudo nano /etc/systemd/system/geoguard-web.service

# Cambiar:
ProtectHome=true
# Por:
ProtectHome=read-only

# Aplicar cambios
sudo systemctl daemon-reload
sudo systemctl restart geoguard-web
```

3. **Verificar logs**:
```bash
sudo journalctl -u geoguard-web -n 50 --no-pager
sudo journalctl -u geoguard-backend -n 50 --no-pager
```

4. **Health check automático**:
```bash
./check-services.sh
```

### Backend no responde

- Verificar que Daphne está corriendo en puerto 8000
- Revisar firewall: `sudo ufw status`
- Verificar PostgreSQL: `sudo systemctl status postgresql`

### App móvil no conecta

- Verificar `API_BASE_URL` en constantes
- Revisar logs del backend: `python manage.py runserver`
- Verificar CORS_ALLOWED_ORIGINS en `.env`

---

## 📞 Soporte

- **Email**: soporte@geoguard.app
- **Issues**: [GitHub Issues](https://github.com/tu-org/geoguard/issues)

---

*Última actualización: Diciembre 2025*
