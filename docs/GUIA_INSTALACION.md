# 🔧 GeoGuard - Guía de Instalación

## Guía Técnica de Instalación y Configuración

---

## 📋 Tabla de Contenidos

1. [Requisitos Previos](#requisitos-previos)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Instalación del Backend (Django)](#instalación-del-backend)
4. [Instalación del Panel Web (Next.js)](#instalación-del-panel-web)
5. [Compilación de la App Móvil (Flutter)](#compilación-de-la-app-móvil)
6. [Compilación de la App Tracker (Flutter)](#compilación-de-la-app-tracker)
7. [Configuración de Firebase](#configuración-de-firebase)
8. [Configuración de Base de Datos](#configuración-de-base-de-datos)
9. [Despliegue en Producción](#despliegue-en-producción)
10. [Variables de Entorno](#variables-de-entorno)

---

## 📦 Requisitos Previos

### Herramientas de Desarrollo

```bash
# Python (Backend)
Python 3.10+ 
pip 21.0+

# Node.js (Web)
Node.js 18.0+
npm 9.0+ o pnpm

# Flutter (Mobile)
Flutter 3.10+
Dart 3.0+
Android Studio (para Android)
Xcode (para iOS, solo macOS)

# Base de Datos
PostgreSQL 14+ con extensión PostGIS
# o
SQLite 3.35+ (solo desarrollo)

# Otros
Git 2.30+
Docker (opcional, para producción)
```

### Verificar Instalaciones

```bash
python --version
node --version
flutter doctor
psql --version
git --version
```

---

## 🏗️ Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                      CLIENTES                               │
├─────────────────┬─────────────────┬─────────────────────────┤
│   App Móvil     │   App Tracker   │    Panel Web            │
│   (Flutter)     │   (Flutter)     │    (Next.js)            │
│   Puerto: N/A   │   Puerto: N/A   │    Puerto: 3000         │
└────────┬────────┴────────┬────────┴────────────┬────────────┘
         │                 │                      │
         │     HTTPS/WSS   │                      │
         └────────────────┬┴──────────────────────┘
                          │
         ┌────────────────▼────────────────┐
         │         API GATEWAY             │
         │         (Nginx)                 │
         │         Puerto: 80/443          │
         └────────────────┬────────────────┘
                          │
         ┌────────────────▼────────────────┐
         │         BACKEND                 │
         │         (Django + DRF)          │
         │         Puerto: 8000            │
         │         WebSocket: Channels     │
         └────────────────┬────────────────┘
                          │
         ┌────────────────▼────────────────┐
         │         BASE DE DATOS           │
         │         (PostgreSQL + PostGIS)  │
         │         Puerto: 5432            │
         └─────────────────────────────────┘
```

---

## 🐍 Instalación del Backend

### 1. Clonar el Repositorio

```bash
git clone https://github.com/tu-organizacion/geoguard.git
cd geoguard/backend
```

### 2. Crear Entorno Virtual

```bash
# Windows
python -m venv venv
venv\Scripts\activate

# Linux/macOS
python3 -m venv venv
source venv/bin/activate
```

### 3. Instalar Dependencias

```bash
pip install -r requirements.txt
```

### 4. Configurar Variables de Entorno

```bash
# Copiar plantilla
cp .env.example .env

# Editar .env con tus valores
```

Contenido mínimo de `.env`:

```env
# Django
SECRET_KEY=tu-clave-secreta-muy-larga-y-segura
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1,10.0.2.2

# Base de datos
DATABASE_URL=postgres://usuario:password@localhost:5432/geoguard
# o para desarrollo rápido:
# DATABASE_URL=sqlite:///db.sqlite3

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:3000

# Firebase (opcional)
GOOGLE_APPLICATION_CREDENTIALS=./firebase-credentials.json

# Google Cloud Storage (opcional)
GCS_BUCKET_NAME=geoguard-media
```

### 5. Ejecutar Migraciones

```bash
python manage.py makemigrations
python manage.py migrate
```

### 6. Crear Superusuario

```bash
python manage.py createsuperuser
```

### 7. Ejecutar Servidor de Desarrollo

```bash
# Para acceso desde emulador/dispositivos
python manage.py runserver 0.0.0.0:8000

# Solo local
python manage.py runserver
```

### 8. Verificar Instalación

```bash
# Abrir en navegador
http://localhost:8000/admin/
http://localhost:8000/api/
```

---

## 🌐 Instalación del Panel Web

### 1. Navegar al Directorio

```bash
cd geoguard/web
```

### 2. Instalar Dependencias

```bash
npm install
# o
pnpm install
```

### 3. Configurar Variables de Entorno

```bash
# Crear archivo .env.local
touch .env.local
```

Contenido de `.env.local`:

```env
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_WS_URL=ws://localhost:8000
```

### 4. Ejecutar en Desarrollo

```bash
npm run dev
# o
pnpm dev
```

### 5. Verificar Instalación

```bash
# Abrir en navegador
http://localhost:3000
```

### 6. Compilar para Producción

```bash
npm run build
npm start
```

---

## 📱 Compilación de la App Móvil

### 1. Navegar al Directorio

```bash
cd geoguard/mobile
```

### 2. Instalar Dependencias

```bash
flutter pub get
```

### 3. Configurar API Base

Editar `lib/core/constants/api_constants.dart`:

```dart
class ApiConstants {
  // Para emulador Android
  static const String baseUrl = 'http://10.0.2.2:8000';
  
  // Para dispositivo físico (usa IP de tu computadora)
  // static const String baseUrl = 'http://192.168.1.100:8000';
  
  // Para producción
  // static const String baseUrl = 'https://api.geoguard.app';
}
```

O usar variable de entorno al compilar:

```bash
flutter run --dart-define=GEOGUARD_API_BASE=http://tu-servidor:8000
```

### 4. Configurar Firebase

1. Crear proyecto en Firebase Console
2. Agregar app Android/iOS
3. Descargar `google-services.json` (Android)
4. Colocar en `android/app/google-services.json`

### 5. Ejecutar en Desarrollo

```bash
# Listar dispositivos
flutter devices

# Ejecutar en dispositivo específico
flutter run -d <device_id>

# Ejecutar en Chrome (web)
flutter run -d chrome
```

### 6. Compilar APK (Android)

```bash
# APK de depuración
flutter build apk --debug

# APK de release
flutter build apk --release

# Bundle para Play Store
flutter build appbundle --release
```

El APK se genera en: `build/app/outputs/flutter-apk/app-release.apk`

### 7. Compilar iOS (solo macOS)

```bash
flutter build ios --release
```

---

## 📍 Compilación de la App Tracker

### 1. Navegar al Directorio

```bash
cd geoguard/tracker
```

### 2. Instalar Dependencias

```bash
flutter pub get
```

### 3. Configurar API Base

Similar a la app móvil, editar constantes o usar `--dart-define`.

### 4. Permisos Especiales (Android)

Verificar `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

### 5. Compilar APK

```bash
flutter build apk --release
```

---

## 🔥 Configuración de Firebase

### 1. Crear Proyecto

1. Ir a [Firebase Console](https://console.firebase.google.com)
2. Crear nuevo proyecto
3. Habilitar Cloud Messaging

### 2. Configurar Android

1. Agregar app Android con package name: `com.geoguard.mobile`
2. Descargar `google-services.json`
3. Colocar en `mobile/android/app/` y `tracker/android/app/`

### 3. Configurar Backend

1. Ir a Configuración del Proyecto > Cuentas de servicio
2. Generar nueva clave privada
3. Guardar como `backend/firebase-credentials.json`
4. Configurar variable de entorno:

```env
GOOGLE_APPLICATION_CREDENTIALS=./firebase-credentials.json
```

### 4. Verificar Configuración

```bash
# En el backend
python manage.py shell
>>> from monitoring.firebase_service import FirebaseService
>>> fs = FirebaseService()
>>> print("Firebase OK" if fs.initialized else "Firebase Error")
```

---

## 🗄️ Configuración de Base de Datos

### PostgreSQL con PostGIS

```bash
# Instalar PostgreSQL
# Ubuntu/Debian
sudo apt install postgresql postgresql-contrib postgis

# macOS (Homebrew)
brew install postgresql postgis

# Windows: Descargar instalador de postgresql.org
```

### Crear Base de Datos

```bash
# Acceder a PostgreSQL
sudo -u postgres psql

# Crear usuario y base de datos
CREATE USER geoguard WITH PASSWORD 'tu_password';
CREATE DATABASE geoguard_db OWNER geoguard;

# Habilitar extensión espacial
\c geoguard_db
CREATE EXTENSION postgis;

# Salir
\q
```

### Configurar DATABASE_URL

```env
DATABASE_URL=postgres://geoguard:tu_password@localhost:5432/geoguard_db
```

### Migraciones con PostGIS

Las migraciones se generan automáticamente. Si hay problemas:

```bash
python manage.py migrate --run-syncdb
```

---

## 🚀 Despliegue en Producción

### Docker Compose

Crear `docker-compose.yml` en la raíz:

```yaml
version: '3.8'

services:
  db:
    image: postgis/postgis:14-3.3
    environment:
      POSTGRES_DB: geoguard
      POSTGRES_USER: geoguard
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: always

  backend:
    build: ./backend
    environment:
      - DATABASE_URL=postgres://geoguard:${DB_PASSWORD}@db:5432/geoguard
      - SECRET_KEY=${SECRET_KEY}
      - ALLOWED_HOSTS=${ALLOWED_HOSTS}
    depends_on:
      - db
    restart: always

  web:
    build: ./web
    environment:
      - NEXT_PUBLIC_API_URL=${API_URL}
    depends_on:
      - backend
    restart: always

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - backend
      - web
    restart: always

volumes:
  postgres_data:
```

### Ejecutar con Docker

```bash
# Crear archivo .env con variables de producción
cp .env.example .env
# Editar .env con valores de producción

# Iniciar servicios
docker-compose up -d

# Ver logs
docker-compose logs -f

# Ejecutar migraciones
docker-compose exec backend python manage.py migrate
```

### Configuración de Nginx

```nginx
# nginx.conf
upstream backend {
    server backend:8000;
}

upstream web {
    server web:3000;
}

server {
    listen 80;
    server_name geoguard.app;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name geoguard.app;

    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    location /api/ {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /ws/ {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location / {
        proxy_pass http://web;
        proxy_set_header Host $host;
    }
}
```

---

## 🔐 Variables de Entorno

### Backend (.env)

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `SECRET_KEY` | Clave secreta de Django | `abc123...` |
| `DEBUG` | Modo debug | `False` |
| `ALLOWED_HOSTS` | Hosts permitidos | `geoguard.app,api.geoguard.app` |
| `DATABASE_URL` | URL de conexión a BD | `postgres://user:pass@host:5432/db` |
| `CORS_ALLOWED_ORIGINS` | Orígenes CORS | `https://geoguard.app` |
| `GOOGLE_APPLICATION_CREDENTIALS` | Ruta a credenciales Firebase | `./firebase-credentials.json` |
| `GCS_BUCKET_NAME` | Bucket de Google Cloud Storage | `geoguard-media` |

### Web (.env.local)

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `NEXT_PUBLIC_API_URL` | URL del API | `https://api.geoguard.app` |
| `NEXT_PUBLIC_WS_URL` | URL WebSocket | `wss://api.geoguard.app` |

### Mobile/Tracker (--dart-define)

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `GEOGUARD_API_BASE` | URL base del API | `https://api.geoguard.app` |

---

## 🧪 Verificación de Instalación

### Checklist Backend

- [ ] Django admin accesible en `/admin/`
- [ ] API responde en `/api/`
- [ ] Migraciones aplicadas sin errores
- [ ] Superusuario creado
- [ ] Firebase configurado (si aplica)

### Checklist Web

- [ ] Página carga sin errores
- [ ] Login funciona
- [ ] Conexión con API exitosa
- [ ] Mapas cargan correctamente

### Checklist Mobile

- [ ] App compila sin errores
- [ ] Login funciona
- [ ] GPS obtiene ubicación
- [ ] Notificaciones funcionan

### Checklist Tracker

- [ ] App compila sin errores
- [ ] Servicio de ubicación activo
- [ ] Sincronización con servidor
- [ ] Detección de geofencing

---

## 🆘 Soporte Técnico

Para problemas de instalación:

1. Revisar logs: `docker-compose logs` o consola de Django/Flutter
2. Verificar variables de entorno
3. Consultar [Solución de Problemas](./TROUBLESHOOTING.md)
4. Contactar: dev@geoguard.app

---

*Versión: 1.0*
*Última actualización: Enero 2025*
