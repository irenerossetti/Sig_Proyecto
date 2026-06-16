"""
Comprehensive tests for the monitoring module.
Includes tests for geofencing, alerts, and API endpoints.
"""
import json
from decimal import Decimal
from datetime import timedelta

from django.test import TestCase
from django.contrib.auth import get_user_model
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APITestCase, APIClient
from rest_framework import status
from rest_framework.authtoken.models import Token

from monitoring.models import (
    Child, Device, SafeZone, Alert, 
    ChildGroup, GroupMembership, GroupTutor, GroupSafeZone
)
from monitoring.models_history import LocationHistory


User = get_user_model()


def create_test_user(email, password='testpass123', **extra_fields):
    """Helper to create a test user with email as username (matches login behavior)."""
    return User.objects.create_user(
        username=email,  # Use email as username since login_view authenticates with email
        email=email,
        password=password,
        **extra_fields
    )


class SafeZoneGeofencingTests(TestCase):
    """Tests for SafeZone geofencing logic."""
    
    def setUp(self):
        """Set up test data."""
        self.user = create_test_user(
            email='tutor@test.com',
            first_name='Test',
            last_name='Tutor'
        )
        self.child = Child.objects.create(
            tutor=self.user,
            full_name='Test Child',
            date_of_birth='2020-01-01'
        )
    
    def test_polygon_contains_point_inside(self):
        """Test that a point inside a polygon is correctly detected."""
        # Create a square polygon around Santa Cruz city center
        # Approximate coordinates: -17.7833, -63.1822
        zone = SafeZone.objects.create(
            child=self.child,
            name='Test Zone',
            zone_type='polygon',
            polygon_points=[
                {'lat': -17.78, 'lng': -63.19},
                {'lat': -17.78, 'lng': -63.17},
                {'lat': -17.79, 'lng': -63.17},
                {'lat': -17.79, 'lng': -63.19},
            ]
        )
        
        # Point inside the polygon
        self.assertTrue(zone.contains_point(-17.785, -63.18))
    
    def test_polygon_contains_point_outside(self):
        """Test that a point outside a polygon is correctly detected."""
        zone = SafeZone.objects.create(
            child=self.child,
            name='Test Zone',
            zone_type='polygon',
            polygon_points=[
                {'lat': -17.78, 'lng': -63.19},
                {'lat': -17.78, 'lng': -63.17},
                {'lat': -17.79, 'lng': -63.17},
                {'lat': -17.79, 'lng': -63.19},
            ]
        )
        
        # Point outside the polygon
        self.assertFalse(zone.contains_point(-17.75, -63.18))
    
    def test_circle_contains_point_inside(self):
        """Test that a point inside a circle is correctly detected."""
        zone = SafeZone.objects.create(
            child=self.child,
            name='School Zone',
            zone_type='circle',
            center_latitude=Decimal('-17.7833'),
            center_longitude=Decimal('-63.1822'),
            radius_meters=100
        )
        
        # Point very close to center (within 100m)
        self.assertTrue(zone.contains_point(-17.7833, -63.1822))
        self.assertTrue(zone.contains_point(-17.7834, -63.1823))
    
    def test_circle_contains_point_outside(self):
        """Test that a point outside a circle is correctly detected."""
        zone = SafeZone.objects.create(
            child=self.child,
            name='School Zone',
            zone_type='circle',
            center_latitude=Decimal('-17.7833'),
            center_longitude=Decimal('-63.1822'),
            radius_meters=100
        )
        
        # Point far from center (> 100m)
        self.assertFalse(zone.contains_point(-17.79, -63.19))
    
    def test_is_point_in_any_zone_true(self):
        """Test checking if point is in any zone when it is."""
        SafeZone.objects.create(
            child=self.child,
            name='Zone 1',
            zone_type='circle',
            center_latitude=Decimal('-17.7833'),
            center_longitude=Decimal('-63.1822'),
            radius_meters=100
        )
        SafeZone.objects.create(
            child=self.child,
            name='Zone 2',
            zone_type='circle',
            center_latitude=Decimal('-17.80'),
            center_longitude=Decimal('-63.20'),
            radius_meters=100
        )
        
        # Point in Zone 1
        self.assertTrue(SafeZone.is_point_in_any_zone(self.child.id, -17.7833, -63.1822))
    
    def test_is_point_in_any_zone_false(self):
        """Test checking if point is in any zone when it's not."""
        SafeZone.objects.create(
            child=self.child,
            name='Zone 1',
            zone_type='circle',
            center_latitude=Decimal('-17.7833'),
            center_longitude=Decimal('-63.1822'),
            radius_meters=100
        )
        
        # Point far from any zone
        self.assertFalse(SafeZone.is_point_in_any_zone(self.child.id, -17.90, -63.30))
    
    def test_get_zones_containing_point(self):
        """Test getting all zones that contain a point."""
        zone1 = SafeZone.objects.create(
            child=self.child,
            name='Large Zone',
            zone_type='circle',
            center_latitude=Decimal('-17.7833'),
            center_longitude=Decimal('-63.1822'),
            radius_meters=500
        )
        zone2 = SafeZone.objects.create(
            child=self.child,
            name='Small Zone',
            zone_type='circle',
            center_latitude=Decimal('-17.7833'),
            center_longitude=Decimal('-63.1822'),
            radius_meters=100
        )
        
        zones = SafeZone.get_zones_containing_point(self.child.id, -17.7833, -63.1822)
        self.assertEqual(len(zones), 2)
    
    def test_inactive_zone_ignored(self):
        """Test that inactive zones are not considered."""
        SafeZone.objects.create(
            child=self.child,
            name='Inactive Zone',
            zone_type='circle',
            center_latitude=Decimal('-17.7833'),
            center_longitude=Decimal('-63.1822'),
            radius_meters=100,
            is_active=False
        )
        
        self.assertFalse(SafeZone.is_point_in_any_zone(self.child.id, -17.7833, -63.1822))


class DeviceModelTests(TestCase):
    """Tests for Device model."""
    
    def setUp(self):
        self.user = create_test_user(
            email='tutor@test.com',
            first_name='Test',
            last_name='Tutor'
        )
        self.child = Child.objects.create(
            tutor=self.user,
            full_name='Test Child',
            date_of_birth='2020-01-01'
        )
        self.device = Device.objects.create(
            child=self.child,
            device_id='TEST-DEVICE-001',
            device_type='smartphone'
        )
    
    def test_update_location(self):
        """Test updating device location."""
        self.device.update_location(-17.7833, -63.1822)
        self.device.refresh_from_db()
        
        self.assertEqual(float(self.device.last_latitude), -17.7833)
        self.assertEqual(float(self.device.last_longitude), -63.1822)
    
    def test_is_online_recent(self):
        """Test device is online when last_seen is recent."""
        self.device.last_seen = timezone.now()
        self.device.save()
        
        # Check serializer's is_online logic
        from monitoring.serializers import DeviceSerializer
        serializer = DeviceSerializer(self.device)
        self.assertTrue(serializer.data.get('is_online', False))
    
    def test_is_online_stale(self):
        """Test device is offline when last_seen is old."""
        self.device.last_seen = timezone.now() - timedelta(minutes=10)
        self.device.save()
        
        from monitoring.serializers import DeviceSerializer
        serializer = DeviceSerializer(self.device)
        self.assertFalse(serializer.data.get('is_online', True))


class LocationHistoryTests(TestCase):
    """Tests for LocationHistory model."""
    
    def setUp(self):
        self.user = create_test_user(
            email='tutor@test.com',
            first_name='Test',
            last_name='Tutor'
        )
        self.child = Child.objects.create(
            tutor=self.user,
            full_name='Test Child',
            date_of_birth='2020-01-01'
        )
        self.device = Device.objects.create(
            child=self.child,
            device_id='TEST-DEVICE-001',
            device_type='smartphone'
        )
    
    def test_record_location(self):
        """Test recording a new location."""
        history = LocationHistory.record_location(
            device=self.device,
            latitude=-17.7833,
            longitude=-63.1822,
            battery_level=85,
            is_in_safe_zone=True
        )
        
        self.assertEqual(float(history.latitude), -17.7833)
        self.assertEqual(float(history.longitude), -63.1822)
        self.assertEqual(history.battery_level, 85)
        self.assertEqual(history.child, self.child)
    
    def test_get_child_history(self):
        """Test retrieving location history for a child."""
        # Create multiple history entries
        for i in range(5):
            LocationHistory.record_location(
                device=self.device,
                latitude=-17.7833 + (i * 0.001),
                longitude=-63.1822,
                battery_level=100 - i
            )
        
        history = LocationHistory.get_child_history(self.child.id)
        self.assertEqual(len(history), 5)


class AlertAPITests(APITestCase):
    """Tests for Alert API endpoints."""
    
    def setUp(self):
        self.user = create_test_user(
            email='tutor@test.com',
            first_name='Test',
            last_name='Tutor'
        )
        self.token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')
        
        self.child = Child.objects.create(
            tutor=self.user,
            full_name='Test Child',
            date_of_birth='2020-01-01'
        )
        self.zone = SafeZone.objects.create(
            child=self.child,
            name='School',
            zone_type='circle',
            center_latitude=Decimal('-17.7833'),
            center_longitude=Decimal('-63.1822'),
            radius_meters=100
        )
    
    def test_list_alerts(self):
        """Test listing alerts for authenticated user."""
        # Create an alert
        Alert.objects.create(
            child=self.child,
            safe_zone=self.zone,
            alert_type='zone_exit',
            latitude=Decimal('-17.79'),
            longitude=Decimal('-63.19'),
            message='Test alert'
        )
        
        response = self.client.get('/api/monitoring/alerts/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
    
    def test_acknowledge_alert(self):
        """Test acknowledging an alert."""
        alert = Alert.objects.create(
            child=self.child,
            safe_zone=self.zone,
            alert_type='zone_exit',
            status='pending',
            latitude=Decimal('-17.79'),
            longitude=Decimal('-63.19'),
            message='Test alert'
        )
        
        response = self.client.post(f'/api/monitoring/alerts/{alert.id}/acknowledge/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        alert.refresh_from_db()
        self.assertEqual(alert.status, 'acknowledged')
        self.assertIsNotNone(alert.acknowledged_at)
    
    def test_resolve_alert(self):
        """Test resolving an alert."""
        alert = Alert.objects.create(
            child=self.child,
            safe_zone=self.zone,
            alert_type='zone_exit',
            status='acknowledged',
            latitude=Decimal('-17.79'),
            longitude=Decimal('-63.19'),
            message='Test alert'
        )
        
        response = self.client.post(f'/api/monitoring/alerts/{alert.id}/resolve/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        alert.refresh_from_db()
        self.assertEqual(alert.status, 'resolved')


class ChildAPITests(APITestCase):
    """Tests for Child API endpoints."""
    
    def setUp(self):
        self.user = create_test_user(
            email='tutor@test.com',
            first_name='Test',
            last_name='Tutor'
        )
        self.token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')
    
    def test_create_child(self):
        """Test creating a new child."""
        data = {
            'full_name': 'New Child',
            'date_of_birth': '2020-06-15',
            'notes': 'Test notes'
        }
        
        response = self.client.post('/api/monitoring/children/', data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Child.objects.count(), 1)
        self.assertEqual(Child.objects.first().tutor, self.user)
    
    def test_list_children_only_own(self):
        """Test that users only see their own children."""
        # Create child for this user
        Child.objects.create(
            tutor=self.user,
            full_name='My Child',
            date_of_birth='2020-01-01'
        )
        
        # Create child for another user
        other_user = create_test_user(
            email='other@test.com',
            first_name='Other',
            last_name='Tutor'
        )
        Child.objects.create(
            tutor=other_user,
            full_name='Other Child',
            date_of_birth='2020-01-01'
        )
        
        response = self.client.get('/api/monitoring/children/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['full_name'], 'My Child')


class SafeZoneAPITests(APITestCase):
    """Tests for SafeZone API endpoints."""
    
    def setUp(self):
        self.user = create_test_user(
            email='tutor@test.com',
            first_name='Test',
            last_name='Tutor'
        )
        self.token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')
        
        self.child = Child.objects.create(
            tutor=self.user,
            full_name='Test Child',
            date_of_birth='2020-01-01'
        )
    
    def test_create_polygon_zone(self):
        """Test creating a polygon safe zone."""
        data = {
            'child': self.child.id,
            'name': 'School Area',
            'zone_type': 'polygon',
            'polygon_points': [
                {'lat': -17.78, 'lng': -63.19},
                {'lat': -17.78, 'lng': -63.17},
                {'lat': -17.79, 'lng': -63.17},
                {'lat': -17.79, 'lng': -63.19},
            ],
            'color': '#FF5722'
        }
        
        response = self.client.post(
            '/api/monitoring/safe-zones/', 
            data, 
            format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(SafeZone.objects.count(), 1)
    
    def test_create_circle_zone(self):
        """Test creating a circle safe zone."""
        data = {
            'child': self.child.id,
            'name': 'Home',
            'zone_type': 'circle',
            'center_latitude': '-17.7833',
            'center_longitude': '-63.1822',
            'radius_meters': 150,
            'color': '#4CAF50'
        }
        
        response = self.client.post(
            '/api/monitoring/safe-zones/', 
            data, 
            format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)


class GroupTests(TestCase):
    """Tests for ChildGroup functionality."""
    
    def setUp(self):
        self.owner = create_test_user(
            email='owner@test.com',
            first_name='Group',
            last_name='Owner'
        )
        self.tutor = create_test_user(
            email='tutor@test.com',
            first_name='Group',
            last_name='Tutor'
        )
        self.child = Child.objects.create(
            tutor=self.owner,
            full_name='Test Child',
            date_of_birth='2020-01-01'
        )
    
    def test_create_group(self):
        """Test creating a child group."""
        group = ChildGroup.objects.create(
            name='Class 1A',
            description='First grade class A',
            owner=self.owner
        )
        
        self.assertEqual(group.members_count, 0)
        self.assertEqual(group.tutors_count, 1)  # Owner counts
    
    def test_add_member_to_group(self):
        """Test adding a child to a group."""
        group = ChildGroup.objects.create(
            name='Class 1A',
            owner=self.owner
        )
        
        membership = GroupMembership.objects.create(
            group=group,
            child=self.child,
            added_by=self.owner
        )
        
        self.assertEqual(group.members_count, 1)
    
    def test_add_tutor_to_group(self):
        """Test adding a co-tutor to a group."""
        group = ChildGroup.objects.create(
            name='Class 1A',
            owner=self.owner
        )
        
        GroupTutor.objects.create(
            group=group,
            tutor=self.tutor,
            role='monitor',
            invited_by=self.owner
        )
        
        self.assertEqual(group.tutors_count, 2)  # Owner + new tutor
    
    def test_group_safe_zone(self):
        """Test group safe zone applies to all members."""
        group = ChildGroup.objects.create(
            name='Class 1A',
            owner=self.owner
        )
        
        zone = GroupSafeZone.objects.create(
            group=group,
            name='School Campus',
            zone_type='polygon',
            polygon_points=[
                {'lat': -17.78, 'lng': -63.19},
                {'lat': -17.78, 'lng': -63.17},
                {'lat': -17.79, 'lng': -63.17},
                {'lat': -17.79, 'lng': -63.19},
            ]
        )
        
        # Point inside
        self.assertTrue(zone.contains_point(-17.785, -63.18))
        # Point outside
        self.assertFalse(zone.contains_point(-17.75, -63.18))


class AuthAPITests(APITestCase):
    """Tests for authentication endpoints."""
    
    def test_register_user(self):
        """Test user registration."""
        data = {
            'email': 'newuser@test.com',
            'password': 'securepass123',
            'full_name': 'New User',
            'phone': '+591 70000000'
        }
        
        response = self.client.post('/api/auth/register/', data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('token', response.data)
        self.assertIn('user', response.data)
    
    def test_login_user(self):
        """Test user login."""
        user = create_test_user(
            email='existing@test.com',
            first_name='Existing',
            last_name='User'
        )
        
        data = {
            'email': 'existing@test.com',
            'password': 'testpass123'
        }
        
        response = self.client.post('/api/auth/login/', data)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('token', response.data)
    
    def test_login_invalid_credentials(self):
        """Test login with invalid credentials."""
        create_test_user(
            email='existing@test.com',
            first_name='Existing',
            last_name='User'
        )
        
        data = {
            'email': 'existing@test.com',
            'password': 'wrongpassword'
        }
        
        response = self.client.post('/api/auth/login/', data)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
    
    def test_logout_user(self):
        """Test user logout."""
        user = create_test_user(
            email='existing@test.com',
            first_name='Existing',
            last_name='User'
        )
        token = Token.objects.create(user=user)
        
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {token.key}')
        response = self.client.post('/api/auth/logout/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Token should be deleted
        self.assertFalse(Token.objects.filter(user=user).exists())
