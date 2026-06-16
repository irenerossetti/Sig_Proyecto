# Generated migration for PostGIS native geometry fields
# Note: Device.last_location, SafeZone.polygon, Alert.location already exist from 0003

from django.db import migrations
import django.contrib.gis.db.models.fields


class Migration(migrations.Migration):
    """
    Add additional PostGIS native geometry fields to SafeZone, GroupSafeZone, and LocationHistory.
    Device.last_location already exists from migration 0003.
    These fields enable efficient spatial queries using ST_Contains, ST_DWithin, etc.
    """

    dependencies = [
        ('monitoring', '0006_locationhistory_alert_alert_type_and_more'),
    ]

    operations = [
        # SafeZone: Add geometry (polygon) and center_point fields
        # Note: 'polygon' field already exists from 0003, we add 'geometry' for consistency
        migrations.AddField(
            model_name='safezone',
            name='geometry',
            field=django.contrib.gis.db.models.fields.PolygonField(
                blank=True, 
                geography=True, 
                null=True, 
                srid=4326,
                help_text='PostGIS polygon geometry for ST_Contains queries'
            ),
        ),
        migrations.AddField(
            model_name='safezone',
            name='center_point',
            field=django.contrib.gis.db.models.fields.PointField(
                blank=True, 
                geography=True, 
                null=True, 
                srid=4326,
                help_text='Center point for circle zones'
            ),
        ),
        
        # GroupSafeZone: Add geometry (polygon) and center_point fields
        migrations.AddField(
            model_name='groupsafezone',
            name='geometry',
            field=django.contrib.gis.db.models.fields.PolygonField(
                blank=True, 
                geography=True, 
                null=True, 
                srid=4326,
                help_text='PostGIS polygon geometry for ST_Contains queries'
            ),
        ),
        migrations.AddField(
            model_name='groupsafezone',
            name='center_point',
            field=django.contrib.gis.db.models.fields.PointField(
                blank=True, 
                geography=True, 
                null=True, 
                srid=4326,
                help_text='Center point for circle zones'
            ),
        ),
        
        # LocationHistory: Add location PointField
        migrations.AddField(
            model_name='locationhistory',
            name='location',
            field=django.contrib.gis.db.models.fields.PointField(
                blank=True, 
                geography=True, 
                null=True, 
                srid=4326,
                help_text='PostGIS native point for route analysis'
            ),
        ),
    ]
