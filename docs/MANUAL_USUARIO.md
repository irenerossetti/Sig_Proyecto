# 📱 GeoGuard - Manual de Usuario

## Sistema de Monitoreo Infantil Basado en Geolocalización

---

## 📋 Tabla de Contenidos

1. [Introducción](#introducción)
2. [Requisitos del Sistema](#requisitos-del-sistema)
3. [Primeros Pasos](#primeros-pasos)
4. [Aplicación Móvil del Tutor](#aplicación-móvil-del-tutor)
5. [Aplicación del Tracker (Dispositivo del Niño)](#aplicación-del-tracker)
6. [Panel Web de Administración](#panel-web-de-administración)
7. [Gestión de Alertas](#gestión-de-alertas)
8. [Preguntas Frecuentes](#preguntas-frecuentes)
9. [Solución de Problemas](#solución-de-problemas)

---

## 📖 Introducción

GeoGuard es un sistema integral de monitoreo que permite a tutores y administradores de instituciones educativas mantener un seguimiento en tiempo real de la ubicación de niños preescolares. El sistema genera alertas automáticas cuando un niño sale de su zona segura designada.

### Componentes del Sistema

1. **Aplicación Móvil del Tutor**: Para padres y tutores que monitorean a sus hijos
2. **Aplicación Tracker**: Instalada en el dispositivo que porta el niño
3. **Panel Web**: Para administradores de instituciones educativas

---

## 💻 Requisitos del Sistema

### Aplicación Móvil (Tutor)
- Android 8.0 o superior / iOS 12.0 o superior
- Conexión a Internet (WiFi o datos móviles)
- GPS habilitado para visualizar ubicaciones

### Aplicación Tracker
- Android 8.0 o superior
- GPS habilitado permanentemente
- Conexión a Internet (datos móviles recomendado)
- Batería con duración mínima de 8 horas

### Panel Web
- Navegador moderno (Chrome, Firefox, Safari, Edge)
- Conexión a Internet estable

---

## 🚀 Primeros Pasos

### 1. Registro de Cuenta

1. Descarga la aplicación GeoGuard desde la tienda de aplicaciones
2. Abre la aplicación y selecciona **"Crear cuenta"**
3. Completa el formulario con:
   - Nombre completo
   - Correo electrónico
   - Contraseña (mínimo 8 caracteres)
   - Número de teléfono (opcional)
4. Verifica tu correo electrónico si es requerido
5. Inicia sesión con tus credenciales

### 2. Configuración Inicial

Una vez registrado, deberás:
1. Registrar a tus hijos en el sistema
2. Vincular el dispositivo tracker
3. Configurar las zonas seguras

---

## 📱 Aplicación Móvil del Tutor

### Pantalla Principal (Dashboard)

Al iniciar sesión verás:
- **Lista de niños registrados** con su estado actual
- **Indicadores de estado**:
  - 🟢 Verde: Dentro de zona segura
  - 🔴 Rojo: Fuera de zona segura
  - ⚪ Gris: Sin conexión
- **Alertas recientes** pendientes de atención

### Registrar un Niño

1. Toca el botón **"+"** o **"Agregar niño"**
2. Completa el formulario:
   - **Nombre completo**: Nombre del niño
   - **Fecha de nacimiento**: Selecciona del calendario
   - **Foto** (opcional): Toma una foto o selecciona de la galería
   - **Notas**: Información adicional relevante
3. Toca **"Guardar"**

### Vincular Dispositivo Tracker

1. Selecciona al niño desde la lista
2. Toca **"Vincular dispositivo"**
3. En el dispositivo tracker, abre la app e ingresa el **código de vinculación** mostrado
4. Espera la confirmación de vinculación exitosa

### Configurar Zonas Seguras

1. Selecciona al niño
2. Ve a **"Zonas seguras"**
3. Toca **"Nueva zona"**
4. Configura la zona:
   - **Nombre**: Ej. "Kinder San José", "Casa"
   - **Tipo de zona**: 
     - Circular (define centro y radio)
     - Polígono (dibuja el contorno)
   - **Dibujar en el mapa**: Ubica la zona en el mapa interactivo
5. Toca **"Guardar zona"**

### Ver Ubicación en Tiempo Real

1. Selecciona al niño desde el dashboard
2. Visualiza el mapa con:
   - **Punto azul**: Ubicación actual del niño
   - **Áreas coloreadas**: Zonas seguras configuradas
   - **Línea de trayecto**: Recorrido reciente
3. Desliza hacia arriba para ver detalles:
   - Última actualización
   - Nivel de batería del dispositivo
   - Estado de conexión

### Historial de Movimientos

1. Ve a **"Historial"** desde el menú
2. Selecciona el niño y la fecha
3. Visualiza:
   - Ruta completa del día
   - Puntos de entrada/salida de zonas
   - Alertas generadas

---

## 📍 Aplicación del Tracker

### Instalación y Configuración

1. Descarga **GeoGuard Tracker** en el dispositivo del niño
2. Otorga todos los permisos solicitados:
   - ✅ Ubicación (siempre permitir)
   - ✅ Notificaciones
   - ✅ Ejecución en segundo plano
   - ✅ Ignorar optimización de batería

### Vinculación con Tutor

1. Abre la app Tracker
2. Ingresa el **código de vinculación** proporcionado por el tutor
3. La app se configurará automáticamente

### Funcionamiento Normal

- La app funciona en segundo plano
- Envía ubicación cada 15-30 segundos
- Muestra indicador en la barra de estado cuando está activa
- Alerta localmente si detecta salida de zona segura

### Indicadores de Estado

| Icono | Significado |
|-------|-------------|
| 🟢 | Conectado y enviando ubicación |
| 🟡 | Conexión intermitente |
| 🔴 | Sin conexión |
| 🔋 | Batería baja (<20%) |

---

## 🖥️ Panel Web de Administración

### Acceso al Panel

1. Navega a `https://geoguard.app/admin` (o URL proporcionada)
2. Inicia sesión con credenciales de administrador
3. Serás dirigido al dashboard principal

### Dashboard Principal

Muestra resumen general:
- Total de niños registrados
- Niños dentro/fuera de zonas seguras
- Alertas pendientes
- Estado de dispositivos

### Mapa en Tiempo Real

1. Ve a **"Mapa en vivo"**
2. Visualiza todos los niños simultáneamente
3. Filtra por:
   - Institución
   - Estado (dentro/fuera de zona)
   - Tutor específico
4. Haz clic en un marcador para ver detalles

### Gestión de Zonas Seguras

1. Ve a **"Zonas seguras"**
2. Opciones disponibles:
   - **Ver lista**: Todas las zonas configuradas
   - **Nueva zona**: Crear zona con editor de mapas
   - **Editar**: Modificar zona existente
   - **Eliminar**: Remover zona

### Editor de Zonas

1. Selecciona tipo de zona (circular/polígono)
2. Usa las herramientas del mapa:
   - 🔵 Dibujar círculo: Click y arrastrar
   - 📐 Dibujar polígono: Click en cada vértice
3. Ajusta propiedades:
   - Nombre
   - Color
   - Radio (para círculos)
4. Guarda la zona

### Reportes y Estadísticas

1. Ve a **"Reportes"**
2. Selecciona período: Hoy, 7 días, 30 días
3. Visualiza:
   - Gráficos de alertas
   - Distribución por tipo
   - Estado de dispositivos
4. Exporta datos en CSV o JSON

### Gestión de Usuarios

1. Ve a **"Usuarios"**
2. Opciones:
   - Ver lista de tutores
   - Editar información
   - Desactivar cuentas
   - Ver niños asociados

---

## 🔔 Gestión de Alertas

### Tipos de Alertas

| Tipo | Descripción | Prioridad |
|------|-------------|-----------|
| **Salida de zona** | El niño salió de su zona segura | 🔴 Alta |
| **Entrada a zona** | El niño ingresó a zona segura | 🟢 Baja |
| **Batería baja** | Dispositivo con menos del 20% | 🟡 Media |
| **Dispositivo offline** | Sin conexión por más de 5 minutos | 🟡 Media |

### Recibir Alertas

Las alertas se envían por:
- **Notificación push** en la app móvil
- **Notificación en el panel web**
- **Correo electrónico** (opcional)

### Reconocer Alertas

1. Al recibir una alerta, tócala para ver detalles
2. Visualiza:
   - Ubicación del niño al momento de la alerta
   - Zona involucrada
   - Hora exacta
3. Opciones:
   - **Reconocer**: Marca como vista
   - **Llamar**: Contacta al dispositivo (si está disponible)
   - **Ver en mapa**: Abre ubicación actual

---

## ❓ Preguntas Frecuentes

### ¿Cada cuánto se actualiza la ubicación?
La ubicación se actualiza cada 15-30 segundos cuando hay movimiento, y cada 2-5 minutos cuando está estático.

### ¿Funciona sin Internet?
El tracker almacena ubicaciones localmente cuando no hay conexión y las sincroniza al reconectarse. Sin embargo, las alertas en tiempo real requieren conexión.

### ¿Cuánta batería consume el tracker?
El tracker está optimizado para consumir entre 5-10% de batería por hora en uso activo.

### ¿Puedo tener múltiples tutores para un niño?
Sí, puedes invitar a otros tutores compartiendo el código del niño.

### ¿Qué tan precisa es la ubicación?
La precisión es de 3-10 metros con GPS activo, y 15-50 metros con ubicación por red.

### ¿Se puede usar en interiores?
Funciona pero con menor precisión. Se recomienda tener acceso a WiFi para mejorar la ubicación.

---

## 🔧 Solución de Problemas

### La ubicación no se actualiza

1. Verifica que el GPS esté activado en el dispositivo tracker
2. Comprueba la conexión a Internet
3. Asegúrate de que la app tenga permisos de ubicación "siempre"
4. Reinicia la app del tracker

### No recibo alertas

1. Verifica que las notificaciones estén habilitadas
2. Comprueba que la app no esté en modo "No molestar"
3. Revisa la configuración de la zona segura
4. Asegúrate de estar conectado a Internet

### El dispositivo aparece offline

1. Verifica la conexión a Internet del tracker
2. Comprueba el nivel de batería
3. Reinicia el dispositivo
4. Desvincula y vuelve a vincular

### La zona no funciona correctamente

1. Verifica que la zona esté guardada correctamente
2. Revisa el radio o los límites del polígono
3. Asegúrate de que el niño esté asignado a la zona
4. Prueba recrear la zona

### Problemas de inicio de sesión

1. Verifica que el correo/contraseña sean correctos
2. Usa "Olvidé mi contraseña" para recuperar acceso
3. Revisa tu conexión a Internet
4. Intenta en otro dispositivo

---

## 📞 Soporte

Si necesitas ayuda adicional:

- **Email**: soporte@geoguard.app
- **Teléfono**: +591 XXX XXXX
- **Horario**: Lunes a Viernes, 8:00 - 18:00

---

*Última actualización: Enero 2025*
*Versión del documento: 1.0*
