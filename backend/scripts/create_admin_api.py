#!/usr/bin/env python
"""
Script para crear usuarios administradores via API HTTP.
Útil cuando no tienes acceso directo a la base de datos.

Uso:
    python scripts/create_admin_api.py
    python scripts/create_admin_api.py --email admin@geoguard.com --name "Admin" --password SecurePass123
"""

import argparse
import getpass
import requests
import sys

# URL del backend (cambiar según entorno)
DEFAULT_API_URL = "http://34.45.10.241/api"


def create_admin_via_api(
    email: str, 
    full_name: str, 
    password: str, 
    phone: str = None,
    api_url: str = DEFAULT_API_URL
) -> dict:
    """
    Crea un usuario administrador usando la API de registro.
    
    Args:
        email: Correo electrónico
        full_name: Nombre completo
        password: Contraseña
        phone: Teléfono (opcional)
        api_url: URL base de la API
    
    Returns:
        dict con respuesta de la API
    """
    url = f"{api_url}/auth/register/"
    
    payload = {
        "email": email,
        "full_name": full_name,
        "password": password,
    }
    
    if phone:
        payload["phone"] = phone
    
    try:
        response = requests.post(url, json=payload, timeout=30)
        
        if response.status_code == 201:
            return {"success": True, "data": response.json()}
        else:
            return {"success": False, "error": response.json(), "status": response.status_code}
            
    except requests.exceptions.ConnectionError:
        return {"success": False, "error": "No se pudo conectar al servidor"}
    except requests.exceptions.Timeout:
        return {"success": False, "error": "Timeout - el servidor no responde"}
    except Exception as e:
        return {"success": False, "error": str(e)}


def interactive_mode(api_url: str):
    """Modo interactivo para crear un administrador."""
    print("\n" + "=" * 50)
    print("   🛡️  GeoGuard - Crear Administrador (API)")
    print("=" * 50)
    print(f"   📡 Servidor: {api_url}")
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
    
    # Solicitar contraseña
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
    print("\n⏳ Creando administrador en el servidor...")
    result = create_admin_via_api(email, full_name, password, phone, api_url)
    
    if result["success"]:
        data = result["data"]
        print("\n" + "=" * 50)
        print("   ✅ Administrador creado exitosamente!")
        print("=" * 50)
        print(f"\n📧 Email:  {data['user']['email']}")
        print(f"👤 Nombre: {data['user']['full_name']}")
        print(f"🔑 Token:  {data['token']}")
        print("\n💡 Usa este token para autenticarte en el panel web")
        print("   Header: Authorization: Token <token>")
        print("=" * 50 + "\n")
    else:
        print("\n" + "=" * 50)
        print("   ❌ Error al crear administrador")
        print("=" * 50)
        error = result.get("error", "Error desconocido")
        if isinstance(error, dict):
            for key, value in error.items():
                if isinstance(value, list):
                    print(f"   {key}: {value[0]}")
                else:
                    print(f"   {key}: {value}")
        else:
            print(f"   {error}")
        print("=" * 50 + "\n")


def main():
    """Función principal."""
    parser = argparse.ArgumentParser(
        description='Crear usuario administrador para GeoGuard via API',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  # Modo interactivo (servidor por defecto)
  python scripts/create_admin_api.py
  
  # Servidor local
  python scripts/create_admin_api.py --url http://localhost:8000/api
  
  # Con argumentos
  python scripts/create_admin_api.py --email admin@geoguard.com --name "Admin" --password SecurePass123
        """
    )
    
    parser.add_argument('-e', '--email', help='Email del administrador')
    parser.add_argument('-n', '--name', help='Nombre completo')
    parser.add_argument('-p', '--password', help='Contraseña (mínimo 8 caracteres)')
    parser.add_argument('--phone', help='Teléfono (opcional)')
    parser.add_argument('--url', default=DEFAULT_API_URL, 
                        help=f'URL base de la API (default: {DEFAULT_API_URL})')
    parser.add_argument('-i', '--interactive', action='store_true', 
                        help='Forzar modo interactivo')
    
    args = parser.parse_args()
    
    # Si no hay argumentos o se pide interactivo, usar modo interactivo
    if args.interactive or not any([args.email, args.name, args.password]):
        interactive_mode(args.url)
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
    print(f"⏳ Conectando a {args.url}...")
    result = create_admin_via_api(args.email, args.name, args.password, args.phone, args.url)
    
    if result["success"]:
        data = result["data"]
        print(f"\n✅ Administrador creado: {data['user']['email']}")
        print(f"🔑 Token: {data['token']}\n")
    else:
        print(f"\n❌ Error: {result.get('error', 'Error desconocido')}\n")
        sys.exit(1)


if __name__ == '__main__':
    main()
