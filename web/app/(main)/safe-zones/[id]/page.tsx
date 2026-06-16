"use client";

import { useEffect, useState, useMemo } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import dynamic from "next/dynamic";
import api, { API_ENDPOINTS } from "@/lib/api";
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  Button,
  Badge,
  Loading,
} from "@/components/ui";
import { getZoneTypeLabel } from "@/lib/utils";
import { SafeZone } from "@/lib/types";
import { ArrowLeft, Edit, MapPin, User, Ruler } from "lucide-react";

// Dynamic import for Google Maps (SSR issues)
const GoogleMapView = dynamic(
  () => import("@/components/maps/GoogleMapView"),
  {
    ssr: false,
    loading: () => (
      <div className="aspect-video bg-[#F8F9FA] dark:bg-[#262626] rounded-xl flex items-center justify-center">
        <Loading text="Cargando mapa..." />
      </div>
    ),
  }
);

// Wrapper with LoadScript
const GoogleMapsWrapper = dynamic(
  () => import("@/components/maps/GoogleMapsProvider"),
  { ssr: false }
);

export default function SafeZoneDetailPage() {
  const params = useParams();
  const id = params.id as string;

  const [zone, setZone] = useState<SafeZone | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchZone = async () => {
      try {
        const response = await api.get(`${API_ENDPOINTS.SAFE_ZONES}${id}/`);
        setZone(response.data);
      } catch (err) {
        console.error("Error fetching zone:", err);
        setError("Error al cargar la zona segura");
      } finally {
        setIsLoading(false);
      }
    };

    if (id) {
      fetchZone();
    }
  }, [id]);

  // Calculate center and map data based on zone type
  const mapData = useMemo(() => {
    if (!zone) return null;

    // For circles - use center coordinates
    if (zone.zone_type === "circle" && zone.center_latitude && zone.center_longitude) {
      return {
        center: { lat: Number(zone.center_latitude), lng: Number(zone.center_longitude) },
        circles: [{
          id: zone.id,
          center: { lat: Number(zone.center_latitude), lng: Number(zone.center_longitude) },
          radius: zone.radius_meters || zone.radius || 100,
          color: zone.color || "#1E8E3E",
          fillColor: zone.color || "#1E8E3E",
          fillOpacity: 0.3,
          label: zone.name,
        }],
        polygons: [],
        latitude: Number(zone.center_latitude),
        longitude: Number(zone.center_longitude),
      };
    }

    // For polygons - calculate center from polygon points
    if (zone.polygon_points && zone.polygon_points.length >= 3) {
      const points = zone.polygon_points;
      const centerLat = points.reduce((sum, p) => sum + p.lat, 0) / points.length;
      const centerLng = points.reduce((sum, p) => sum + p.lng, 0) / points.length;

      return {
        center: { lat: centerLat, lng: centerLng },
        polygons: [{
          id: zone.id,
          points: points,
          color: zone.color || "#1E8E3E",
          fillColor: zone.color || "#1E8E3E",
          fillOpacity: 0.3,
          label: zone.name,
        }],
        circles: [],
        latitude: centerLat,
        longitude: centerLng,
      };
    }

    // Fallback to legacy coordinates if available
    if (zone.latitude && zone.longitude) {
      return {
        center: { lat: zone.latitude, lng: zone.longitude },
        circles: zone.radius ? [{
          id: zone.id,
          center: { lat: zone.latitude, lng: zone.longitude },
          radius: zone.radius,
          color: zone.color || "#1E8E3E",
          fillColor: zone.color || "#1E8E3E",
          fillOpacity: 0.3,
          label: zone.name,
        }] : [],
        polygons: [],
        latitude: zone.latitude,
        longitude: zone.longitude,
      };
    }

    return null;
  }, [zone]);

  if (isLoading) {
    return <Loading text="Cargando..." />;
  }

  if (error || !zone) {
    return (
      <div className="flex flex-col items-center justify-center h-64">
        <p className="text-[#D93025] mb-4">{error || "Zona no encontrada"}</p>
        <Link href="/safe-zones">
          <Button variant="outline">Volver a la lista</Button>
        </Link>
      </div>
    );
  }

  const googleMapsUrl = mapData 
    ? `https://www.google.com/maps?q=${mapData.latitude},${mapData.longitude}&z=16`
    : "#";

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link href="/safe-zones">
            <Button variant="ghost" size="icon">
              <ArrowLeft className="h-5 w-5" />
            </Button>
          </Link>
          <div>
            <h1 className="text-2xl font-bold text-[#202124] dark:text-white">{zone.name}</h1>
            <p className="text-[#5F6368] dark:text-[#9AA0A6]">{zone.description}</p>
          </div>
        </div>
        <Link href={`/safe-zones/${id}/edit`}>
          <Button variant="outline" className="gap-2">
            <Edit className="h-4 w-4" />
            Editar
          </Button>
        </Link>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Info Card */}
        <Card>
          <CardHeader>
            <CardTitle className="text-[#202124] dark:text-white">Información</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-[#5F6368] dark:text-[#9AA0A6]">Tipo</span>
              <Badge
                variant={
                  zone.zone_type === "polygon"
                    ? "info"
                    : zone.zone_type === "circle"
                    ? "success"
                    : "default"
                }
              >
                {getZoneTypeLabel(zone.zone_type)}
              </Badge>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-[#5F6368] dark:text-[#9AA0A6]">Estado</span>
              <Badge variant={zone.is_active ? "success" : "default"}>
                {zone.is_active ? "Activa" : "Inactiva"}
              </Badge>
            </div>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 text-[#5F6368] dark:text-[#9AA0A6]">
                <User className="h-4 w-4" />
                Niño asignado
              </div>
              <span className="font-medium text-[#202124] dark:text-white">{zone.child_name || `ID: ${zone.child}`}</span>
            </div>
            {zone.zone_type === "circle" && (
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2 text-[#5F6368] dark:text-[#9AA0A6]">
                  <Ruler className="h-4 w-4" />
                  Radio
                </div>
                <span className="font-medium text-[#202124] dark:text-white">
                  {zone.radius_meters || zone.radius || 100} metros
                </span>
              </div>
            )}
            {zone.zone_type === "polygon" && zone.polygon_points && (
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2 text-[#5F6368] dark:text-[#9AA0A6]">
                  <MapPin className="h-4 w-4" />
                  Puntos
                </div>
                <span className="font-medium text-[#202124] dark:text-white">
                  {zone.polygon_points.length} vértices
                </span>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Location Card */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-[#202124] dark:text-white">
              <MapPin className="h-5 w-5 text-[#1E8E3E] dark:text-[#4ade80]" />
              Ubicación
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {mapData ? (
              <>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">
                      {zone.zone_type === "polygon" ? "Centro (Lat)" : "Latitud"}
                    </p>
                    <p className="font-mono text-[#202124] dark:text-white">
                      {mapData.latitude.toFixed(6)}
                    </p>
                  </div>
                  <div>
                    <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">
                      {zone.zone_type === "polygon" ? "Centro (Lng)" : "Longitud"}
                    </p>
                    <p className="font-mono text-[#202124] dark:text-white">
                      {mapData.longitude.toFixed(6)}
                    </p>
                  </div>
                </div>
                <a
                  href={googleMapsUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="block"
                >
                  <Button variant="outline" className="w-full gap-2">
                    <MapPin className="h-4 w-4" />
                    Ver en Google Maps
                  </Button>
                </a>
              </>
            ) : (
              <div className="text-center py-4">
                <p className="text-[#5F6368] dark:text-[#9AA0A6]">
                  No hay coordenadas disponibles para esta zona.
                </p>
                <p className="text-sm text-[#9AA0A6] mt-1">
                  Edita la zona para agregar ubicación.
                </p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Map Preview */}
      <Card>
        <CardHeader>
          <CardTitle className="text-[#202124] dark:text-white">Vista previa del mapa</CardTitle>
        </CardHeader>
        <CardContent>
          {mapData ? (
            <GoogleMapsWrapper>
              <div className="aspect-video rounded-xl overflow-hidden">
                <GoogleMapView
                  center={mapData.center}
                  zoom={17}
                  height="100%"
                  polygons={mapData.polygons}
                  circles={mapData.circles}
                  mapTypeId="hybrid"
                />
              </div>
            </GoogleMapsWrapper>
          ) : (
            <div className="aspect-video bg-[#F8F9FA] dark:bg-[#262626] rounded-xl flex items-center justify-center">
              <div className="text-center">
                <MapPin className="h-12 w-12 text-[#9AA0A6] mx-auto mb-2" />
                <p className="text-[#5F6368] dark:text-[#9AA0A6]">
                  No hay datos de ubicación para mostrar
                </p>
                <Link href={`/safe-zones/${id}/edit`}>
                  <Button variant="outline" className="mt-4">
                    Configurar ubicación
                  </Button>
                </Link>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
