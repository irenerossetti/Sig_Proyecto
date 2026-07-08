"""
WebSocket consumers for real-time location updates.

Optimizado para tiempo real estilo Uber/WhatsApp:
- Broadcast PRIMERO, persistencia DESPUÉS (async)
- Procesamiento en background para alertas y geofencing
- Mínima latencia en actualizaciones de ubicación
"""
import json
import logging
import asyncio
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from asgiref.sync import sync_to_async
from django.contrib.auth.models import AnonymousUser
from django.utils import timezone

logger = logging.getLogger(__name__)


class LocationConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer para actualizaciones de ubicación en tiempo real.
    
    Grupos:
    - tutor_{user_id}: Para que el tutor reciba ubicaciones de sus hijos
    - child_{child_id}: Para que trackers envíen ubicaciones de un niño específico
    """
    
    async def connect(self):
        """Handle WebSocket connection."""
        self.user = self.scope.get('user', AnonymousUser())
        
        if isinstance(self.user, AnonymousUser) or not self.user.is_authenticated:
            logger.warning("WebSocket connection rejected: unauthenticated user")
            await self.close(code=4001)
            return
        
        # Crear grupo único para este tutor
        self.tutor_group = f"tutor_{self.user.id}"
        
        # Unirse al grupo del tutor
        await self.channel_layer.group_add(
            self.tutor_group,
            self.channel_name
        )
        
        await self.accept()
        logger.info(f"WebSocket connected: user={self.user.email}, group={self.tutor_group}")
        
        # Enviar confirmación de conexión
        await self.send(text_data=json.dumps({
            'type': 'connection_established',
            'message': 'Connected to GeoGuard real-time location service',
            'tutor_id': self.user.id,
        }))
    
    async def disconnect(self, close_code):
        """Handle WebSocket disconnection."""
        if hasattr(self, 'tutor_group'):
            await self.channel_layer.group_discard(
                self.tutor_group,
                self.channel_name
            )
            logger.info(f"WebSocket disconnected: group={self.tutor_group}, code={close_code}")
    
    async def receive(self, text_data):
        """Handle messages from WebSocket client (mobile app)."""
        try:
            data = json.loads(text_data)
            message_type = data.get('type')
            
            if message_type == 'ping':
                # Responder a ping para mantener conexión viva
                await self.send(text_data=json.dumps({'type': 'pong'}))
            
            elif message_type == 'subscribe_child':
                # Suscribirse a actualizaciones de un niño específico
                child_id = data.get('child_id')
                if child_id:
                    # Verificar que el niño pertenece al tutor
                    is_valid = await self._verify_child_ownership(child_id)
                    if is_valid:
                        child_group = f"child_{child_id}"
                        await self.channel_layer.group_add(child_group, self.channel_name)
                        await self.send(text_data=json.dumps({
                            'type': 'subscribed',
                            'child_id': child_id,
                        }))
                    else:
                        await self.send(text_data=json.dumps({
                            'type': 'error',
                            'message': 'Child not found or not authorized',
                        }))
            
            elif message_type == 'unsubscribe_child':
                child_id = data.get('child_id')
                if child_id:
                    child_group = f"child_{child_id}"
                    await self.channel_layer.group_discard(child_group, self.channel_name)
                    await self.send(text_data=json.dumps({
                        'type': 'unsubscribed',
                        'child_id': child_id,
                    }))
                    
        except json.JSONDecodeError:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'message': 'Invalid JSON',
            }))
    
    async def location_update(self, event):
        """
        Handler para enviar actualizaciones de ubicación al cliente.
        Llamado cuando se recibe un mensaje en el grupo.
        """
        await self.send(text_data=json.dumps({
            'type': 'location_update',
            'child_id': event['child_id'],
            'child_name': event['child_name'],
            'latitude': event['latitude'],
            'longitude': event['longitude'],
            'battery_level': event.get('battery_level'),
            'timestamp': event['timestamp'],
        }))
    
    async def alert_created(self, event):
        """
        Handler para enviar alertas al cliente.
        Llamado cuando un niño sale de la zona segura.
        """
        await self.send(text_data=json.dumps({
            'type': 'alert',
            'alert_id': event['alert_id'],
            'child_id': event['child_id'],
            'child_name': event['child_name'],
            'message': event['message'],
            'latitude': event['latitude'],
            'longitude': event['longitude'],
            'timestamp': event['timestamp'],
        }))
    
    @database_sync_to_async
    def _verify_child_ownership(self, child_id):
        """Verify that the child belongs to the authenticated tutor."""
        from .models import Child
        return Child.objects.filter(id=child_id, tutor=self.user).exists()


class TrackerConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer para dispositivos tracker.
    Permite enviar ubicaciones en tiempo real sin autenticación de usuario,
    pero requiere device_id válido.
    """
    
    async def connect(self):
        """Handle tracker WebSocket connection."""
        try:
            # Obtener device_id de query params
            query_string = self.scope.get('query_string', b'').decode()
            from urllib.parse import parse_qs
            query_params = parse_qs(query_string)
            
            device_id_list = query_params.get('device_id', [])
            self.device_id = device_id_list[0] if device_id_list else None
            
            if not self.device_id:
                logger.warning("Tracker WebSocket rejected: no device_id")
                await self.close(code=4002)
                return
            
            # Verificar que el device existe y obtener child_id
            device_info = await self._get_device_info()
            if not device_info:
                logger.warning(f"Tracker WebSocket rejected: invalid device_id={self.device_id}")
                await self.close(code=4003)
                return
            
            self.child_id = device_info['child_id']
            self.tutor_id = device_info['tutor_id']
            self.child_name = device_info['child_name']
            
            # Aceptar conexión
            await self.accept()
            logger.info(f"Tracker connected: device={self.device_id}, child={self.child_id}, tutor={self.tutor_id}")
            
            # Enviar confirmación
            await self.send(text_data=json.dumps({
                'type': 'connection_established',
                'message': 'Tracker connected',
                'device_id': self.device_id,
                'child_name': self.child_name,
            }))
            
            logger.info(f"Tracker {self.device_id}: connection_established sent, waiting for messages...")
            
        except Exception as e:
            logger.error(f"Tracker connect error: {e}")
            import traceback
            logger.error(traceback.format_exc())
            await self.close(code=4000)
    
    async def disconnect(self, close_code):
        """Handle tracker disconnection."""
        logger.info(f"Tracker disconnected: device={getattr(self, 'device_id', 'unknown')}, code={close_code}")
    
    async def receive(self, text_data):
        """
        Handle location updates from tracker.
        
        OPTIMIZACIÓN ESTILO UBER/WHATSAPP:
        1. Broadcast INMEDIATO a clientes (< 50ms)
        2. Confirmación al tracker
        3. Persistencia y geofencing en BACKGROUND (no bloquea)
        """
        try:
            data = json.loads(text_data)
            message_type = data.get('type')
            
            if message_type == 'location':
                latitude = data.get('latitude')
                longitude = data.get('longitude')
                battery_level = data.get('battery_level')
                
                if latitude is not None and longitude is not None:
                    # 1. BROADCAST INMEDIATO - Esto es lo que hace la diferencia
                    #    Los clientes reciben la ubicación ANTES de guardar en BD
                    await self._broadcast_location(latitude, longitude, battery_level)
                    
                    # 2. Confirmación inmediata al tracker
                    await self.send(text_data=json.dumps({
                        'type': 'location_ack',
                        'success': True,
                    }))
                    
                    # 3. Procesar en BACKGROUND (persistencia, geofencing, alertas)
                    #    No bloqueamos el flujo principal
                    asyncio.create_task(
                        self._process_location_background(latitude, longitude, battery_level)
                    )
            
            elif message_type == 'ping':
                await self.send(text_data=json.dumps({'type': 'pong'}))
                
        except json.JSONDecodeError:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'message': 'Invalid JSON',
            }))
    
    async def _process_location_background(self, latitude, longitude, battery_level):
        """
        Procesa la ubicación en background:
        - Guarda en BD
        - Verifica geofencing
        - Envía alertas si es necesario
        
        Esto se ejecuta DESPUÉS del broadcast, sin bloquear.
        """
        try:
            result = await self._update_device_location(latitude, longitude, battery_level)
            
            if result.get('alert'):
                await self._broadcast_alert(result['alert'])
                
        except Exception as e:
            logger.error(f"Background processing error: {e}")
    
    @database_sync_to_async
    def _get_device_info(self):
        """Get device info from database."""
        from .models import Device
        try:
            device = Device.objects.select_related('child__tutor').get(device_id=self.device_id)
            return {
                'child_id': device.child.id,
                'child_name': device.child.full_name,
                'tutor_id': device.child.tutor.id,
            }
        except Device.DoesNotExist:
            return None
    
    @database_sync_to_async
    def _update_device_location(self, latitude, longitude, battery_level):
        """Update device location in database and check safe zones (individual AND group)."""
        from django.utils import timezone
        from .models import Device, SafeZone, GroupSafeZone, GroupMembership, GroupTutor, Alert
        from decimal import Decimal
        
        try:
            device = Device.objects.select_related('child__tutor').get(device_id=self.device_id)
            
            # Guardar estado anterior para detectar cambios
            was_in_safe_zone = getattr(device, 'is_in_safe_zone', None)
            previous_battery = device.battery_level
            
            # Actualizar ubicación
            device.last_latitude = Decimal(str(latitude))
            device.last_longitude = Decimal(str(longitude))
            device.last_seen = timezone.now()
            if battery_level is not None:
                device.battery_level = battery_level
            
            child = device.child
            tutor = child.tutor
            
            # =========================================================
            # VERIFICAR ZONAS INDIVIDUALES
            # =========================================================
            individual_zones = SafeZone.objects.filter(child=child, is_active=True)
            has_individual_zones = individual_zones.exists()
            
            is_in_any_individual_zone = False
            entered_individual_zones = []
            exited_individual_zones = []
            
            if has_individual_zones:
                for zone in individual_zones:
                    is_in_zone = zone.contains_point(latitude, longitude)
                    if is_in_zone:
                        is_in_any_individual_zone = True
                        entered_individual_zones.append(zone)
                    else:
                        exited_individual_zones.append(zone)
            
            # =========================================================
            # VERIFICAR ZONAS DE GRUPO
            # =========================================================
            group_memberships = GroupMembership.objects.filter(
                child=child, 
                is_active=True,
                group__is_active=True
            ).select_related('group')
            
            # Tracking de zonas de grupo
            entered_group_zones = []  # [(zone, group), ...]
            exited_group_zones = []   # [(zone, group), ...]
            
            for membership in group_memberships:
                group = membership.group
                group_zones = GroupSafeZone.objects.filter(group=group, is_active=True)
                
                for zone in group_zones:
                    is_in_zone = zone.contains_point(latitude, longitude)
                    if is_in_zone:
                        entered_group_zones.append({'zone': zone, 'group': group})
                    else:
                        exited_group_zones.append({'zone': zone, 'group': group})
            
            # Determinar estado general de seguridad
            is_safe = is_in_any_individual_zone or len(entered_group_zones) > 0
            
            # Guardar estado actual
            device.is_in_safe_zone = is_safe
            device.save()
            
            # Registrar en el historial de ubicación
            try:
                from monitoring.models_history import LocationHistory
                LocationHistory.record_location(
                    device=device,
                    latitude=device.last_latitude,
                    longitude=device.last_longitude,
                    battery_level=device.battery_level,
                    is_in_safe_zone=is_safe
                )
            except Exception as history_error:
                logger.error(f"Error writing to LocationHistory in consumers: {history_error}")
            
            alert_data = None
            sent_notifications = set()  # Evitar duplicados por usuario
            
            # =========================================================
            # ALERTAS DE SALIDA - ZONAS INDIVIDUALES
            # Solo si tiene zonas individuales y salió de TODAS
            # =========================================================
            if has_individual_zones and not is_in_any_individual_zone:
                # Verificar si ya hay alerta pendiente reciente
                recent_alert = Alert.objects.filter(
                    child=child,
                    status='pending',
                    group__isnull=True,
                    created_at__gte=timezone.now() - timezone.timedelta(minutes=5)
                ).exists()
                
                if not recent_alert:
                    # Construir mensaje con nombres de zonas
                    zone_names = [z.name for z in exited_individual_zones]
                    if len(zone_names) == 1:
                        zone_text = f"la zona '{zone_names[0]}'"
                    else:
                        zone_text = f"las zonas: {', '.join(zone_names)}"
                    
                    alert = Alert.objects.create(
                        child=child,
                        latitude=device.last_latitude,
                        longitude=device.last_longitude,
                        message=f"¡ALERTA! {child.full_name} ha salido de {zone_text}.",
                        status='pending',
                        alert_type='zone_exit'
                    )
                    alert_data = {
                        'id': alert.id,
                        'message': alert.message,
                        'created_at': alert.created_at.isoformat(),
                        'type': 'zone_exit',
                        'latitude': float(alert.latitude) if alert.latitude else 0.0,
                        'longitude': float(alert.longitude) if alert.longitude else 0.0,
                    }
                    
                    # Enviar notificación push con nombre de zona
                    try:
                        from .firebase_service import send_zone_exit_alert
                        send_zone_exit_alert(
                            tutor, 
                            child.full_name, 
                            alert.id, 
                            latitude, 
                            longitude,
                            zone_name=zone_names[0] if len(zone_names) == 1 else None,
                            child_id=child.id
                        )
                        sent_notifications.add(tutor.id)
                        logger.info(f"Individual zone exit notification sent for {child.full_name}")
                    except Exception as e:
                        logger.error(f"Failed to send zone exit notification: {e}")
            
            # =========================================================
            # ALERTAS DE SALIDA - ZONAS DE GRUPO
            # Una alerta por grupo (no por zona)
            # =========================================================
            notified_groups = set()  # Evitar múltiples alertas por grupo
            
            for exited_info in exited_group_zones:
                zone = exited_info['zone']
                group = exited_info['group']
                
                # Solo una alerta por grupo
                if group.id in notified_groups:
                    continue
                
                # Verificar si ya hay alerta pendiente para este grupo y niño
                recent_group_alert = Alert.objects.filter(
                    child=child,
                    group=group,
                    status='pending',
                    created_at__gte=timezone.now() - timezone.timedelta(minutes=5)
                ).exists()
                
                if not recent_group_alert:
                    notified_groups.add(group.id)
                    
                    # Crear alerta
                    alert = Alert.objects.create(
                        child=child,
                        group=group,
                        latitude=device.last_latitude,
                        longitude=device.last_longitude,
                        message=f"¡ALERTA GRUPO! {child.full_name} ha salido de la zona '{zone.name}' del grupo '{group.name}'.",
                        status='pending',
                        alert_type='zone_exit'
                    )
                    
                    logger.info(f"Group zone exit alert created: child={child.full_name}, group={group.name}, zone={zone.name}")
                    
                    # Notificar al dueño del grupo (solo si no ya notificado)
                    if group.owner.id not in sent_notifications:
                        try:
                            from .firebase_service import send_zone_exit_alert
                            send_zone_exit_alert(
                                group.owner, 
                                child.full_name, 
                                alert.id, 
                                latitude, 
                                longitude,
                                group_name=group.name,
                                zone_name=zone.name,
                                child_id=child.id
                            )
                            sent_notifications.add(group.owner.id)
                            logger.info(f"Group zone exit notification sent to owner {group.owner.email}")
                        except Exception as e:
                            logger.error(f"Failed to send notification to owner: {e}")
                    
                    # Notificar a co-tutores del grupo
                    for group_tutor in GroupTutor.objects.filter(group=group, is_active=True).select_related('tutor'):
                        if group_tutor.tutor.id not in sent_notifications:
                            try:
                                from .firebase_service import send_zone_exit_alert
                                send_zone_exit_alert(
                                    group_tutor.tutor, 
                                    child.full_name, 
                                    alert.id, 
                                    latitude, 
                                    longitude,
                                    group_name=group.name,
                                    zone_name=zone.name,
                                    child_id=child.id
                                )
                                sent_notifications.add(group_tutor.tutor.id)
                                logger.info(f"Group zone exit notification sent to tutor {group_tutor.tutor.email}")
                            except Exception as e:
                                logger.error(f"Failed to send notification to tutor: {e}")
            
            # =========================================================
            # ALERTAS DE ENTRADA - Solo si HABÍA alerta pendiente
            # =========================================================
            sent_entry_notifications = set()
            
            # Entrada a zona INDIVIDUAL - solo si había alerta pendiente
            if is_in_any_individual_zone and has_individual_zones:
                pending_individual_alert = Alert.objects.filter(
                    child=child,
                    status='pending',
                    group__isnull=True
                ).first()
                
                if pending_individual_alert:
                    pending_individual_alert.status = 'resolved'
                    pending_individual_alert.save()
                    
                    # Enviar notificación de entrada con nombre de zona
                    zone_name = entered_individual_zones[0].name if entered_individual_zones else None
                    if tutor.id not in sent_entry_notifications:
                        try:
                            from .firebase_service import send_zone_entry_alert
                            send_zone_entry_alert(tutor, child.full_name, zone_name=zone_name)
                            sent_entry_notifications.add(tutor.id)
                            logger.info(f"Individual zone entry notification sent for {child.full_name}")
                        except Exception as e:
                            logger.error(f"Failed to send zone entry notification: {e}")
            
            # Entrada a zonas de GRUPO - solo si había alerta pendiente para ese grupo
            notified_entry_groups = set()
            
            for entered_info in entered_group_zones:
                zone = entered_info['zone']
                group = entered_info['group']
                
                if group.id in notified_entry_groups:
                    continue
                
                # Solo notificar si había alerta pendiente para este grupo
                pending_group_alert = Alert.objects.filter(
                    child=child,
                    group=group,
                    status='pending'
                ).first()
                
                if pending_group_alert:
                    notified_entry_groups.add(group.id)
                    pending_group_alert.status = 'resolved'
                    pending_group_alert.save()
                    
                    logger.info(f"Child {child.full_name} entered group zone '{zone.name}' of group '{group.name}'")
                    
                    # Notificar al dueño (si no ya notificado)
                    if group.owner.id not in sent_entry_notifications:
                        try:
                            from .firebase_service import send_zone_entry_alert
                            send_zone_entry_alert(
                                group.owner, 
                                child.full_name,
                                group_name=group.name,
                                zone_name=zone.name
                            )
                            sent_entry_notifications.add(group.owner.id)
                            logger.info(f"Group zone entry notification sent to owner {group.owner.email}")
                        except Exception as e:
                            logger.error(f"Failed to send notification to owner: {e}")
                    
                    # Notificar a co-tutores
                    for group_tutor in GroupTutor.objects.filter(group=group, is_active=True).select_related('tutor'):
                        if group_tutor.tutor.id not in sent_entry_notifications:
                            try:
                                from .firebase_service import send_zone_entry_alert
                                send_zone_entry_alert(
                                    group_tutor.tutor, 
                                    child.full_name,
                                    group_name=group.name,
                                    zone_name=zone.name
                                )
                                sent_entry_notifications.add(group_tutor.tutor.id)
                                logger.info(f"Group zone entry notification sent to tutor {group_tutor.tutor.email}")
                            except Exception as e:
                                logger.error(f"Failed to send notification to tutor: {e}")
            
            # =========================================================
            # BATERÍA BAJA
            # =========================================================
            if battery_level is not None and battery_level <= 20:
                if previous_battery is None or previous_battery > 20:
                    try:
                        from .firebase_service import send_low_battery_alert
                        send_low_battery_alert(tutor, child.full_name, battery_level)
                        logger.info(f"Low battery notification sent for {child.full_name}: {battery_level}%")
                    except Exception as e:
                        logger.error(f"Failed to send low battery notification: {e}")
            
            return {'success': True, 'alert': alert_data}
            
        except Device.DoesNotExist:
            return {'success': False, 'error': 'Device not found'}
        except Exception as e:
            logger.error(f"Error updating location: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {'success': False, 'error': str(e)}
    
    async def _broadcast_location(self, latitude, longitude, battery_level):
        """Broadcast location update to all subscribed clients."""
        from django.utils import timezone
        
        timestamp = timezone.now().isoformat()
        
        try:
            # Enviar al grupo del tutor
            tutor_group = f"tutor_{self.tutor_id}"
            logger.info(f"Broadcasting location to group {tutor_group}: child={self.child_id}, lat={latitude}, lng={longitude}")
            
            await self.channel_layer.group_send(
                tutor_group,
                {
                    'type': 'location_update',
                    'child_id': self.child_id,
                    'child_name': self.child_name,
                    'latitude': latitude,
                    'longitude': longitude,
                    'battery_level': battery_level,
                    'timestamp': timestamp,
                }
            )
            
            # También enviar al grupo específico del niño
            child_group = f"child_{self.child_id}"
            logger.info(f"Broadcasting location to group {child_group}")
            
            await self.channel_layer.group_send(
                child_group,
                {
                    'type': 'location_update',
                    'child_id': self.child_id,
                    'child_name': self.child_name,
                    'latitude': latitude,
                    'longitude': longitude,
                    'battery_level': battery_level,
                    'timestamp': timestamp,
                }
            )
        except Exception as e:
            # No fallar si el broadcast falla (Redis down, etc)
            logger.error(f"Broadcast error (non-fatal): {e}")
    
    async def _broadcast_alert(self, alert_data):
        """Broadcast alert to tutor."""
        tutor_group = f"tutor_{self.tutor_id}"
        await self.channel_layer.group_send(
            tutor_group,
            {
                'type': 'alert_created',
                'alert_id': alert_data['id'],
                'child_id': self.child_id,
                'child_name': self.child_name,
                'message': alert_data['message'],
                'latitude': alert_data.get('latitude', 0.0),
                'longitude': alert_data.get('longitude', 0.0),
                'timestamp': alert_data['created_at'],
            }
        )
