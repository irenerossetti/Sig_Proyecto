from django.db import migrations

def create_spatial_indexes(apps, schema_editor):
    if schema_editor.connection.vendor != 'sqlite':
        schema_editor.execute("CREATE INDEX IF NOT EXISTS monitoring_safezone_geometry_gist ON monitoring_safezone USING GIST (geometry);")
        schema_editor.execute("CREATE INDEX IF NOT EXISTS monitoring_safezone_center_point_gist ON monitoring_safezone USING GIST (center_point);")
        schema_editor.execute("CREATE INDEX IF NOT EXISTS monitoring_groupsafezone_geometry_gist ON monitoring_groupsafezone USING GIST (geometry);")
        schema_editor.execute("CREATE INDEX IF NOT EXISTS monitoring_groupsafezone_center_point_gist ON monitoring_groupsafezone USING GIST (center_point);")
        schema_editor.execute("CREATE INDEX IF NOT EXISTS monitoring_locationhistory_location_gist ON monitoring_locationhistory USING GIST (location);")

def drop_spatial_indexes(apps, schema_editor):
    if schema_editor.connection.vendor != 'sqlite':
        schema_editor.execute("DROP INDEX IF EXISTS monitoring_safezone_geometry_gist;")
        schema_editor.execute("DROP INDEX IF EXISTS monitoring_safezone_center_point_gist;")
        schema_editor.execute("DROP INDEX IF EXISTS monitoring_groupsafezone_geometry_gist;")
        schema_editor.execute("DROP INDEX IF EXISTS monitoring_groupsafezone_center_point_gist;")
        schema_editor.execute("DROP INDEX IF EXISTS monitoring_locationhistory_location_gist;")

class Migration(migrations.Migration):

    dependencies = [
        ('monitoring', '0008_sync_postgis_data'),
    ]

    operations = [
        migrations.RunPython(create_spatial_indexes, reverse_code=drop_spatial_indexes)
    ]
