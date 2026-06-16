# GeoGuard - Guía de Deployment

Este documento explica las **dos formas** de hacer deployment en GeoGuard.

---

## 📋 Tabla de Contenidos

1. [Método 1: Script PowerShell (Recomendado para desarrollo)](#método-1-script-powershell)
2. [Método 2: GitHub Actions (Automático)](#método-2-github-actions)
3. [Comparación de Métodos](#comparación)
4. [Rollback](#rollback)
5. [Troubleshooting](#troubleshooting)

---

## Método 1: Script PowerShell

**🎯 Ideal para**: Desarrollo diario, testing, deployments rápidos

### Requisitos Previos

```powershell
# 1. Google Cloud SDK instalado
gcloud --version

# 2. Autenticado con GCP
gcloud auth login
gcloud config set project geoguard-478318

# 3. Acceso SSH configurado
gcloud compute ssh geoguard-vm --zone=us-central1-a --command="echo OK"
```

### Uso del Script

```powershell
# Deploy todo (backend + web)
.\deploy.ps1 -all

# Solo backend
.\deploy.ps1 -backend

# Solo web
.\deploy.ps1 -web

# Skip git operations (útil si ya hiciste commit/push)
.\deploy.ps1 -backend -skipGit
```

### ¿Qué hace el script?

1. **Git** (opcional):
   - Commit cambios locales
   - Push a `origin/main`

2. **Backend**:
   - Crea tarball excluyendo `.venv`, `__pycache__`, etc.
   - Sube a GCS (`gs://geoguard-media/backend.tar.gz`)
   - Hace backup en VM (`backend` → `backend_backup`)
   - Extrae nueva versión
   - Reinicia servicio `geoguard-backend`

3. **Web**:
   - Instala dependencias (`npm install`)
   - Build Next.js (`npm run build`)
   - Crea paquete standalone
   - Sube a GCS (`gs://geoguard-media/web-standalone.tar.gz`)
   - Hace backup en VM (`web` → `web_backup`)
   - Extrae nueva versión
   - Reinicia servicio `geoguard-web`

### Ventajas

✅ Muy rápido (2-3 minutos)  
✅ Control total del proceso  
✅ Gratis (sin límites de CI/CD)  
✅ Fácil debugging  
✅ Rollback automático en caso de error  

### Desventajas

❌ Requiere tener gcloud configurado localmente  
❌ Solo funciona desde tu máquina  

---

## Método 2: GitHub Actions

**🎯 Ideal para**: Producción, CI/CD automático, deployment desde cualquier lugar

### Configuración Inicial (Una sola vez)

#### 1. Crear Service Account

```bash
# Crear service account
gcloud iam service-accounts create github-deployer \
  --display-name="GitHub Actions Deployer"

# Dar permisos
gcloud projects add-iam-policy-binding geoguard-478318 \
  --member="serviceAccount:github-deployer@geoguard-478318.iam.gserviceaccount.com" \
  --role="roles/compute.instanceAdmin.v1"

gcloud projects add-iam-policy-binding geoguard-478318 \
  --member="serviceAccount:github-deployer@geoguard-478318.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

# Generar key
gcloud iam service-accounts keys create github-sa-key.json \
  --iam-account=github-deployer@geoguard-478318.iam.gserviceaccount.com
```

#### 2. Agregar Secret a GitHub

1. Ve a tu repo: `https://github.com/Joabits/SIG/settings/secrets/actions`
2. Click en **"New repository secret"**
3. Name: `GCP_SA_KEY`
4. Value: Pega el contenido completo de `github-sa-key.json`
5. Click **"Add secret"**

### Uso Automático

Los workflows se ejecutan automáticamente cuando:

- **Backend**: Push a `main` con cambios en `backend/**`
- **Web**: Push a `main` con cambios en `web/**`

```bash
# Commit y push
git add .
git commit -m "Update backend API"
git push origin main

# GitHub Actions se ejecuta automáticamente
# Ver progreso en: https://github.com/Joabits/SIG/actions
```

### Uso Manual (Workflow Dispatch)

1. Ve a: `https://github.com/Joabits/SIG/actions`
2. Selecciona workflow:
   - "Deploy Backend to GCE"
   - "Deploy Web to GCE"
3. Click en **"Run workflow"**
4. Selecciona branch `main`
5. Click **"Run workflow"**

### Ventajas

✅ Totalmente automático  
✅ Funciona desde cualquier lugar (solo necesitas hacer `git push`)  
✅ Logs públicos de cada deployment  
✅ Integración con PRs y reviews  
✅ Historial completo de deployments  

### Desventajas

❌ Más lento (5-8 minutos)  
❌ Consume minutos de GitHub Actions (2,000/mes gratis)  
❌ Más complejo de debuggear  

---

## Comparación

| Característica | PowerShell Script | GitHub Actions |
|---|---|---|
| **Velocidad** | ⚡ 2-3 min | 🐢 5-8 min |
| **Costo** | ✅ Gratis | ⚠️ 2,000 min/mes gratis |
| **Setup** | ✅ Muy simple | ⚠️ Requiere configuración |
| **Automatización** | ❌ Manual | ✅ Automático |
| **Debugging** | ✅ Fácil | ❌ Más difícil |
| **Rollback** | ✅ Automático | ⚠️ Manual |
| **Requiere local** | ❌ Sí | ✅ No |

---

## Rollback

### Con Script PowerShell

El rollback es automático si el deployment falla. También puedes hacerlo manualmente:

```bash
# Rollback backend
gcloud compute ssh geoguard-vm --zone=us-central1-a --command="
  sudo -u geoguard rm -rf /home/geoguard/backend
  sudo -u geoguard cp -r /home/geoguard/backend_backup /home/geoguard/backend
  sudo systemctl restart geoguard-backend
"

# Rollback web
gcloud compute ssh geoguard-vm --zone=us-central1-a --command="
  sudo -u geoweb rm -rf /home/geoweb/web
  sudo -u geoweb mv /home/geoweb/web_backup /home/geoweb/web
  sudo systemctl restart geoguard-web
"
```

### Con GitHub Actions

Re-run un workflow anterior exitoso:

1. Ve a `https://github.com/Joabits/SIG/actions`
2. Busca el deployment anterior que funcionaba
3. Click en **"Re-run all jobs"**

---

## Troubleshooting

### Error: "Permission denied"

```bash
# Verificar que estás autenticado
gcloud auth list

# Re-autenticar si es necesario
gcloud auth login
```

### Error: "Connection timeout" al hacer SSH

```bash
# Verificar que la VM está corriendo
gcloud compute instances list

# Verificar reglas de firewall
gcloud compute firewall-rules list | grep ssh
```

### Error: "Service failed to start"

```bash
# Ver logs del servicio
gcloud compute ssh geoguard-vm --zone=us-central1-a --command="
  sudo journalctl -u geoguard-backend -n 50
"

# O para web
gcloud compute ssh geoguard-vm --zone=us-central1-a --command="
  sudo journalctl -u geoguard-web -n 50
"
```

### Error: Build de Next.js falla

```bash
# Limpiar cache y rebuild
cd web
rm -rf .next node_modules
npm install
npm run build
```

### Ver estado de servicios

```bash
gcloud compute ssh geoguard-vm --zone=us-central1-a --command="
  sudo systemctl status geoguard-backend geoguard-web --no-pager
"
```

---

## Recomendación Final

**Para ti (desarrollo activo)**:

1. **Día a día**: Usa `deploy.ps1` (rápido y simple)
2. **Producción**: Deja GitHub Actions como respaldo automático

**Workflow sugerido**:

```powershell
# Desarrollo local
cd D:\SIG
# ... hacer cambios ...

# Deploy rápido
.\deploy.ps1 -backend

# Cuando esté estable, push a GitHub (trigger automático)
git push origin main
```

De esta forma tienes **lo mejor de ambos mundos**:
- Velocidad en desarrollo
- Automatización en producción
- Backup/rollback fácil
- Sin depender 100% de GitHub Actions

---

## URLs del Proyecto

- **Web Admin**: https://geoguard.site
- **API**: https://geoguard.site/api/
- **Django Admin**: https://geoguard.site/admin/
- **GitHub Actions**: https://github.com/Joabits/SIG/actions
- **GCP Console**: https://console.cloud.google.com/compute/instances?project=geoguard-478318
