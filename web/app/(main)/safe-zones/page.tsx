"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
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
import { getZoneTypeLabel } from "@/lib/utils";
import { SafeZone, Child } from "@/lib/types";
import { Plus, MapPin, Eye, Edit, Trash2 } from "lucide-react";

export default function SafeZonesPage() {
  const [safeZones, setSafeZones] = useState<SafeZone[]>([]);
  const [children, setChildren] = useState<Child[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [zonesRes, childrenRes] = await Promise.all([
          api.get(API_ENDPOINTS.SAFE_ZONES),
          api.get(API_ENDPOINTS.CHILDREN),
        ]);

        setSafeZones(zonesRes.data.results || zonesRes.data);
        setChildren(childrenRes.data.results || childrenRes.data);
      } catch (err) {
        console.error("Error fetching safe zones:", err);
        setError("Error al cargar las zonas seguras");
      } finally {
        setIsLoading(false);
      }
    };

    fetchData();
  }, []);

  const deleteZone = async (id: number) => {
    if (!confirm("¿Estás seguro de eliminar esta zona segura?")) return;

    try {
      await api.delete(`${API_ENDPOINTS.SAFE_ZONES}${id}/`);
      setSafeZones(safeZones.filter((z) => z.id !== id));
    } catch (err) {
      console.error("Error deleting zone:", err);
      alert("Error al eliminar la zona");
    }
  };

  const getChildName = (childId: number) => {
    const child = children.find((c) => c.id === childId);
    return child ? `${child.first_name} ${child.last_name}` : "Desconocido";
  };

  const getZoneTypeBadgeVariant = (type: string) => {
    switch (type) {
      case "school":
        return "info";
      case "home":
        return "success";
      default:
        return "default";
    }
  };

  if (isLoading) {
    return <Loading text="Cargando zonas seguras..." />;
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[#202124] dark:text-white">Zonas Seguras</h1>
          <p className="text-[#5F6368] dark:text-[#9AA0A6]">
            Configura las áreas donde los niños deberían estar
          </p>
        </div>
        <Link href="/safe-zones/new">
          <Button className="gap-2">
            <Plus className="h-4 w-4" />
            Nueva zona
          </Button>
        </Link>
      </div>

      {error && (
        <div className="p-4 bg-[#FCE8E6] dark:bg-[#5C2B29] border border-[#F5C6CB] dark:border-[#8B3A3A] rounded-xl text-[#C5221F] dark:text-[#F28B82]">
          {error}
        </div>
      )}

      {/* Zones List */}
      {safeZones.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="p-4 bg-[#DCF5E3] dark:bg-[#1E3A2F] rounded-full mb-4">
              <MapPin className="h-8 w-8 text-[#1E8E3E] dark:text-[#4ade80]" />
            </div>
            <h3 className="text-lg font-medium text-[#202124] dark:text-white mb-2">
              No hay zonas seguras
            </h3>
            <p className="text-[#5F6368] dark:text-[#9AA0A6] mb-4">
              Crea zonas seguras para monitorear a los niños
            </p>
            <Link href="/safe-zones/new">
              <Button>Crear zona segura</Button>
            </Link>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Nombre</TableHead>
                  <TableHead>Tipo</TableHead>
                  <TableHead>Niño</TableHead>
                  <TableHead>Radio</TableHead>
                  <TableHead>Estado</TableHead>
                  <TableHead>Coordenadas</TableHead>
                  <TableHead className="text-right">Acciones</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {safeZones.map((zone) => (
                  <TableRow key={zone.id}>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <MapPin className="h-4 w-4 text-[#1E8E3E] dark:text-[#4ade80]" />
                        <div>
                          <p className="font-medium text-[#202124] dark:text-white">{zone.name}</p>
                          <p className="text-xs text-[#5F6368] dark:text-[#9AA0A6] truncate max-w-[200px]">
                            {zone.description}
                          </p>
                        </div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant={getZoneTypeBadgeVariant(zone.zone_type) as "default" | "success" | "warning" | "danger" | "info"}>
                        {getZoneTypeLabel(zone.zone_type)}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-[#202124] dark:text-white">{zone.child_name || getChildName(zone.child)}</TableCell>
                    <TableCell className="text-[#202124] dark:text-white">{zone.radius_meters || zone.radius || "-"}m</TableCell>
                    <TableCell>
                      <Badge variant={zone.is_active ? "success" : "default"}>
                        {zone.is_active ? "Activa" : "Inactiva"}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      {zone.zone_type === 'polygon' && zone.polygon_points && zone.polygon_points.length > 0 ? (
                        <span className="text-xs text-[#5F6368] dark:text-[#9AA0A6]">
                          {zone.polygon_points.length} puntos
                        </span>
                      ) : (zone.center_latitude || zone.latitude) ? (
                        <span className="text-xs text-[#5F6368] dark:text-[#9AA0A6]">
                          {(zone.center_latitude || zone.latitude)?.toFixed(4)}, {(zone.center_longitude || zone.longitude)?.toFixed(4)}
                        </span>
                      ) : (
                        <span className="text-xs text-[#9AA0A6]">-</span>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex items-center justify-end gap-1">
                        <Link href={`/safe-zones/${zone.id}`}>
                          <Button variant="ghost" size="icon" title="Ver">
                            <Eye className="h-4 w-4" />
                          </Button>
                        </Link>
                        <Link href={`/safe-zones/${zone.id}/edit`}>
                          <Button variant="ghost" size="icon" title="Editar">
                            <Edit className="h-4 w-4" />
                          </Button>
                        </Link>
                        <Button
                          variant="ghost"
                          size="icon"
                          title="Eliminar"
                          onClick={() => deleteZone(zone.id)}
                        >
                          <Trash2 className="h-4 w-4 text-[#D93025]" />
                        </Button>
                      </div>
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
