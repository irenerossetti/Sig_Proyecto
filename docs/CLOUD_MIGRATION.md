# Migración a Arquitectura Cloud-Native

## 🎯 Arquitectura Objetivo

```
┌─────────────────────────────────────────────────────────────┐
│                         INTERNET                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ HTTPS (443)
                     │
        ┌────────────▼──────────────┐
        │    geoguard.site (DNS)    │
        │   Hostinger / Cloud DNS   │
        └────────────┬──────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         │                       │
         ▼                       ▼
┌────────────────┐      ┌────────────────┐
│   Cloud Run    │      │  VM Backend    │
│   (Next.js)    │◄─────┤   (Django)     │
│  geoguard-web  │ API  │  34.122.14.143 │
│                │      │   Port 8000    │
└────────┬───────┘      └────────┬───────┘
         │                       │
         │                       │ Cloud SQL Proxy
         │                       │
         │              ┌────────▼───────┐
         │              │   Cloud SQL    │
         │              │  PostgreSQL    │
         │              │  + PostGIS     │
         │              │  geoguard-db   │
         │              └────────────────┘
         │
         │              ┌────────────────┐
         └──────────────►  Cloud Storage │
                        │  (Media Files) │
                        └────────────────┘
```

## 📊 Comparación de Arquitecturas

### Antes (Todo en VM)
- **VM e2-medium**: Backend + Frontend + PostgreSQL
- **Costos**: ~$13/mes VM + storage
- **Escalabilidad**: Manual, requiere resize VM
- **Disponibilidad**: Single point of failure
- **Backups**: Manuales

### Después (Cloud-Native)
- **VM e2-medium**: Solo Backend Django
- **Cloud Run**: Frontend Next.js (auto-scale)
- **Cloud SQL**: Base de datos gestionada
- **Costos**: ~$20-25/mes total
- **Escalabilidad**: Automática (0 → N instancias)
- **Disponibilidad**: Alta (managed services)
- **Backups**: Automáticos (Cloud SQL)

## 🚀 Guía de Migración

### Pre-requisitos
- [ ] Cuenta GCP con billing habilitado
- [ ] gcloud CLI instalado y autenticado
- [ ] Acceso SSH a geoguard-vm
- [ ] Acceso a Hostinger DNS

### Paso 1: Configurar Cloud SQL

```bash
# Ejecutar script de configuración
bash setup-cloud-sql.sh
```

**Qué hace:**
- Crea instancia Cloud SQL PostgreSQL 15
- Configura tier `db-f1-micro` (7.5 GB RAM, 250 GB storage)
- Habilita backups automáticos diarios (3 AM UTC)
- Genera contraseña segura para usuario `postgres`
- Retiene 7 días de backups + transaction logs

**Salida esperada:**
```
✅ Cloud SQL configurado exitosamente!

📋 Información de conexión:
   Connection Name: geoguard-441521:us-central1:geoguard-db
   Database: geoguard
   User: postgres
   Password: [GENERADA_ALEATORIAMENTE]

🔗 Connection String para .env:
   DATABASE_URL=postgis://postgres:[PASSWORD]@/geoguard?host=/cloudsql/geoguard-441521:us-central1:geoguard-db
```

**⚠️ IMPORTANTE:** Guardar la contraseña generada de forma segura.

### Paso 2: Habilitar PostGIS (Manual)

```bash
# Conectar a Cloud SQL
gcloud sql connect geoguard-db --user=postgres

# Dentro de psql:
\c geoguard
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
\q
```

### Paso 3: Instalar Cloud SQL Proxy en VM

```bash
# Copiar script a VM
gcloud compute scp setup-cloud-sql-proxy.sh geoguard-vm:~ --zone=us-central1-a

# Ejecutar en VM
gcloud compute ssh geoguard-vm --zone=us-central1-a --command "bash ~/setup-cloud-sql-proxy.sh"
```

**Qué hace:**
- Descarga Cloud SQL Proxy v2.8.2
- Crea servicio systemd `cloud-sql-proxy.service`
- Inicia proxy escuchando en `127.0.0.1:5432`
- Backend se conecta a Cloud SQL como si fuera local

**Verificar:**
```bash
gcloud compute ssh geoguard-vm --zone=us-central1-a --command "sudo systemctl status cloud-sql-proxy"
```

### Paso 4: Migrar Datos a Cloud SQL

```bash
# En la VM, exportar datos actuales
gcloud compute ssh geoguard-vm --zone=us-central1-a

# Ejecutar script de migración
bash migrate-to-cloud-sql.sh
```

**Método 1: Via Cloud Storage (Recomendado)**
```bash
# Crear bucket si no existe
gsutil mb -p geoguard-441521 -l us-central1 gs://geoguard-backups/

# Subir dump
gsutil cp /tmp/geoguard-backup-*.sql gs://geoguard-backups/migration/

# Importar desde GCS
gcloud sql import sql geoguard-db \
  gs://geoguard-backups/migration/geoguard-backup-*.sql \
  --database=geoguard
```

**Método 2: Via psql directo**
```bash
# Conectar a Cloud SQL
gcloud sql connect geoguard-db --user=postgres --database=geoguard

# Importar dump
\i /tmp/geoguard-backup-*.sql
```

### Paso 5: Actualizar Backend para Cloud SQL

```bash
# Obtener contraseña de Cloud SQL del Paso 1
CLOUD_SQL_PASSWORD="[LA_CONTRASEÑA_GENERADA]"

# Actualizar .env en VM
gcloud compute ssh geoguard-vm --zone=us-central1-a

sudo nano /home/geoguard/backend/.env
# Cambiar:
# DATABASE_URL=postgis://postgres:OLD_PASSWORD@localhost:5432/geoguard
# Por:
# DATABASE_URL=postgis://postgres:CLOUD_SQL_PASSWORD@127.0.0.1:5432/geoguard

# Reiniciar backend
sudo systemctl restart geoguard-backend

# Verificar
sudo systemctl status geoguard-backend
curl http://localhost:8000/api/
```

**Verificar conectividad:**
```bash
# Ejecutar script de verificación
cd ~/backend
source .venv/bin/activate
python manage.py check
python manage.py showmigrations
```

### Paso 6: Preparar Next.js para Cloud Run

El `Dockerfile` y `next.config.ts` ya están configurados correctamente:
- ✅ `output: "standalone"` habilitado
- ✅ Dockerfile multi-stage optimizado
- ✅ Imagen base `node:20-alpine`

**Verificar localmente (opcional):**
```bash
cd web/

# Build imagen Docker
docker build -t geoguard-web .

# Probar localmente
docker run -p 3000:3000 \
  -e NEXT_PUBLIC_API_URL=http://34.122.14.143:8000/api \
  geoguard-web
```

### Paso 7: Desplegar a Cloud Run

```bash
# Ejecutar script de despliegue
bash deploy-web-cloud-run.sh
```

**Qué hace:**
1. Crea `.env.production` con `NEXT_PUBLIC_API_URL`
2. Build imagen Docker con Cloud Build
3. Push a Container Registry: `gcr.io/geoguard-441521/geoguard-web`
4. Deploy a Cloud Run con configuración:
   - Min instances: 0 (escala a cero cuando no hay tráfico)
   - Max instances: 10
   - Memory: 512 MB
   - CPU: 1 vCPU
   - Timeout: 60s
   - Unauthenticated access

**Salida esperada:**
```
✅ Despliegue completado exitosamente!

🌐 URL del servicio: https://geoguard-web-[HASH]-uc.a.run.app
```

**Probar URL temporal:**
```bash
curl -I https://geoguard-web-[HASH]-uc.a.run.app
```

### Paso 8: Configurar Dominio Personalizado

```bash
# Mapear dominio a Cloud Run
gcloud run domain-mappings create \
  --service=geoguard-web \
  --domain=geoguard.site \
  --region=us-central1

gcloud run domain-mappings create \
  --service=geoguard-web \
  --domain=www.geoguard.site \
  --region=us-central1
```

**Obtener registros DNS:**
```bash
gcloud run domain-mappings describe \
  --domain=geoguard.site \
  --region=us-central1
```

**Salida:**
```
resourceRecords:
- rrdata: ghs.googlehosted.com.
  type: CNAME
```

**Actualizar DNS en Hostinger:**
1. Login a Hostinger panel
2. Ir a DNS / Nameservers
3. Actualizar registros:
   ```
   Tipo    Nombre    Valor
   ────────────────────────────────────
   CNAME   @         ghs.googlehosted.com.
   CNAME   www       ghs.googlehosted.com.
   ```
4. Guardar y esperar propagación (5-15 minutos)

**Verificar DNS:**
```bash
nslookup geoguard.site
# Debe apuntar a googlehosted.com
```

### Paso 9: Actualizar CORS y ALLOWED_HOSTS

```bash
gcloud compute ssh geoguard-vm --zone=us-central1-a

# Editar .env
sudo nano /home/geoguard/backend/.env

# Actualizar:
CORS_ALLOWED_ORIGINS=https://geoguard.site,https://www.geoguard.site
ALLOWED_HOSTS=geoguard.site,www.geoguard.site,34.122.14.143,localhost

# Reiniciar backend
sudo systemctl restart geoguard-backend
```

### Paso 10: Limpiar VM (Opcional)

Ya no necesitamos Next.js corriendo en la VM:

```bash
gcloud compute ssh geoguard-vm --zone=us-central1-a

# Detener y deshabilitar servicio web
sudo systemctl stop geoguard-web
sudo systemctl disable geoguard-web

# Liberar recursos
sudo rm -rf /home/geoguard/web/.next
sudo rm -rf /home/geoguard/web/node_modules

# Opcional: detener PostgreSQL local si ya no se usa
sudo systemctl stop postgresql
sudo systemctl disable postgresql
```

## ✅ Verificación Final

### 1. Verificar Frontend
```bash
# Acceder a sitio
curl -I https://geoguard.site

# Debe retornar:
# HTTP/2 200
# content-type: text/html
# x-cloud-trace-context: [PRESENTE]
```

### 2. Verificar Backend
```bash
# Probar endpoint API
curl http://34.122.14.143:8000/api/

# Debe retornar respuesta JSON
```

### 3. Verificar Base de Datos
```bash
# Conectar a Cloud SQL
gcloud sql connect geoguard-db --user=postgres --database=geoguard

# Verificar datos
SELECT COUNT(*) FROM accounts_customuser;
SELECT COUNT(*) FROM monitoring_child;
\q
```

### 4. Verificar Login End-to-End
1. Acceder a https://geoguard.site/login
2. Ingresar credenciales: `geoguard@gmail.com` / `12345678*`
3. Verificar redirección a dashboard
4. Verificar datos cargan correctamente

## 📊 Monitoreo

### Logs de Cloud Run
```bash
# Ver logs en tiempo real
gcloud run logs tail geoguard-web --project=geoguard-441521

# Ver logs recientes
gcloud run logs read geoguard-web --limit=50
```

### Logs de Backend (VM)
```bash
gcloud compute ssh geoguard-vm --zone=us-central1-a --command "sudo journalctl -u geoguard-backend -f"
```

### Logs de Cloud SQL Proxy
```bash
gcloud compute ssh geoguard-vm --zone=us-central1-a --command "sudo journalctl -u cloud-sql-proxy -f"
```

### Métricas de Cloud Run
```bash
# Abrir en consola web
gcloud run services describe geoguard-web --region=us-central1
```

## 💰 Costos Estimados

| Servicio | Configuración | Costo/mes |
|----------|---------------|-----------|
| Cloud SQL | db-f1-micro (0.6 GB RAM) | ~$7 |
| Cloud Run | 512 MB RAM, escala a 0 | ~$0.50 |
| VM e2-medium | Backend Django | ~$13 |
| Cloud Storage | Media files | ~$0.50 |
| Cloud Build | Build triggers | Gratis (120 min/día) |
| **TOTAL** | | **~$21/mes** |

### Optimización de Costos

**Si el tráfico es muy bajo:**
- Cloud Run escala a 0 → $0 cuando no hay uso
- Cloud SQL: considerar auto-pause (no disponible para db-f1-micro)

**Si el tráfico crece:**
- Cloud Run auto-escala sin intervención
- Cloud SQL: upgrade a `db-g1-small` ($25/mes, 1.7 GB RAM)
- VM: mantener igual (solo backend)

## 🔐 Seguridad

### Checklist Post-Migración
- [ ] Cloud SQL: Backups automáticos habilitados
- [ ] Cloud SQL: No tiene IP pública (solo Cloud SQL Proxy)
- [ ] Cloud Run: HTTPS automático con certificado gestionado
- [ ] Backend: CORS configurado solo para dominio oficial
- [ ] Backend: ALLOWED_HOSTS restringido
- [ ] Secrets: Contraseñas en variables de entorno, no hardcoded
- [ ] Firewall: VM solo acepta tráfico en puerto 8000 desde Cloud Run

### Hardening Adicional
```bash
# En VM, restringir acceso SSH
gcloud compute firewall-rules create allow-ssh-from-iap \
  --allow=tcp:22 \
  --source-ranges=35.235.240.0/20 \
  --target-tags=geoguard-vm

# Deshabilitar SSH directo
gcloud compute instances remove-tags geoguard-vm \
  --tags=allow-ssh \
  --zone=us-central1-a
```

## 🚨 Rollback Plan

Si algo falla, rollback rápido:

### Rollback Frontend
```bash
# Apuntar DNS de vuelta a VM IP
# En Hostinger:
# A @ → 34.122.14.143
# A www → 34.122.14.143

# Reiniciar Next.js en VM
gcloud compute ssh geoguard-vm --zone=us-central1-a --command "
sudo systemctl enable geoguard-web
sudo systemctl start geoguard-web
"
```

### Rollback Database
```bash
# Restaurar PostgreSQL local
gcloud compute ssh geoguard-vm --zone=us-central1-a --command "
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Cambiar DATABASE_URL en .env
sudo sed -i 's|DATABASE_URL=.*|DATABASE_URL=postgis://postgres:l!inq4JoReIvT#gbG%zO@localhost:5432/geoguard|' /home/geoguard/backend/.env

# Reiniciar backend
sudo systemctl restart geoguard-backend
"
```

## 📞 Soporte

### Troubleshooting Común

**Error: Cloud Run no puede conectar a backend**
- Verificar CORS_ALLOWED_ORIGINS en backend `.env`
- Verificar firewall de VM permite tráfico desde Cloud Run IPs
- Solución temporal: Agregar `*` en CORS (solo para debug)

**Error: Backend no puede conectar a Cloud SQL**
- Verificar cloud-sql-proxy está corriendo: `sudo systemctl status cloud-sql-proxy`
- Verificar contraseña en DATABASE_URL es correcta
- Revisar logs: `sudo journalctl -u cloud-sql-proxy -n 50`

**Error: Sitio lento/timeout**
- Cloud Run: aumentar memory a 1 GB: `gcloud run services update geoguard-web --memory=1Gi`
- Cloud Run: aumentar min-instances a 1: `gcloud run services update geoguard-web --min-instances=1` (evita cold starts)
- Cloud SQL: upgrade a db-g1-small

**Error: 502 Bad Gateway**
- Backend caído: `gcloud compute ssh geoguard-vm --command "sudo systemctl status geoguard-backend"`
- VM sin recursos: `gcloud compute ssh geoguard-vm --command "free -h && df -h"`

## 🎓 Referencias

- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Next.js Deployment](https://nextjs.org/docs/deployment)
- [PostGIS Extension](https://cloud.google.com/sql/docs/postgres/extensions)
- [Cloud SQL Proxy](https://cloud.google.com/sql/docs/postgres/sql-proxy)

## 📝 Changelog

- **2024-12-06**: Creación de guía de migración
- **2024-12-06**: Scripts de automatización creados
- **2024-12-06**: Dockerfile optimizado para Cloud Run
