# GeoGuard Backend - Google Cloud Run Setup
# Ejecutar estos comandos en Google Cloud Shell o con gcloud CLI instalado

# Variables
PROJECT_ID="geoguard-478318"
REGION="us-central1"
SERVICE_NAME="geoguard-api"
REPOSITORY="geoguard"

# 1. Configurar proyecto
gcloud config set project $PROJECT_ID

# 2. Habilitar APIs necesarias
gcloud services enable \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    secretmanager.googleapis.com

# 3. Crear repositorio de Artifact Registry
gcloud artifacts repositories create $REPOSITORY \
    --repository-format=docker \
    --location=$REGION \
    --description="GeoGuard Docker images"

# 4. Crear secretos en Secret Manager
# Primero crea un SECRET_KEY seguro
python3 -c "import secrets; print(secrets.token_urlsafe(50))"

# Luego guárdalo como secreto (reemplaza YOUR_SECRET_KEY con el valor generado)
echo -n "YOUR_SECRET_KEY" | gcloud secrets create SECRET_KEY --data-file=-

# Guardar DATABASE_URL como secreto
echo -n "postgresql://postgres:Joabits222157933*@136.114.137.62:5432/geoguard" | gcloud secrets create DATABASE_URL --data-file=-

# 5. Crear Service Account para GitHub Actions
SA_NAME="github-actions-deployer"
SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

gcloud iam service-accounts create $SA_NAME \
    --display-name="GitHub Actions Deployer"

# 6. Otorgar permisos al Service Account
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/secretmanager.secretAccessor"

# 7. Crear clave JSON para GitHub Actions
gcloud iam service-accounts keys create gcp-sa-key.json \
    --iam-account=$SA_EMAIL

echo ""
echo "=============================================="
echo "✅ Setup completo!"
echo ""
echo "📋 SIGUIENTE PASO:"
echo "1. Copia el contenido de 'gcp-sa-key.json'"
echo "2. Ve a tu repo en GitHub → Settings → Secrets → Actions"
echo "3. Crea un secreto llamado 'GCP_SA_KEY' con ese contenido"
echo "4. Elimina el archivo gcp-sa-key.json por seguridad"
echo ""
echo "🚀 Luego haz push a main y el deploy será automático!"
echo "=============================================="
