from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

app_name = 'accounts'

router = DefaultRouter()
router.register(r'users', views.UserViewSet, basename='users')

urlpatterns = [
    path('register/', views.register_view, name='register'),
    path('login/', views.login_view, name='login'),
    path('logout/', views.logout_view, name='logout'),
    path('profile/', views.profile_view, name='profile'),
    path('password-reset/', views.password_reset_request_view, name='password_reset'),
    path('change-password/', views.change_password_view, name='change_password'),
    path('fcm-token/', views.register_fcm_token_view, name='fcm_token'),
    path('make-admin/', views.make_admin_view, name='make_admin'),
    path('', include(router.urls)),
]
