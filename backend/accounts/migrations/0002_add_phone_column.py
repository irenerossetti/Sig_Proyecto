from django.db import migrations

def add_phone_conditional(apps, schema_editor):
    if schema_editor.connection.vendor != 'sqlite':
        with schema_editor.connection.cursor() as cursor:
            cursor.execute("ALTER TABLE auth_user ADD COLUMN IF NOT EXISTS phone varchar(20);")

def remove_phone_conditional(apps, schema_editor):
    if schema_editor.connection.vendor != 'sqlite':
        with schema_editor.connection.cursor() as cursor:
            cursor.execute("ALTER TABLE auth_user DROP COLUMN IF EXISTS phone;")

class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(add_phone_conditional, reverse_code=remove_phone_conditional)
    ]
