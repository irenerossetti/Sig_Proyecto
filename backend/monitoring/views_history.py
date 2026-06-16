"""
Views for location history, analytics, and reports.
"""
import csv
from io import StringIO
from datetime import timedelta

from django.utils import timezone
from django.http import HttpResponse
from django.db.models import Count, Q
from django.db.models.functions import TruncDate, TruncHour

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from drf_spectacular.utils import extend_schema, extend_schema_view, OpenApiParameter, OpenApiTypes

from .models import Child, Alert, Device, SafeZone
from .models_history import LocationHistory
from .serializers_history import (
    LocationHistorySerializer,
    LocationHistoryFilterSerializer,
    MovementStatsSerializer,
    AlertStatsSerializer,
    ReportExportSerializer,
)


@extend_schema_view(
    list=extend_schema(
        summary="Listar historial de ubicaciones",
        description="Lista el historial de ubicaciones de los niños del tutor.",
        tags=["location-history"]
    ),
    retrieve=extend_schema(
        summary="Obtener ubicación",
        description="Obtiene los detalles de una ubicación específica.",
        tags=["location-history"]
    ),
)
class LocationHistoryViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for viewing location history.
    Provides movement tracking and route replay.
    """
    serializer_class = LocationHistorySerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        """Filter to only show history for user's children."""
        user = self.request.user
        child_ids = Child.objects.filter(tutor=user).values_list('id', flat=True)
        return LocationHistory.objects.filter(child_id__in=child_ids)
    
    @extend_schema(
        summary="Historial por niño",
        description="Obtiene el historial de ubicaciones de un niño específico con filtros de fecha.",
        tags=["location-history"],
        parameters=[
            OpenApiParameter("child_id", OpenApiTypes.INT, description="ID del niño", required=True),
            OpenApiParameter("start_date", OpenApiTypes.DATETIME, description="Fecha de inicio"),
            OpenApiParameter("end_date", OpenApiTypes.DATETIME, description="Fecha de fin"),
            OpenApiParameter("limit", OpenApiTypes.INT, description="Límite de resultados (default 1000)"),
        ]
    )
    @action(detail=False, methods=['get'])
    def by_child(self, request):
        """Get location history for a specific child."""
        filter_serializer = LocationHistoryFilterSerializer(data=request.query_params)
        filter_serializer.is_valid(raise_exception=True)
        
        child_id = filter_serializer.validated_data['child_id']
        
        # Verify child belongs to user
        if not Child.objects.filter(id=child_id, tutor=request.user).exists():
            return Response(
                {"error": "Niño no encontrado"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        history = LocationHistory.get_child_history(
            child_id=child_id,
            start_date=filter_serializer.validated_data.get('start_date'),
            end_date=filter_serializer.validated_data.get('end_date'),
            limit=filter_serializer.validated_data.get('limit', 1000)
        )
        
        serializer = self.get_serializer(history, many=True)
        return Response(serializer.data)
    
    @extend_schema(
        summary="Obtener ruta",
        description="Obtiene el historial de ubicaciones formateado como ruta para visualización en mapa.",
        tags=["location-history"],
        parameters=[
            OpenApiParameter("child_id", OpenApiTypes.INT, description="ID del niño", required=True),
            OpenApiParameter("start_date", OpenApiTypes.DATETIME, description="Fecha de inicio"),
            OpenApiParameter("end_date", OpenApiTypes.DATETIME, description="Fecha de fin"),
            OpenApiParameter("limit", OpenApiTypes.INT, description="Límite de puntos (default 1000)"),
        ]
    )
    @action(detail=False, methods=['get'])
    def route(self, request):
        """
        Get location history formatted as a route for map display.
        Returns simplified data optimized for drawing paths.
        """
        filter_serializer = LocationHistoryFilterSerializer(data=request.query_params)
        filter_serializer.is_valid(raise_exception=True)
        
        child_id = filter_serializer.validated_data['child_id']
        
        if not Child.objects.filter(id=child_id, tutor=request.user).exists():
            return Response(
                {"error": "Niño no encontrado"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        history = LocationHistory.get_child_history(
            child_id=child_id,
            start_date=filter_serializer.validated_data.get('start_date'),
            end_date=filter_serializer.validated_data.get('end_date'),
            limit=filter_serializer.validated_data.get('limit', 1000)
        )
        
        # Format as route points
        route_points = [
            {
                'lat': float(loc.latitude),
                'lng': float(loc.longitude),
                'timestamp': loc.timestamp.isoformat(),
                'in_zone': loc.is_in_safe_zone,
                'battery': loc.battery_level,
            }
            for loc in history
        ]
        
        return Response({
            'child_id': child_id,
            'points_count': len(route_points),
            'route': route_points,
        })


class AnalyticsViewSet(viewsets.ViewSet):
    """
    ViewSet for analytics and statistics.
    """
    permission_classes = [IsAuthenticated]
    
    @action(detail=False, methods=['get'])
    def movement_stats(self, request):
        """Get movement statistics for a child."""
        serializer = MovementStatsSerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        
        child_id = serializer.validated_data['child_id']
        start_date = serializer.validated_data.get('start_date', timezone.now() - timedelta(days=7))
        end_date = serializer.validated_data.get('end_date', timezone.now())
        
        if not Child.objects.filter(id=child_id, tutor=request.user).exists():
            return Response(
                {"error": "Niño no encontrado"},
                status=status.HTTP_404_NOT_FOUND
            )
        
        stats = LocationHistory.get_movement_stats(child_id, start_date, end_date)
        
        return Response({
            'child_id': child_id,
            'start_date': start_date.isoformat(),
            'end_date': end_date.isoformat(),
            **stats
        })
    
    @action(detail=False, methods=['get'])
    def alert_stats(self, request):
        """Get alert statistics."""
        serializer = AlertStatsSerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        
        period = serializer.validated_data['period']
        child_id = serializer.validated_data.get('child_id')
        
        # Calculate date range
        now = timezone.now()
        if period == 'day':
            start_date = now - timedelta(days=1)
        elif period == 'week':
            start_date = now - timedelta(weeks=1)
        else:  # month
            start_date = now - timedelta(days=30)
        
        # Base queryset
        alerts = Alert.objects.filter(
            child__tutor=request.user,
            created_at__gte=start_date
        )
        
        if child_id:
            alerts = alerts.filter(child_id=child_id)
        
        # Stats by type
        by_type = alerts.values('alert_type').annotate(count=Count('id'))
        
        # Stats by status
        by_status = alerts.values('status').annotate(count=Count('id'))
        
        # Stats over time
        if period == 'day':
            time_trunc = TruncHour('created_at')
        else:
            time_trunc = TruncDate('created_at')
        
        over_time = alerts.annotate(
            time_period=time_trunc
        ).values('time_period').annotate(
            count=Count('id')
        ).order_by('time_period')
        
        # Top children with alerts
        top_children = alerts.values(
            'child_id', 'child__full_name'
        ).annotate(
            count=Count('id')
        ).order_by('-count')[:5]
        
        return Response({
            'period': period,
            'start_date': start_date.isoformat(),
            'end_date': now.isoformat(),
            'total_alerts': alerts.count(),
            'by_type': list(by_type),
            'by_status': list(by_status),
            'over_time': list(over_time),
            'top_children': list(top_children),
        })
    
    @action(detail=False, methods=['get'])
    def dashboard_summary(self, request):
        """Get comprehensive dashboard summary."""
        user = request.user
        now = timezone.now()
        today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        week_ago = now - timedelta(weeks=1)
        
        # Children stats
        children = Child.objects.filter(tutor=user, is_active=True)
        children_count = children.count()
        
        # Devices stats
        devices = Device.objects.filter(child__tutor=user)
        active_devices = devices.filter(is_active=True).count()
        online_devices = devices.filter(
            is_active=True,
            last_seen__gte=now - timedelta(minutes=5)
        ).count()
        
        # Children in/out of zone
        in_zone = devices.filter(is_in_safe_zone=True, is_active=True).count()
        out_of_zone = devices.filter(is_in_safe_zone=False, is_active=True).count()
        
        # Alerts stats
        alerts_today = Alert.objects.filter(
            child__tutor=user,
            created_at__gte=today
        ).count()
        
        alerts_week = Alert.objects.filter(
            child__tutor=user,
            created_at__gte=week_ago
        ).count()
        
        pending_alerts = Alert.objects.filter(
            child__tutor=user,
            status='pending'
        ).count()
        
        # Safe zones
        safe_zones = SafeZone.objects.filter(
            child__tutor=user,
            is_active=True
        ).count()
        
        # Recent alerts
        recent_alerts = Alert.objects.filter(
            child__tutor=user
        ).select_related('child').order_by('-created_at')[:5]
        
        recent_alerts_data = [
            {
                'id': a.id,
                'child_name': a.child.full_name,
                'alert_type': a.alert_type,
                'message': a.message,
                'status': a.status,
                'created_at': a.created_at.isoformat(),
            }
            for a in recent_alerts
        ]
        
        # Location updates today
        location_updates_today = LocationHistory.objects.filter(
            child__tutor=user,
            timestamp__gte=today
        ).count()
        
        return Response({
            'children': {
                'total': children_count,
                'in_zone': in_zone,
                'out_of_zone': out_of_zone,
            },
            'devices': {
                'total': devices.count(),
                'active': active_devices,
                'online': online_devices,
            },
            'alerts': {
                'today': alerts_today,
                'this_week': alerts_week,
                'pending': pending_alerts,
            },
            'safe_zones': safe_zones,
            'location_updates_today': location_updates_today,
            'recent_alerts': recent_alerts_data,
        })


class ReportExportViewSet(viewsets.ViewSet):
    """
    ViewSet for exporting reports.
    """
    permission_classes = [IsAuthenticated]
    
    @action(detail=False, methods=['get'])
    def export(self, request):
        """Export report data."""
        serializer = ReportExportSerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        
        report_type = serializer.validated_data['report_type']
        child_id = serializer.validated_data.get('child_id')
        start_date = serializer.validated_data['start_date']
        end_date = serializer.validated_data['end_date']
        export_format = serializer.validated_data['format']
        
        user = request.user
        
        if report_type == 'movement_history':
            data = self._get_movement_data(user, child_id, start_date, end_date)
        elif report_type == 'alerts':
            data = self._get_alerts_data(user, child_id, start_date, end_date)
        else:  # summary
            data = self._get_summary_data(user, child_id, start_date, end_date)
        
        if export_format == 'csv':
            return self._export_csv(data, report_type)
        
        return Response(data)
    
    def _get_movement_data(self, user, child_id, start_date, end_date):
        """Get movement history data."""
        queryset = LocationHistory.objects.filter(
            child__tutor=user,
            timestamp__gte=start_date,
            timestamp__lte=end_date
        )
        
        if child_id:
            queryset = queryset.filter(child_id=child_id)
        
        return [
            {
                'child_name': loc.child.full_name,
                'latitude': float(loc.latitude),
                'longitude': float(loc.longitude),
                'battery': loc.battery_level,
                'in_zone': loc.is_in_safe_zone,
                'timestamp': loc.timestamp.isoformat(),
            }
            for loc in queryset[:5000]
        ]
    
    def _get_alerts_data(self, user, child_id, start_date, end_date):
        """Get alerts data."""
        queryset = Alert.objects.filter(
            child__tutor=user,
            created_at__gte=start_date,
            created_at__lte=end_date
        ).select_related('child', 'safe_zone')
        
        if child_id:
            queryset = queryset.filter(child_id=child_id)
        
        return [
            {
                'child_name': alert.child.full_name,
                'alert_type': alert.alert_type,
                'status': alert.status,
                'message': alert.message,
                'latitude': float(alert.latitude) if alert.latitude else None,
                'longitude': float(alert.longitude) if alert.longitude else None,
                'created_at': alert.created_at.isoformat(),
                'acknowledged_at': alert.acknowledged_at.isoformat() if alert.acknowledged_at else None,
            }
            for alert in queryset
        ]
    
    def _get_summary_data(self, user, child_id, start_date, end_date):
        """Get summary data."""
        children = Child.objects.filter(tutor=user, is_active=True)
        if child_id:
            children = children.filter(id=child_id)
        
        summary = []
        for child in children:
            alerts = Alert.objects.filter(
                child=child,
                created_at__gte=start_date,
                created_at__lte=end_date
            )
            
            locations = LocationHistory.objects.filter(
                child=child,
                timestamp__gte=start_date,
                timestamp__lte=end_date
            )
            
            summary.append({
                'child_name': child.full_name,
                'total_alerts': alerts.count(),
                'zone_exit_alerts': alerts.filter(alert_type='zone_exit').count(),
                'total_locations': locations.count(),
                'in_zone_percentage': round(
                    locations.filter(is_in_safe_zone=True).count() / max(locations.count(), 1) * 100, 1
                ),
                'device_status': 'active' if hasattr(child, 'device') and child.device.is_active else 'inactive',
            })
        
        return summary
    
    def _export_csv(self, data, report_type):
        """Export data as CSV."""
        if not data:
            return HttpResponse("No data", content_type='text/csv')
        
        output = StringIO()
        writer = csv.DictWriter(output, fieldnames=data[0].keys())
        writer.writeheader()
        writer.writerows(data)
        
        response = HttpResponse(output.getvalue(), content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="{report_type}_{timezone.now().strftime("%Y%m%d")}.csv"'
        
        return response
