# Generated migration for Group models
# Manual migration to handle existing fields

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('monitoring', '0003_add_postgis_fields'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        # Create the new Group models
        migrations.CreateModel(
            name='ChildGroup',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=150)),
                ('description', models.TextField(blank=True)),
                ('color', models.CharField(default='#1E88E5', max_length=7)),
                ('icon', models.CharField(default='users', max_length=50)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('owner', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='owned_groups', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'Grupo',
                'verbose_name_plural': 'Grupos',
                'ordering': ['name'],
            },
        ),
        migrations.CreateModel(
            name='GroupMembership',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('is_active', models.BooleanField(default=True)),
                ('joined_at', models.DateTimeField(auto_now_add=True)),
                ('added_by', models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='added_memberships', to=settings.AUTH_USER_MODEL)),
                ('child', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='group_memberships', to='monitoring.child')),
                ('group', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='memberships', to='monitoring.childgroup')),
            ],
            options={
                'verbose_name': 'Miembro del grupo',
                'verbose_name_plural': 'Miembros del grupo',
                'unique_together': {('group', 'child')},
            },
        ),
        migrations.CreateModel(
            name='GroupSafeZone',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100)),
                ('zone_type', models.CharField(choices=[('polygon', 'Polígono'), ('circle', 'Círculo')], default='polygon', max_length=20)),
                ('center_latitude', models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ('center_longitude', models.DecimalField(blank=True, decimal_places=6, max_digits=9, null=True)),
                ('radius_meters', models.IntegerField(blank=True, default=100, null=True)),
                ('polygon_points', models.JSONField(blank=True, default=list)),
                ('color', models.CharField(default='#1E8E3E', max_length=7)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('group', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='safe_zones', to='monitoring.childgroup')),
            ],
            options={
                'verbose_name': 'Zona segura del grupo',
                'verbose_name_plural': 'Zonas seguras del grupo',
            },
        ),
        migrations.CreateModel(
            name='GroupTutor',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('role', models.CharField(choices=[('admin', 'Administrador'), ('monitor', 'Monitor')], default='monitor', max_length=20)),
                ('is_active', models.BooleanField(default=True)),
                ('joined_at', models.DateTimeField(auto_now_add=True)),
                ('group', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='tutors', to='monitoring.childgroup')),
                ('invited_by', models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='sent_invitations', to=settings.AUTH_USER_MODEL)),
                ('tutor', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='group_tutor_roles', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'Tutor del grupo',
                'verbose_name_plural': 'Tutores del grupo',
                'unique_together': {('group', 'tutor')},
            },
        ),
        # Add group field to Alert (optional FK)
        migrations.AddField(
            model_name='alert',
            name='group',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='alerts', to='monitoring.childgroup'),
        ),
    ]
