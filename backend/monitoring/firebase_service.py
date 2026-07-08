"""
Firebase Cloud Messaging Service para GeoGuard.
Envía notificaciones push para diferentes eventos:
- Salida de zona segura
- Entrada a zona segura
- Batería baja
"""
import os
import logging
import firebase_admin
from firebase_admin import credentials, messaging
from django.conf import settings

logger = logging.getLogger(__name__)

# Inicializar Firebase Admin SDK
_firebase_app = None


def initialize_firebase():
    """Inicializa Firebase Admin SDK si no está inicializado."""
    global _firebase_app
    
    if _firebase_app is not None:
        return _firebase_app
    
    try:
        # Buscar credenciales en diferentes ubicaciones
        cred_path = os.path.join(settings.BASE_DIR, 'firebase-credentials.json')
        
        # Las credenciales pueden estar en una variable de entorno
        if os.getenv('FIREBASE_CREDENTIALS'):
            import json
            cred_dict = json.loads(os.getenv('FIREBASE_CREDENTIALS'))
            if 'private_key' in cred_dict:
                cred_dict['private_key'] = cred_dict['private_key'].replace('\\n', '\n')
            cred = credentials.Certificate(cred_dict)
        elif os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
        else:
            logger.warning("Firebase credentials not found. Push notifications disabled.")
            return None
        
        _firebase_app = firebase_admin.initialize_app(cred)
        logger.info("Firebase Admin SDK initialized successfully")
        return _firebase_app
    except Exception as e:
        logger.error(f"Failed to initialize Firebase: {e}")
        return None


def send_push_notification(fcm_token: str, title: str, body: str, data: dict = None, priority: str = 'high') -> bool:
    """
    Envía una notificación push a un dispositivo específico.
    
    Args:
        fcm_token: Token FCM del dispositivo
        title: Título de la notificación
        body: Cuerpo del mensaje
        data: Datos adicionales (opcional)
        priority: Prioridad del mensaje ('high' o 'normal')
    
    Returns:
        True si se envió correctamente, False en caso contrario
    """
    if not fcm_token:
        logger.warning("No FCM token provided, skipping push notification")
        return False
    
    if initialize_firebase() is None:
        logger.warning("Firebase not initialized, skipping push notification")
        return False
    
    try:
        # Asegurar que data solo contenga strings
        string_data = {}
        if data:
            for key, value in data.items():
                string_data[key] = str(value) if value is not None else ''
        
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=string_data,
            token=fcm_token,
            android=messaging.AndroidConfig(
                priority=priority,
                notification=messaging.AndroidNotification(
                    icon='ic_notification',
                    color='#D32F2F',
                    sound='default',
                    channel_id='geoguard_alerts',
                    default_sound=True,
                    default_vibrate_timings=True,
                    visibility='public',
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound='default',
                        badge=1,
                        content_available=True,
                    ),
                ),
            ),
        )
        
        response = messaging.send(message)
        logger.info(f"Push notification sent successfully: {response}")
        return True
    except messaging.UnregisteredError:
        logger.warning(f"FCM token is invalid or unregistered: {fcm_token[:20]}...")
        return False
    except Exception as e:
        logger.error(f"Failed to send push notification: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return False


def send_zone_exit_alert(tutor, child_name: str, alert_id: int = None, latitude: float = None, longitude: float = None, group_name: str = None, zone_name: str = None, child_id: int = None) -> bool:
    """
    Notificación cuando un niño SALE de la zona segura.
    Incluye la dirección si está disponible.
    
    Args:
        tutor: Usuario a notificar
        child_name: Nombre del niño
        alert_id: ID de la alerta
        latitude: Latitud de la ubicación
        longitude: Longitud de la ubicación
        group_name: Nombre del grupo (si es alerta de grupo)
        zone_name: Nombre de la zona (individual o de grupo)
        child_id: ID del niño
    """
    if not tutor.fcm_token:
        logger.warning(f"Tutor {tutor.email} has no FCM token")
        return False
    
    # Título y cuerpo diferentes para alertas de grupo vs individuales
    if group_name:
        title = f"🚨 ¡ALERTA GRUPO! {child_name}"
        body = f"{child_name} ha salido de la zona '{zone_name}' del grupo '{group_name}'."
    elif zone_name:
        title = f"🚨 ¡ALERTA! {child_name}"
        body = f"{child_name} ha salido de la zona '{zone_name}'."
    else:
        title = f"🚨 ¡ALERTA! {child_name}"
        body = f"{child_name} ha salido de la zona segura."
    
    # Intentar obtener la dirección
    address = None
    if latitude and longitude:
        try:
            from .google_services import get_geocoding_service
            geocoding = get_geocoding_service()
            address = geocoding.reverse_geocode_sync(latitude, longitude)
            if address:
                body += f"\n📍 {address}"
        except Exception as e:
            logger.warning(f"Failed to get address for alert: {e}")
    
    if not address:
        body += " Verifica su ubicación inmediatamente."
    
    data = {
        'type': 'zone_exit',
        'child_name': child_name,
        'child_id': str(child_id) if child_id else '',
        'alert_id': str(alert_id) if alert_id else '',
        'address': address or '',
        'latitude': str(latitude) if latitude else '',
        'longitude': str(longitude) if longitude else '',
        'group_name': group_name or '',
        'zone_name': zone_name or '',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
    }
    
    logger.info(f"Sending zone exit alert to {tutor.email} for child {child_name}" + (f" (group: {group_name})" if group_name else ""))
    return send_push_notification(tutor.fcm_token, title, body, data)


def send_zone_entry_alert(tutor, child_name: str, group_name: str = None, zone_name: str = None) -> bool:
    """
    Notificación cuando un niño ENTRA a la zona segura.
    
    Args:
        tutor: Usuario a notificar
        child_name: Nombre del niño
        group_name: Nombre del grupo (si es entrada a zona de grupo)
        zone_name: Nombre de la zona (individual o de grupo)
    """
    if not tutor.fcm_token:
        logger.warning(f"Tutor {tutor.email} has no FCM token")
        return False
    
    # Título y cuerpo diferentes para alertas de grupo vs individuales
    if group_name:
        title = f"✅ {child_name} está seguro"
        body = f"{child_name} ha entrado a la zona '{zone_name}' del grupo '{group_name}'."
    elif zone_name:
        title = f"✅ {child_name} está seguro"
        body = f"{child_name} ha entrado a la zona '{zone_name}'."
    else:
        title = f"✅ {child_name} está seguro"
        body = f"{child_name} ha entrado a una zona segura."
    
    data = {
        'type': 'zone_entry',
        'child_name': child_name,
        'group_name': group_name or '',
        'zone_name': zone_name or '',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
    }
    
    logger.info(f"Sending zone entry alert to {tutor.email} for child {child_name}" + (f" (group: {group_name})" if group_name else ""))
    return send_push_notification(tutor.fcm_token, title, body, data, priority='normal')


def send_low_battery_alert(tutor, child_name: str, battery_level: int) -> bool:
    """
    Notificación cuando la batería del dispositivo está baja.
    """
    if not tutor.fcm_token:
        logger.warning(f"Tutor {tutor.email} has no FCM token")
        return False
    
    title = f"🔋 Batería baja - {child_name}"
    body = f"El dispositivo de {child_name} tiene {battery_level}% de batería. Cárgalo pronto."
    
    data = {
        'type': 'low_battery',
        'child_name': child_name,
        'battery_level': str(battery_level),
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
    }
    
    logger.info(f"Sending low battery alert to {tutor.email} for child {child_name}")
    return send_push_notification(tutor.fcm_token, title, body, data, priority='normal')


# Mantener compatibilidad con código existente
def send_alert_notification(tutor, child_name: str, alert_message: str, alert_id: int = None) -> bool:
    """Alias para send_zone_exit_alert (compatibilidad)."""
    return send_zone_exit_alert(tutor, child_name, alert_id)


def send_manual_notification(user, title: str, message: str, notification_id: int = None) -> bool:
    """
    Envía una notificación manual (creada por admin).
    
    Args:
        user: Usuario destinatario
        title: Título de la notificación
        message: Mensaje de la notificación
        notification_id: ID de la notificación en la base de datos
    
    Returns:
        True si se envió correctamente, False en caso contrario
    """
    if not user.fcm_token:
        logger.warning(f"User {user.email} has no FCM token")
        return False
    
    data = {
        'type': 'manual_notification',
        'notification_id': str(notification_id) if notification_id else '',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
    }
    
    logger.info(f"Sending manual notification to {user.email}: {title}")
    return send_push_notification(user.fcm_token, title, message, data, priority='high')
