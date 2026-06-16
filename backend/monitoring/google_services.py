"""
Google Cloud Services for GeoGuard.
Provides Geocoding, Roads API, and Places API integration.
"""
import os
import logging
import httpx
from typing import Optional, Tuple, List, Dict, Any
from functools import lru_cache
from django.conf import settings
import environ
from pathlib import Path

logger = logging.getLogger(__name__)

# Load .env file to ensure API key is available
# This is needed because this module may be imported before Django settings fully loads
_env_file = Path(__file__).resolve().parent.parent / ".env"
if _env_file.exists():
    environ.Env.read_env(str(_env_file))

# Get API key from environment (now .env is loaded)
GOOGLE_MAPS_API_KEY = os.getenv('GOOGLE_MAPS_API_KEY', '')
logger.info(f"Google Maps API key loaded: {'Yes' if GOOGLE_MAPS_API_KEY else 'No'} (length: {len(GOOGLE_MAPS_API_KEY)})")


class GoogleGeocodingService:
    """
    Service for reverse geocoding coordinates to human-readable addresses.
    """
    BASE_URL = "https://maps.googleapis.com/maps/api/geocode/json"
    
    def __init__(self):
        self.api_key = GOOGLE_MAPS_API_KEY
        self._cache: Dict[str, str] = {}
    
    async def reverse_geocode(
        self, 
        latitude: float, 
        longitude: float,
        language: str = 'es'
    ) -> Optional[str]:
        """
        Convert coordinates to a human-readable address.
        
        Args:
            latitude: Latitude coordinate
            longitude: Longitude coordinate
            language: Language for results (default: Spanish)
            
        Returns:
            Formatted address string or None if failed
        """
        if not self.api_key:
            logger.warning("Google Maps API key not configured")
            return None
        
        # Check cache first (round to 4 decimals ~11m precision)
        cache_key = f"{round(latitude, 4)},{round(longitude, 4)}"
        if cache_key in self._cache:
            return self._cache[cache_key]
        
        try:
            params = {
                'latlng': f"{latitude},{longitude}",
                'key': self.api_key,
                'language': language,
                'result_type': 'street_address|route|neighborhood|locality'
            }
            
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(self.BASE_URL, params=params)
                data = response.json()
            
            if data.get('status') == 'OK' and data.get('results'):
                # Get the most specific address
                address = data['results'][0].get('formatted_address', '')
                
                # Cache the result
                self._cache[cache_key] = address
                
                # Keep cache size manageable
                if len(self._cache) > 1000:
                    # Remove oldest entries
                    keys = list(self._cache.keys())[:500]
                    for k in keys:
                        del self._cache[k]
                
                return address
            
            logger.warning(f"Geocoding failed: {data.get('status')}")
            return None
            
        except Exception as e:
            logger.error(f"Geocoding error: {e}")
            return None
    
    def reverse_geocode_sync(
        self, 
        latitude: float, 
        longitude: float,
        language: str = 'es'
    ) -> Optional[str]:
        """Synchronous version of reverse_geocode."""
        logger.info(f"reverse_geocode_sync called: {latitude}, {longitude}")
        
        if not self.api_key:
            logger.warning("No API key configured!")
            return None
        
        logger.info(f"Using API key: {self.api_key[:10]}...")
        
        cache_key = f"{round(latitude, 4)},{round(longitude, 4)}"
        if cache_key in self._cache:
            logger.info(f"Cache hit: {cache_key}")
            return self._cache[cache_key]
        
        try:
            params = {
                'latlng': f"{latitude},{longitude}",
                'key': self.api_key,
                'language': language,
            }
            
            logger.info(f"Calling Google Geocoding API...")
            
            with httpx.Client(timeout=10.0) as client:
                response = client.get(self.BASE_URL, params=params)
                data = response.json()
            
            logger.info(f"Google API status: {data.get('status')}")
            
            if data.get('status') == 'OK' and data.get('results'):
                address = data['results'][0].get('formatted_address', '')
                logger.info(f"Got address: {address}")
                self._cache[cache_key] = address
                return address
            
            logger.warning(f"No results. Status: {data.get('status')}, Error: {data.get('error_message', 'N/A')}")
            return None
            
        except Exception as e:
            logger.error(f"Geocoding sync error: {e}")
            return None


class GoogleRoadsService:
    """
    Service for snapping GPS coordinates to roads.
    Makes the tracking path smoother and more accurate.
    """
    BASE_URL = "https://roads.googleapis.com/v1/snapToRoads"
    
    def __init__(self):
        self.api_key = GOOGLE_MAPS_API_KEY
    
    async def snap_to_road(
        self, 
        points: List[Tuple[float, float]],
        interpolate: bool = True
    ) -> List[Dict[str, float]]:
        """
        Snap a list of GPS points to the nearest road.
        
        Args:
            points: List of (latitude, longitude) tuples
            interpolate: Whether to interpolate points along the road
            
        Returns:
            List of snapped points with lat/lng
        """
        if not self.api_key or not points:
            return [{'latitude': p[0], 'longitude': p[1]} for p in points]
        
        try:
            # Roads API accepts max 100 points
            points = points[:100]
            path = '|'.join([f"{lat},{lng}" for lat, lng in points])
            
            params = {
                'path': path,
                'key': self.api_key,
                'interpolate': str(interpolate).lower()
            }
            
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(self.BASE_URL, params=params)
                data = response.json()
            
            if 'snappedPoints' in data:
                return [
                    {
                        'latitude': p['location']['latitude'],
                        'longitude': p['location']['longitude']
                    }
                    for p in data['snappedPoints']
                ]
            
            # Return original points if snapping failed
            return [{'latitude': p[0], 'longitude': p[1]} for p in points]
            
        except Exception as e:
            logger.error(f"Roads API error: {e}")
            return [{'latitude': p[0], 'longitude': p[1]} for p in points]


class GooglePlacesService:
    """
    Service for finding nearby places/landmarks.
    Useful for alert messages like "Marco left school - near Parque Urbano"
    """
    BASE_URL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
    
    # Place types relevant for child safety
    RELEVANT_TYPES = [
        'school', 'park', 'hospital', 'police', 'church',
        'shopping_mall', 'bus_station', 'subway_station'
    ]
    
    def __init__(self):
        self.api_key = GOOGLE_MAPS_API_KEY
        self._cache: Dict[str, Dict] = {}
    
    async def find_nearby_landmark(
        self, 
        latitude: float, 
        longitude: float,
        radius: int = 200,
        language: str = 'es'
    ) -> Optional[Dict[str, Any]]:
        """
        Find the nearest relevant landmark to a location.
        
        Args:
            latitude: Latitude coordinate
            longitude: Longitude coordinate
            radius: Search radius in meters
            language: Language for results
            
        Returns:
            Dict with place name, type, and distance, or None
        """
        if not self.api_key:
            return None
        
        # Check cache
        cache_key = f"{round(latitude, 3)},{round(longitude, 3)}"
        if cache_key in self._cache:
            return self._cache[cache_key]
        
        try:
            params = {
                'location': f"{latitude},{longitude}",
                'radius': radius,
                'key': self.api_key,
                'language': language,
                'type': '|'.join(self.RELEVANT_TYPES)
            }
            
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(self.BASE_URL, params=params)
                data = response.json()
            
            if data.get('status') == 'OK' and data.get('results'):
                place = data['results'][0]
                result = {
                    'name': place.get('name'),
                    'type': place.get('types', ['unknown'])[0],
                    'vicinity': place.get('vicinity'),
                    'distance': self._calculate_distance(
                        latitude, longitude,
                        place['geometry']['location']['lat'],
                        place['geometry']['location']['lng']
                    )
                }
                
                self._cache[cache_key] = result
                return result
            
            return None
            
        except Exception as e:
            logger.error(f"Places API error: {e}")
            return None
    
    def _calculate_distance(
        self, 
        lat1: float, lon1: float, 
        lat2: float, lon2: float
    ) -> float:
        """Calculate distance between two points in meters."""
        from math import radians, sin, cos, sqrt, atan2
        
        R = 6371000  # Earth's radius in meters
        
        lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return R * c


# Singleton instances
_geocoding_service: Optional[GoogleGeocodingService] = None
_roads_service: Optional[GoogleRoadsService] = None
_places_service: Optional[GooglePlacesService] = None


def get_geocoding_service() -> GoogleGeocodingService:
    """Get singleton geocoding service instance."""
    global _geocoding_service
    if _geocoding_service is None:
        _geocoding_service = GoogleGeocodingService()
    return _geocoding_service


def get_roads_service() -> GoogleRoadsService:
    """Get singleton roads service instance."""
    global _roads_service
    if _roads_service is None:
        _roads_service = GoogleRoadsService()
    return _roads_service


def get_places_service() -> GooglePlacesService:
    """Get singleton places service instance."""
    global _places_service
    if _places_service is None:
        _places_service = GooglePlacesService()
    return _places_service
