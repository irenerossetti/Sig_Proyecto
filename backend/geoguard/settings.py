"""Base settings for the GeoGuard backend."""

from pathlib import Path
import os
import environ
import sys
import types

BASE_DIR = Path(__file__).resolve().parent.parent

# Read .env file early so that environmental variables are available for GIS checks
env = environ.Env(
    DEBUG=(bool, False),
)
ENV_FILE = BASE_DIR / ".env"
if ENV_FILE.exists():
    environ.Env.read_env(ENV_FILE)

# ----------------- GIS Mocking for non-GDAL setups (e.g. SQLite on Windows) -----------------
# This allows Django migrations to load and run without requiring external GDAL binaries.
USE_GIS = os.getenv("CLOUD_RUN") == "True" or os.getenv("USE_POSTGIS") == "True"
if USE_GIS:
    # Double check if GDAL is actually available on this system
    try:
        from django.contrib.gis.gdal import HAS_GDAL
        if not HAS_GDAL:
            USE_GIS = False
    except Exception:
        USE_GIS = False

if not USE_GIS:
    from django.db import models as django_models
    
    class MockGeometryField(django_models.Field):
        geom_type = 'Geometry'
        def __init__(self, *args, **kwargs):
            kwargs.pop('srid', None)
            kwargs.pop('geography', None)
            kwargs.pop('spatial_index', None)
            kwargs.pop('dim', None)
            kwargs.pop('extent', None)
            kwargs.pop('tolerance', None)
            super().__init__(*args, **kwargs)
            
        def db_type(self, connection):
            if connection.vendor == 'postgresql':
                return f'geography({self.geom_type},4326)'
            return 'text'
            
        def deconstruct(self):
            name, path, args, kwargs = super().deconstruct()
            new_kwargs = {
                'null': kwargs.get('null', True),
                'blank': kwargs.get('blank', True),
            }
            return name, "django.db.models.TextField", args, new_kwargs
            
    class PointField(MockGeometryField):
        geom_type = 'Point'
        
    class PolygonField(MockGeometryField):
        geom_type = 'Polygon'
        
    class LineStringField(MockGeometryField):
        geom_type = 'LineString'
        
    class MultiPointField(MockGeometryField):
        geom_type = 'MultiPoint'
        
    class MultiPolygonField(MockGeometryField):
        geom_type = 'MultiPolygon'
        
    class GeometryField(MockGeometryField):
        geom_type = 'Geometry'

    gis_mod = types.ModuleType('django.contrib.gis')
    gis_mod.__path__ = []
    gis_db_mod = types.ModuleType('django.contrib.gis.db')
    gis_db_mod.__path__ = []
    mock_gis_db_models = types.ModuleType('django.contrib.gis.db.models')
    mock_gis_db_models.__path__ = []
    mock_gis_db_models_fields = types.ModuleType('django.contrib.gis.db.models.fields')
    mock_gis_geos = types.ModuleType('django.contrib.gis.geos')
    mock_gis_measure = types.ModuleType('django.contrib.gis.measure')
    mock_gis_db_models_functions = types.ModuleType('django.contrib.gis.db.models.functions')
    
    # Hierarchical binding
    setattr(gis_mod, 'db', gis_db_mod)
    setattr(gis_mod, 'geos', mock_gis_geos)
    setattr(gis_mod, 'measure', mock_gis_measure)
    setattr(gis_db_mod, 'models', mock_gis_db_models)
    setattr(mock_gis_db_models, 'fields', mock_gis_db_models_fields)
    setattr(mock_gis_db_models, 'functions', mock_gis_db_models_functions)
    
    mock_classes = {
        'PointField': PointField,
        'PolygonField': PolygonField,
        'LineStringField': LineStringField,
        'MultiPointField': MultiPointField,
        'MultiPolygonField': MultiPolygonField,
        'GeometryField': GeometryField,
    }
    for field_name, field_class in mock_classes.items():
        setattr(mock_gis_db_models_fields, field_name, field_class)
        setattr(mock_gis_db_models, field_name, field_class)
        
    setattr(mock_gis_db_models, 'models', django_models)
    
    class DummyGEOSGeometry:
        def __init__(self, *args, **kwargs): pass
    setattr(mock_gis_geos, 'GEOSGeometry', DummyGEOSGeometry)
    setattr(mock_gis_geos, 'Point', DummyGEOSGeometry)
    setattr(mock_gis_geos, 'Polygon', DummyGEOSGeometry)
    
    sys.modules['django.contrib.gis'] = gis_mod
    sys.modules['django.contrib.gis.db'] = gis_db_mod
    sys.modules['django.contrib.gis.db.models'] = mock_gis_db_models
    sys.modules['django.contrib.gis.db.models.fields'] = mock_gis_db_models_fields
    sys.modules['django.contrib.gis.geos'] = mock_gis_geos
    sys.modules['django.contrib.gis.measure'] = mock_gis_measure
    sys.modules['django.contrib.gis.db.models.functions'] = mock_gis_db_models_functions
    
    import django.contrib
    django.contrib.gis = gis_mod
# --------------------------------------------------------------------------------------------

SECRET_KEY = env("SECRET_KEY", default="django-insecure-change-me")
DEBUG = env("DEBUG", default=False)
ALLOWED_HOSTS = env.list("ALLOWED_HOSTS", default=["localhost", "127.0.0.1"])

# Cloud Run specific: Allow all hosts when CLOUD_RUN is set
if os.getenv("CLOUD_RUN") == "True":
    ALLOWED_HOSTS = ["*"]

CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=[])

# Security settings for production
if not DEBUG:
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
    SECURE_SSL_REDIRECT = env.bool("SECURE_SSL_REDIRECT", default=False)
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True

INSTALLED_APPS = [
    "daphne",  # ASGI server para WebSockets
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "rest_framework.authtoken",
    "corsheaders",
    "channels",  # Django Channels para WebSockets
    # Local apps
    "accounts",
    "monitoring",
]

if USE_GIS:
    # Insert GIS apps after staticfiles
    gis_index = INSTALLED_APPS.index("django.contrib.staticfiles") + 1
    INSTALLED_APPS.insert(gis_index, "django.contrib.gis")
    INSTALLED_APPS.insert(gis_index + 1, "rest_framework_gis")

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "geoguard.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "geoguard.wsgi.application"
ASGI_APPLICATION = "geoguard.asgi.application"

# Channel Layers para WebSockets
# Usamos InMemoryChannelLayer para evitar timeouts y desconexiones de Redis
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    },
}

DATABASES = {
    "default": env.db(
        "DATABASE_URL",
        default="postgres://postgres:postgres@localhost:5432/geoguard",
    )
}

# Connection pooling para mejor rendimiento con psycopg3
if "sqlite" not in DATABASES["default"]["ENGINE"]:
    # NOTA: db-f1-micro tiene ~25 conexiones max, reducimos CONN_MAX_AGE para liberarlas rápido
    DATABASES["default"]["CONN_MAX_AGE"] = 0  # Cerrar conexiones inmediatamente en desarrollo
    DATABASES["default"]["CONN_HEALTH_CHECKS"] = True  # Verificar conexiones vivas
    DATABASES["default"]["OPTIONS"] = {
        "connect_timeout": 30,  # Aumentar timeout para Cloud SQL
    }

# Cloud Run: usar socket Unix, GCE VM: usar conexión directa con PostGIS
if os.getenv("CLOUD_RUN") == "True" and USE_GIS:
    # En Cloud Run usamos PostGIS con soporte geoespacial completo via Unix socket
    DATABASES["default"]["ENGINE"] = "django.contrib.gis.db.backends.postgis"
    DATABASES["default"]["HOST"] = "/cloudsql/geoguard-478318:us-central1:geoguard"
    print(f"DEBUG: Running in Cloud Run with PostGIS. CLOUD_RUN={os.getenv('CLOUD_RUN')}")
    print(f"DEBUG: DB Config: HOST={DATABASES['default']['HOST']}, NAME={DATABASES['default']['NAME']}")
elif USE_GIS:
    # En GCE VM o desarrollo local con GDAL/PostGIS disponible
    DATABASES["default"]["ENGINE"] = "django.contrib.gis.db.backends.postgis"
    print(f"DEBUG: Using PostGIS. HOST={DATABASES['default'].get('HOST', 'from DATABASE_URL')}")
else:
    # Si GDAL no está disponible, usar el backend estándar de Postgres o Sqlite
    if "postgis" in DATABASES["default"]["ENGINE"] or "postgresql" in DATABASES["default"]["ENGINE"]:
        DATABASES["default"]["ENGINE"] = "django.db.backends.postgresql"
        print("DEBUG: GDAL missing. Falling back to django.db.backends.postgresql engine")
    else:
        print("DEBUG: Using default non-GIS database engine")

REST_FRAMEWORK = {
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.TokenAuthentication",
        "rest_framework.authentication.SessionAuthentication",
    ],
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
}

# API Documentation settings
SPECTACULAR_SETTINGS = {
    'TITLE': 'GeoGuard API',
    'DESCRIPTION': '''
    API para el sistema de monitoreo GeoGuard.
    
    ## Autenticación
    La API usa Token Authentication. Incluye el token en el header:
    ```
    Authorization: Token <your_token>
    ```
    
    ## Endpoints principales
    - `/api/auth/` - Autenticación (registro, login, logout)
    - `/api/monitoring/children/` - Gestión de niños
    - `/api/monitoring/devices/` - Dispositivos GPS
    - `/api/monitoring/safe-zones/` - Zonas seguras (geofencing)
    - `/api/monitoring/alerts/` - Alertas de seguridad
    - `/api/monitoring/groups/` - Grupos de niños
    ''',
    'VERSION': '1.0.0',
    'SERVE_INCLUDE_SCHEMA': False,
    'COMPONENT_SPLIT_REQUEST': True,
    'TAGS': [
        {'name': 'auth', 'description': 'Autenticación de usuarios'},
        {'name': 'children', 'description': 'Gestión de niños'},
        {'name': 'devices', 'description': 'Dispositivos GPS'},
        {'name': 'safe-zones', 'description': 'Zonas seguras y geofencing'},
        {'name': 'alerts', 'description': 'Alertas de seguridad'},
        {'name': 'groups', 'description': 'Grupos de niños'},
        {'name': 'location-history', 'description': 'Historial de ubicaciones'},
    ],
}

CORS_ALLOWED_ORIGINS = env.list("CORS_ALLOWED_ORIGINS", default=[])
CORS_ALLOW_CREDENTIALS = True
# Allow all origins for mobile apps (they don't send Origin header typically)
CORS_ALLOW_ALL_ORIGINS = env.bool("CORS_ALLOW_ALL_ORIGINS", default=True)

LANGUAGE_CODE = "es-bo"
TIME_ZONE = "America/La_Paz"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"
MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

AUTH_USER_MODEL = "accounts.User"

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": "INFO",
    },
    "loggers": {
        "django": {
            "handlers": ["console"],
            "level": "INFO",
            "propagate": True,
        },
        "django.request": {
            "handlers": ["console"],
            "level": "ERROR",
            "propagate": True,
        },
        "accounts": {  # Log messages from the accounts app
            "handlers": ["console"],
            "level": "DEBUG",
            "propagate": True,
        },
    },
}
