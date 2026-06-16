"use client";

import { useState, useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import api, { API_ENDPOINTS } from "@/lib/api";
import {
  Card,
  CardContent,
  CardFooter,
  Button,
  Input,
  Loading,
} from "@/components/ui";
import { SafeZoneEditor } from "@/components/maps";
import type { MapPoint } from "@/components/maps";
import { Child } from "@/lib/types";
import { ArrowLeft, Loader2, MapPin } from "lucide-react";
import { AxiosError } from "axios";

export default function NewSafeZonePage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const childIdParam = searchParams.get("child");

  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [zoneType, setZoneType] = useState<"polygon" | "circle">("polygon");
  const [childId, setChildId] = useState(childIdParam || "");
  const [children, setChildren] = useState<Child[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isLoadingChildren, setIsLoadingChildren] = useState(true);
  const [error, setError] = useState("");

  // Zone data
  const [polygonPoints, setPolygonPoints] = useState<MapPoint[]>([]);
  const [circleCenter, setCircleCenter] = useState<MapPoint | null>(null);
  const [circleRadius, setCircleRadius] = useState<number>(100);

  // Get selected child's last known location for map centering
  const selectedChild = children.find((c) => c.id === parseInt(childId));
  const mapCenter: MapPoint = selectedChild?.device?.last_latitude && selectedChild?.device?.last_longitude
    ? { lat: selectedChild.device.last_latitude, lng: selectedChild.device.last_longitude }
    : { lat: -17.7833, lng: -63.1821 }; // Santa Cruz default

  useEffect(() => {
    const fetchChildren = async () => {
      try {
        const response = await api.get(API_ENDPOINTS.CHILDREN);
        setChildren(response.data.results || response.data);
      } catch (err) {
        console.error("Error fetching children:", err);
      } finally {
        setIsLoadingChildren(false);
      }
    };

    fetchChildren();
  }, []);

  const handlePolygonChange = (points: MapPoint[]) => {
    setPolygonPoints(points);
  };

  const handleCircleChange = (center: MapPoint, radius: number) => {
    setCircleCenter(center);
    setCircleRadius(radius);
  };

  const handleZoneTypeChange = (type: "polygon" | "circle") => {
    setZoneType(type);
    // Clear the other type's data
    if (type === "polygon") {
      setCircleCenter(null);
      setCircleRadius(100);
    } else {
      setPolygonPoints([]);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    if (!childId) {
      setError("Debes seleccionar un niño");
      return;
    }

    // Validate zone data
    if (zoneType === "polygon" && polygonPoints.length < 3) {
      setError("Debes dibujar un polígono con al menos 3 puntos en el mapa");
      return;
    }

    if (zoneType === "circle" && !circleCenter) {
      setError("Debes dibujar un círculo en el mapa");
      return;
    }

    setIsLoading(true);

    try {
      const payload: Record<string, unknown> = {
        name,
        description,
        zone_type: zoneType,
        child: parseInt(childId),
        is_active: true,
      };

      if (zoneType === "polygon") {
        payload.polygon_points = polygonPoints.map((p) => ({ lat: p.lat, lng: p.lng }));
      } else {
        payload.center_latitude = circleCenter!.lat;
        payload.center_longitude = circleCenter!.lng;
        payload.radius_meters = Math.round(circleRadius);
      }

      await api.post(API_ENDPOINTS.SAFE_ZONES, payload);
      router.push("/safe-zones");
    } catch (err) {
      const axiosError = err as AxiosError<{ detail?: string; non_field_errors?: string[] }>;
      const detail = axiosError.response?.data?.detail;
      const nonFieldErrors = axiosError.response?.data?.non_field_errors;
      setError(detail || nonFieldErrors?.[0] || "Error al crear la zona segura");
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoadingChildren) {
    return <Loading text="Cargando..." />;
  }

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link href="/safe-zones">
          <Button variant="ghost" size="icon">
            <ArrowLeft className="h-5 w-5" />
          </Button>
        </Link>
        <div>
          <h1 className="text-2xl font-bold text-[#202124] dark:text-white">Nueva zona segura</h1>
          <p className="text-[#5F6368] dark:text-[#9AA0A6]">
            Dibuja un área de monitoreo en el mapa
          </p>
        </div>
      </div>

      {/* Form */}
      <form onSubmit={handleSubmit}>
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Left column - Form fields */}
          <div className="lg:col-span-1 space-y-4">
            <Card>
              <CardContent className="space-y-4 pt-6">
                {error && (
                  <div className="p-3 bg-[#FCE8E6] dark:bg-[#5C2B29] border border-[#F5C6CB] dark:border-[#8B3A3A] rounded-xl text-[#C5221F] dark:text-[#F28B82] text-sm">
                    {error}
                  </div>
                )}

                <Input
                  label="Nombre de la zona"
                  type="text"
                  placeholder="Ej: Kinder Los Angelitos"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                />

                <Input
                  label="Descripción"
                  type="text"
                  placeholder="Descripción breve de la zona"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                />

                <div>
                  <label className="block text-sm font-medium text-[#202124] dark:text-white mb-1">
                    Niño
                  </label>
                  <select
                    value={childId}
                    onChange={(e) => setChildId(e.target.value)}
                    className="flex h-10 w-full rounded-xl border border-[#DADCE0] dark:border-[#404040] bg-white dark:bg-[#262626] px-3 py-2 text-sm text-[#202124] dark:text-white focus:outline-none focus:ring-2 focus:ring-[#1E8E3E]"
                    required
                  >
                    <option value="">Selecciona un niño</option>
                    {children.map((child) => (
                      <option key={child.id} value={child.id}>
                        {child.full_name}
                      </option>
                    ))}
                  </select>
                </div>

                {/* Zone info summary */}
                <div className="pt-4 border-t border-[#E8EAED] dark:border-[#404040]">
                  <h4 className="text-sm font-medium text-[#202124] dark:text-white mb-2">
                    Resumen de la zona
                  </h4>
                  <div className="space-y-2 text-sm text-[#5F6368] dark:text-[#9AA0A6]">
                    <p>
                      <span className="font-medium">Tipo:</span>{" "}
                      {zoneType === "polygon" ? "Polígono" : "Círculo"}
                    </p>
                    {zoneType === "polygon" && (
                      <p>
                        <span className="font-medium">Puntos:</span>{" "}
                        {polygonPoints.length >= 3 ? `${polygonPoints.length} puntos` : "Sin definir"}
                      </p>
                    )}
                    {zoneType === "circle" && circleCenter && (
                      <>
                        <p>
                          <span className="font-medium">Centro:</span>{" "}
                          {circleCenter.lat.toFixed(4)}, {circleCenter.lng.toFixed(4)}
                        </p>
                        <p>
                          <span className="font-medium">Radio:</span>{" "}
                          {Math.round(circleRadius)} metros
                        </p>
                      </>
                    )}
                  </div>
                </div>
              </CardContent>

              <CardFooter className="flex gap-3">
                <Link href="/safe-zones" className="flex-1">
                  <Button type="button" variant="outline" className="w-full">
                    Cancelar
                  </Button>
                </Link>
                <Button type="submit" className="flex-1" disabled={isLoading}>
                  {isLoading ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Guardando...
                    </>
                  ) : (
                    <>
                      <MapPin className="mr-2 h-4 w-4" />
                      Crear zona
                    </>
                  )}
                </Button>
              </CardFooter>
            </Card>
          </div>

          {/* Right column - Map editor */}
          <div className="lg:col-span-2">
            <Card>
              <CardContent className="pt-6">
                <SafeZoneEditor
                  zoneType={zoneType}
                  onZoneTypeChange={handleZoneTypeChange}
                  onPolygonChange={handlePolygonChange}
                  onCircleChange={handleCircleChange}
                  initialPolygon={polygonPoints}
                  initialCircle={circleCenter ? { center: circleCenter, radius: circleRadius } : undefined}
                  center={mapCenter}
                  height="500px"
                />
              </CardContent>
            </Card>
          </div>
        </div>
      </form>
    </div>
  );
}
