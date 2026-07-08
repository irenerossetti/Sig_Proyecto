import secrets
import string

from rest_framework import serializers
from drf_spectacular.utils import extend_schema_field, OpenApiTypes

from .models import (
    Alert, Child, Device, SafeZone,
    ChildGroup, GroupMembership, GroupTutor, GroupSafeZone,
    Notification
)
from .storage import upload_child_photo, delete_child_photo


def generate_device_id(length=6):
    """
    Generate a unique alphanumeric device ID.
    Only uses letters (uppercase) and numbers, no symbols.
    Example: 'A1B2C3' or 'X9Y8Z7'
    """
    alphabet = string.ascii_uppercase + string.digits
    while True:
        device_id = ''.join(secrets.choice(alphabet) for _ in range(length))
        # Check if already exists
        if not Device.objects.filter(device_id=device_id).exists():
            return device_id


class DeviceSerializer(serializers.ModelSerializer):
    """
    Serializer para dispositivos GPS.
    
    Incluye el estado de conexión calculado dinámicamente (is_online)
    basado en la última conexión del dispositivo.
    """
    is_online = serializers.SerializerMethodField(read_only=True)
    child_name = serializers.CharField(source="child.full_name", read_only=True)
    child = serializers.IntegerField(source="child.id", read_only=True)
    
    class Meta:
        model = Device
        fields = [
            "id",
            "device_id",
            "device_type",
            "last_latitude",
            "last_longitude",
            "last_seen",
            "battery_level",
            "is_active",
            "is_online",
            "is_in_safe_zone",
            "child",
            "child_name",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at", "is_online", "child", "child_name", "is_in_safe_zone"]
    
    @extend_schema_field(OpenApiTypes.BOOL)
    def get_is_online(self, obj):
        """
        Determina si el dispositivo está en línea basándose en last_seen.
        Un dispositivo se considera en línea si last_seen fue hace menos de 5 minutos.
        """
        from django.utils import timezone
        from datetime import timedelta
        
        if not obj.is_active:
            return False
        if not obj.last_seen:
            return False
        
        # Consideramos "en línea" si la última conexión fue hace menos de 5 minutos
        online_threshold = timezone.now() - timedelta(minutes=5)
        return obj.last_seen >= online_threshold


class DeviceCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating a device and associating it with a child."""
    child_id = serializers.IntegerField(write_only=True)

    class Meta:
        model = Device
        fields = [
            "id",
            "child_id",
            "device_id",
            "device_type",
            "is_active",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def validate_child_id(self, value):
        user = self.context["request"].user
        try:
            child = Child.objects.get(id=value, tutor=user)
        except Child.DoesNotExist:
            raise serializers.ValidationError("Niño no encontrado o no pertenece al tutor.")
        if hasattr(child, "device"):
            raise serializers.ValidationError("Este niño ya tiene un dispositivo asignado.")
        return value

    def create(self, validated_data):
        child_id = validated_data.pop("child_id")
        child = Child.objects.get(id=child_id)
        return Device.objects.create(child=child, **validated_data)


class DeviceLocationUpdateSerializer(serializers.Serializer):
    """Serializer for updating device location (simulates GPS updates)."""
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6)
    battery_level = serializers.IntegerField(required=False, min_value=0, max_value=100)


class ChildSerializer(serializers.ModelSerializer):
    device = DeviceSerializer(read_only=True)
    photo = serializers.ImageField(required=False, allow_null=True, write_only=True)
    photo_url = serializers.SerializerMethodField(read_only=True)
    is_own_child = serializers.SerializerMethodField(read_only=True)
    tutor = serializers.IntegerField(source='tutor.id', read_only=True)
    tutor_name = serializers.CharField(source='tutor.full_name', read_only=True)

    # Legacy fields for compatibility with web client
    first_name = serializers.CharField(required=False, allow_blank=True, write_only=True)
    last_name = serializers.CharField(required=False, allow_blank=True, write_only=True)
    grade = serializers.CharField(required=False, allow_blank=True, allow_null=True, write_only=True)

    def to_internal_value(self, data):
        # Merge first_name and last_name into full_name if full_name is not provided
        if 'full_name' not in data and ('first_name' in data or 'last_name' in data):
            first = data.get('first_name') or ''
            last = data.get('last_name') or ''
            data = data.copy()
            data['full_name'] = f"{first} {last}".strip()
        # Map grade to notes
        if 'grade' in data and 'notes' not in data:
            data = data.copy()
            data['notes'] = data.get('grade')
        return super().to_internal_value(data)

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        # Parse full_name back into first_name and last_name for representation
        full_name = instance.full_name or ""
        parts = full_name.split(' ', 1)
        ret['first_name'] = parts[0] if parts else ""
        ret['last_name'] = parts[1] if len(parts) > 1 else ""
        ret['grade'] = instance.notes
        return ret

    class Meta:
        model = Child
        fields = [
            "id",
            "full_name",
            "date_of_birth",
            "photo",
            "photo_url",
            "notes",
            "is_active",
            "created_at",
            "updated_at",
            "device",
            "is_own_child",
            "tutor",
            "tutor_name",
        ]
        read_only_fields = ["id", "created_at", "updated_at", "device", "photo_url", "is_own_child", "tutor", "tutor_name"]

    def get_photo_url(self, obj):
        """Return the photo URL from the model field."""
        if obj.photo:
            photo_value = str(obj.photo)
            # If it's already a full URL (GCS or external), return as-is
            if photo_value.startswith('http://') or photo_value.startswith('https://'):
                return photo_value
            # If it's a relative path, build the full URL
            request = self.context.get('request')
            if request and hasattr(obj.photo, 'url'):
                return request.build_absolute_uri(obj.photo.url)
            # Fallback for local storage
            if hasattr(obj.photo, 'url'):
                return obj.photo.url
        return None

    def get_is_own_child(self, obj):
        """Indica si el niño pertenece directamente al usuario actual."""
        request = self.context.get('request')
        if request and hasattr(request, 'user'):
            return obj.tutor == request.user
        return False

    def create(self, validated_data):
        photo = validated_data.pop('photo', None)
        instance = super().create(validated_data)
        
        if photo:
            # Upload to GCS and store URL
            photo_url = upload_child_photo(photo, instance.id, photo.name)
            instance.photo = photo_url
            instance.save(update_fields=['photo'])
        
        # Automatically create a device with unique alphanumeric ID
        device_id = generate_device_id()
        Device.objects.create(
            child=instance,
            device_id=device_id,
            device_type='auto_generated',
            is_active=True
        )
        
        return instance

    def update(self, instance, validated_data):
        photo = validated_data.pop('photo', None)
        
        if photo:
            # Delete old photo if exists
            if instance.photo:
                old_url = str(instance.photo)
                delete_child_photo(old_url)
            
            # Upload new photo
            photo_url = upload_child_photo(photo, instance.id, photo.name)
            instance.photo = photo_url
            instance.save(update_fields=['photo'])
        
        return super().update(instance, validated_data)


class AlertSerializer(serializers.ModelSerializer):
    child_name = serializers.CharField(source="child.full_name", read_only=True)

    class Meta:
        model = Alert
        fields = [
            "id",
            "child",
            "child_name",
            "safe_zone",
            "status",
            "latitude",
            "longitude",
            "message",
            "acknowledged_at",
            "resolved_at",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "child_name",
            "acknowledged_at",
            "resolved_at",
            "created_at",
        ]


class SafeZoneSerializer(serializers.ModelSerializer):
    child_name = serializers.CharField(source="child.full_name", read_only=True)

    class Meta:
        model = SafeZone
        fields = [
            "id",
            "child",
            "child_name",
            "name",
            "zone_type",
            "center_latitude",
            "center_longitude",
            "radius_meters",
            "polygon_points",
            "color",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "child_name", "created_at", "updated_at"]

    def validate_child(self, value):
        """Ensure the child belongs to the current user (or user is staff)."""
        user = self.context["request"].user
        if not user.is_staff and value.tutor != user:
            raise serializers.ValidationError("Este niño no pertenece al tutor.")
        return value

    def validate(self, data):
        # For partial updates, only validate fields that are being updated
        is_update = self.instance is not None
        
        zone_type = data.get("zone_type", getattr(self.instance, 'zone_type', 'polygon') if is_update else "polygon")
        
        if zone_type == "circle":
            # Only validate circle fields if they're being set or it's a create
            if not is_update or "center_latitude" in data or "center_longitude" in data:
                center_lat = data.get("center_latitude", getattr(self.instance, 'center_latitude', None) if is_update else None)
                center_lng = data.get("center_longitude", getattr(self.instance, 'center_longitude', None) if is_update else None)
                if not center_lat or not center_lng:
                    raise serializers.ValidationError(
                        "Las zonas circulares requieren center_latitude y center_longitude."
                    )
        elif zone_type == "polygon":
            # Only validate polygon_points if they're being set or it's a create
            if "polygon_points" in data or not is_update:
                polygon_points = data.get("polygon_points", [])
                if len(polygon_points) < 3:
                    raise serializers.ValidationError(
                        "Los polígonos requieren al menos 3 puntos."
                    )
                # Validar estructura de puntos
                for point in polygon_points:
                    if not isinstance(point, dict) or "lat" not in point or "lng" not in point:
                        raise serializers.ValidationError(
                            "Cada punto debe tener 'lat' y 'lng'."
                        )
        return data
        return data


# ============== Group Serializers ==============

class GroupMembershipSerializer(serializers.ModelSerializer):
    """Serializer for group membership - shows child info."""
    child_name = serializers.CharField(source='child.full_name', read_only=True)
    child_photo = serializers.SerializerMethodField(read_only=True)
    added_by_name = serializers.SerializerMethodField(read_only=True)
    
    class Meta:
        model = GroupMembership
        fields = [
            'id',
            'group',
            'child',
            'child_name',
            'child_photo',
            'added_by',
            'added_by_name',
            'is_active',
            'joined_at',
        ]
        read_only_fields = ['id', 'added_by', 'added_by_name', 'joined_at']
    
    def get_child_photo(self, obj):
        if obj.child.photo:
            photo_value = str(obj.child.photo)
            if photo_value.startswith('http://') or photo_value.startswith('https://'):
                return photo_value
        return None
    
    def get_added_by_name(self, obj):
        if obj.added_by:
            return obj.added_by.get_full_name() or obj.added_by.email
        return None


class GroupTutorSerializer(serializers.ModelSerializer):
    """Serializer for co-tutors of a group."""
    tutor_name = serializers.SerializerMethodField(read_only=True)
    tutor_email = serializers.CharField(source='tutor.email', read_only=True)
    invited_by_name = serializers.SerializerMethodField(read_only=True)
    
    class Meta:
        model = GroupTutor
        fields = [
            'id',
            'group',
            'tutor',
            'tutor_name',
            'tutor_email',
            'role',
            'invited_by',
            'invited_by_name',
            'is_active',
            'joined_at',
        ]
        read_only_fields = ['id', 'invited_by', 'invited_by_name', 'joined_at']
    
    def get_tutor_name(self, obj):
        if obj.tutor:
            return obj.tutor.get_full_name() or obj.tutor.email
        return None
    
    def get_invited_by_name(self, obj):
        if obj.invited_by:
            return obj.invited_by.get_full_name() or obj.invited_by.email
        return None


class GroupTutorInviteSerializer(serializers.Serializer):
    """Serializer for inviting a co-tutor by email."""
    email = serializers.EmailField()
    role = serializers.ChoiceField(choices=GroupTutor.ROLE_CHOICES, default='monitor')


class GroupSafeZoneSerializer(serializers.ModelSerializer):
    """Serializer for safe zones shared by a group."""
    group_name = serializers.CharField(source='group.name', read_only=True)
    
    class Meta:
        model = GroupSafeZone
        fields = [
            'id',
            'group',
            'group_name',
            'name',
            'zone_type',
            'center_latitude',
            'center_longitude',
            'radius_meters',
            'polygon_points',
            'color',
            'is_active',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'group_name', 'created_at', 'updated_at']
    
    def validate(self, data):
        # For partial updates, only validate fields that are being updated
        is_update = self.instance is not None
        
        zone_type = data.get("zone_type", getattr(self.instance, 'zone_type', 'polygon') if is_update else "polygon")
        
        if zone_type == "circle":
            # Only validate circle fields if they're being set or it's a create
            if not is_update or "center_latitude" in data or "center_longitude" in data:
                center_lat = data.get("center_latitude", getattr(self.instance, 'center_latitude', None) if is_update else None)
                center_lng = data.get("center_longitude", getattr(self.instance, 'center_longitude', None) if is_update else None)
                if not center_lat or not center_lng:
                    raise serializers.ValidationError(
                        "Las zonas circulares requieren center_latitude y center_longitude."
                    )
        elif zone_type == "polygon":
            # Only validate polygon_points if they're being set or it's a create
            if "polygon_points" in data or not is_update:
                polygon_points = data.get("polygon_points", [])
                if len(polygon_points) < 3:
                    raise serializers.ValidationError(
                        "Los polígonos requieren al menos 3 puntos."
                    )
                for point in polygon_points:
                    if not isinstance(point, dict) or "lat" not in point or "lng" not in point:
                        raise serializers.ValidationError(
                            "Cada punto debe tener 'lat' y 'lng'."
                        )
        return data


class ChildGroupSerializer(serializers.ModelSerializer):
    """Main serializer for child groups."""
    owner_name = serializers.SerializerMethodField(read_only=True)
    members_count = serializers.IntegerField(read_only=True)
    tutors_count = serializers.IntegerField(read_only=True)
    
    class Meta:
        model = ChildGroup
        fields = [
            'id',
            'name',
            'description',
            'owner',
            'owner_name',
            'color',
            'icon',
            'is_active',
            'members_count',
            'tutors_count',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'owner', 'owner_name', 'members_count', 'tutors_count', 'created_at', 'updated_at']
    
    def get_owner_name(self, obj):
        """Get the owner's full name."""
        if obj.owner:
            return obj.owner.get_full_name() or obj.owner.email
        return None


class ChildGroupDetailSerializer(ChildGroupSerializer):
    """Detailed serializer with nested memberships, tutors and safe zones."""
    memberships = GroupMembershipSerializer(many=True, read_only=True)
    tutors = GroupTutorSerializer(many=True, read_only=True)
    safe_zones = GroupSafeZoneSerializer(many=True, read_only=True)
    
    class Meta(ChildGroupSerializer.Meta):
        fields = ChildGroupSerializer.Meta.fields + ['memberships', 'tutors', 'safe_zones']


class ChildWithLocationSerializer(serializers.ModelSerializer):
    """Serializer for child with current location (for group map view)."""
    device = DeviceSerializer(read_only=True)
    photo_url = serializers.SerializerMethodField(read_only=True)
    
    class Meta:
        model = Child
        fields = [
            'id',
            'full_name',
            'photo_url',
            'is_active',
            'device',
        ]
    
    def get_photo_url(self, obj):
        if obj.photo:
            photo_value = str(obj.photo)
            if photo_value.startswith('http://') or photo_value.startswith('https://'):
                return photo_value
        return None


# ============== Notification Serializers ==============

class NotificationSerializer(serializers.ModelSerializer):
    """Serializer for manual push notifications."""
    created_by_name = serializers.SerializerMethodField(read_only=True)
    specific_user_email = serializers.SerializerMethodField(read_only=True)
    recipient_type_display = serializers.CharField(source='get_recipient_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
    class Meta:
        model = Notification
        fields = [
            'id',
            'title',
            'message',
            'recipient_type',
            'recipient_type_display',
            'specific_user',
            'specific_user_email',
            'status',
            'status_display',
            'sent_count',
            'failed_count',
            'created_by',
            'created_by_name',
            'sent_at',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id', 
            'status', 
            'sent_count', 
            'failed_count', 
            'created_by', 
            'created_by_name',
            'sent_at', 
            'created_at', 
            'updated_at',
            'recipient_type_display',
            'status_display',
            'specific_user_email',
        ]
    
    def get_created_by_name(self, obj):
        if not obj.created_by:
            return None
        return obj.created_by.get_full_name() or obj.created_by.email

    def get_specific_user_email(self, obj):
        return obj.specific_user.email if obj.specific_user else None

    def validate(self, data):
        recipient_type = data.get('recipient_type', 'all')
        specific_user = data.get('specific_user')
        
        if recipient_type == 'specific' and not specific_user:
            raise serializers.ValidationError({
                'specific_user': 'Debe seleccionar un usuario cuando el tipo de destinatario es "Usuario específico".'
            })
        
        return data
