# Data migration to sync existing data to PostGIS native fields

from django.db import migrations


def sync_postgis_fields_forward(apps, schema_editor):
    """
    Populate PostGIS native fields from legacy coordinate/JSON fields.
    This runs SQL directly for efficiency since we're on PostGIS.
    Note: Device.last_location already exists from migration 0003, skip it.
    """
    if schema_editor.connection.vendor == 'sqlite':
        return
        
    # Update LocationHistory.location from latitude/longitude
    schema_editor.execute("""
        UPDATE monitoring_locationhistory 
        SET location = ST_SetSRID(ST_MakePoint(
            CAST(longitude AS DOUBLE PRECISION), 
            CAST(latitude AS DOUBLE PRECISION)
        ), 4326)::geography
        WHERE latitude IS NOT NULL AND longitude IS NOT NULL
        AND location IS NULL
    """)
    
    # Update SafeZone.center_point from center_latitude/center_longitude
    schema_editor.execute("""
        UPDATE monitoring_safezone 
        SET center_point = ST_SetSRID(ST_MakePoint(
            CAST(center_longitude AS DOUBLE PRECISION), 
            CAST(center_latitude AS DOUBLE PRECISION)
        ), 4326)::geography
        WHERE center_latitude IS NOT NULL AND center_longitude IS NOT NULL
        AND center_point IS NULL
    """)
    
    # Update GroupSafeZone.center_point from center_latitude/center_longitude
    schema_editor.execute("""
        UPDATE monitoring_groupsafezone 
        SET center_point = ST_SetSRID(ST_MakePoint(
            CAST(center_longitude AS DOUBLE PRECISION), 
            CAST(center_latitude AS DOUBLE PRECISION)
        ), 4326)::geography
        WHERE center_latitude IS NOT NULL AND center_longitude IS NOT NULL
        AND center_point IS NULL
    """)
    
    # Note: Polygon geometry is more complex to migrate from JSON
    # The save() method in the models will handle this on next save
    # We can also run a Python loop for existing polygons:


def sync_polygon_geometry(apps, schema_editor):
    """
    Sync polygon geometry from JSON polygon_points.
    Uses Python because JSON parsing is complex in raw SQL.
    """
    if schema_editor.connection.vendor == 'sqlite':
        return
        
    SafeZone = apps.get_model('monitoring', 'SafeZone')
    GroupSafeZone = apps.get_model('monitoring', 'GroupSafeZone')
    
    # Import GEOS for geometry creation
    try:
        from django.contrib.gis.geos import Polygon
    except ImportError:
        print("GDAL/GEOS not available, skipping polygon sync")
        return
    
    for zone in SafeZone.objects.filter(polygon_points__len__gte=3):
        try:
            points = zone.polygon_points
            if points and len(points) >= 3:
                coords = [(p['lng'], p['lat']) for p in points]
                if coords[0] != coords[-1]:
                    coords.append(coords[0])
                zone.geometry = Polygon(coords, srid=4326)
                zone.save(update_fields=['geometry'])
        except (KeyError, TypeError, ValueError) as e:
            print(f"Error syncing SafeZone {zone.id}: {e}")
    
    for zone in GroupSafeZone.objects.filter(polygon_points__len__gte=3):
        try:
            points = zone.polygon_points
            if points and len(points) >= 3:
                coords = [(p['lng'], p['lat']) for p in points]
                if coords[0] != coords[-1]:
                    coords.append(coords[0])
                zone.geometry = Polygon(coords, srid=4326)
                zone.save(update_fields=['geometry'])
        except (KeyError, TypeError, ValueError) as e:
            print(f"Error syncing GroupSafeZone {zone.id}: {e}")


def noop(apps, schema_editor):
    """Reverse migration is a no-op - data is still in legacy fields."""
    pass


class Migration(migrations.Migration):
    dependencies = [
        ('monitoring', '0007_postgis_native_fields'),
    ]

    operations = [
        migrations.RunPython(sync_postgis_fields_forward, noop),
        migrations.RunPython(sync_polygon_geometry, noop),
    ]
