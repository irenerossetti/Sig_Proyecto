"""
Account views for authentication and user management.
"""
from django.contrib.auth import authenticate, login, logout, get_user_model
from rest_framework import status, viewsets
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework.response import Response
from rest_framework.authtoken.models import Token

from .serializers import UserRegistrationSerializer, UserSerializer, UserAdminSerializer
from monitoring.storage import upload_tutor_photo, delete_tutor_photo

User = get_user_model()


class UserViewSet(viewsets.ModelViewSet):
    """
    ViewSet para administración de usuarios (solo admins).
    """
    queryset = User.objects.all().order_by('-date_joined')
    serializer_class = UserAdminSerializer
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        queryset = super().get_queryset()
        
        # Filtros opcionales
        is_active = self.request.query_params.get('is_active')
        is_staff = self.request.query_params.get('is_staff')
        search = self.request.query_params.get('search')
        
        if is_active is not None:
            queryset = queryset.filter(is_active=is_active.lower() == 'true')
        if is_staff is not None:
            queryset = queryset.filter(is_staff=is_staff.lower() == 'true')
        if search:
            queryset = queryset.filter(
                email__icontains=search
            ) | queryset.filter(
                first_name__icontains=search
            ) | queryset.filter(
                last_name__icontains=search
            )
        
        return queryset

    @action(detail=True, methods=['post'])
    def toggle_active(self, request, pk=None):
        """Activar/desactivar un usuario."""
        user = self.get_object()
        user.is_active = not user.is_active
        user.save()
        return Response({
            'message': f'Usuario {"activado" if user.is_active else "desactivado"}.',
            'is_active': user.is_active
        })

    @action(detail=True, methods=['post'])
    def make_staff(self, request, pk=None):
        """Hacer o quitar staff a un usuario."""
        user = self.get_object()
        user.is_staff = not user.is_staff
        user.save()
        return Response({
            'message': f'Usuario {"ahora es staff" if user.is_staff else "ya no es staff"}.',
            'is_staff': user.is_staff
        })


@api_view(['POST'])
@permission_classes([AllowAny])
def register_view(request):
    """Register a new user and return authentication token."""
    serializer = UserRegistrationSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.save()
        token, _ = Token.objects.get_or_create(user=user)
        
        return Response({
            'token': token.key,
            'user': UserSerializer(user, context={'request': request}).data
        }, status=status.HTTP_201_CREATED)
    
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def login_view(request):
    """Authenticate user and return token."""
    email = request.data.get('email')
    password = request.data.get('password')

    if not email or not password:
        return Response(
            {'error': 'Se requiere correo y contraseña.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    # Buscar el username correspondiente al email ingresado para poder autenticar correctamente en Django
    try:
        user_obj = User.objects.get(email=email)
        username_to_auth = user_obj.username
    except User.DoesNotExist:
        username_to_auth = email

    user = authenticate(request, username=username_to_auth, password=password)
    
    if user is not None:
        login(request, user)
        token, _ = Token.objects.get_or_create(user=user)
        
        return Response({
            'token': token.key,
            'user': UserSerializer(user, context={'request': request}).data
        })
    
    return Response(
        {'error': 'Credenciales inválidas.'},
        status=status.HTTP_401_UNAUTHORIZED
    )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout_view(request):
    """Logout user and delete their token."""
    try:
        # Delete the user's token
        request.user.auth_token.delete()
    except Exception:
        pass
    
    logout(request)
    return Response({'message': 'Sesión cerrada exitosamente.'})


@api_view(['GET', 'PATCH'])
@permission_classes([IsAuthenticated])
def profile_view(request):
    """Get or update current user profile."""
    if request.method == 'GET':
        return Response(UserSerializer(request.user, context={'request': request}).data)
    
    # PATCH - Update profile
    user = request.user
    full_name = request.data.get('full_name')
    phone = request.data.get('phone')
    photo = request.FILES.get('photo')
    
    if full_name is not None:
        if len(full_name.strip()) < 2:
            return Response(
                {'error': 'El nombre debe tener al menos 2 caracteres.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        # Split full_name into first_name and last_name
        name_parts = full_name.strip().split(' ', 1)
        user.first_name = name_parts[0]
        user.last_name = name_parts[1] if len(name_parts) > 1 else ''
    
    if phone is not None:
        user.phone = phone.strip() if phone.strip() else None

    if photo is not None:
        if user.photo:
            try:
                delete_tutor_photo(str(user.photo))
            except Exception:
                pass
        uploaded_url = upload_tutor_photo(photo, user.id, photo.name)
        # Store URL string in photo field for consistency with child photos
        user.photo = uploaded_url
    
    user.save()
    return Response({
        'message': 'Perfil actualizado exitosamente.',
        'user': UserSerializer(user, context={'request': request}).data
    })


@api_view(['POST'])
@permission_classes([AllowAny])
def password_reset_request_view(request):
    """
    Request a password reset. 
    Checks if the email exists in the database.
    """
    email = request.data.get('email')
    if not email:
        return Response({'error': 'El correo es requerido.'}, status=status.HTTP_400_BAD_REQUEST)
    
    # Check if user exists
    from django.contrib.auth import get_user_model
    User = get_user_model()
    
    if not User.objects.filter(email=email).exists():
        return Response(
            {'error': 'No encontramos una cuenta asociada a este correo.'}, 
            status=status.HTTP_404_NOT_FOUND
        )
        
    # Simulate sending email
    return Response({'message': 'Se han enviado las instrucciones a tu correo.'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def change_password_view(request):
    """
    Change the current user's password.
    Requires current password and new password.
    """
    current_password = request.data.get('current_password')
    new_password = request.data.get('new_password')
    
    if not current_password or not new_password:
        return Response(
            {'error': 'Se requiere la contraseña actual y la nueva.'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    if len(new_password) < 8:
        return Response(
            {'error': 'La nueva contraseña debe tener al menos 8 caracteres.'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    user = request.user
    
    if not user.check_password(current_password):
        return Response(
            {'error': 'La contraseña actual es incorrecta.'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    user.set_password(new_password)
    user.save()
    
    # Update the session to prevent logout
    from django.contrib.auth import update_session_auth_hash
    update_session_auth_hash(request, user)
    
    return Response({'message': 'Contraseña actualizada exitosamente.'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def register_fcm_token_view(request):
    """
    Registra el token FCM del dispositivo para recibir notificaciones push.
    """
    fcm_token = request.data.get('fcm_token')
    
    if not fcm_token:
        return Response(
            {'error': 'fcm_token es requerido.'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    user = request.user
    user.fcm_token = fcm_token
    user.save(update_fields=['fcm_token'])
    
    return Response({'message': 'Token FCM registrado exitosamente.'})


@api_view(['POST'])
@permission_classes([AllowAny])
def make_admin_view(request):
    """
    Promover un usuario a administrador usando una clave secreta.
    SOLO para configuración inicial cuando no hay acceso a la DB.
    
    POST /api/auth/make-admin/
    {
        "email": "user@example.com",
        "secret_key": "GEOGUARD_ADMIN_SECRET"
    }
    """
    import os
    from django.conf import settings
    
    email = request.data.get('email')
    secret_key = request.data.get('secret_key')
    
    if not email or not secret_key:
        return Response(
            {'error': 'email y secret_key son requeridos.'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Verificar clave secreta desde variable de entorno
    # En producción DEBE estar configurada en las variables de entorno
    admin_secret = os.environ.get('GEOGUARD_ADMIN_SECRET')
    
    if not admin_secret:
        # Solo permitir default en modo DEBUG
        if settings.DEBUG:
            admin_secret = 'GeoGuard2024AdminSetup!'
        else:
            return Response(
                {'error': 'GEOGUARD_ADMIN_SECRET no está configurada en producción.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    if secret_key != admin_secret:
        return Response(
            {'error': 'Clave secreta inválida.'},
            status=status.HTTP_403_FORBIDDEN
        )
    
    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return Response(
            {'error': 'Usuario no encontrado.'},
            status=status.HTTP_404_NOT_FOUND
        )
    
    # Promover a admin
    user.is_staff = True
    user.is_superuser = True
    user.save()
    
    return Response({
        'message': f'Usuario {email} promovido a administrador exitosamente.',
        'user': {
            'id': user.id,
            'email': user.email,
            'is_staff': user.is_staff,
            'is_superuser': user.is_superuser,
        }
    })
