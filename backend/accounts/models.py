from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    """Extended user model for GeoGuard tutors and staff."""
    phone = models.CharField(max_length=20, blank=True)
    # Token FCM para notificaciones push
    fcm_token = models.TextField(blank=True, null=True)
    photo = models.ImageField(upload_to='tutors/photos/', blank=True, null=True)
    
    class Meta:
        db_table = 'auth_user'
        verbose_name = 'Usuario'
        verbose_name_plural = 'Usuarios'

    def __str__(self):
        return self.get_full_name() or self.email

