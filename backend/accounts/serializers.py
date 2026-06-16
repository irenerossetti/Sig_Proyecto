from django.contrib.auth import get_user_model
from rest_framework import serializers

User = get_user_model()


class UserRegistrationSerializer(serializers.ModelSerializer):
    """Serializer for user registration."""
    password = serializers.CharField(write_only=True, min_length=8)
    full_name = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = User
        fields = ['email', 'full_name', 'phone', 'password']

    def validate_email(self, value):
        """Ensure email is unique."""
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Este correo ya está registrado.")
        return value

    def create(self, validated_data):
        """Create a new user with encrypted password."""
        full_name = validated_data.pop('full_name')
        name_parts = full_name.strip().split(' ', 1)
        first_name = name_parts[0]
        last_name = name_parts[1] if len(name_parts) > 1 else ''

        user = User.objects.create_user(
            username=validated_data['email'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=first_name,
            last_name=last_name,
            phone=validated_data.get('phone', ''),
        )
        return user


class UserSerializer(serializers.ModelSerializer):
    """Serializer for user details."""
    full_name = serializers.SerializerMethodField()
    photo_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'email', 'full_name', 'phone', 'photo_url', 'date_joined']

    def get_full_name(self, obj):
        return obj.get_full_name() or obj.email

    def get_photo_url(self, obj):
        """Return absolute photo URL when available."""
        if obj.photo:
            photo_value = str(obj.photo)
            if photo_value.startswith('http://') or photo_value.startswith('https://'):
                return photo_value
            request = self.context.get('request') if hasattr(self, 'context') else None
            if request and hasattr(obj.photo, 'url'):
                return request.build_absolute_uri(obj.photo.url)
            if hasattr(obj.photo, 'url'):
                return obj.photo.url
        return None


class UserAdminSerializer(serializers.ModelSerializer):
    """Serializer for admin user management."""
    full_name = serializers.SerializerMethodField()
    children_count = serializers.SerializerMethodField()
    has_fcm_token = serializers.SerializerMethodField()
    photo_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'email', 'full_name', 'phone', 'photo_url', 'date_joined',
            'is_active', 'is_staff', 'is_superuser', 'children_count', 'has_fcm_token'
        ]
        read_only_fields = ['id', 'date_joined', 'children_count', 'has_fcm_token']

    def get_full_name(self, obj):
        return obj.get_full_name() or obj.email

    def get_children_count(self, obj):
        return obj.children.count() if hasattr(obj, 'children') else 0

    def get_has_fcm_token(self, obj):
        return bool(obj.fcm_token)

    def get_photo_url(self, obj):
        if obj.photo:
            photo_value = str(obj.photo)
            if photo_value.startswith('http://') or photo_value.startswith('https://'):
                return photo_value
            request = self.context.get('request') if hasattr(self, 'context') else None
            if request and hasattr(obj.photo, 'url'):
                return request.build_absolute_uri(obj.photo.url)
            if hasattr(obj.photo, 'url'):
                return obj.photo.url
        return None
