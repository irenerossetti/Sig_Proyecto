from rest_framework.routers import DefaultRouter

from .views import (
    AlertViewSet, 
    ChildViewSet, 
    DeviceViewSet, 
    SafeZoneViewSet,
    GeocodingViewSet,
    PlacesViewSet,
    ChildGroupViewSet,
    GroupSafeZoneViewSet,
    NotificationViewSet,
)
from .views_history import (
    LocationHistoryViewSet,
    AnalyticsViewSet,
    ReportExportViewSet,
)

router = DefaultRouter()
router.register(r'children', ChildViewSet, basename='children')
router.register(r'alerts', AlertViewSet, basename='alerts')
router.register(r'devices', DeviceViewSet, basename='devices')
router.register(r'safe-zones', SafeZoneViewSet, basename='safe-zones')
router.register(r'geocoding', GeocodingViewSet, basename='geocoding')
router.register(r'places', PlacesViewSet, basename='places')
router.register(r'groups', ChildGroupViewSet, basename='groups')
router.register(r'group-safe-zones', GroupSafeZoneViewSet, basename='group-safe-zones')
router.register(r'notifications', NotificationViewSet, basename='notifications')
router.register(r'location-history', LocationHistoryViewSet, basename='location-history')
router.register(r'analytics', AnalyticsViewSet, basename='analytics')
router.register(r'reports', ReportExportViewSet, basename='reports')

urlpatterns = router.urls
