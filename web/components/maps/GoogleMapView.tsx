"use client";

import { GoogleMap, Polygon, Circle, Marker, InfoWindow } from "@react-google-maps/api";
import { useCallback, useState, useMemo } from "react";

export interface MapPoint {
  lat: number;
  lng: number;
}

export interface MapMarker {
  id: number | string;
  position: MapPoint;
  label?: string;
  icon?: "child" | "alert" | "device" | "default";
  color?: string;
  popup?: string;
}

export interface MapPolygonData {
  id: number | string;
  points: MapPoint[];
  color?: string;
  fillColor?: string;
  fillOpacity?: number;
  label?: string;
}

export interface MapCircleData {
  id: number | string;
  center: MapPoint;
  radius: number;
  color?: string;
  fillColor?: string;
  fillOpacity?: number;
  label?: string;
}

export interface GoogleMapViewProps {
  center?: MapPoint;
  zoom?: number;
  height?: string;
  markers?: MapMarker[];
  polygons?: MapPolygonData[];
  circles?: MapCircleData[];
  onClick?: (point: MapPoint) => void;
  onPolygonClick?: (id: number | string) => void;
  className?: string;
  mapTypeId?: "roadmap" | "satellite" | "hybrid" | "terrain";
}

const defaultCenter: MapPoint = { lat: -17.7833, lng: -63.1821 }; // Santa Cruz, Bolivia

const mapContainerStyle = {
  width: "100%",
  height: "100%",
};

// Custom marker icons as SVG data URLs - returns a simple object that Google Maps can use
const getMarkerIconUrl = (type: string, color: string = "#1E8E3E"): string => {
  const icons: Record<string, string> = {
    child: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="${color}" width="32" height="32"><circle cx="12" cy="8" r="4"/><path d="M12 14c-4 0-8 2-8 4v2h16v-2c0-2-4-4-8-4z"/></svg>`,
    alert: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#D93025" width="32" height="32"><path d="M12 2L1 21h22L12 2zm0 3.5L19.5 19h-15L12 5.5zM11 10v4h2v-4h-2zm0 6v2h2v-2h-2z"/></svg>`,
    device: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="${color}" width="32" height="32"><rect x="7" y="2" width="10" height="20" rx="2"/><circle cx="12" cy="18" r="1" fill="white"/></svg>`,
    default: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="${color}" width="32" height="32"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/></svg>`,
  };

  const svg = icons[type] || icons.default;
  return `data:image/svg+xml,${encodeURIComponent(svg)}`;
};

export default function GoogleMapView({
  center = defaultCenter,
  zoom = 15,
  height = "400px",
  markers = [],
  polygons = [],
  circles = [],
  onClick,
  onPolygonClick,
  className = "",
  mapTypeId = "roadmap",
}: GoogleMapViewProps) {
  const [selectedMarker, setSelectedMarker] = useState<MapMarker | null>(null);

  const handleMapClick = useCallback(
    (e: google.maps.MapMouseEvent) => {
      if (onClick && e.latLng) {
        onClick({ lat: e.latLng.lat(), lng: e.latLng.lng() });
      }
      setSelectedMarker(null);
    },
    [onClick]
  );

  // Ensure center has valid coordinates
  const safeCenter = useMemo(() => {
    if (center && typeof center.lat === 'number' && typeof center.lng === 'number') {
      return center;
    }
    return defaultCenter;
  }, [center]);

  // Build map options inside the component where google is available
  const mapOptions = useMemo(() => ({
    disableDefaultUI: false,
    zoomControl: true,
    mapTypeControl: true,
    scaleControl: true,
    streetViewControl: false,
    rotateControl: false,
    fullscreenControl: true,
    styles: [
      {
        featureType: "poi" as const,
        elementType: "labels" as const,
        stylers: [{ visibility: "off" as const }],
      },
    ],
    mapTypeId,
  }), [mapTypeId]);

  // Build marker icon inside component where google.maps is available
  const getMarkerIcon = useCallback((type: string, color: string = "#1E8E3E") => {
    const url = getMarkerIconUrl(type, color);
    if (typeof google !== "undefined" && google.maps) {
      return {
        url,
        scaledSize: new google.maps.Size(32, 32),
        anchor: new google.maps.Point(16, 32),
      };
    }
    return url;
  }, []);

  return (
    <div className={`relative rounded-xl overflow-hidden ${className}`} style={{ height }}>
      <GoogleMap
        mapContainerStyle={mapContainerStyle}
        center={safeCenter}
        zoom={zoom}
        onClick={handleMapClick}
        options={mapOptions}
      >
        {/* Render polygons */}
        {polygons.map((polygon) => (
          <Polygon
            key={polygon.id}
            paths={polygon.points}
            options={{
              strokeColor: polygon.color || "#1E8E3E",
              strokeOpacity: 0.8,
              strokeWeight: 2,
              fillColor: polygon.fillColor || polygon.color || "#1E8E3E",
              fillOpacity: polygon.fillOpacity ?? 0.3,
              clickable: !!onPolygonClick,
            }}
            onClick={() => onPolygonClick?.(polygon.id)}
          />
        ))}

        {/* Render circles */}
        {circles.map((circle) => (
          <Circle
            key={circle.id}
            center={circle.center}
            radius={circle.radius}
            options={{
              strokeColor: circle.color || "#1E8E3E",
              strokeOpacity: 0.8,
              strokeWeight: 2,
              fillColor: circle.fillColor || circle.color || "#1E8E3E",
              fillOpacity: circle.fillOpacity ?? 0.3,
            }}
          />
        ))}

        {/* Render markers */}
        {markers.map((marker) => (
          <Marker
            key={marker.id}
            position={marker.position}
            icon={getMarkerIcon(marker.icon || "default", marker.color)}
            title={marker.label}
            onClick={() => setSelectedMarker(marker)}
          />
        ))}

        {/* Info window for selected marker */}
        {selectedMarker && (
          <InfoWindow
            position={selectedMarker.position}
            onCloseClick={() => setSelectedMarker(null)}
          >
            <div 
              className="p-2 min-w-[150px]"
              dangerouslySetInnerHTML={{ __html: selectedMarker.popup || `<strong>${selectedMarker.label}</strong>` }}
            />
          </InfoWindow>
        )}
      </GoogleMap>
    </div>
  );
}
