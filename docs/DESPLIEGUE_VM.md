# Guía de Despliegue en Google Cloud VM

## 📋 Requisitos Previos

1. **VM de Google Cloud** con Ubuntu 20.04+ o Debian
2. **Dominio configurado**: `geoguard.site` apuntando a la IP de tu VM
3. **Puertos abiertos**: 80, 443, 8000, 3000

## 🚀 Configuración Inicial de la VM (Solo una vez)

### 1. Conectarse a la VM

```bash
gcloud compute ssh nombre-de-tu-vm --zone=tu-zona
```

### 2. Instalar dependencias

```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Instalar Node.js y npm
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Instalar PM2 para Node.js
sudo npm install -g pm2

# Instalar Nginx
sudo apt install -y nginx

# Instalar Certbot para SSL
sudo apt install -y certbot python3-certbot-nginx

# Instalar Git
sudo apt install -y git
```

### 3. Clonar repositorio

```bash
cd ~
git clone TU_REPOSITORIO_URL geoguard
cd geoguard
```

### 4. Configurar Backend

```bash
cd backend

# Copiar y editar variables de entorno
cp .env.production .env
nano .env

# Actualizar estos valores:
# SECRET_KEY=genera_una_clave_fuerte_aqui
# GEOGUARD_ADMIN_SECRET=otra_clave_fuerte_aqui
# ALLOWED_HOSTS=geoguard.site,www.geoguard.site,IP_DE_TU_VM
```

### 5. Configurar Nginx

```bash
# Copiar configuración
sudo cp ../nginx-geoguard.conf /etc/nginx/sites-available/geoguard

# Crear enlace simbólico
sudo ln -s /etc/nginx/sites-available/geoguard /etc/nginx/sites-enabled/

# Remover configuración default
sudo rm /etc/nginx/sites-enabled/default

# Verificar configuración
sudo nginx -t
```

### 6. Obtener certificado SSL (Let's Encrypt)

```bash
sudo certbot --nginx -d geoguard.site -d www.geoguard.site
```

### 7. Configurar firewall

```bash
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

## 🔄 Despliegue (Cada vez que actualices)

### Opción A: Script automático

```bash
cd ~/geoguard
bash deploy-vm.sh
```

### Opción B: Manual

```bash
cd ~/geoguard

# 1. Actualizar código
git pull origin main

# 2. Backend
cd backend
docker build -t geoguard-backend .
docker stop geoguard-backend-container || true
docker rm geoguard-backend-container || true
docker run -d \
  --name geoguard-backend-container \
  --restart unless-stopped \
  -p 8000:8080 \
  --env-file .env \
  geoguard-backend

# 3. Web
cd ../web
npm install
npm run build
pm2 stop geoguard-web || true
pm2 start npm --name "geoguard-web" -- start
pm2 save

# 4. Recargar Nginx
sudo systemctl reload nginx
```

## 📱 Configurar Mobile para Producción

En tu máquina local, ejecuta la app mobile normalmente. Ya está configurada para usar `https://geoguard.site`:

```bash
cd mobile
flutter run
```

La app automáticamente se conectará al backend en la nube.

## 🔍 Verificar Despliegue

```bash
# Estado de Docker
docker ps

# Logs del backend
docker logs -f geoguard-backend-container

# Estado de PM2
pm2 status

# Logs de la web
pm2 logs geoguard-web

# Estado de Nginx
sudo systemctl status nginx

# Verificar SSL
curl https://geoguard.site/api/
```

## 🛠️ Comandos Útiles

```bash
# Reiniciar backend
docker restart geoguard-backend-container

# Reiniciar web
pm2 restart geoguard-web

# Ver logs en tiempo real
docker logs -f geoguard-backend-container
pm2 logs geoguard-web

# Ejecutar migraciones
docker exec -it geoguard-backend-container python manage.py migrate

# Crear superusuario
docker exec -it geoguard-backend-container python manage.py createsuperuser

# Recolectar archivos estáticos
docker exec -it geoguard-backend-container python manage.py collectstatic --noinput
```

## 🔒 Seguridad

1. **Cambiar SECRET_KEY** en `.env` del backend
2. **Cambiar GEOGUARD_ADMIN_SECRET** en `.env`
3. **Configurar DEBUG=False** en producción
4. **Actualizar certificados SSL** automáticamente:

```bash
sudo certbot renew --dry-run
```

## 📊 Monitoreo

```bash
# Ver recursos del sistema
htop

# Ver espacio en disco
df -h

# Ver uso de memoria
free -m

# Ver logs de Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## 🆘 Troubleshooting

### Backend no responde
```bash
docker logs geoguard-backend-container
docker restart geoguard-backend-container
```

### Web no carga
```bash
pm2 logs geoguard-web
pm2 restart geoguard-web
```

### SSL no funciona
```bash
sudo certbot certificates
sudo certbot renew --force-renewal
sudo systemctl reload nginx
```

### Mobile no conecta
- Verificar que el dominio `geoguard.site` esté accesible
- Verificar CORS en backend `.env`: debe incluir el dominio
- Verificar firewall: puertos 80 y 443 abiertos
