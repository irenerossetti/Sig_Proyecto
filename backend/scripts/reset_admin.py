#!/usr/bin/env python
import os
import sys
import django

sys.path.insert(0, '/home/geoguard/backend')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'geoguard.settings')
django.setup()

from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token

User = get_user_model()

email = 'geoguard@gmail.com'
password = '12345678*'
full_name = 'GeoGuard Admin'

# Eliminar usuario existente si existe
User.objects.filter(email=email).delete()
User.objects.filter(username=email).delete()

# Crear nuevo usuario
user = User.objects.create_user(
    username=email,
    email=email,
    password=password,
    first_name='GeoGuard',
    last_name='Admin',
    is_staff=True,
    is_superuser=True,
)

# Crear token
token, _ = Token.objects.get_or_create(user=user)

print(f'Usuario creado: {user.email}')
print(f'Token: {token.key}')
