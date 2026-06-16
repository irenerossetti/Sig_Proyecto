# Generated manually for PostGIS support
# This migration adds geospatial fields to existing models
# Note: GDAL import is wrapped to allow migrations to run without GDAL installed

from django.db import migrations

# Conditional import for GDAL - allows migration loading without GDAL
try:
    import django.contrib.gis.db.models.fields as gis_fields
    HAS_GDAL = True
except Exception:
    HAS_GDAL = False
    gis_fields = None


class Migration(migrations.Migration):

    dependencies = [
        ('monitoring', '0002_add_polygon_to_safezone'),
    ]

    # Only run operations if GDAL is available
    # These migrations are already applied in production
    operations = [
        # Add PointField to Device for GPS location
        migrations.AddField(
            model_name='device',
            name='last_location',
            field=gis_fields.PointField(
                blank=True, 
                geography=True, 
                null=True, 
                srid=4326
            ) if HAS_GDAL else migrations.RunSQL.noop,
        ),
        # Add PolygonField to SafeZone for spatial queries
        migrations.AddField(
            model_name='safezone',
            name='polygon',
            field=gis_fields.PolygonField(
                blank=True, 
                geography=True, 
                null=True, 
                srid=4326
            ) if HAS_GDAL else migrations.RunSQL.noop,
        ),
        # Add PointField to Alert for alert location
        migrations.AddField(
            model_name='alert',
            name='location',
            field=gis_fields.PointField(
                blank=True, 
                geography=True, 
                null=True, 
                srid=4326
            ) if HAS_GDAL else migrations.RunSQL.noop,
        ),
    ] if HAS_GDAL else []
