import os
import math
from django.conf import settings
from django.db import models

# PostGIS support - conditional import for local development without GDAL
try:
    from django.contrib.gis.db import models as gis_models
    from django.contrib.gis.geos import Point, Polygon
    from django.contrib.gis.db.models.functions import Distance
    from django.contrib.gis.measure import D
    HAS_POSTGIS = True
except (ImportError, Exception):
    HAS_POSTGIS = False
    gis_models = None
    Point = None
    Polygon = None

# Importar modelo de historial de ubicaciones
from monitoring.models_history import LocationHistory


class Child(models.Model):
    """Represents a child being monitored."""
    tutor = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='children')
    full_name = models.CharField(max_length=150)
    date_of_birth = models.DateField()
    photo = models.ImageField(upload_to='children/', blank=True, null=True)
    notes = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Niño'
        verbose_name_plural = 'Niños'
        ordering = ['full_name']

    def __str__(self):
        return self.full_name


class Device(models.Model):
    """GPS device or smartphone assigned to a child."""
    child = models.OneToOneField(Child, on_delete=models.CASCADE, related_name='device')
    device_id = models.CharField(max_length=100, unique=True)
    device_type = models.CharField(max_length=50, blank=True)
    # Campos para compatibilidad con el frontend existente
    last_latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    last_longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    last_seen = models.DateTimeField(null=True, blank=True)
    battery_level = models.IntegerField(null=True, blank=True)
    is_in_safe_zone = models.BooleanField(default=True, null=True)  # Track zone status
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Dispositivo'
        verbose_name_plural = 'Dispositivos'

    def __str__(self):
        return f"{self.device_id} ({self.child.full_name})"
    
    def update_location(self, latitude, longitude):
        """Update device location with both legacy and PostGIS fields."""
        self.last_latitude = latitude
        self.last_longitude = longitude
        self.save(update_fields=['last_latitude', 'last_longitude', 'updated_at'])


# Add PostGIS fields dynamically if available
if HAS_POSTGIS:
    Device.add_to_class(
        'last_location',
        gis_models.PointField(geography=True, null=True, blank=True, srid=4326)
    )


class SafeZone(models.Model):
    """Defines a safe area boundary using PostGIS geometry."""
    ZONE_TYPE_CHOICES = [
        ('polygon', 'Polígono'),
        ('circle', 'Círculo'),
    ]
    
    child = models.ForeignKey(Child, on_delete=models.CASCADE, related_name='safe_zones')
    name = models.CharField(max_length=100)
    zone_type = models.CharField(max_length=20, choices=ZONE_TYPE_CHOICES, default='polygon')
    
    # Campos legacy para compatibilidad con círculos
    center_latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    center_longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    radius_meters = models.IntegerField(default=100, null=True, blank=True)
    
    # Campo JSON para compatibilidad con frontend existente
    polygon_points = models.JSONField(default=list, blank=True)
    
    color = models.CharField(max_length=7, default='#1E8E3E')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Zona segura'
        verbose_name_plural = 'Zonas seguras'
        # Índice espacial para consultas rápidas
        indexes = [
            models.Index(fields=['child', 'is_active']),
        ]

    def __str__(self):
        return f"{self.name} ({self.child.full_name})"
    
    def save(self, *args, **kwargs):
        """Override save to sync PostGIS geometry fields from legacy data."""
        self._sync_geometry()
        super().save(*args, **kwargs)
    
    def _sync_geometry(self):
        """Sync PostGIS geometry fields from legacy JSON/coordinate fields."""
        if not HAS_POSTGIS:
            return
            
        # Sync polygon geometry
        if self.polygon_points and len(self.polygon_points) >= 3:
            try:
                coords = [(p['lng'], p['lat']) for p in self.polygon_points]
                # Close the polygon if not already closed
                if coords[0] != coords[-1]:
                    coords.append(coords[0])
                self.geometry = Polygon(coords, srid=4326)
            except (KeyError, TypeError, ValueError):
                pass
        
        # Sync center point for circles
        if self.center_latitude and self.center_longitude:
            try:
                self.center_point = Point(
                    float(self.center_longitude), 
                    float(self.center_latitude), 
                    srid=4326
                )
            except (TypeError, ValueError):
                pass
    
    def contains_point(self, lat, lng):
        """
        Check if a point is inside the safe zone.
        Uses PostGIS native functions when available, falls back to Python.
        """
        # Try PostGIS native first (much faster)
        if HAS_POSTGIS and Point:
            point = Point(float(lng), float(lat), srid=4326)
            
            # Check polygon using ST_Contains
            if hasattr(self, 'geometry') and self.geometry:
                return self.geometry.contains(point)
            
            # Check circle using ST_DWithin
            if self.zone_type == 'circle' and hasattr(self, 'center_point') and self.center_point and self.radius_meters:
                return self.center_point.distance(point) * 111319.9 <= self.radius_meters
        
        # Fallback to Python implementation
        if self.polygon_points and len(self.polygon_points) >= 3:
            return self._point_in_polygon(lat, lng)
        
        if self.zone_type == 'circle' and self.center_latitude and self.center_longitude:
            return self._point_in_circle(lat, lng)
        
        return False
    
    def _point_in_polygon(self, lat, lng):
        """Ray casting algorithm for point-in-polygon test."""
        points = self.polygon_points
        n = len(points)
        inside = False
        
        j = n - 1
        for i in range(n):
            xi, yi = points[i]['lat'], points[i]['lng']
            xj, yj = points[j]['lat'], points[j]['lng']
            
            if ((yi > lng) != (yj > lng)) and (lat < (xj - xi) * (lng - yi) / (yj - yi) + xi):
                inside = not inside
            j = i
        
        return inside
    
    def _point_in_circle(self, lat, lng):
        """Check if point is within circle using haversine distance."""
        R = 6371000  # Earth radius in meters
        lat1 = math.radians(float(self.center_latitude))
        lon1 = math.radians(float(self.center_longitude))
        lat2 = math.radians(lat)
        lon2 = math.radians(lng)
        
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        
        a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
        c = 2 * math.asin(math.sqrt(a))
        distance = R * c
        
        return distance <= (self.radius_meters or 100)
    
    @classmethod
    def get_zones_containing_point(cls, child_id, lat, lng):
        """
        Get all zones that contain a point for a child.
        Uses PostGIS ST_Contains for polygons and ST_DWithin for circles.
        """
        # Check if PostGIS fields are available on this model
        has_geometry_field = hasattr(cls, 'geometry') and hasattr(cls._meta.get_field('geometry'), 'geom_type')
        
        if HAS_POSTGIS and Point and has_geometry_field:
            point = Point(float(lng), float(lat), srid=4326)
            zones = cls.objects.filter(child_id=child_id, is_active=True)
            
            # Get polygon zones containing the point
            polygon_zones = zones.filter(
                geometry__isnull=False
            ).filter(
                geometry__contains=point
            )
            
            # Get circle zones - need to check distance manually since ST_DWithin
            # requires the distance in meters and we have different radii per zone
            circle_zones = []
            for zone in zones.filter(zone_type='circle', center_point__isnull=False):
                if hasattr(zone, 'center_point') and zone.center_point and zone.radius_meters:
                    # Distance in degrees * ~111km per degree at equator
                    distance_m = zone.center_point.distance(point) * 111319.9
                    if distance_m <= zone.radius_meters:
                        circle_zones.append(zone)
            
            return list(polygon_zones) + circle_zones
        
        # Fallback to Python implementation
        zones = cls.objects.filter(child_id=child_id, is_active=True)
        return [z for z in zones if z.contains_point(lat, lng)]
    
    @classmethod
    def get_zones_not_containing_point(cls, child_id, lat, lng):
        """
        Get all active zones that do NOT contain the point.
        These are the zones the child has exited.
        """
        all_zones = cls.objects.filter(child_id=child_id, is_active=True)
        zones_containing = cls.get_zones_containing_point(child_id, lat, lng)
        containing_ids = {z.id for z in zones_containing}
        return [z for z in all_zones if z.id not in containing_ids]
    
    @classmethod
    def is_point_in_any_zone(cls, child_id, lat, lng):
        """
        Check if a point is inside ANY safe zone for the child.
        Returns True if safe, False if outside all zones.
        Optimized to stop at first match.
        """
        # Check if PostGIS fields are available on this model
        has_geometry_field = hasattr(cls, 'geometry') and hasattr(cls._meta.get_field('geometry'), 'geom_type')
        
        if HAS_POSTGIS and Point and has_geometry_field:
            point = Point(float(lng), float(lat), srid=4326)
            zones = cls.objects.filter(child_id=child_id, is_active=True)
            
            # Quick check for polygon zones
            if zones.filter(geometry__isnull=False, geometry__contains=point).exists():
                return True
            
            # Check circle zones
            for zone in zones.filter(zone_type='circle', center_point__isnull=False):
                if hasattr(zone, 'center_point') and zone.center_point and zone.radius_meters:
                    distance_m = zone.center_point.distance(point) * 111319.9
                    if distance_m <= zone.radius_meters:
                        return True
            
            return False
        
        # Fallback
        return len(cls.get_zones_containing_point(child_id, lat, lng)) > 0


# Add PostGIS fields to SafeZone dynamically if available
if HAS_POSTGIS:
    SafeZone.add_to_class(
        'geometry',
        gis_models.PolygonField(geography=True, null=True, blank=True, srid=4326)
    )
    SafeZone.add_to_class(
        'center_point',
        gis_models.PointField(geography=True, null=True, blank=True, srid=4326)
    )


class Alert(models.Model):
    """Alert triggered when a child leaves a safe zone."""
    STATUS_CHOICES = [
        ('pending', 'Pendiente'),
        ('acknowledged', 'Reconocida'),
        ('resolved', 'Resuelta'),
    ]
    
    ALERT_TYPE_CHOICES = [
        ('zone_exit', 'Salida de zona'),
        ('zone_entry', 'Entrada a zona'),
        ('low_battery', 'Batería baja'),
        ('device_offline', 'Dispositivo sin conexión'),
    ]
    
    child = models.ForeignKey(Child, on_delete=models.CASCADE, related_name='alerts')
    safe_zone = models.ForeignKey(SafeZone, on_delete=models.SET_NULL, null=True, blank=True)
    group = models.ForeignKey('ChildGroup', on_delete=models.SET_NULL, null=True, blank=True, related_name='alerts')
    alert_type = models.CharField(max_length=20, choices=ALERT_TYPE_CHOICES, default='zone_exit')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    # Coordenadas de la alerta
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    message = models.TextField()
    acknowledged_at = models.DateTimeField(null=True, blank=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Alerta'
        verbose_name_plural = 'Alertas'
        ordering = ['-created_at']

    def __str__(self):
        return f"Alerta {self.id} - {self.child.full_name} ({self.status})"


class ChildGroup(models.Model):
    """
    Group of children for collective monitoring.
    Useful for teachers, daycare centers, or families with multiple children.
    """
    name = models.CharField(max_length=150)
    description = models.TextField(blank=True)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name='owned_groups'
    )
    color = models.CharField(max_length=7, default='#1E88E5')  # Color del grupo
    icon = models.CharField(max_length=50, default='users')  # Icono del grupo
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = 'Grupo'
        verbose_name_plural = 'Grupos'
        ordering = ['name']
    
    def __str__(self):
        return self.name
    
    @property
    def members_count(self):
        return self.memberships.filter(is_active=True).count()
    
    @property
    def tutors_count(self):
        return self.tutors.filter(is_active=True).count() + 1  # +1 for owner


class GroupMembership(models.Model):
    """
    Membership of a child in a group.
    A child can belong to multiple groups.
    """
    group = models.ForeignKey(ChildGroup, on_delete=models.CASCADE, related_name='memberships')
    child = models.ForeignKey(Child, on_delete=models.CASCADE, related_name='group_memberships')
    added_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.SET_NULL, 
        null=True,
        related_name='added_memberships'
    )
    is_active = models.BooleanField(default=True)
    joined_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = 'Miembro del grupo'
        verbose_name_plural = 'Miembros del grupo'
        unique_together = ['group', 'child']
    
    def __str__(self):
        return f"{self.child.full_name} en {self.group.name}"


class GroupTutor(models.Model):
    """
    Co-tutor who can help manage a group.
    Has permissions to view locations and receive alerts.
    """
    ROLE_CHOICES = [
        ('admin', 'Administrador'),  # Can add/remove children and tutors
        ('monitor', 'Monitor'),       # Can only view and receive alerts
    ]
    
    group = models.ForeignKey(ChildGroup, on_delete=models.CASCADE, related_name='tutors')
    tutor = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name='group_tutor_roles'
    )
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='monitor')
    invited_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='sent_invitations'
    )
    is_active = models.BooleanField(default=True)
    joined_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = 'Tutor del grupo'
        verbose_name_plural = 'Tutores del grupo'
        unique_together = ['group', 'tutor']
    
    def __str__(self):
        return f"{self.tutor.email} - {self.group.name} ({self.role})"


class GroupSafeZone(models.Model):
    """
    Safe zone shared by all children in a group.
    When a child in the group exits this zone, all tutors are alerted.
    """
    ZONE_TYPE_CHOICES = [
        ('polygon', 'Polígono'),
        ('circle', 'Círculo'),
    ]
    
    group = models.ForeignKey(ChildGroup, on_delete=models.CASCADE, related_name='safe_zones')
    name = models.CharField(max_length=100)
    zone_type = models.CharField(max_length=20, choices=ZONE_TYPE_CHOICES, default='polygon')
    
    # Para círculos
    center_latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    center_longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    radius_meters = models.IntegerField(default=100, null=True, blank=True)
    
    # Para polígonos
    polygon_points = models.JSONField(default=list, blank=True)
    
    color = models.CharField(max_length=7, default='#1E8E3E')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = 'Zona segura del grupo'
        verbose_name_plural = 'Zonas seguras del grupo'
    
    def __str__(self):
        return f"{self.name} ({self.group.name})"
    
    def save(self, *args, **kwargs):
        """Override save to sync PostGIS geometry fields from legacy data."""
        self._sync_geometry()
        super().save(*args, **kwargs)
    
    def _sync_geometry(self):
        """Sync PostGIS geometry fields from legacy JSON/coordinate fields."""
        if not HAS_POSTGIS:
            return
            
        if self.polygon_points and len(self.polygon_points) >= 3:
            try:
                coords = [(p['lng'], p['lat']) for p in self.polygon_points]
                if coords[0] != coords[-1]:
                    coords.append(coords[0])
                self.geometry = Polygon(coords, srid=4326)
            except (KeyError, TypeError, ValueError):
                pass
        
        if self.center_latitude and self.center_longitude:
            try:
                self.center_point = Point(
                    float(self.center_longitude), 
                    float(self.center_latitude), 
                    srid=4326
                )
            except (TypeError, ValueError):
                pass
    
    def contains_point(self, lat, lng):
        """Check if a point is inside the safe zone using PostGIS when available."""
        if HAS_POSTGIS and Point:
            point = Point(float(lng), float(lat), srid=4326)
            
            if hasattr(self, 'geometry') and self.geometry:
                return self.geometry.contains(point)
            
            if self.zone_type == 'circle' and hasattr(self, 'center_point') and self.center_point and self.radius_meters:
                return self.center_point.distance(point) * 111319.9 <= self.radius_meters
        
        # Fallback to Python
        if self.polygon_points and len(self.polygon_points) >= 3:
            return self._point_in_polygon(lat, lng)
        
        if self.zone_type == 'circle' and self.center_latitude and self.center_longitude:
            return self._point_in_circle(lat, lng)
        
        return False
    
    def _point_in_polygon(self, lat, lng):
        """Ray casting algorithm for point-in-polygon test."""
        points = self.polygon_points
        n = len(points)
        inside = False
        
        j = n - 1
        for i in range(n):
            xi, yi = points[i]['lat'], points[i]['lng']
            xj, yj = points[j]['lat'], points[j]['lng']
            
            if ((yi > lng) != (yj > lng)) and (lat < (xj - xi) * (lng - yi) / (yj - yi) + xi):
                inside = not inside
            j = i
        
        return inside
    
    def _point_in_circle(self, lat, lng):
        """Check if point is within circle using haversine distance."""
        R = 6371000  # Earth radius in meters
        lat1 = math.radians(float(self.center_latitude))
        lon1 = math.radians(float(self.center_longitude))
        lat2 = math.radians(lat)
        lon2 = math.radians(lng)
        
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        
        a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
        c = 2 * math.asin(math.sqrt(a))
        distance = R * c
        
        return distance <= (self.radius_meters or 100)


# Add PostGIS fields to GroupSafeZone dynamically if available
if HAS_POSTGIS:
    GroupSafeZone.add_to_class(
        'geometry',
        gis_models.PolygonField(geography=True, null=True, blank=True, srid=4326)
    )
    GroupSafeZone.add_to_class(
        'center_point',
        gis_models.PointField(geography=True, null=True, blank=True, srid=4326)
    )


class Notification(models.Model):
    """Manual push notifications sent by administrators."""
    
    RECIPIENT_TYPE_CHOICES = [
        ('all', 'Todos los usuarios'),
        ('tutors', 'Solo tutores'),
        ('specific', 'Usuario específico'),
    ]
    
    STATUS_CHOICES = [
        ('draft', 'Borrador'),
        ('sent', 'Enviada'),
        ('failed', 'Fallida'),
    ]
    
    title = models.CharField(max_length=100, verbose_name='Título')
    message = models.TextField(verbose_name='Mensaje')
    recipient_type = models.CharField(
        max_length=20, 
        choices=RECIPIENT_TYPE_CHOICES, 
        default='all',
        verbose_name='Destinatarios'
    )
    specific_user = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True,
        related_name='received_notifications',
        verbose_name='Usuario específico'
    )
    status = models.CharField(
        max_length=20, 
        choices=STATUS_CHOICES, 
        default='draft',
        verbose_name='Estado'
    )
    sent_count = models.IntegerField(default=0, verbose_name='Notificaciones enviadas')
    failed_count = models.IntegerField(default=0, verbose_name='Notificaciones fallidas')
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.SET_NULL, 
        null=True,
        related_name='created_notifications',
        verbose_name='Creado por'
    )
    sent_at = models.DateTimeField(null=True, blank=True, verbose_name='Fecha de envío')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = 'Notificación'
        verbose_name_plural = 'Notificaciones'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.title} ({self.get_status_display()})"
