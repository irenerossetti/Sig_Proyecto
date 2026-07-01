# backend/monitoring/management/commands/populate_data.py

import random
import json
from datetime import datetime, timedelta, date
from django.core.management.base import BaseCommand
from django.contrib.auth.hashers import make_password
from django.contrib.gis.geos import Point, Polygon
from django.db import transaction, connection
from django.contrib.auth.models import Group
from django.utils import timezone

class Command(BaseCommand):
    help = 'Pobla la base de datos con datos de prueba para GeoGuard'

    def add_arguments(self, parser):
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Elimina datos existentes antes de poblar',
        )

    @transaction.atomic
    def handle(self, *args, **kwargs):
        from accounts.models import User
        from monitoring.models import Child, SafeZone, Alert, Device

        if kwargs['clear']:
            self.stdout.write('🗑️  Limpiando datos...')
            Alert.objects.all().delete()
            Device.objects.all().delete()
            Child.objects.all().delete()
            SafeZone.objects.all().delete()
            self.stdout.write('✅ Datos limpiados.')

        self.stdout.write('🚀 Poblando base de datos...')

        self.stdout.write('📋 Creando personal...')
        usuarios = self._crear_usuarios()

        self.stdout.write('🗺️  Creando zona segura...')
        zona = self._crear_zona(usuarios)

        self.stdout.write('👶 Creando 93 niños...')
        ninos = self._crear_ninos(zona, usuarios)

        self.stdout.write('🔔 Creando alertas...')
        self._crear_alertas(ninos, zona)

        self.stdout.write(self.style.SUCCESS(
            f'\n✅ ¡TODO LISTO!\n'
            f'   👤 Usuarios: {User.objects.count()}\n'
            f'   🗺️  Zonas seguras: {SafeZone.objects.count()}\n'
            f'   👶 Niños: {Child.objects.count()}\n'
            f'   📱 Dispositivos: {Device.objects.count()}\n'
            f'   🔔 Alertas: {Alert.objects.count()}'
        ))

    def _crear_usuarios(self):
        from accounts.models import User

        usuarios = []

        grupo_director, _ = Group.objects.get_or_create(name='Directores')
        grupo_maestro, _ = Group.objects.get_or_create(name='Maestros')
        grupo_auxiliar, _ = Group.objects.get_or_create(name='Auxiliares')
        grupo_tutor, _ = Group.objects.get_or_create(name='Tutores')
        grupo_seguridad, _ = Group.objects.get_or_create(name='Seguridad')

        personal = [
            {'username': 'directora', 'email': 'directora@kinder.com', 'password': 'directora123', 'first_name': 'María', 'last_name': 'Gutiérrez', 'phone': '+59171234567', 'is_superuser': True, 'is_staff': True, 'groups': [grupo_director]},
            {'username': 'maestra1', 'email': 'maestra1@kinder.com', 'password': 'maestra123', 'first_name': 'Ana', 'last_name': 'Pérez', 'phone': '+59171234568', 'is_superuser': False, 'is_staff': True, 'groups': [grupo_maestro]},
            {'username': 'maestra2', 'email': 'maestra2@kinder.com', 'password': 'maestra123', 'first_name': 'Laura', 'last_name': 'Flores', 'phone': '+59171234569', 'is_superuser': False, 'is_staff': True, 'groups': [grupo_maestro]},
            {'username': 'maestra3', 'email': 'maestra3@kinder.com', 'password': 'maestra123', 'first_name': 'Carmen', 'last_name': 'Ramírez', 'phone': '+59171234570', 'is_superuser': False, 'is_staff': True, 'groups': [grupo_maestro]},
            {'username': 'auxiliar', 'email': 'auxiliar@kinder.com', 'password': 'auxiliar123', 'first_name': 'José', 'last_name': 'Martínez', 'phone': '+59171234571', 'is_superuser': False, 'is_staff': False, 'groups': [grupo_auxiliar]},
            {'username': 'portero', 'email': 'portero@kinder.com', 'password': 'portero123', 'first_name': 'Roberto', 'last_name': 'Ortiz', 'phone': '+59171234572', 'is_superuser': False, 'is_staff': False, 'groups': [grupo_seguridad]},
        ]

        for data in personal:
            user, creado = User.objects.get_or_create(
                username=data['username'],
                defaults={
                    'email': data['email'],
                    'password': make_password(data['password']),
                    'first_name': data['first_name'],
                    'last_name': data['last_name'],
                    'phone': data['phone'],
                    'is_superuser': data.get('is_superuser', False),
                    'is_staff': data.get('is_staff', False),
                    'is_active': True
                }
            )
            if creado:
                for grupo in data.get('groups', []):
                    user.groups.add(grupo)
                usuarios.append(user)
                self.stdout.write(f'   ✅ {user.username} ({user.email})')

        tutores_data = [
            {'username': 'tutor1', 'email': 'tutor1@test.com', 'first_name': 'Carlos', 'last_name': 'López'},
            {'username': 'tutor2', 'email': 'tutor2@test.com', 'first_name': 'Marta', 'last_name': 'Sánchez'},
            {'username': 'tutor3', 'email': 'tutor3@test.com', 'first_name': 'Luis', 'last_name': 'García'},
            {'username': 'tutor4', 'email': 'tutor4@test.com', 'first_name': 'Ana', 'last_name': 'Rodríguez'},
            {'username': 'tutor5', 'email': 'tutor5@test.com', 'first_name': 'Pedro', 'last_name': 'Martínez'},
        ]

        for data in tutores_data:
            user, creado = User.objects.get_or_create(
                username=data['username'],
                defaults={
                    'email': data['email'],
                    'password': make_password('tutor123'),
                    'first_name': data['first_name'],
                    'last_name': data['last_name'],
                    'phone': f'+5917{random.randint(10000000, 99999999)}',
                    'is_superuser': False,
                    'is_staff': False,
                    'is_active': True
                }
            )
            if creado:
                user.groups.add(grupo_tutor)
                usuarios.append(user)
                self.stdout.write(f'   ✅ Tutor: {user.username} ({user.email})')

        self.stdout.write(f'   ✅ Total usuarios: {len(usuarios)}')
        return usuarios

    def _crear_zona(self, usuarios):
        from monitoring.models import Child, SafeZone
        from accounts.models import User

        grupo_tutor = Group.objects.get(name='Tutores')
        tutores = list(User.objects.filter(groups=grupo_tutor))
        if not tutores:
            tutores = list(User.objects.filter(is_staff=False)[:5])
        
        tutor_temporal = tutores[0] if tutores else None
        
        fecha_nacimiento = date.today() - timedelta(days=365*5)
        
        child_temporal = Child.objects.create(
            full_name='Zona Segura - Temporal',
            tutor=tutor_temporal,
            date_of_birth=fecha_nacimiento,
            is_active=False,
            notes='Niño temporal para asociar la zona segura'
        )

        coordenadas = [
            [-17.7835, -63.2225],
            [-17.7828, -63.2218],
            [-17.7820, -63.2223],
            [-17.7815, -63.2228],
            [-17.7822, -63.2235],
            [-17.7830, -63.2232],
            [-17.7835, -63.2225],
        ]

        poligono = Polygon(coordenadas, srid=4326)
        centro_lat = sum(p[0] for p in coordenadas) / len(coordenadas)
        centro_lng = sum(p[1] for p in coordenadas) / len(coordenadas)
        centro_punto = Point(centro_lng, centro_lat, srid=4326)

        # Generar EWKT manual si es un objeto Mock (DummyGEOSGeometry)
        if hasattr(poligono, 'ewkt'):
            poligono_ewkt = poligono.ewkt
        else:
            # En PostGIS/WKT la longitud va antes de la latitud
            coords_str = ", ".join(f"{p[1]} {p[0]}" for p in coordenadas)
            poligono_ewkt = f"SRID=4326;POLYGON(({coords_str}))"

        if hasattr(centro_punto, 'ewkt'):
            centro_ewkt = centro_punto.ewkt
        else:
            centro_ewkt = f"SRID=4326;POINT({centro_lng} {centro_lat})"

        zona = SafeZone.objects.filter(name="Unidad Educativa 6 de Enero").first()
        if zona:
            self.stdout.write('   ℹ️ Zona segura ya existía')
            return zona

        ahora = timezone.now()

        try:
            with connection.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO monitoring_safezone (
                        name, child_id, zone_type, center_latitude, center_longitude,
                        radius_meters, polygon_points, color, is_active,
                        geometry, center_point, polygon,
                        created_at, updated_at
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s,
                        ST_SetSRID(ST_GeomFromText(%s), 4326),
                        ST_SetSRID(ST_GeomFromText(%s), 4326),
                        ST_SetSRID(ST_GeomFromText(%s), 4326),
                        %s, %s
                    ) RETURNING id
                """, [
                    "Unidad Educativa 6 de Enero",
                    child_temporal.id,
                    'polygon',
                    centro_lat,
                    centro_lng,
                    150,
                    json.dumps(coordenadas),
                    '#4CAF50',
                    True,
                    poligono_ewkt,
                    centro_ewkt,
                    poligono_ewkt,
                    ahora,
                    ahora
                ])
                
                zona_id = cursor.fetchone()[0]
                zona = SafeZone.objects.get(id=zona_id)
                self.stdout.write('   ✅ Zona segura creada (usando SQL)')
                return zona
                
        except Exception as e:
            self.stdout.write(f'   ❌ Error con SQL: {e}')
            raise

    def _crear_ninos(self, zona, usuarios):
        from monitoring.models import Child, Device
        from accounts.models import User

        ninos = []

        nombres_completos = [
            'Mateo López', 'Lucas García', 'Sofía Martínez', 'Valentina Pérez', 'Santiago González',
            'Emma Rodríguez', 'Daniel Sánchez', 'Isabella Ramírez', 'Nicolás Torres', 'Catalina Flores',
            'Sebastián Rivera', 'Victoria Morales', 'Diego Ortiz', 'Martina Cruz', 'Samuel Reyes',
            'Valeria Gutiérrez', 'Gabriel Mendoza', 'Camila Herrera', 'Alejandro Rojas', 'Lucía Gómez',
            'Rafael Álvarez', 'Mía Romero', 'Leonardo Fernández', 'Sara Díaz', 'Benjamín Muñoz',
            'Elena López', 'Francisco García', 'Olivia Martínez', 'Emiliano Pérez', 'Valentina González',
            'Julián Rodríguez', 'Renata Sánchez', 'Matías Ramírez', 'Florencia Torres', 'Lorenzo Flores',
            'Abril Rivera', 'Manuel Morales', 'Aitana Ortiz', 'Joaquín Cruz', 'Noa Reyes',
            'Pablo Gutiérrez', 'Julia Mendoza', 'Adrián Herrera', 'Alma Rojas', 'Hugo Gómez',
            'David Álvarez', 'Paula Romero', 'Javier Fernández', 'Clara Díaz', 'Óscar Muñoz'
        ]

        grupo_tutor = Group.objects.get(name='Tutores')
        tutores = list(User.objects.filter(groups=grupo_tutor))
        if not tutores:
            tutores = list(User.objects.filter(is_staff=False)[:5])

        centro_lat = float(zona.center_latitude)
        centro_lng = float(zona.center_longitude)

        for i in range(93):
            nombre_completo = random.choice(nombres_completos)
            tutor = random.choice(tutores) if tutores else None
            
            edad = random.randint(3, 6)
            fecha_nacimiento = date.today() - timedelta(days=365*edad + random.randint(0, 180))

            nino = Child.objects.create(
                full_name=nombre_completo,
                tutor=tutor,
                date_of_birth=fecha_nacimiento,
                is_active=True,
                notes=random.choice(['', 'Alergia al polen', 'Asma leve', 'Sin observaciones', '']),
                photo=''
            )

            lat = centro_lat + random.uniform(-0.0005, 0.0005)
            lng = centro_lng + random.uniform(-0.0005, 0.0005)
            
            # Adaptar Point para que funcione como WKT text si esta mockeado (DummyGEOSGeometry)
            try:
                p = Point(lng, lat, srid=4326)
                if p.__class__.__name__ == 'DummyGEOSGeometry' or 'Dummy' in str(p.__class__):
                    location_val = f'POINT({lng} {lat})'
                else:
                    location_val = p
            except Exception:
                location_val = f'POINT({lng} {lat})'

            Device.objects.create(
                child=nino,
                device_id=f'GEO-{i+1:04d}',
                device_type=random.choice(['Tracker', 'Wearable', 'Smartwatch']),
                last_latitude=lat,
                last_longitude=lng,
                last_seen=datetime.now() - timedelta(minutes=random.randint(0, 30)),
                battery_level=random.randint(20, 100),
                is_in_safe_zone=random.choice([True, True, True, False]),
                is_active=True,
                last_location=location_val
            )

            ninos.append(nino)

            if (i + 1) % 10 == 0:
                self.stdout.write(f'   ℹ️ {i+1}/93 niños creados')

        self.stdout.write(f'   ✅ {len(ninos)} niños creados')
        return ninos

    def _crear_alertas(self, ninos, zona):
        from monitoring.models import Alert

        tipos = ['SALIDA', 'SIN_CONEXION', 'BATERIA_BAJA', 'ENTRADA']
        mensajes = {
            'SALIDA': 'Niño salió de la zona segura',
            'SIN_CONEXION': 'Dispositivo sin conexión por más de 5 minutos',
            'BATERIA_BAJA': 'Batería del dispositivo por debajo del 15%',
            'ENTRADA': 'Niño ingresó a la zona segura'
        }

        estados = ['ACTIVE', 'ACKNOWLEDGED', 'RESOLVED']

        numero_alertas = random.randint(50, 100)
        self.stdout.write(f'   ℹ️ Creando {numero_alertas} alertas...')

        centro_lat = float(zona.center_latitude)
        centro_lng = float(zona.center_longitude)

        # Obtener el ID del grupo (si existe, sino NULL)
        group_id = None
        try:
            from monitoring.models import Group as MonitorGroup
            grupo = MonitorGroup.objects.first()
            if grupo:
                group_id = grupo.id
        except:
            pass

        for i in range(numero_alertas):
            nino = random.choice(ninos)
            tipo = random.choice(tipos)

            fecha = datetime.now() - timedelta(
                days=random.randint(0, 7),
                hours=random.randint(0, 23),
                minutes=random.randint(0, 59)
            )

            lat = centro_lat + random.uniform(-0.002, 0.002)
            lng = centro_lng + random.uniform(-0.002, 0.002)

            estado = random.choices(
                ['ACTIVE', 'ACKNOWLEDGED', 'RESOLVED'],
                weights=[30, 30, 40]
            )[0]

            # Adaptar Point para que funcione como WKT text si esta mockeado (DummyGEOSGeometry)
            try:
                p = Point(lng, lat, srid=4326)
                if p.__class__.__name__ == 'DummyGEOSGeometry' or 'Dummy' in str(p.__class__):
                    location_val = f'POINT({lng} {lat})'
                else:
                    location_val = p
            except Exception:
                location_val = f'POINT({lng} {lat})'

            # Crear usando el ORM de Django para compatibilidad con BD sin PostGIS
            alert = Alert.objects.create(
                child=nino,
                safe_zone=zona,
                group_id=group_id,
                alert_type=tipo,
                status=estado,
                latitude=lat,
                longitude=lng,
                message=mensajes.get(tipo, 'Alerta general'),
                acknowledged_at=fecha + timedelta(minutes=random.randint(1, 10)) if estado in ['ACKNOWLEDGED', 'RESOLVED'] else None,
                resolved_at=fecha + timedelta(minutes=random.randint(10, 30)) if estado == 'RESOLVED' else None,
                location=location_val
            )
            # Forzar la fecha de creacion personalizada
            Alert.objects.filter(id=alert.id).update(created_at=fecha)

        self.stdout.write(f'   ✅ {numero_alertas} alertas creadas')