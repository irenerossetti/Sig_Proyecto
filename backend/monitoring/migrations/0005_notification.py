# Manual migration for Notification model
# This migration does not require GDAL/PostGIS

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('monitoring', '0004_group_models'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Notification',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title', models.CharField(max_length=100, verbose_name='Título')),
                ('message', models.TextField(verbose_name='Mensaje')),
                ('recipient_type', models.CharField(
                    choices=[
                        ('all', 'Todos los usuarios'),
                        ('tutors', 'Solo tutores'),
                        ('specific', 'Usuario específico'),
                    ],
                    default='all',
                    max_length=20,
                    verbose_name='Destinatarios'
                )),
                ('status', models.CharField(
                    choices=[
                        ('draft', 'Borrador'),
                        ('sent', 'Enviada'),
                        ('failed', 'Fallida'),
                    ],
                    default='draft',
                    max_length=20,
                    verbose_name='Estado'
                )),
                ('sent_count', models.IntegerField(default=0, verbose_name='Notificaciones enviadas')),
                ('failed_count', models.IntegerField(default=0, verbose_name='Notificaciones fallidas')),
                ('sent_at', models.DateTimeField(blank=True, null=True, verbose_name='Fecha de envío')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('created_by', models.ForeignKey(
                    null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='created_notifications',
                    to=settings.AUTH_USER_MODEL,
                    verbose_name='Creado por'
                )),
                ('specific_user', models.ForeignKey(
                    blank=True,
                    null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='received_notifications',
                    to=settings.AUTH_USER_MODEL,
                    verbose_name='Usuario específico'
                )),
            ],
            options={
                'verbose_name': 'Notificación',
                'verbose_name_plural': 'Notificaciones',
                'ordering': ['-created_at'],
            },
        ),
    ]
