"use client";

import { useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
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
import { formatDateTime, getAlertTypeLabel, formatTimeAgo } from "@/lib/utils";
import { Alert } from "@/lib/types";
import { Bell, Check, AlertTriangle, MapPin } from "lucide-react";
import { cn } from "@/lib/utils";

export default function AlertsPage() {
  const searchParams = useSearchParams();
  const childFilter = searchParams.get("child");

  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<"all" | "pending" | "acknowledged">("all");

  useEffect(() => {
    const fetchAlerts = async () => {
      try {
        const response = await api.get(API_ENDPOINTS.ALERTS);
        let data = response.data.results || response.data;
        
        // Filter by child if specified
        if (childFilter) {
          data = data.filter((a: Alert) => a.child === parseInt(childFilter));
        }
        
        setAlerts(data);
      } catch (err) {
        console.error("Error fetching alerts:", err);
        setError("Error al cargar las alertas");
      } finally {
        setIsLoading(false);
      }
    };

    fetchAlerts();
  }, [childFilter]);

  const acknowledgeAlert = async (alertId: number) => {
    try {
      await api.patch(`${API_ENDPOINTS.ALERTS}${alertId}/`, {
        is_acknowledged: true,
      });
      setAlerts(
        alerts.map((a) =>
          a.id === alertId
            ? { ...a, is_acknowledged: true, acknowledged_at: new Date().toISOString() }
            : a
        )
      );
    } catch (err: unknown) {
      console.error("Error acknowledging alert:", err);
      const axiosErr = err as { response?: { status?: number } };
      if (axiosErr.response?.status === 404) {
        // Si el endpoint no soporta PATCH, actualizar solo localmente
        setAlerts(
          alerts.map((a) =>
            a.id === alertId
              ? { ...a, is_acknowledged: true, acknowledged_at: new Date().toISOString() }
              : a
          )
        );
      }
    }
  };

  const acknowledgeAll = async () => {
    try {
      const pendingAlerts = alerts.filter((a) => !a.is_acknowledged);
      await Promise.all(
        pendingAlerts.map((a) =>
          api.patch(`${API_ENDPOINTS.ALERTS}${a.id}/`, { is_acknowledged: true })
        )
      );
      setAlerts(
        alerts.map((a) => ({
          ...a,
          is_acknowledged: true,
          acknowledged_at: new Date().toISOString(),
        }))
      );
    } catch (err: unknown) {
      console.error("Error acknowledging all alerts:", err);
      // Si falla, actualizar solo localmente
      const axiosErr = err as { response?: { status?: number } };
      if (axiosErr.response?.status === 404) {
        setAlerts(
          alerts.map((a) => ({
            ...a,
            is_acknowledged: true,
            acknowledged_at: new Date().toISOString(),
          }))
        );
      }
    }
  };

  const filteredAlerts = alerts.filter((alert) => {
    if (filter === "pending") return !alert.is_acknowledged;
    if (filter === "acknowledged") return alert.is_acknowledged;
    return true;
  });

  const pendingCount = alerts.filter((a) => !a.is_acknowledged).length;

  if (isLoading) {
    return <Loading text="Cargando alertas..." />;
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[#202124] dark:text-white">Alertas</h1>
          <p className="text-[#5F6368] dark:text-[#9AA0A6]">
            {pendingCount > 0
              ? `${pendingCount} alerta${pendingCount > 1 ? "s" : ""} pendiente${
                  pendingCount > 1 ? "s" : ""
                }`
              : "No hay alertas pendientes"}
          </p>
        </div>
        {pendingCount > 0 && (
          <Button onClick={acknowledgeAll} variant="outline" className="gap-2">
            <Check className="h-4 w-4" />
            Marcar todas como leídas
          </Button>
        )}
      </div>

      {error && (
        <div className="p-4 bg-[#FCE8E6] dark:bg-[#5C2B29] border border-[#F5C6CB] dark:border-[#8B3A3A] rounded-xl text-[#C5221F] dark:text-[#F28B82]">
          {error}
        </div>
      )}

      {/* Filters */}
      <div className="flex gap-2">
        <Button
          variant={filter === "all" ? "default" : "outline"}
          size="sm"
          onClick={() => setFilter("all")}
        >
          Todas ({alerts.length})
        </Button>
        <Button
          variant={filter === "pending" ? "default" : "outline"}
          size="sm"
          onClick={() => setFilter("pending")}
        >
          Pendientes ({pendingCount})
        </Button>
        <Button
          variant={filter === "acknowledged" ? "default" : "outline"}
          size="sm"
          onClick={() => setFilter("acknowledged")}
        >
          Leídas ({alerts.length - pendingCount})
        </Button>
      </div>

      {/* Alerts List */}
      {filteredAlerts.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="p-4 bg-[#DCF5E3] dark:bg-[#1E3A2F] rounded-full mb-4">
              <Bell className="h-8 w-8 text-[#1E8E3E] dark:text-[#4ade80]" />
            </div>
            <h3 className="text-lg font-medium text-[#202124] dark:text-white mb-2">
              {filter === "pending"
                ? "No hay alertas pendientes"
                : filter === "acknowledged"
                ? "No hay alertas leídas"
                : "No hay alertas"}
            </h3>
            <p className="text-[#5F6368] dark:text-[#9AA0A6]">
              {filter === "pending"
                ? "¡Excelente! Todos los niños están seguros"
                : "Las alertas aparecerán aquí cuando ocurran eventos"}
            </p>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Estado</TableHead>
                  <TableHead>Niño</TableHead>
                  <TableHead>Tipo</TableHead>
                  <TableHead>Mensaje</TableHead>
                  <TableHead>Zona</TableHead>
                  <TableHead>Fecha</TableHead>
                  <TableHead className="text-right">Acción</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredAlerts.map((alert) => (
                  <TableRow
                    key={alert.id}
                    className={cn(!alert.is_acknowledged && "bg-[#FCE8E6] dark:bg-[#5C2B29]/30")}
                  >
                    <TableCell>
                      <div
                        className={cn(
                          "p-2 rounded-full w-fit",
                          alert.is_acknowledged ? "bg-[#E8EAED] dark:bg-[#404040]" : "bg-[#FCE8E6] dark:bg-[#5C2B29]"
                        )}
                      >
                        <AlertTriangle
                          className={cn(
                            "h-4 w-4",
                            alert.is_acknowledged
                              ? "text-[#5F6368] dark:text-[#9AA0A6]"
                              : "text-[#D93025]"
                          )}
                        />
                      </div>
                    </TableCell>
                    <TableCell className="font-medium text-[#202124] dark:text-white">
                      {alert.child_name}
                    </TableCell>
                    <TableCell>
                      <Badge
                        variant={
                          alert.alert_type === "exit"
                            ? "danger"
                            : alert.alert_type === "enter"
                            ? "success"
                            : alert.alert_type === "low_battery"
                            ? "warning"
                            : "default"
                        }
                      >
                        {getAlertTypeLabel(alert.alert_type)}
                      </Badge>
                    </TableCell>
                    <TableCell className="max-w-xs truncate text-[#5F6368] dark:text-[#9AA0A6]">
                      {alert.message}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-1">
                        <MapPin className="h-3 w-3 text-[#9AA0A6]" />
                        <span className="text-[#5F6368] dark:text-[#9AA0A6]">{alert.safe_zone_name || "-"}</span>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div>
                        <div className="text-sm text-[#202124] dark:text-white">{formatTimeAgo(alert.created_at)}</div>
                        <div className="text-xs text-[#9AA0A6]">
                          {formatDateTime(alert.created_at)}
                        </div>
                      </div>
                    </TableCell>
                    <TableCell className="text-right">
                      {!alert.is_acknowledged && (
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => acknowledgeAlert(alert.id)}
                          className="gap-1"
                        >
                          <Check className="h-4 w-4" />
                          Marcar leída
                        </Button>
                      )}
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
