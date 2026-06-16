"""
Location History Model and ViewSet for tracking movement history.
"""
from django.db import models
from django.conf import settings

# PostGIS support - conditional import
try:
    from django.contrib.gis.db import models as gis_models
    from django.contrib.gis.geos import Point
    HAS_POSTGIS = True
except (ImportError, Exception):
    HAS_POSTGIS = False
    gis_models = None
    Point = None


class LocationHistory(models.Model):
    """
    Stores historical location data for each device.
    This enables movement tracking, route replay, and analytics.
    """
    device = models.ForeignKey(
        'Device',
        on_delete=models.CASCADE,
        related_name='location_history'
    )
    child = models.ForeignKey(
        'Child',
        on_delete=models.CASCADE,
        related_name='location_history'
    )
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    battery_level = models.IntegerField(null=True, blank=True)
    is_in_safe_zone = models.BooleanField(default=True)
    accuracy = models.FloatField(null=True, blank=True)  # GPS accuracy in meters
    speed = models.FloatField(null=True, blank=True)  # Speed in m/s
    heading = models.FloatField(null=True, blank=True)  # Direction in degrees
    timestamp = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = 'Historial de ubicación'
        verbose_name_plural = 'Historial de ubicaciones'
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['device', '-timestamp']),
            models.Index(fields=['child', '-timestamp']),
            models.Index(fields=['timestamp']),
        ]
    
    def __str__(self):
        return f"{self.child.full_name} - {self.timestamp}"
    
    def save(self, *args, **kwargs):
        """Sync PostGIS location field from lat/lng."""
        if HAS_POSTGIS and Point and self.latitude and self.longitude:
            if hasattr(self, 'location'):
                self.location = Point(float(self.longitude), float(self.latitude), srid=4326)
        super().save(*args, **kwargs)
    
    @classmethod
    def record_location(cls, device, latitude, longitude, battery_level=None, 
                        is_in_safe_zone=True, accuracy=None, speed=None, heading=None):
        """
        Record a new location entry for the device.
        """
        kwargs = dict(
            device=device,
            child=device.child,
            latitude=latitude,
            longitude=longitude,
            battery_level=battery_level,
            is_in_safe_zone=is_in_safe_zone,
            accuracy=accuracy,
            speed=speed,
            heading=heading
        )
        
        # Add location point if PostGIS is available
        if HAS_POSTGIS and Point:
            kwargs['location'] = Point(float(longitude), float(latitude), srid=4326)
        
        return cls.objects.create(**kwargs)
    
    @classmethod
    def get_child_history(cls, child_id, start_date=None, end_date=None, limit=1000):
        """
        Get location history for a child within a date range.
        """
        queryset = cls.objects.filter(child_id=child_id)
        
        if start_date:
            queryset = queryset.filter(timestamp__gte=start_date)
        if end_date:
            queryset = queryset.filter(timestamp__lte=end_date)
        
        return queryset[:limit]
    
    @classmethod
    def get_movement_stats(cls, child_id, start_date, end_date):
        """
        Calculate movement statistics for a child.
        """
        from django.db.models import Count, Avg, Min, Max
        from django.db.models.functions import TruncDate
        
        queryset = cls.objects.filter(
            child_id=child_id,
            timestamp__gte=start_date,
            timestamp__lte=end_date
        )
        
        # Daily location counts
        daily_counts = queryset.annotate(
            date=TruncDate('timestamp')
        ).values('date').annotate(
            location_count=Count('id')
        ).order_by('date')
        
        # Zone statistics
        zone_stats = queryset.aggregate(
            total_locations=Count('id'),
            in_zone_count=Count('id', filter=models.Q(is_in_safe_zone=True)),
            out_of_zone_count=Count('id', filter=models.Q(is_in_safe_zone=False)),
            avg_battery=Avg('battery_level'),
            min_battery=Min('battery_level'),
            max_battery=Max('battery_level'),
        )
        
        return {
            'daily_counts': list(daily_counts),
            'zone_stats': zone_stats,
            'total_days': len(daily_counts),
        }


# Add PostGIS field to LocationHistory dynamically if available
if HAS_POSTGIS:
    LocationHistory.add_to_class(
        'location',
        gis_models.PointField(geography=True, null=True, blank=True, srid=4326)
    )
