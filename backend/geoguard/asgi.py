"""ASGI config for geoguard project with WebSocket support."""

import os
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "geoguard.settings")

# Initialize Django ASGI application early to ensure the AppRegistry
# is populated before importing consumers
django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter
from monitoring.routing import websocket_urlpatterns
from monitoring.middleware import TokenAuthMiddleware

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    # WebSocket sin AllowedHostsOriginValidator porque apps móviles 
    # no envían header Origin válido
    "websocket": TokenAuthMiddleware(
        URLRouter(websocket_urlpatterns)
    ),
})
