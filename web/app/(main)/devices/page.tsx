"use client";

import { useEffect, useState } from "react";
import api, { API_ENDPOINTS } from "@/lib/api";
import {
  Card,
  CardContent,
  Button,
  Badge,
  Loading,
  Table,
  TableHeader,
  TableBody,
  TableHead,
  TableRow,
  TableCell,
} from "@/components/ui";
import { formatDateTime, getBatteryColor } from "@/lib/utils";
import { Device, Child } from "@/lib/types";
import {
  Smartphone,
  Battery,
  MapPin,
  Clock,
  Baby,
  Wifi,
  WifiOff,
  Signal,
} from "lucide-react";

export default function DevicesPage() {
  const [devices, setDevices] = useState<Device[]>([]);
  const [children, setChildren] = useState<Child[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [devicesRes, childrenRes] = await Promise.all([
          api.get(API_ENDPOINTS.DEVICES),
          api.get(API_ENDPOINTS.CHILDREN),
        ]);
        setDevices(devicesRes.data.results || devicesRes.data);
        setChildren(childrenRes.data.results || childrenRes.data);
      } catch (err) {
        console.error("Error fetching devices:", err);
        setError("Error al cargar los dispositivos");
      } finally {
        setIsLoading(false);
      }
    };

    fetchData();
  }, []);

  const getChildName = (childId: number | null | undefined, childName?: string | null) => {
    if (childName) return childName;
    if (!childId) return "Sin asignar";
    const child = children.find((c) => c.id === childId);
    return child?.full_name || child?.first_name || `Niño #${childId}`;
  };

  const toggleDeviceStatus = async (deviceId: number, currentStatus: boolean) => {
    try {
      await api.patch(`${API_ENDPOINTS.DEVICES}${deviceId}/`, {
        is_active: !currentStatus,
      });
      setDevices(
        devices.map((d) =>
          d.id === deviceId ? { ...d, is_active: !currentStatus } : d
        )
      );
    } catch (err) {
      console.error("Error updating device:", err);
      alert("Error al actualizar el dispositivo");
    }
  };

  const activeDevices = devices.filter((d) => d.is_active).length;

  if (isLoading) {
    return <Loading text="Cargando dispositivos..." />;
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[#202124] dark:text-white">Dispositivos</h1>
          <p className="text-[#5F6368] dark:text-[#9AA0A6]">
            Gestiona los dispositivos GPS vinculados
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 px-3 py-1.5 bg-[#DCF5E3] dark:bg-[#1E3A2F] rounded-full">
            <Signal className="h-4 w-4 text-[#1E8E3E] dark:text-[#4ade80]" />
            <span className="text-sm font-medium text-[#0D5425] dark:text-[#4ade80]">
              {activeDevices} activos
            </span>
          </div>
          <div className="flex items-center gap-2 px-3 py-1.5 bg-[#F8F9FA] dark:bg-[#262626] rounded-full">
            <Smartphone className="h-4 w-4 text-[#5F6368] dark:text-[#9AA0A6]" />
            <span className="text-sm font-medium text-[#5F6368] dark:text-[#9AA0A6]">
              {devices.length} total
            </span>
          </div>
        </div>
      </div>

      {error && (
        <div className="p-4 bg-[#FCE8E6] dark:bg-[#5C2B29] border border-[#F5C6CB] dark:border-[#8B3A3A] rounded-xl text-[#C5221F] dark:text-[#F28B82]">
          {error}
        </div>
      )}

      {/* Devices List */}
      {devices.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="p-4 bg-[#DCF5E3] dark:bg-[#1E3A2F] rounded-full mb-4">
              <Smartphone className="h-8 w-8 text-[#1E8E3E] dark:text-[#4ade80]" />
            </div>
            <h3 className="text-lg font-medium text-[#202124] dark:text-white mb-2">
              No hay dispositivos registrados
            </h3>
            <p className="text-[#5F6368] dark:text-[#9AA0A6]">
              Los dispositivos se vinculan desde la app móvil
            </p>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Dispositivo</TableHead>
                  <TableHead>Niño asignado</TableHead>
                  <TableHead>Tipo</TableHead>
                  <TableHead>Batería</TableHead>
                  <TableHead>Ubicación</TableHead>
                  <TableHead>Última conexión</TableHead>
                  <TableHead>En zona segura</TableHead>
                  <TableHead>Estado</TableHead>
                  <TableHead className="text-right">Acciones</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {devices.map((device) => (
                  <TableRow key={device.id}>
                    <TableCell>
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-[#E8F0FE] dark:bg-[#1A3A5C] flex items-center justify-center flex-shrink-0">
                          <Smartphone className="h-5 w-5 text-[#1A73E8]" />
                        </div>
                        <div>
                          <p className="font-medium text-[#202124] dark:text-white">
                            {device.device_id}
                          </p>
                          <p className="text-xs text-[#5F6368] dark:text-[#9AA0A6]">ID: {device.id}</p>
                        </div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Baby className="h-4 w-4 text-[#1E8E3E] dark:text-[#4ade80]" />
                        <span className="text-[#202124] dark:text-white">
                          {getChildName(device.child, device.child_name)}
                        </span>
                      </div>
                    </TableCell>
                    <TableCell>
                      <span className="text-[#5F6368] dark:text-[#9AA0A6]">
                        {device.device_type || "GPS Tracker"}
                      </span>
                    </TableCell>
                    <TableCell>
                      {device.battery_level !== null ? (
                        <div className="flex items-center gap-2">
                          <Battery
                            className={`h-4 w-4 ${getBatteryColor(device.battery_level)}`}
                          />
                          <span className="text-[#202124] dark:text-white">{device.battery_level}%</span>
                        </div>
                      ) : (
                        <span className="text-[#9AA0A6]">-</span>
                      )}
                    </TableCell>
                    <TableCell>
                      {device.last_latitude && device.last_longitude ? (
                        <a
                          href={`https://www.google.com/maps?q=${device.last_latitude},${device.last_longitude}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center gap-1 text-[#1A73E8] hover:underline"
                        >
                          <MapPin className="h-4 w-4" />
                          Ver mapa
                        </a>
                      ) : (
                        <span className="text-[#9AA0A6]">Sin ubicación</span>
                      )}
                    </TableCell>
                    <TableCell>
                      {device.last_seen ? (
                        <div className="flex items-center gap-2 text-[#5F6368] dark:text-[#9AA0A6]">
                          <Clock className="h-4 w-4" />
                          <span className="text-sm">
                            {formatDateTime(device.last_seen)}
                          </span>
                        </div>
                      ) : (
                        <span className="text-[#9AA0A6]">Nunca</span>
                      )}
                    </TableCell>
                    <TableCell>
                      {device.is_in_safe_zone === true ? (
                        <Badge variant="success">Sí</Badge>
                      ) : device.is_in_safe_zone === false ? (
                        <Badge variant="danger">No</Badge>
                      ) : (
                        <Badge variant="default">-</Badge>
                      )}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        {device.is_active ? (
                          <Wifi className="h-4 w-4 text-[#1E8E3E] dark:text-[#4ade80]" />
                        ) : (
                          <WifiOff className="h-4 w-4 text-[#D93025]" />
                        )}
                        <Badge variant={device.is_active ? "success" : "danger"}>
                          {device.is_active ? "Activo" : "Inactivo"}
                        </Badge>
                      </div>
                    </TableCell>
                    <TableCell className="text-right">
                      <Button
                        variant={device.is_active ? "outline" : "default"}
                        size="sm"
                        onClick={() => toggleDeviceStatus(device.id, device.is_active)}
                      >
                        {device.is_active ? "Desactivar" : "Activar"}
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
