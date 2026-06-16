#!/usr/bin/env python
"""
Script para crear usuarios administradores en GeoGuard.

Uso:
    python manage.py shell < scripts/create_admin.py
    
O ejecutar directamente:
    python scripts/create_admin.py

También puedes usarlo con argumentos:
    python scripts/create_admin.py --email admin@geoguard.com --name "Admin Principal" --password SecurePass123
"""

import os
import sys
import argparse
import getpass

# Configurar Django
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'geoguard.settings')

import django
django.setup()

from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token

User = get_user_model()


def create_admin(email: str, full_name: str, password: str, phone: str = None) -> dict:
    """
    Crea un usuario administrador con token de autenticación.
    
    Args:
        email: Correo electrónico del administrador
        full_name: Nombre completo
        password: Contraseña
        phone: Teléfono (opcional)
    
    Returns:
        dict con información del usuario creado y su token
    """
    # Verificar si el usuario ya existe
    if User.objects.filter(email=email).exists():
        print(f"\n❌ Error: Ya existe un usuario con el email '{email}'")
        return None
    
    # Crear el usuario administrador
    user = User.objects.create_user(
        email=email,
        password=password,
        full_name=full_name,
        phone=phone,
        is_staff=True,
        is_superuser=True,
    )
    
    # Crear token de autenticación
    token, _ = Token.objects.get_or_create(user=user)
    
    return {
        'user': user,
        'token': token.key,
    }


def interactive_mode():
    """Modo interactivo para crear un administrador."""
    print("\n" + "=" * 50)
    print("   🛡️  GeoGuard - Crear Administrador")
    print("=" * 50 + "\n")
    
    # Solicitar datos
    email = input("📧 Email: ").strip()
    if not email:
        print("❌ El email es obligatorio")
        return
    
    full_name = input("👤 Nombre completo: ").strip()
    if not full_name:
        print("❌ El nombre es obligatorio")
        return
    
    phone = input("📱 Teléfono (opcional, Enter para omitir): ").strip() or None
    
    # Solicitar contraseña de forma segura
    password = getpass.getpass("🔐 Contraseña: ")
    if not password:
        print("❌ La contraseña es obligatoria")
        return
    
    if len(password) < 8:
        print("❌ La contraseña debe tener al menos 8 caracteres")
        return
    
    password_confirm = getpass.getpass("🔐 Confirmar contraseña: ")
    if password != password_confirm:
        print("❌ Las contraseñas no coinciden")
        return
    
    # Crear el administrador
    print("\n⏳ Creando administrador...")
    result = create_admin(email, full_name, password, phone)
    
    if result:
        print("\n" + "=" * 50)
        print("   ✅ Administrador creado exitosamente!")
        print("=" * 50)
        print(f"\n📧 Email:  {result['user'].email}")
        print(f"👤 Nombre: {result['user'].full_name}")
        print(f"🔑 Token:  {result['token']}")
        print(f"📅 Creado: {result['user'].date_joined.strftime('%Y-%m-%d %H:%M')}")
        print("\n💡 Usa este token en el header: Authorization: Token {token}")
        print("=" * 50 + "\n")


def main():
    """Función principal con soporte para argumentos CLI."""
    parser = argparse.ArgumentParser(
        description='Crear usuario administrador para GeoGuard Web',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  # Modo interactivo
  python scripts/create_admin.py
  
  # Con argumentos
  python scripts/create_admin.py --email admin@geoguard.com --name "Admin" --password SecurePass123
  
  # Con teléfono
  python scripts/create_admin.py -e admin@school.edu -n "Director" -p Pass1234 --phone "+591 70000000"
        """
    )
    
    parser.add_argument('-e', '--email', help='Email del administrador')
    parser.add_argument('-n', '--name', help='Nombre completo')
    parser.add_argument('-p', '--password', help='Contraseña (mínimo 8 caracteres)')
    parser.add_argument('--phone', help='Teléfono (opcional)')
    parser.add_argument('-i', '--interactive', action='store_true', 
                        help='Forzar modo interactivo')
    
    args = parser.parse_args()
    
    # Si no hay argumentos o se pide interactivo, usar modo interactivo
    if args.interactive or not any([args.email, args.name, args.password]):
        interactive_mode()
        return
    
    # Validar argumentos requeridos
    if not args.email:
        print("❌ Error: --email es requerido")
        sys.exit(1)
    if not args.name:
        print("❌ Error: --name es requerido")
        sys.exit(1)
    if not args.password:
        print("❌ Error: --password es requerido")
        sys.exit(1)
    if len(args.password) < 8:
        print("❌ Error: La contraseña debe tener al menos 8 caracteres")
        sys.exit(1)
    
    # Crear administrador
    result = create_admin(args.email, args.name, args.password, args.phone)
    
    if result:
        print(f"\n✅ Administrador creado: {result['user'].email}")
        print(f"🔑 Token: {result['token']}\n")
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()
