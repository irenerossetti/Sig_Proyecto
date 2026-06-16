"""
Serializers for location history and analytics.
"""
from rest_framework import serializers
from django.utils import timezone
from datetime import timedelta

from .models_history import LocationHistory


class LocationHistorySerializer(serializers.ModelSerializer):
    """Serializer for location history records."""
    child_name = serializers.CharField(source='child.full_name', read_only=True)
    device_id = serializers.CharField(source='device.device_id', read_only=True)
    
    class Meta:
        model = LocationHistory
        fields = [
            'id',
            'device',
            'device_id',
            'child',
            'child_name',
            'latitude',
            'longitude',
            'battery_level',
            'is_in_safe_zone',
            'accuracy',
            'speed',
            'heading',
            'timestamp',
        ]
        read_only_fields = ['id', 'timestamp', 'child_name', 'device_id']


class LocationHistoryFilterSerializer(serializers.Serializer):
    """Serializer for filtering location history."""
    child_id = serializers.IntegerField(required=True)
    start_date = serializers.DateTimeField(required=False)
    end_date = serializers.DateTimeField(required=False)
    limit = serializers.IntegerField(required=False, default=1000, max_value=5000)
    
    def validate(self, data):
        # Default to last 24 hours if no dates provided
        if 'start_date' not in data:
            data['start_date'] = timezone.now() - timedelta(hours=24)
        if 'end_date' not in data:
            data['end_date'] = timezone.now()
        
        if data['start_date'] > data['end_date']:
            raise serializers.ValidationError("start_date must be before end_date")
        
        return data


class MovementStatsSerializer(serializers.Serializer):
    """Serializer for movement statistics."""
    child_id = serializers.IntegerField()
    start_date = serializers.DateTimeField()
    end_date = serializers.DateTimeField()
    daily_counts = serializers.ListField(read_only=True)
    zone_stats = serializers.DictField(read_only=True)
    total_days = serializers.IntegerField(read_only=True)


class AlertStatsSerializer(serializers.Serializer):
    """Serializer for alert statistics."""
    period = serializers.ChoiceField(choices=['day', 'week', 'month'], default='week')
    child_id = serializers.IntegerField(required=False)


class ReportExportSerializer(serializers.Serializer):
    """Serializer for report export requests."""
    report_type = serializers.ChoiceField(
        choices=['movement_history', 'alerts', 'summary'],
        default='summary'
    )
    child_id = serializers.IntegerField(required=False)
    start_date = serializers.DateTimeField(required=False)
    end_date = serializers.DateTimeField(required=False)
    format = serializers.ChoiceField(choices=['json', 'csv'], default='json')
    
    def validate(self, data):
        if 'start_date' not in data:
            data['start_date'] = timezone.now() - timedelta(days=7)
        if 'end_date' not in data:
            data['end_date'] = timezone.now()
        return data
