"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import Image from "next/image";
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
import { formatDate, formatDateTime, getBatteryColor, normalizeChildPhoto } from "@/lib/utils";
import { Child, SafeZone, Alert } from "@/lib/types";
import {
  ArrowLeft,
  Edit,
  Battery,
  Smartphone,
  MapPin,
  Bell,
  Calendar,
  User,
} from "lucide-react";

export default function ChildDetailPage() {
  const params = useParams();
  const id = params.id as string;

  const [child, setChild] = useState<Child | null>(null);
  const [safeZones, setSafeZones] = useState<SafeZone[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // States for copying/associating existing zones
  const [allExistingZones, setAllExistingZones] = useState<SafeZone[]>([]);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedZoneId, setSelectedZoneId] = useState("");
  const [isCopying, setIsCopying] = useState(false);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [childRes, zonesRes, alertsRes] = await Promise.all([
          api.get(`${API_ENDPOINTS.CHILDREN}${id}/`),
          api.get(API_ENDPOINTS.SAFE_ZONES),
          api.get(API_ENDPOINTS.ALERTS),
        ]);

        setChild(normalizeChildPhoto(childRes.data));
        
        // Filter zones and alerts for this child
        const allZones = zonesRes.data.results || zonesRes.data;
        const allAlerts = alertsRes.data.results || alertsRes.data;
        
        setSafeZones(allZones.filter((z: SafeZone) => z.child === parseInt(id)));
        setAlerts(allAlerts.filter((a: Alert) => a.child === parseInt(id)));
      } catch (err) {
        console.error("Error fetching child:", err);
        setError("Error al cargar los datos del niño");
      } finally {
        setIsLoading(false);
      }
    };

    if (id) {
      fetchData();
    }
  }, [id]);

  const openCopyModal = async () => {
    setIsModalOpen(true);
    try {
      const response = await api.get(API_ENDPOINTS.SAFE_ZONES);
      const zones = response.data.results || response.data;
      // Filter out zones already assigned to this child
      setAllExistingZones(zones.filter((z: SafeZone) => z.child !== parseInt(id)));
    } catch (err) {
      console.error("Error loading safe zones:", err);
    }
  };

  const handleCopyZone = async () => {
    if (!selectedZoneId) return;
    setIsCopying(true);
    try {
      const zoneToCopy = allExistingZones.find((z) => z.id === parseInt(selectedZoneId));
      if (zoneToCopy) {
        const payload: any = {
          name: zoneToCopy.name,
          description: zoneToCopy.description || "",
          zone_type: zoneToCopy.zone_type,
          child: parseInt(id),
          is_active: true,
        };
        if (zoneToCopy.zone_type === "polygon") {
          payload.polygon_points = zoneToCopy.polygon_points;
        } else {
          payload.center_latitude = zoneToCopy.center_latitude;
          payload.center_longitude = zoneToCopy.center_longitude;
          payload.radius_meters = zoneToCopy.radius_meters;
        }
        
        await api.post(API_ENDPOINTS.SAFE_ZONES, payload);
        
        // Refresh zones list
        const zonesRes = await api.get(API_ENDPOINTS.SAFE_ZONES);
        const allZones = zonesRes.data.results || zonesRes.data;
        setSafeZones(allZones.filter((z: SafeZone) => z.child === parseInt(id)));
        
        // Close modal
        setIsModalOpen(false);
        setSelectedZoneId("");
      }
    } catch (err) {
      console.error("Error copying zone:", err);
    } finally {
      setIsCopying(false);
    }
  };

  if (isLoading) {
    return <Loading text="Cargando..." />;
  }

  if (error || !child) {
    return (
      <div className="flex flex-col items-center justify-center h-64">
        <p className="text-[#D93025] mb-4">{error || "Niño no encontrado"}</p>
        <Link href="/children">
          <Button variant="outline">Volver a la lista</Button>
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link href="/children">
            <Button variant="ghost" size="icon">
              <ArrowLeft className="h-5 w-5" />
            </Button>
          </Link>
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 rounded-full bg-[#DCF5E3] dark:bg-[#1E3A2F] flex items-center justify-center overflow-hidden">
              {child.photo ? (
                <Image
                  src={child.photo}
                  alt={child.full_name || child.first_name || "Niño"}
                  width={64}
                  height={64}
                  className="w-16 h-16 rounded-full object-cover"
                  unoptimized
                />
              ) : (
                <span className="text-2xl text-[#1E8E3E] dark:text-[#4ade80] font-medium">
                  {(child.full_name || child.first_name || "N")[0]}
                </span>
              )}
            </div>
            <div>
              <h1 className="text-2xl font-bold text-[#202124] dark:text-white">
                {child.full_name || `${child.first_name || ""} ${child.last_name || ""}`.trim() || "Sin nombre"}
              </h1>
              <p className="text-[#5F6368] dark:text-[#9AA0A6]">{child.grade || "Sin grado"}</p>
            </div>
          </div>
        </div>
        <Link href={`/children/${id}/edit`}>
          <Button variant="outline" className="gap-2">
            <Edit className="h-4 w-4" />
            Editar
          </Button>
        </Link>
      </div>

      {/* Info Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Basic Info */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2 text-[#202124] dark:text-white">
              <User className="h-4 w-4 text-[#1E8E3E] dark:text-[#4ade80]" />
              Información básica
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex items-center gap-2">
              <Calendar className="h-4 w-4 text-[#9AA0A6]" />
              <span className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">
                Nacimiento: {formatDate(child.date_of_birth)}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-sm text-[#9AA0A6]">
                Registrado: {formatDate(child.created_at)}
              </span>
            </div>
          </CardContent>
        </Card>

        {/* Device Info */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2 text-[#202124] dark:text-white">
              <Smartphone className="h-4 w-4 text-[#1E8E3E] dark:text-[#4ade80]" />
              Dispositivo
            </CardTitle>
          </CardHeader>
          <CardContent>
            {child.device ? (
              <div className="space-y-3">
                <Badge variant="success">Conectado</Badge>
                <div className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">
                  ID: {child.device.device_id}
                </div>
                {child.device.battery_level !== null && (
                  <div className="flex items-center gap-2">
                    <Battery
                      className={`h-4 w-4 ${getBatteryColor(
                        child.device.battery_level
                      )}`}
                    />
                    <span className="text-[#202124] dark:text-white">{child.device.battery_level}%</span>
                  </div>
                )}
                {child.device.last_seen && (
                  <div className="text-xs text-[#9AA0A6]">
                    Última conexión: {formatDateTime(child.device.last_seen)}
                  </div>
                )}
              </div>
            ) : (
              <div className="text-center py-4">
                <Badge variant="default">Sin dispositivo</Badge>
                <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6] mt-2">
                  Vincula un dispositivo para comenzar el monitoreo
                </p>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Stats */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2 text-[#202124] dark:text-white">
              <Bell className="h-4 w-4 text-[#1E8E3E] dark:text-[#4ade80]" />
              Estadísticas
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex justify-between items-center">
              <span className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">Zonas seguras</span>
              <Badge variant="info">{safeZones.length}</Badge>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">Alertas totales</span>
              <Badge variant="default">{alerts.length}</Badge>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">Alertas pendientes</span>
              <Badge variant={alerts.filter(a => !a.is_acknowledged).length > 0 ? "danger" : "success"}>
                {alerts.filter(a => !a.is_acknowledged).length}
              </Badge>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Safe Zones */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="flex items-center gap-2 text-[#202124] dark:text-white">
            <MapPin className="h-5 w-5 text-[#1E8E3E] dark:text-[#4ade80]" />
            Zonas seguras
          </CardTitle>
          <div className="flex gap-2">
            <Button size="sm" variant="outline" onClick={openCopyModal}>
              Copiar existente
            </Button>
            <Link href={`/safe-zones/new?child=${id}`}>
              <Button size="sm">Agregar zona</Button>
            </Link>
          </div>
        </CardHeader>
        <CardContent>
          {safeZones.length === 0 ? (
            <p className="text-center text-[#5F6368] dark:text-[#9AA0A6] py-4">
              No hay zonas seguras configuradas para este niño
            </p>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {safeZones.map((zone) => (
                <div
                  key={zone.id}
                  className="p-3 rounded-xl bg-[#F8F9FA] dark:bg-[#262626] flex items-start gap-3"
                >
                  <MapPin className="h-5 w-5 text-[#1E8E3E] dark:text-[#4ade80] mt-0.5" />
                  <div>
                    <p className="font-medium text-[#202124] dark:text-white">{zone.name}</p>
                    <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">{zone.description}</p>
                    <p className="text-xs text-[#9AA0A6]">
                      Radio: {zone.radius}m
                    </p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Recent Alerts */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="flex items-center gap-2 text-[#202124] dark:text-white">
            <Bell className="h-5 w-5 text-[#1E8E3E] dark:text-[#4ade80]" />
            Alertas recientes
          </CardTitle>
          <Link href={`/alerts?child=${id}`}>
            <Button variant="outline" size="sm">Ver todas</Button>
          </Link>
        </CardHeader>
        <CardContent>
          {alerts.length === 0 ? (
            <p className="text-center text-[#5F6368] dark:text-[#9AA0A6] py-4">
              No hay alertas para este niño
            </p>
          ) : (
            <div className="space-y-3">
              {alerts.slice(0, 5).map((alert) => (
                <div
                  key={alert.id}
                  className="p-3 rounded-xl bg-[#F8F9FA] dark:bg-[#262626] flex items-start justify-between"
                >
                  <div>
                    <p className="font-medium text-sm text-[#202124] dark:text-white">{alert.message}</p>
                    <p className="text-xs text-[#9AA0A6]">
                      {formatDateTime(alert.created_at)}
                    </p>
                  </div>
                  <Badge variant={alert.is_acknowledged ? "default" : "danger"}>
                    {alert.is_acknowledged ? "Leída" : "Pendiente"}
                  </Badge>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Associate Existing Zone Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <Card className="w-full max-w-md bg-white dark:bg-[#1f1f1f] shadow-xl rounded-2xl border border-[#E8EAED] dark:border-[#404040]">
            <CardHeader>
              <CardTitle className="text-lg text-[#202124] dark:text-white">Asociar zona segura existente</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">
                Elige una zona segura de otro niño para duplicarla y asignarla a este niño:
              </p>
              <div>
                <select
                  value={selectedZoneId}
                  onChange={(e) => setSelectedZoneId(e.target.value)}
                  className="w-full h-10 rounded-xl border border-[#DADCE0] dark:border-[#404040] bg-white dark:bg-[#262626] px-3 py-2 text-sm text-[#202124] dark:text-white focus:outline-none focus:ring-2 focus:ring-[#1E8E3E]"
                >
                  <option value="">Selecciona una zona...</option>
                  {allExistingZones.map((zone) => (
                    <option key={zone.id} value={zone.id}>
                      {zone.name} ({zone.child_name || "Otro niño"})
                    </option>
                  ))}
                </select>
              </div>
            </CardContent>
            <CardFooter className="flex justify-end gap-3 pt-4 border-t border-[#E8EAED] dark:border-[#404040]">
              <Button
                variant="outline"
                size="sm"
                onClick={() => {
                  setIsModalOpen(false);
                  setSelectedZoneId("");
                }}
                disabled={isCopying}
              >
                Cancelar
              </Button>
              <Button
                size="sm"
                onClick={handleCopyZone}
                disabled={!selectedZoneId || isCopying}
              >
                {isCopying ? "Copiando..." : "Asociar zona"}
              </Button>
            </CardFooter>
          </Card>
        </div>
      )}
    </div>
  );
}
