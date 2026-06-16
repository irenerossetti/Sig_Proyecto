# GeoGuard Web Admin Panel

Panel de administración web para el sistema de monitoreo GeoGuard.

## Tecnologías

- **Framework**: Next.js 16.0.6
- **UI**: React 19, Tailwind CSS 4
- **Estado**: React Context (AuthContext)
- **HTTP Client**: Axios
- **Iconos**: Lucide React
- **Fechas**: date-fns

## Estructura del Proyecto

```
web/
├── app/
│   ├── layout.tsx          # Layout raíz con AuthProvider
│   ├── page.tsx            # Página principal (redirección)
│   ├── globals.css         # Estilos globales
│   ├── login/              # Página de login
│   ├── register/           # Página de registro
│   └── (main)/             # Rutas protegidas
│       ├── layout.tsx      # Layout con sidebar
│       ├── dashboard/      # Dashboard principal
│       ├── children/       # Gestión de niños
│       ├── alerts/         # Visualización de alertas
│       ├── safe-zones/     # Gestión de zonas seguras
│       └── settings/       # Configuración de usuario
├── components/
│   ├── ui/                 # Componentes UI reutilizables
│   │   ├── Button.tsx
│   │   ├── Input.tsx
│   │   ├── Card.tsx
│   │   ├── Badge.tsx
│   │   ├── Table.tsx
│   │   └── Spinner.tsx
│   └── layout/             # Componentes de layout
│       ├── Sidebar.tsx
│       └── Header.tsx
├── contexts/
│   └── AuthContext.tsx     # Contexto de autenticación
├── lib/
│   ├── api.ts              # Cliente Axios configurado
│   ├── types.ts            # Tipos TypeScript
│   └── utils.ts            # Funciones utilitarias
└── .env.local              # Variables de entorno
```

## Instalación

```bash
# Instalar dependencias
npm install

# Copiar archivo de entorno
cp .env.example .env.local

# Editar .env.local con la URL del backend
```

## Desarrollo

```bash
# Iniciar servidor de desarrollo
npm run dev

# El servidor estará disponible en http://localhost:3000
```

## Variables de Entorno

| Variable | Descripción | Valor por defecto |
|----------|-------------|-------------------|
| `NEXT_PUBLIC_API_URL` | URL del backend Django | `http://34.45.10.241/api` |

## Autenticación

El sistema usa **Token Authentication** integrado con el backend Django:

1. El usuario ingresa credenciales en `/login`
2. Se envía POST a `/api/auth/login/`
3. El backend responde con `{ token, user }`
4. El token se guarda en `localStorage`
5. Todas las peticiones incluyen header `Authorization: Token <token>`
6. Al cerrar sesión, se elimina el token y se redirige a login

## Páginas Principales

### Dashboard (`/dashboard`)
- Resumen de estadísticas (niños, alertas, zonas, dispositivos)
- Alertas recientes
- Lista de niños con estado

### Niños (`/children`)
- Lista de niños registrados
- Agregar nuevo niño
- Ver detalle de cada niño
- Estado del dispositivo vinculado

### Alertas (`/alerts`)
- Lista de todas las alertas
- Filtros: todas, pendientes, leídas
- Marcar alertas como leídas
- Información de tipo y zona

### Zonas Seguras (`/safe-zones`)
- Lista de zonas configuradas
- Crear nueva zona con geolocalización
- Vista de mapa con Google Maps embed
- Editar y eliminar zonas

### Configuración (`/settings`)
- Actualizar perfil de usuario
- Cambiar contraseña
- Cerrar sesión

## Build para Producción

```bash
# Crear build optimizado
npm run build

# Iniciar servidor de producción
npm start
```

## Despliegue

El proyecto está listo para desplegar en:
- **Vercel** (recomendado para Next.js)
- **Google Cloud Run**
- **Cualquier servidor con Node.js**

### Despliegue en Vercel

```bash
# Instalar Vercel CLI
npm i -g vercel

# Desplegar
vercel
```

Asegúrate de configurar la variable de entorno `NEXT_PUBLIC_API_URL` en el dashboard de Vercel.
