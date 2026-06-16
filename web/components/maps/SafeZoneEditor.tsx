"use client";

import { useState, useCallback } from "react";
import MapContainer, { MapPoint, MapPolygon, MapCircle } from "./MapContainer";
import { Button } from "@/components/ui";
import { Trash2, Circle, Pentagon } from "lucide-react";

export interface SafeZoneEditorProps {
  initialPolygon?: MapPoint[];
  initialCircle?: { center: MapPoint; radius: number };
  zoneType: "polygon" | "circle";
  onZoneTypeChange: (type: "polygon" | "circle") => void;
  onPolygonChange: (points: MapPoint[]) => void;
  onCircleChange: (center: MapPoint, radius: number) => void;
  center?: MapPoint;
  height?: string;
}

export default function SafeZoneEditor({
  initialPolygon = [],
  initialCircle,
  zoneType,
  onZoneTypeChange,
  onPolygonChange,
  onCircleChange,
  center = { lat: -17.7833, lng: -63.1821 },
  height = "400px",
}: SafeZoneEditorProps) {
  const [polygonPoints, setPolygonPoints] = useState<MapPoint[]>(initialPolygon);
  const [circleData, setCircleData] = useState<{ center: MapPoint; radius: number } | null>(
    initialCircle || null
  );
  const [drawingMode, setDrawingMode] = useState<"polygon" | "circle" | null>(null);

  const handlePolygonComplete = useCallback((points: MapPoint[]) => {
    setPolygonPoints(points);
    onPolygonChange(points);
    setDrawingMode(null);
  }, [onPolygonChange]);

  const handleCircleComplete = useCallback((circleCenter: MapPoint, radius: number) => {
    setCircleData({ center: circleCenter, radius });
    onCircleChange(circleCenter, radius);
    setDrawingMode(null);
  }, [onCircleChange]);

  const clearZone = useCallback(() => {
    setPolygonPoints([]);
    setCircleData(null);
    onPolygonChange([]);
    setDrawingMode(null);
  }, [onPolygonChange]);

  const startDrawing = useCallback(() => {
    clearZone();
    setDrawingMode(zoneType);
  }, [zoneType, clearZone]);

  const handleZoneTypeChange = useCallback((type: "polygon" | "circle") => {
    onZoneTypeChange(type);
    clearZone();
  }, [onZoneTypeChange, clearZone]);

  // Prepare map data
  const mapPolygons: MapPolygon[] = zoneType === "polygon" && polygonPoints.length >= 3
    ? [{
        id: "editor-polygon",
        points: polygonPoints,
        color: "#1E8E3E",
        fillColor: "#1E8E3E",
        fillOpacity: 0.3,
        label: "Zona segura",
      }]
    : [];

  const mapCircles: MapCircle[] = zoneType === "circle" && circleData
    ? [{
        id: "editor-circle",
        center: circleData.center,
        radius: circleData.radius,
        color: "#1E8E3E",
        fillColor: "#1E8E3E",
        fillOpacity: 0.3,
        label: `Radio: ${Math.round(circleData.radius)}m`,
      }]
    : [];

  return (
    <div className="space-y-4">
      {/* Zone type selector */}
      <div className="flex items-center gap-4">
        <span className="text-sm font-medium text-[#202124] dark:text-white">Tipo de zona:</span>
        <div className="flex gap-2">
          <button
            type="button"
            onClick={() => handleZoneTypeChange("polygon")}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-colors ${
              zoneType === "polygon"
                ? "bg-[#1E8E3E] text-white"
                : "bg-[#F8F9FA] dark:bg-[#262626] text-[#5F6368] dark:text-[#9AA0A6] hover:bg-[#E8EAED] dark:hover:bg-[#404040]"
            }`}
          >
            <Pentagon className="h-4 w-4" />
            Polígono
          </button>
          <button
            type="button"
            onClick={() => handleZoneTypeChange("circle")}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-colors ${
              zoneType === "circle"
                ? "bg-[#1E8E3E] text-white"
                : "bg-[#F8F9FA] dark:bg-[#262626] text-[#5F6368] dark:text-[#9AA0A6] hover:bg-[#E8EAED] dark:hover:bg-[#404040]"
            }`}
          >
            <Circle className="h-4 w-4" />
            Círculo
          </button>
        </div>
      </div>

      {/* Drawing controls */}
      <div className="flex items-center gap-3">
        <Button
          type="button"
          onClick={startDrawing}
          className="gap-2"
        >
          {zoneType === "polygon" ? <Pentagon className="h-4 w-4" /> : <Circle className="h-4 w-4" />}
          {polygonPoints.length > 0 || circleData ? "Redibujar" : "Dibujar"} zona
        </Button>
        
        {(polygonPoints.length > 0 || circleData) && (
          <Button
            type="button"
            variant="outline"
            onClick={clearZone}
            className="gap-2"
          >
            <Trash2 className="h-4 w-4" />
            Limpiar
          </Button>
        )}
      </div>

      {/* Instructions */}
      <div className="text-sm text-[#5F6368] dark:text-[#9AA0A6] bg-[#F8F9FA] dark:bg-[#262626] rounded-xl p-3">
        {zoneType === "polygon" ? (
          <ul className="list-disc list-inside space-y-1">
            <li>Haz clic en el mapa para agregar puntos del polígono</li>
            <li>Necesitas al menos 3 puntos para formar una zona</li>
            <li>Doble clic o botón &quot;Completar&quot; para terminar</li>
          </ul>
        ) : (
          <ul className="list-disc list-inside space-y-1">
            <li>Primer clic: coloca el centro del círculo</li>
            <li>Segundo clic: define el radio (distancia al centro)</li>
          </ul>
        )}
      </div>

      {/* Map */}
      <MapContainer
        center={circleData?.center || (polygonPoints.length > 0 ? polygonPoints[0] : center)}
        zoom={15}
        height={height}
        polygons={mapPolygons}
        circles={mapCircles}
        drawingMode={drawingMode}
        onPolygonComplete={handlePolygonComplete}
        onCircleComplete={handleCircleComplete}
        showControls
      />

      {/* Zone info */}
      {zoneType === "polygon" && polygonPoints.length >= 3 && (
        <div className="bg-[#DCF5E3] dark:bg-[#1E3A2F] rounded-xl p-3">
          <p className="text-sm text-[#1E8E3E] dark:text-[#4ade80] font-medium">
            ✓ Polígono creado con {polygonPoints.length} puntos
          </p>
          <p className="text-xs text-[#5F6368] dark:text-[#9AA0A6] mt-1">
            Coordenadas guardadas automáticamente
          </p>
        </div>
      )}

      {zoneType === "circle" && circleData && (
        <div className="bg-[#DCF5E3] dark:bg-[#1E3A2F] rounded-xl p-3">
          <p className="text-sm text-[#1E8E3E] dark:text-[#4ade80] font-medium">
            ✓ Círculo creado - Radio: {Math.round(circleData.radius)} metros
          </p>
          <p className="text-xs text-[#5F6368] dark:text-[#9AA0A6] mt-1">
            Centro: {circleData.center.lat.toFixed(6)}, {circleData.center.lng.toFixed(6)}
          </p>
        </div>
      )}
    </div>
  );
}
