"""
WebSocket URL routing for the monitoring app.
"""
from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    # WebSocket para tutores (app mobile) - requiere autenticación
    re_path(r'ws/location/$', consumers.LocationConsumer.as_asgi()),
    
    # WebSocket para trackers - requiere device_id
    re_path(r'ws/tracker/$', consumers.TrackerConsumer.as_asgi()),
]
