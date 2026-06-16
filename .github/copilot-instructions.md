# GeoGuard – Copilot Instructions

## Project Vision
- **Problema**: En Santa Cruz de la Sierra no existe una herramienta en tiempo real que avise cuando un niño prescolar sale del kinder. Los controles manuales son lentos/caros; necesitamos alertas tempranas para evitar pérdidas, accidentes o secuestros.
- **Meta general**: Diseñar e implementar un sistema SIG que monitoree la posición del niño y envíe alertas al tutor/madre si abandona su zona segura.
- **Fases clave**: (1) Levantar/digitalizar datos geoespaciales (polígonos de unidades educativas). (2) Diseñar la BD espacial + alfanumérica. (3) Desarrollar backend Django + app móvil Flutter. (4) Ejecutar análisis espacial para detectar salidas y notificar. (5) Capacitar a tutores/personal y definir el soporte inicial.
- **Alcance**: Incluye diseño/implementación del sistema, adquisición de hardware/red sugerido y capacitación básica. No cubre despliegues masivos posteriores ni operaciones de campo continuas.

## Architecture Snapshot
- Two apps: `backend/` (Django 5.1 + DRF TokenAuth) serves `/api/auth/` and `/api/monitoring/`, while `mobile/` is a Flutter 3.9 client (Riverpod + GoRouter + Material3) calling the API at `http://10.0.2.2:8000` by default.
- Auth drives everything: the custom user model (`accounts/models.py`) issues DRF tokens via `accounts/views.py`; Flutter persists the token with `flutter_secure_storage` and injects it via the `Authorization: Token <value>` header in every repository.
- Monitoring flows live under the `monitoring` Django app (Child/Device/SafeZone/Alert models + ModelViewSets) and the `features/monitoring` directory on Flutter (domain models → repositories → providers → UI).

## Backend (Django) Practices
- Load configuration exclusively via `.env` (copy `.env.example`); `DATABASE_URL`, `ALLOWED_HOSTS`, and `CORS_ALLOWED_ORIGINS` must be set before migrations (`python manage.py makemigrations && python manage.py migrate`).
- Always run the dev server as `python manage.py runserver 0.0.0.0:8000` so the Android emulator can reach it through `10.0.2.2`.
- New resources follow the existing pattern: serializer in `monitoring/serializers.py`, DRF ViewSet in `monitoring/views.py`, register via `monitoring/urls.py` router, and expose under `/api/monitoring/<resource>/` in `geoguard/urls.py`.
- Token auth is enforced globally (`REST_FRAMEWORK` settings). If you add unauthenticated endpoints, decorate them explicitly with `@permission_classes([AllowAny])`.
- Media uploads (child photos) require `MEDIA_URL`/`MEDIA_ROOT`; when adding File/Image fields, be sure to update the API clients to send multipart data (see `ChildViewSet.parser_classes`).

## Mobile (Flutter) Practices
- Providers first: state flows through Riverpod. For new API calls create a repository in `features/<domain>/data`, a `FutureProvider/StateNotifier` in `.../providers`, then consume it in the UI. Example: `childrenListProvider` → `ChildrenListScreen`.
- Use `ApiConstants` for every endpoint and respect the `GEOGUARD_API_BASE` compile-time override when pointing to staging/prod.
- Navigation uses nested GoRouter routes under `/home`. Add new screens inside `core/config/app_router.dart` so they inherit auth guards automatically.
- UI must match the Material 3 minimalist theme defined in `core/config/app_theme.dart` (filled inputs, stadium buttons, light surfaces). Reuse `Theme.of(context).colorScheme` instead of hard-coded colors.
- After mutations (register child, acknowledge alert, etc.) invalidate the relevant providers (`ref.invalidate(childrenListProvider)`) so the dashboard refreshes, mirroring the logic in `child_form_controller.dart`.

## Web (Next.js) Practices
- **IMPORTANTE: Usar SOLO Tailwind CSS para estilos**. NO usar CSS modules, styled-components, emotion, ni ninguna otra librería de estilos. Tailwind v4 está configurado y cualquier otra solución de estilos romperá la consistencia del proyecto.
- El proyecto web está en `web/` y usa Next.js 15 con App Router y TypeScript.
- Todos los colores deben usar las variables CSS definidas en `app/globals.css` con soporte para modo claro/oscuro usando la clase `dark:`.
- Componentes UI reutilizables están en `components/ui/` (Button, Card, Input, Badge, Table, Spinner). Usarlos en lugar de crear nuevos.
- Layout principal con Sidebar y Header está en `components/layout/`. Las páginas protegidas van dentro de `app/(main)/`.
- Para colores, usar el patrón: `text-[#202124] dark:text-[#fafafa]`, `bg-white dark:bg-[#171717]`, etc.
- La paleta de colores está centralizada en `lib/colors.ts` para referencia programática.
- Tipografía: Roboto (cargada via next/font/google).
- AuthContext y ThemeContext manejan autenticación y tema respectivamente.

## API Contracts to Remember
- Auth: `POST /api/auth/register/` expects `{full_name,email,password,phone?}` and returns `{token,user}`; `POST /api/auth/login/` expects `{email,password}`; `POST /api/auth/logout/` requires a valid token.
- Monitoring: `GET/POST /api/monitoring/children/` is scoped to `request.user` (no tutor field in payload); responses include nested `device` data. `GET /api/monitoring/alerts/` returns the tutor’s alerts ordered by `created_at` desc.
- Flutter domain models (`features/monitoring/domain/monitoring_models.dart`) show the canonical JSON keys—match them when extending the API to avoid double mapping.

## Developer Workflow Tips
- Backend deps live in `backend/requirements.txt` (psycopg[binary], django-environ, corsheaders). Install inside the venv before running migrations.
- Mobile builds expect `flutter pub get`, then `flutter run` with the backend already up; if you change the API base URL, pass `--dart-define=GEOGUARD_API_BASE=http://<host>:<port>`.
- The emulator talks to the host via `10.0.2.2`; remember to update `ALLOWED_HOSTS` in `.env` whenever that IP is used or Django will raise `DisallowedHost`.
- Keep credentials out of source—only `.env.example` belongs in Git. When documenting steps, mention `.env` variables instead of hardcoding secrets.

Feedback welcome: call out any areas where the guidance is unclear or missing so we can refine it further.
