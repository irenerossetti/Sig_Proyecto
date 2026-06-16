#!/usr/bin/env python
"""
Script para promover un usuario a administrador via API.
Usa un endpoint especial que verifica una clave secreta.

Uso:
    python scripts/make_admin_api.py --email geoguard@gmail.com --secret YOUR_SECRET_KEY
"""

import argparse
import requests
import sys

DEFAULT_API_URL = "http://34.45.10.241/api"


def make_admin(email: str, secret_key: str, api_url: str = DEFAULT_API_URL) -> dict:
    """
    Promover usuario a admin usando endpoint especial.
    """
    url = f"{api_url}/auth/make-admin/"
    
    payload = {
        "email": email,
        "secret_key": secret_key,
    }
    
    try:
        response = requests.post(url, json=payload, timeout=30)
        
        if response.status_code == 200:
            return {"success": True, "data": response.json()}
        else:
            return {"success": False, "error": response.json(), "status": response.status_code}
            
    except requests.exceptions.RequestException as e:
        return {"success": False, "error": str(e)}


def main():
    parser = argparse.ArgumentParser(description='Promover usuario a admin via API')
    parser.add_argument('-e', '--email', required=True, help='Email del usuario')
    parser.add_argument('-s', '--secret', required=True, help='Clave secreta de admin')
    parser.add_argument('--url', default=DEFAULT_API_URL, help='URL de la API')
    
    args = parser.parse_args()
    
    print(f"⏳ Promoviendo {args.email} a administrador...")
    result = make_admin(args.email, args.secret, args.url)
    
    if result["success"]:
        print(f"✅ {result['data'].get('message', 'Usuario promovido a admin')}")
    else:
        print(f"❌ Error: {result.get('error', 'Error desconocido')}")
        if result.get('status') == 404:
            print("   El endpoint /auth/make-admin/ no existe. Despliega el backend actualizado.")
        sys.exit(1)


if __name__ == '__main__':
    main()
