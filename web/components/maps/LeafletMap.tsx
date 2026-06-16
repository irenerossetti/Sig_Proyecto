"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import type { MapContainerProps, MapPoint } from "./MapContainer";

// Fix Leaflet default icon issue
const DefaultIcon = L.icon({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});

// Custom icons
const createCustomIcon = (type: string, color?: string) => {
  const iconColor = color || "#1E8E3E";
  const iconSvg = {
    child: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="${iconColor}" width="32" height="32"><circle cx="12" cy="8" r="4" fill="${iconColor}"/><path d="M12 14c-4 0-8 2-8 4v2h16v-2c0-2-4-4-8-4z" fill="${iconColor}"/></svg>`,
    alert: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#D93025" width="32" height="32"><path d="M12 2L1 21h22L12 2zm0 3.5L19.5 19h-15L12 5.5zM11 10v4h2v-4h-2zm0 6v2h2v-2h-2z"/></svg>`,
    device: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="${iconColor}" width="32" height="32"><rect x="7" y="2" width="10" height="20" rx="2" fill="${iconColor}"/><circle cx="12" cy="18" r="1" fill="white"/></svg>`,
    default: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="${iconColor}" width="32" height="32"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/></svg>`,
  };
  
  const svg = iconSvg[type as keyof typeof iconSvg] || iconSvg.default;
  
  return L.divIcon({
    html: svg,
    className: "custom-marker-icon",
    iconSize: [32, 32],
    iconAnchor: [16, 32],
    popupAnchor: [0, -32],
  });
};

L.Marker.prototype.options.icon = DefaultIcon;

export default function LeafletMap({
  center = { lat: -17.7833, lng: -63.1821 }, // Santa Cruz, Bolivia
  zoom = 13,
  height = "400px",
  markers = [],
  polygons = [],
  circles = [],
  drawingMode,
  onPolygonComplete,
  onCircleComplete,
  onMarkerPlace,
  onPolygonEdit,
  onClick,
  className = "",
  showControls = true,
}: MapContainerProps) {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<L.Map | null>(null);
  const markersLayerRef = useRef<L.LayerGroup | null>(null);
  const polygonsLayerRef = useRef<L.LayerGroup | null>(null);
  const circlesLayerRef = useRef<L.LayerGroup | null>(null);
  const drawingLayerRef = useRef<L.LayerGroup | null>(null);
  
  const [isDrawing, setIsDrawing] = useState(false);
  const [drawingPoints, setDrawingPoints] = useState<MapPoint[]>([]);
  const [tempCircle, setTempCircle] = useState<{ center: MapPoint; radius: number } | null>(null);

  // Initialize map
  useEffect(() => {
    if (!mapRef.current || mapInstanceRef.current) return;

    const map = L.map(mapRef.current, {
      center: [center.lat, center.lng],
      zoom,
      zoomControl: showControls,
    });

    // Add tile layer (OpenStreetMap)
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      maxZoom: 19,
    }).addTo(map);

    // Create layer groups
    markersLayerRef.current = L.layerGroup().addTo(map);
    polygonsLayerRef.current = L.layerGroup().addTo(map);
    circlesLayerRef.current = L.layerGroup().addTo(map);
    drawingLayerRef.current = L.layerGroup().addTo(map);

    mapInstanceRef.current = map;

    return () => {
      map.remove();
      mapInstanceRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Update center and zoom
  useEffect(() => {
    if (mapInstanceRef.current) {
      mapInstanceRef.current.setView([center.lat, center.lng], zoom);
    }
  }, [center.lat, center.lng, zoom]);

  // Handle markers
  useEffect(() => {
    if (!markersLayerRef.current) return;
    
    markersLayerRef.current.clearLayers();

    markers.forEach((marker) => {
      const icon = marker.icon ? createCustomIcon(marker.icon, marker.color) : DefaultIcon;
      const leafletMarker = L.marker([marker.position.lat, marker.position.lng], { icon });
      
      if (marker.popup) {
        leafletMarker.bindPopup(marker.popup);
      }
      
      if (marker.label) {
        leafletMarker.bindTooltip(marker.label, { permanent: false, direction: "top" });
      }
      
      leafletMarker.addTo(markersLayerRef.current!);
    });
  }, [markers]);

  // Handle polygons
  useEffect(() => {
    if (!polygonsLayerRef.current) return;
    
    polygonsLayerRef.current.clearLayers();

    polygons.forEach((polygon) => {
      const latLngs = polygon.points.map((p) => [p.lat, p.lng] as L.LatLngTuple);
      const leafletPolygon = L.polygon(latLngs, {
        color: polygon.color || "#1E8E3E",
        fillColor: polygon.fillColor || polygon.color || "#1E8E3E",
        fillOpacity: polygon.fillOpacity ?? 0.3,
        weight: 2,
      });

      if (polygon.label) {
        leafletPolygon.bindTooltip(polygon.label, { permanent: false, direction: "center" });
      }

      if (polygon.editable && onPolygonEdit) {
        leafletPolygon.on("click", () => {
          // Enable editing (simplified - in production use Leaflet.draw or similar)
          const newPoints = polygon.points.map((p) => ({ ...p }));
          onPolygonEdit(polygon.id, newPoints);
        });
      }

      leafletPolygon.addTo(polygonsLayerRef.current!);
    });
  }, [polygons, onPolygonEdit]);

  // Handle circles
  useEffect(() => {
    if (!circlesLayerRef.current) return;
    
    circlesLayerRef.current.clearLayers();

    circles.forEach((circle) => {
      const leafletCircle = L.circle([circle.center.lat, circle.center.lng], {
        radius: circle.radius,
        color: circle.color || "#1E8E3E",
        fillColor: circle.fillColor || circle.color || "#1E8E3E",
        fillOpacity: circle.fillOpacity ?? 0.3,
        weight: 2,
      });

      if (circle.label) {
        leafletCircle.bindTooltip(circle.label, { permanent: false, direction: "center" });
      }

      leafletCircle.addTo(circlesLayerRef.current!);
    });
  }, [circles]);

  // Handle drawing mode
  const handleMapClick = useCallback((e: L.LeafletMouseEvent) => {
    const point = { lat: e.latlng.lat, lng: e.latlng.lng };

    if (onClick) {
      onClick(point);
    }

    if (!drawingMode) return;

    if (drawingMode === "marker" && onMarkerPlace) {
      onMarkerPlace(point);
      return;
    }

    if (drawingMode === "polygon") {
      const newPoints = [...drawingPoints, point];
      setDrawingPoints(newPoints);
      setIsDrawing(true);

      // Draw temporary polygon
      if (drawingLayerRef.current) {
        drawingLayerRef.current.clearLayers();
        if (newPoints.length > 1) {
          const latLngs = newPoints.map((p) => [p.lat, p.lng] as L.LatLngTuple);
          L.polyline(latLngs, { color: "#1E8E3E", dashArray: "5, 5" }).addTo(drawingLayerRef.current);
        }
        newPoints.forEach((p) => {
          L.circleMarker([p.lat, p.lng], { radius: 5, color: "#1E8E3E", fillColor: "#1E8E3E", fillOpacity: 1 }).addTo(drawingLayerRef.current!);
        });
      }
    }

    if (drawingMode === "circle") {
      if (!tempCircle) {
        setTempCircle({ center: point, radius: 100 });
        setIsDrawing(true);
      } else {
        // Calculate radius from distance
        const centerLatLng = L.latLng(tempCircle.center.lat, tempCircle.center.lng);
        const clickLatLng = L.latLng(point.lat, point.lng);
        const radius = centerLatLng.distanceTo(clickLatLng);
        
        if (onCircleComplete) {
          onCircleComplete(tempCircle.center, radius);
        }
        
        setTempCircle(null);
        setIsDrawing(false);
        if (drawingLayerRef.current) {
          drawingLayerRef.current.clearLayers();
        }
      }
    }
  }, [drawingMode, drawingPoints, tempCircle, onClick, onMarkerPlace, onCircleComplete]);

  // Handle double click to complete polygon
  const handleMapDblClick = useCallback(() => {
    if (drawingMode === "polygon" && drawingPoints.length >= 3 && onPolygonComplete) {
      onPolygonComplete(drawingPoints);
      setDrawingPoints([]);
      setIsDrawing(false);
      if (drawingLayerRef.current) {
        drawingLayerRef.current.clearLayers();
      }
    }
  }, [drawingMode, drawingPoints, onPolygonComplete]);

  // Handle mouse move for circle drawing
  const handleMapMouseMove = useCallback((e: L.LeafletMouseEvent) => {
    if (drawingMode === "circle" && tempCircle && drawingLayerRef.current) {
      drawingLayerRef.current.clearLayers();
      
      const centerLatLng = L.latLng(tempCircle.center.lat, tempCircle.center.lng);
      const mouseLatLng = L.latLng(e.latlng.lat, e.latlng.lng);
      const radius = centerLatLng.distanceTo(mouseLatLng);
      
      L.circle([tempCircle.center.lat, tempCircle.center.lng], {
        radius,
        color: "#1E8E3E",
        fillColor: "#1E8E3E",
        fillOpacity: 0.2,
        dashArray: "5, 5",
      }).addTo(drawingLayerRef.current);
      
      L.circleMarker([tempCircle.center.lat, tempCircle.center.lng], {
        radius: 5,
        color: "#1E8E3E",
        fillColor: "#1E8E3E",
        fillOpacity: 1,
      }).addTo(drawingLayerRef.current);
    }
  }, [drawingMode, tempCircle]);

  // Attach map events
  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!map) return;

    map.on("click", handleMapClick);
    map.on("dblclick", handleMapDblClick);
    map.on("mousemove", handleMapMouseMove);

    return () => {
      map.off("click", handleMapClick);
      map.off("dblclick", handleMapDblClick);
      map.off("mousemove", handleMapMouseMove);
    };
  }, [handleMapClick, handleMapDblClick, handleMapMouseMove]);

  // Cancel drawing
  const cancelDrawing = useCallback(() => {
    setDrawingPoints([]);
    setTempCircle(null);
    setIsDrawing(false);
    if (drawingLayerRef.current) {
      drawingLayerRef.current.clearLayers();
    }
  }, []);

  // Complete polygon drawing
  const completePolygon = useCallback(() => {
    if (drawingPoints.length >= 3 && onPolygonComplete) {
      onPolygonComplete(drawingPoints);
      setDrawingPoints([]);
      setIsDrawing(false);
      if (drawingLayerRef.current) {
        drawingLayerRef.current.clearLayers();
      }
    }
  }, [drawingPoints, onPolygonComplete]);

  return (
    <div className={`relative ${className}`} style={{ height }}>
      <div ref={mapRef} className="w-full h-full rounded-xl overflow-hidden" />
      
      {/* Drawing controls */}
      {isDrawing && (
        <div className="absolute top-4 left-1/2 transform -translate-x-1/2 z-[1000] bg-white dark:bg-[#262626] rounded-xl shadow-lg p-3 flex items-center gap-3">
          {drawingMode === "polygon" && (
            <>
              <span className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">
                {drawingPoints.length} puntos • Doble clic para terminar
              </span>
              <button
                onClick={completePolygon}
                disabled={drawingPoints.length < 3}
                className="px-3 py-1.5 text-sm bg-[#1E8E3E] text-white rounded-lg hover:bg-[#0D5425] disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Completar
              </button>
            </>
          )}
          {drawingMode === "circle" && (
            <span className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">
              Clic para establecer el radio
            </span>
          )}
          <button
            onClick={cancelDrawing}
            className="px-3 py-1.5 text-sm bg-[#D93025] text-white rounded-lg hover:bg-[#B02A1F]"
          >
            Cancelar
          </button>
        </div>
      )}
      
      {/* Drawing mode indicator */}
      {drawingMode && !isDrawing && (
        <div className="absolute top-4 left-1/2 transform -translate-x-1/2 z-[1000] bg-[#1E8E3E] text-white rounded-xl shadow-lg px-4 py-2 text-sm">
          {drawingMode === "polygon" && "Clic para agregar puntos del polígono"}
          {drawingMode === "circle" && "Clic para colocar el centro del círculo"}
          {drawingMode === "marker" && "Clic para colocar el marcador"}
        </div>
      )}

      {/* Custom marker styles */}
      <style jsx global>{`
        .custom-marker-icon {
          background: transparent;
          border: none;
        }
        .leaflet-popup-content-wrapper {
          border-radius: 12px;
        }
        .leaflet-container {
          font-family: 'Roboto', system-ui, -apple-system, sans-serif;
        }
      `}</style>
    </div>
  );
}
