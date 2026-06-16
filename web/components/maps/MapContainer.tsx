"use client";

import { useEffect, useState } from "react";
import dynamic from "next/dynamic";

// Lazy load the map to avoid SSR issues with Leaflet
const LazyMap = dynamic(() => import("./LeafletMap"), {
  ssr: false,
  loading: () => (
    <div className="flex items-center justify-center h-full bg-[#F8F9FA] dark:bg-[#262626] rounded-xl">
      <div className="flex flex-col items-center gap-2">
        <div className="w-8 h-8 border-4 border-[#1E8E3E] border-t-transparent rounded-full animate-spin" />
        <span className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">Cargando mapa...</span>
      </div>
    </div>
  ),
});

export interface MapPoint {
  lat: number;
  lng: number;
}

export interface MapMarker {
  id: string | number;
  position: MapPoint;
  label?: string;
  icon?: "child" | "alert" | "device" | "default";
  popup?: string;
  color?: string;
}

export interface MapPolygon {
  id: string | number;
  points: MapPoint[];
  color?: string;
  fillColor?: string;
  fillOpacity?: number;
  editable?: boolean;
  label?: string;
}

export interface MapCircle {
  id: string | number;
  center: MapPoint;
  radius: number; // in meters
  color?: string;
  fillColor?: string;
  fillOpacity?: number;
  editable?: boolean;
  label?: string;
}

export interface MapContainerProps {
  center?: MapPoint;
  zoom?: number;
  height?: string;
  markers?: MapMarker[];
  polygons?: MapPolygon[];
  circles?: MapCircle[];
  drawingMode?: "polygon" | "circle" | "marker" | null;
  onPolygonComplete?: (points: MapPoint[]) => void;
  onCircleComplete?: (center: MapPoint, radius: number) => void;
  onMarkerPlace?: (position: MapPoint) => void;
  onPolygonEdit?: (id: string | number, points: MapPoint[]) => void;
  onCircleEdit?: (id: string | number, center: MapPoint, radius: number) => void;
  onClick?: (position: MapPoint) => void;
  className?: string;
  showControls?: boolean;
  showSearch?: boolean;
}

export default function MapContainer(props: MapContainerProps) {
  const [isMounted, setIsMounted] = useState(false);

  useEffect(() => {
    // Using a microtask to set mounted state after hydration
    const timer = requestAnimationFrame(() => setIsMounted(true));
    return () => cancelAnimationFrame(timer);
  }, []);

  if (!isMounted) {
    return (
      <div 
        className={`bg-[#F8F9FA] dark:bg-[#262626] rounded-xl ${props.className || ""}`}
        style={{ height: props.height || "400px" }}
      >
        <div className="flex items-center justify-center h-full">
          <span className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">Inicializando mapa...</span>
        </div>
      </div>
    );
  }

  return <LazyMap {...props} />;
}
