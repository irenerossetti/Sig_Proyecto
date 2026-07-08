from django.utils import timezone
from django.db.models import Q
from rest_framework import mixins, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from drf_spectacular.utils import extend_schema, extend_schema_view, OpenApiParameter, OpenApiTypes
import asyncio
import logging

from .models import (
    Alert, Child, Device, SafeZone,
    ChildGroup, GroupMembership, GroupTutor, GroupSafeZone,
    Notification
)
from .serializers import (
    AlertSerializer,
    ChildSerializer,
    DeviceCreateSerializer,
    DeviceLocationUpdateSerializer,
    DeviceSerializer,
    SafeZoneSerializer,
    ChildGroupSerializer,
    ChildGroupDetailSerializer,
    GroupMembershipSerializer,
    GroupTutorSerializer,
    GroupTutorInviteSerializer,
    GroupSafeZoneSerializer,
    ChildWithLocationSerializer,
    NotificationSerializer,
)
from .firebase_service import send_alert_notification
from accounts.models import User

logger = logging.getLogger(__name__)


@extend_schema_view(
    list=extend_schema(
        summary="Listar niños",
        description="Lista todos los niños del tutor autenticado, incluyendo niños de grupos compartidos.",
        tags=["children"]
    ),
    retrieve=extend_schema(
        summary="Obtener niño",
        description="Obtiene los detalles de un niño específico.",
        tags=["children"]
    ),
    create=extend_schema(
        summary="Registrar niño",
        description="Registra un nuevo niño. Automáticamente crea un dispositivo GPS asociado.",
        tags=["children"]
    ),
    update=extend_schema(
        summary="Actualizar niño",
        description="Actualiza los datos de un niño. Solo el tutor propietario puede editar.",
        tags=["children"]
    ),
    destroy=extend_schema(
        summary="Eliminar niño",
        description="Elimina un niño y su dispositivo asociado. Solo el tutor propietario puede eliminar.",
        tags=["children"]
    ),
)
class ChildViewSet(viewsets.ModelViewSet):
	"""CRUD operations for children belonging to the authenticated tutor."""

	serializer_class = ChildSerializer
	permission_classes = [permissions.IsAuthenticated]
	parser_classes = [JSONParser, MultiPartParser, FormParser]

	def get_queryset(self):
		user = self.request.user
		
		# Admins ven todos los niños
		if user.is_staff:
			return Child.objects.all().select_related("device", "tutor").order_by("full_name")
		
		# Niños propios del tutor
		own_children = Q(tutor=user)
		
		# Niños de grupos donde el usuario es co-tutor activo
		# (grupos donde está invitado como admin o monitor)
		group_children = Q(
			group_memberships__group__tutors__tutor=user,
			group_memberships__group__tutors__is_active=True,
			group_memberships__is_active=True
		)
		
		return (
			Child.objects.filter(own_children | group_children)
			.select_related("device")
			.distinct()
			.order_by("full_name")
		)

	def perform_create(self, serializer):
		serializer.save(tutor=self.request.user)

	def perform_update(self, serializer):
		# Solo el tutor propietario puede editar
		child = self.get_object()
		if child.tutor != self.request.user:
			raise permissions.PermissionDenied("Solo el tutor propietario puede editar este niño")
		serializer.save(tutor=self.request.user)
	
	def perform_destroy(self, instance):
		# Solo el tutor propietario puede eliminar
		if instance.tutor != self.request.user:
			raise permissions.PermissionDenied("Solo el tutor propietario puede eliminar este niño")
		instance.delete()


@extend_schema_view(
    list=extend_schema(
        summary="Listar alertas",
        description="Lista todas las alertas de los niños del tutor, ordenadas por fecha.",
        tags=["alerts"]
    ),
    retrieve=extend_schema(
        summary="Obtener alerta",
        description="Obtiene los detalles de una alerta específica.",
        tags=["alerts"]
    ),
    update=extend_schema(
        summary="Actualizar alerta",
        description="Actualiza el estado de una alerta.",
        tags=["alerts"]
    ),
)
class AlertViewSet(mixins.ListModelMixin, mixins.UpdateModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
	"""Expose alerts related to the tutor's children and groups."""

	serializer_class = AlertSerializer
	permission_classes = [permissions.IsAuthenticated]

	def get_queryset(self):
		user = self.request.user
		
		# Admins ven todas las alertas
		if user.is_staff:
			return Alert.objects.all().select_related("child").order_by("-created_at")
		
		# Alertas de niños propios
		own_children_alerts = Q(child__tutor=user)
		
		# Alertas de niños en grupos donde el usuario es co-tutor activo
		group_children_alerts = Q(
			child__group_memberships__group__tutors__tutor=user,
			child__group_memberships__group__tutors__is_active=True,
			child__group_memberships__is_active=True
		)
		
		return (
			Alert.objects.filter(own_children_alerts | group_children_alerts)
			.select_related("child")
			.distinct()
			.order_by("-created_at")
		)

	@extend_schema(
		summary="Reconocer alerta",
		description="Marca una alerta como reconocida (acknowledged). El tutor ha visto la alerta.",
		tags=["alerts"],
	)
	@action(detail=True, methods=["post"], url_path="acknowledge")
	def acknowledge(self, request, pk=None):
		"""Mark an alert as acknowledged."""
		alert = self.get_object()
		if alert.status == 'acknowledged' or alert.status == 'resolved':
			return Response(
				{"error": "La alerta ya fue reconocida o resuelta"},
				status=status.HTTP_400_BAD_REQUEST
			)
		
		alert.status = 'acknowledged'
		alert.acknowledged_at = timezone.now()
		alert.save(update_fields=['status', 'acknowledged_at'])
		
		return Response(AlertSerializer(alert).data)

	@extend_schema(
		summary="Resolver alerta",
		description="Marca una alerta como resuelta. El niño está a salvo.",
		tags=["alerts"],
	)
	@action(detail=True, methods=["post"], url_path="resolve")
	def resolve(self, request, pk=None):
		"""Mark an alert as resolved."""
		alert = self.get_object()
		if alert.status == 'resolved':
			return Response(
				{"error": "La alerta ya fue resuelta"},
				status=status.HTTP_400_BAD_REQUEST
			)
		
		alert.status = 'resolved'
		alert.resolved_at = timezone.now()
		if not alert.acknowledged_at:
			alert.acknowledged_at = timezone.now()
		alert.save(update_fields=['status', 'resolved_at', 'acknowledged_at'])
		
		return Response(AlertSerializer(alert).data)

	@extend_schema(
		summary="Contar alertas pendientes",
		description="Retorna el número de alertas pendientes del tutor.",
		tags=["alerts"],
	)
	@action(detail=False, methods=["get"], url_path="pending-count")
	def pending_count(self, request):
		"""Get count of pending alerts."""
		count = self.get_queryset().filter(status='pending').count()
		return Response({"pending_count": count})


@extend_schema_view(
    list=extend_schema(
        summary="Listar dispositivos",
        description="Lista todos los dispositivos GPS de los niños del tutor.",
        tags=["devices"]
    ),
    retrieve=extend_schema(
        summary="Obtener dispositivo",
        description="Obtiene los detalles de un dispositivo específico.",
        tags=["devices"]
    ),
    create=extend_schema(
        summary="Crear dispositivo",
        description="Crea un nuevo dispositivo GPS y lo asocia a un niño.",
        tags=["devices"]
    ),
)
class DeviceViewSet(viewsets.ModelViewSet):
    """CRUD operations for devices assigned to the tutor's children."""

    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.action == "create":
            return DeviceCreateSerializer
        if self.action == "update_location":
            return DeviceLocationUpdateSerializer
        return DeviceSerializer

    def get_queryset(self):
        user = self.request.user
        # Admins ven todos los dispositivos
        if user.is_staff:
            return Device.objects.all().select_related("child", "child__tutor").order_by("-last_seen")
        return Device.objects.filter(child__tutor=user).select_related("child")

    def _check_safe_zones_and_create_alert(self, device):
        """
        Verifica si el dispositivo está fuera de todas las zonas seguras.
        Si está fuera, crea una alerta usando consulta espacial PostGIS.
        """
        if device.last_latitude is None or device.last_longitude is None:
            return
        
        lat = float(device.last_latitude)
        lng = float(device.last_longitude)
        child = device.child
        
        # Consulta espacial PostGIS: ¿está el punto dentro de alguna zona?
        is_safe = SafeZone.is_point_in_any_zone(child.id, lat, lng)
        
        if not is_safe:
            # Verificar que haya zonas activas para este niño
            has_zones = SafeZone.objects.filter(child=child, is_active=True).exists()
            if has_zones:
                # Verificar si ya existe una alerta pendiente reciente (últimos 5 minutos)
                recent_alert = Alert.objects.filter(
                    child=child,
                    status='pending',
                    created_at__gte=timezone.now() - timezone.timedelta(minutes=5)
                ).exists()
                
                if not recent_alert:
                    # Obtener nombres de las zonas de las que salió
                    exited_zones = SafeZone.get_zones_not_containing_point(child.id, lat, lng)
                    zone_names = [z.name for z in exited_zones]
                    if len(zone_names) == 1:
                        zone_text = f"la zona '{zone_names[0]}'"
                    elif len(zone_names) > 1:
                        zone_text = f"las zonas: {', '.join(zone_names)}"
                    else:
                        zone_text = "las zonas seguras"
                    
                    # Crear la alerta
                    alert = Alert.objects.create(
                        child=child,
                        latitude=device.last_latitude,
                        longitude=device.last_longitude,
                        message=f"¡ALERTA! {child.full_name} ha salido de {zone_text}.",
                        status='pending'
                    )
                    
                    # Enviar notificación push al tutor
                    try:
                        send_alert_notification(
                            tutor=child.tutor,
                            child_name=child.full_name,
                            alert_message=alert.message,
                            alert_id=alert.id
                        )
                    except Exception as e:
                        import logging
                        logger = logging.getLogger(__name__)
                        logger.error(f"Failed to send push notification: {e}")

        # Update security status on device and save
        device.is_in_safe_zone = is_safe
        device.save(update_fields=['is_in_safe_zone'])

        # Record entry in LocationHistory
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
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Error writing to LocationHistory in views: {history_error}")

    @extend_schema(
        summary="Actualizar ubicación por device_id",
        description="Actualiza la ubicación de un dispositivo usando su device_id. Endpoint público para la app tracker.",
        tags=["devices"],
        request=DeviceLocationUpdateSerializer,
    )
    @action(detail=False, methods=["post"], url_path="update-location-by-id", permission_classes=[permissions.AllowAny])
    def update_location_by_id(self, request):
        """Update device location using device_id (for tracker app)."""
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"update_location_by_id called with data: {request.data}")
        
        device_id = request.data.get("device_id")
        if not device_id:
            return Response({"error": "device_id is required"}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            device = Device.objects.get(device_id=device_id)
        except Device.DoesNotExist:
            logger.error(f"Device not found: {device_id}")
            return Response({"error": "Device not found"}, status=status.HTTP_404_NOT_FOUND)

        serializer = DeviceLocationUpdateSerializer(data=request.data)
        if not serializer.is_valid():
            logger.error(f"Validation errors: {serializer.errors}")
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        device.last_latitude = serializer.validated_data["latitude"]
        device.last_longitude = serializer.validated_data["longitude"]
        device.last_seen = timezone.now()
        if "battery_level" in serializer.validated_data:
            device.battery_level = serializer.validated_data["battery_level"]
        device.save()  # El save() ahora sincroniza automáticamente el Point PostGIS
        
        # Verificar zonas seguras y crear alerta si es necesario (PostGIS)
        self._check_safe_zones_and_create_alert(device)

        return Response({"status": "success"}, status=status.HTTP_200_OK)

    @extend_schema(
        summary="Actualizar ubicación",
        description="Actualiza la ubicación GPS de un dispositivo específico.",
        tags=["devices"],
        request=DeviceLocationUpdateSerializer,
    )
    @action(detail=True, methods=["post"], url_path="location")
    def update_location(self, request, pk=None):
        """Update device GPS location (simulates real device updates)."""
        device = self.get_object()
        serializer = DeviceLocationUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        device.last_latitude = serializer.validated_data["latitude"]
        device.last_longitude = serializer.validated_data["longitude"]
        device.last_seen = timezone.now()
        if "battery_level" in serializer.validated_data:
            device.battery_level = serializer.validated_data["battery_level"]
        device.save()  # El save() ahora sincroniza automáticamente el Point PostGIS
        
        # Verificar zonas seguras y crear alerta si es necesario (PostGIS)
        self._check_safe_zones_and_create_alert(device)

        return Response(DeviceSerializer(device).data, status=status.HTTP_200_OK)


@extend_schema_view(
    list=extend_schema(
        summary="Listar zonas seguras",
        description="Lista todas las zonas seguras de los niños del tutor.",
        tags=["safe-zones"],
        parameters=[
            OpenApiParameter(
                name="child",
                type=OpenApiTypes.INT,
                location=OpenApiParameter.QUERY,
                description="Filtrar por ID de niño"
            )
        ]
    ),
    retrieve=extend_schema(
        summary="Obtener zona segura",
        description="Obtiene los detalles de una zona segura específica.",
        tags=["safe-zones"]
    ),
    create=extend_schema(
        summary="Crear zona segura",
        description="Crea una nueva zona segura (polígono o círculo) para un niño.",
        tags=["safe-zones"]
    ),
    update=extend_schema(
        summary="Actualizar zona segura",
        description="Actualiza una zona segura existente.",
        tags=["safe-zones"]
    ),
    destroy=extend_schema(
        summary="Eliminar zona segura",
        description="Elimina una zona segura.",
        tags=["safe-zones"]
    ),
)
class SafeZoneViewSet(viewsets.ModelViewSet):
    """CRUD operations for safe zones belonging to the tutor's children."""

    serializer_class = SafeZoneSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        
        # Admins ven todas las zonas seguras
        if user.is_staff:
            queryset = SafeZone.objects.all().select_related("child", "child__tutor").order_by("-created_at")
        else:
            queryset = SafeZone.objects.filter(
                child__tutor=user
            ).select_related("child").order_by("-created_at")
        
        # Filtrar por niño si se especifica
        child_id = self.request.query_params.get("child")
        if child_id:
            queryset = queryset.filter(child_id=child_id)
        
        return queryset

    @extend_schema(
        summary="Verificar punto en zona",
        description="Verifica si un punto está dentro de una zona segura usando PostGIS ST_Contains.",
        tags=["safe-zones"],
    )
    @action(detail=True, methods=["post"], url_path="check-point")
    def check_point(self, request, pk=None):
        """Check if a point is inside the safe zone using PostGIS ST_Contains."""
        safe_zone = self.get_object()
        lat = request.data.get("latitude")
        lng = request.data.get("longitude")
        
        if lat is None or lng is None:
            return Response(
                {"error": "latitude and longitude are required"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            lat = float(lat)
            lng = float(lng)
        except (ValueError, TypeError):
            return Response(
                {"error": "Invalid latitude or longitude"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Usar PostGIS para verificación espacial
        is_inside = safe_zone.contains_point(lat, lng)
        return Response({
            "is_inside": is_inside,
            "safe_zone_id": safe_zone.id,
            "safe_zone_name": safe_zone.name,
        })
    
    @extend_schema(
        summary="Verificar todas las zonas",
        description="Verifica si un punto está dentro de ALGUNA zona segura de un niño usando PostGIS.",
        tags=["safe-zones"],
    )
    @action(detail=False, methods=["post"], url_path="check-all")
    def check_all_zones(self, request):
        """
        Verifica si un punto está dentro de ALGUNA zona segura de un niño.
        Usa consulta espacial PostGIS optimizada con índice GiST.
        """
        child_id = request.data.get("child_id")
        lat = request.data.get("latitude")
        lng = request.data.get("longitude")
        
        if not all([child_id, lat, lng]):
            return Response(
                {"error": "child_id, latitude and longitude are required"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            lat = float(lat)
            lng = float(lng)
            child_id = int(child_id)
        except (ValueError, TypeError):
            return Response(
                {"error": "Invalid parameters"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Verificar que el niño pertenece al tutor
        if not Child.objects.filter(id=child_id, tutor=request.user).exists():
            return Response(
                {"error": "Child not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Consulta espacial PostGIS
        is_safe = SafeZone.is_point_in_any_zone(child_id, lat, lng)
        zones_containing = SafeZone.get_zones_containing_point(child_id, lat, lng)
        
        return Response({
            "is_safe": is_safe,
            "child_id": child_id,
            "latitude": lat,
            "longitude": lng,
            "zones_containing": [
                {"id": z.id, "name": z.name} for z in zones_containing
            ]
        })


class GeocodingViewSet(viewsets.ViewSet):
    """
    Google Cloud Geocoding API endpoints.
    Provides address lookup for coordinates.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    @action(detail=False, methods=["post"], url_path="reverse")
    def reverse_geocode(self, request):
        """
        Convert coordinates to a human-readable address.
        
        POST /api/monitoring/geocoding/reverse/
        {
            "latitude": -17.7694,
            "longitude": -63.2078
        }
        
        Returns:
        {
            "address": "Av. Banzer, Santa Cruz de la Sierra, Bolivia",
            "latitude": -17.7694,
            "longitude": -63.2078
        }
        """
        lat = request.data.get("latitude")
        lng = request.data.get("longitude")
        
        if lat is None or lng is None:
            return Response(
                {"error": "latitude and longitude are required"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            lat = float(lat)
            lng = float(lng)
        except (ValueError, TypeError):
            return Response(
                {"error": "Invalid coordinates"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            from .google_services import get_geocoding_service
            geocoding = get_geocoding_service()
            address = geocoding.reverse_geocode_sync(lat, lng)
            
            return Response({
                "address": address,
                "latitude": lat,
                "longitude": lng,
            })
        except Exception as e:
            logger.error(f"Geocoding error: {e}")
            return Response(
                {"error": "Geocoding service unavailable"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE
            )
    
    @action(detail=False, methods=["post"], url_path="batch")
    def batch_geocode(self, request):
        """
        Get addresses for multiple coordinates.
        
        POST /api/monitoring/geocoding/batch/
        {
            "points": [
                {"latitude": -17.7694, "longitude": -63.2078},
                {"latitude": -17.7700, "longitude": -63.2100}
            ]
        }
        """
        points = request.data.get("points", [])
        
        if not points or len(points) > 20:
            return Response(
                {"error": "Provide 1-20 points"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            from .google_services import get_geocoding_service
            geocoding = get_geocoding_service()
            
            results = []
            for point in points:
                lat = point.get("latitude")
                lng = point.get("longitude")
                if lat is not None and lng is not None:
                    address = geocoding.reverse_geocode_sync(float(lat), float(lng))
                    results.append({
                        "latitude": lat,
                        "longitude": lng,
                        "address": address,
                    })
            
            return Response({"results": results})
        except Exception as e:
            logger.error(f"Batch geocoding error: {e}")
            return Response(
                {"error": "Geocoding service unavailable"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE
            )


class PlacesViewSet(viewsets.ViewSet):
    """
    Google Cloud Places API endpoints.
    Find nearby landmarks and points of interest.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    @action(detail=False, methods=["post"], url_path="nearby")
    def find_nearby(self, request):
        """
        Find nearby landmarks (schools, parks, etc.)
        
        POST /api/monitoring/places/nearby/
        {
            "latitude": -17.7694,
            "longitude": -63.2078,
            "radius": 200
        }
        """
        lat = request.data.get("latitude")
        lng = request.data.get("longitude")
        radius = request.data.get("radius", 200)
        
        if lat is None or lng is None:
            return Response(
                {"error": "latitude and longitude are required"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            from .google_services import get_places_service
            places = get_places_service()
            
            # Run async function in sync context
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                result = loop.run_until_complete(
                    places.find_nearby_landmark(float(lat), float(lng), int(radius))
                )
            finally:
                loop.close()
            
            if result:
                return Response(result)
            else:
                return Response({"message": "No landmarks found nearby"})
                
        except Exception as e:
            logger.error(f"Places API error: {e}")
            return Response(
                {"error": "Places service unavailable"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE
            )


# ============== Group ViewSets ==============

class ChildGroupViewSet(viewsets.ModelViewSet):
    """
    CRUD operations for child groups.
    Users can create groups, add children, and invite co-tutors.
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action == 'retrieve':
            return ChildGroupDetailSerializer
        return ChildGroupSerializer
    
    def get_queryset(self):
        """
        Return groups where user is owner OR is a co-tutor.
        Admins see all groups.
        """
        user = self.request.user
        
        base_qs = ChildGroup.objects.select_related("owner")
        
        # Admins ven todos los grupos
        if user.is_staff:
            return base_qs.order_by('name')
        
        return base_qs.filter(
            Q(owner=user) | Q(tutors__tutor=user, tutors__is_active=True)
        ).distinct().order_by('name')
    
    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)
    
    @action(detail=True, methods=['get'], url_path='members')
    def list_members(self, request, pk=None):
        """List all children in a group with their locations."""
        group = self.get_object()
        memberships = group.memberships.filter(is_active=True).select_related('child__device')
        serializer = GroupMembershipSerializer(memberships, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'], url_path='add-child')
    def add_child(self, request, pk=None):
        """Add a child to the group (owner or admin only)."""
        group = self.get_object()
        
        # Check permission
        if not self._can_manage_group(request.user, group):
            return Response(
                {"error": "No tienes permiso para gestionar este grupo"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        child_id = request.data.get('child_id')
        if not child_id:
            return Response(
                {"error": "child_id es requerido"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check child belongs to user
        try:
            child = Child.objects.get(id=child_id, tutor=request.user)
        except Child.DoesNotExist:
            return Response(
                {"error": "Niño no encontrado o no te pertenece"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Check if already member
        if GroupMembership.objects.filter(group=group, child=child).exists():
            return Response(
                {"error": "Este niño ya es miembro del grupo"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        membership = GroupMembership.objects.create(
            group=group,
            child=child,
            added_by=request.user
        )
        
        return Response(
            GroupMembershipSerializer(membership).data,
            status=status.HTTP_201_CREATED
        )
    
    @action(detail=True, methods=['post'], url_path='remove-child')
    def remove_child(self, request, pk=None):
        """Remove a child from the group."""
        group = self.get_object()
        
        if not self._can_manage_group(request.user, group):
            return Response(
                {"error": "No tienes permiso para gestionar este grupo"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        child_id = request.data.get('child_id')
        try:
            membership = GroupMembership.objects.get(group=group, child_id=child_id)
            membership.delete()
            return Response({"status": "removed"})
        except GroupMembership.DoesNotExist:
            return Response(
                {"error": "Membresía no encontrada"},
                status=status.HTTP_404_NOT_FOUND
            )
    
    @action(detail=True, methods=['post'], url_path='invite-tutor')
    def invite_tutor(self, request, pk=None):
        """Invite a co-tutor by email."""
        group = self.get_object()
        
        # Only owner can invite tutors
        if group.owner != request.user:
            return Response(
                {"error": "Solo el dueño puede invitar tutores"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        serializer = GroupTutorInviteSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        email = serializer.validated_data['email']
        role = serializer.validated_data['role']
        
        # Find user by email
        try:
            tutor_user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response(
                {"error": "Usuario no encontrado con ese email"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Can't invite yourself
        if tutor_user == request.user:
            return Response(
                {"error": "No puedes invitarte a ti mismo"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check if already a tutor
        if GroupTutor.objects.filter(group=group, tutor=tutor_user).exists():
            return Response(
                {"error": "Este usuario ya es tutor del grupo"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        group_tutor = GroupTutor.objects.create(
            group=group,
            tutor=tutor_user,
            role=role,
            invited_by=request.user
        )
        
        return Response(
            GroupTutorSerializer(group_tutor).data,
            status=status.HTTP_201_CREATED
        )
    
    @action(detail=True, methods=['post'], url_path='remove-tutor')
    def remove_tutor(self, request, pk=None):
        """Remove a co-tutor from the group."""
        group = self.get_object()
        
        if group.owner != request.user:
            return Response(
                {"error": "Solo el dueño puede remover tutores"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        tutor_id = request.data.get('tutor_id')
        try:
            group_tutor = GroupTutor.objects.get(group=group, tutor_id=tutor_id)
            group_tutor.delete()
            return Response({"status": "removed"})
        except GroupTutor.DoesNotExist:
            return Response(
                {"error": "Tutor no encontrado en este grupo"},
                status=status.HTTP_404_NOT_FOUND
            )
    
    @action(detail=True, methods=['get'], url_path='locations')
    def get_locations(self, request, pk=None):
        """
        Get current locations of all children in the group.
        Returns children with their device locations for the map view.
        """
        group = self.get_object()
        memberships = group.memberships.filter(is_active=True).select_related('child__device')
        child_ids = memberships.values_list('child_id', flat=True)
        child_safe_zones = SafeZone.objects.filter(
            child_id__in=child_ids,
            is_active=True,
        ).select_related('child')
        
        children_data = []
        for membership in memberships:
            child = membership.child
            child_data = ChildWithLocationSerializer(child).data
            children_data.append(child_data)
        
        return Response({
            "group_id": group.id,
            "group_name": group.name,
            "children": children_data,
            "safe_zones": GroupSafeZoneSerializer(
                group.safe_zones.filter(is_active=True),
                many=True,
            ).data,
            "child_safe_zones": SafeZoneSerializer(child_safe_zones, many=True).data,
        })
    
    def _can_manage_group(self, user, group):
        """Check if user can manage the group (owner or admin tutor)."""
        if group.owner == user:
            return True
        return GroupTutor.objects.filter(
            group=group, 
            tutor=user, 
            role='admin',
            is_active=True
        ).exists()


class GroupSafeZoneViewSet(viewsets.ModelViewSet):
    """CRUD operations for group safe zones."""
    serializer_class = GroupSafeZoneSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        
        # Admins ven todas las zonas de grupo
        if user.is_staff:
            return GroupSafeZone.objects.all().select_related('group', 'group__owner').order_by('-created_at')
        
        # Only zones from groups user owns or is a tutor of
        return GroupSafeZone.objects.filter(
            Q(group__owner=user) | Q(group__tutors__tutor=user, group__tutors__is_active=True)
        ).distinct().select_related('group').order_by('-created_at')
    
    def perform_create(self, serializer):
        # Validate user can create zones for this group
        group = serializer.validated_data.get('group')
        if group.owner != self.request.user:
            is_admin = GroupTutor.objects.filter(
                group=group, tutor=self.request.user, role='admin', is_active=True
            ).exists()
            if not is_admin:
                raise permissions.exceptions.PermissionDenied(
                    "No tienes permiso para crear zonas en este grupo"
                )
        serializer.save()
    
    @action(detail=True, methods=['post'], url_path='check-point')
    def check_point(self, request, pk=None):
        """Check if a point is inside the group safe zone."""
        zone = self.get_object()
        lat = request.data.get('latitude')
        lng = request.data.get('longitude')
        
        if lat is None or lng is None:
            return Response(
                {"error": "latitude y longitude son requeridos"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            lat = float(lat)
            lng = float(lng)
        except (ValueError, TypeError):
            return Response(
                {"error": "Coordenadas inválidas"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        is_inside = zone.contains_point(lat, lng)
        return Response({
            "is_inside": is_inside,
            "zone_id": zone.id,
            "zone_name": zone.name,
        })


# ============== Notification ViewSet ==============

class NotificationViewSet(viewsets.ModelViewSet):
    """
    ViewSet for manual push notifications.
    Only staff/admin users can create and send notifications.
    """
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated, permissions.IsAdminUser]
    
    def get_queryset(self):
        return Notification.objects.all().select_related(
            'created_by', 'specific_user'
        ).order_by('-created_at')
    
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)
    
    @action(detail=True, methods=['post'], url_path='send')
    def send_notification(self, request, pk=None):
        """
        Send the notification to the target recipients via FCM.
        """
        from .firebase_service import send_manual_notification
        
        notification = self.get_object()
        
        # Don't re-send if already sent
        if notification.status == 'sent':
            return Response(
                {"error": "Esta notificación ya fue enviada"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            # Get target users based on recipient_type
            if notification.recipient_type == 'all':
                # All users with FCM tokens
                target_users = User.objects.filter(
                    fcm_token__isnull=False
                ).exclude(fcm_token='')
            elif notification.recipient_type == 'tutors':
                # Only non-staff users (regular tutors) with FCM tokens
                target_users = User.objects.filter(
                    is_staff=False,
                    fcm_token__isnull=False
                ).exclude(fcm_token='')
            elif notification.recipient_type == 'specific':
                # Specific user
                if notification.specific_user and notification.specific_user.fcm_token:
                    target_users = [notification.specific_user]
                else:
                    notification.status = 'failed'
                    notification.save()
                    return Response(
                        {"error": "El usuario seleccionado no tiene token FCM registrado"},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            else:
                target_users = []
            
            # Send notifications
            sent_count = 0
            failed_count = 0
            
            for user in target_users:
                try:
                    success = send_manual_notification(
                        user=user,
                        title=notification.title,
                        message=notification.message,
                        notification_id=notification.id
                    )
                    if success:
                        sent_count += 1
                    else:
                        failed_count += 1
                except Exception as e:
                    logger.error(f"Error sending notification to {user.email}: {e}")
                    failed_count += 1
            
            # Update notification status
            notification.status = 'sent' if sent_count > 0 else 'failed'
            notification.sent_count = sent_count
            notification.failed_count = failed_count
            notification.sent_at = timezone.now()
            notification.save()
            
            return Response({
                "status": notification.status,
                "sent_count": sent_count,
                "failed_count": failed_count,
                "message": f"Notificación enviada a {sent_count} usuarios"
            })
            
        except Exception as e:
            logger.error(f"Error in send_notification: {e}")
            notification.status = 'failed'
            notification.save()
            return Response(
                {"error": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
