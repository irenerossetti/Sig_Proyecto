"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import api, { API_ENDPOINTS } from "@/lib/api";
import { Card, CardHeader, CardTitle, CardContent, Badge, Loading } from "@/components/ui";
import { formatTimeAgo, getAlertTypeLabel, cn, normalizeChildPhoto } from "@/lib/utils";
import { Child, Alert, SafeZone, Device } from "@/lib/types";
import {
  Users,
  Bell,
  MapPin,
  Smartphone,
  AlertTriangle,
  CheckCircle,
  ChevronRight,
  ShieldCheck,
} from "lucide-react";

interface DashboardStats {
  children: Child[];
  alerts: Alert[];
  safeZones: SafeZone[];
  devices: Device[];
}

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [childrenRes, alertsRes, safeZonesRes, devicesRes] = await Promise.all([
          api.get(API_ENDPOINTS.CHILDREN),
          api.get(API_ENDPOINTS.ALERTS),
          api.get(API_ENDPOINTS.SAFE_ZONES),
          api.get(API_ENDPOINTS.DEVICES),
        ]);

        setStats({
          children: (childrenRes.data.results || childrenRes.data).map(normalizeChildPhoto),
          alerts: alertsRes.data.results || alertsRes.data,
          safeZones: safeZonesRes.data.results || safeZonesRes.data,
          devices: devicesRes.data.results || devicesRes.data,
        });
      } catch (err) {
        console.error("Error fetching dashboard data:", err);
        setError("Error al cargar los datos");
      } finally {
        setIsLoading(false);
      }
    };

    fetchData();
  }, []);

  if (isLoading) {
    return <Loading text="Cargando dashboard..." />;
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <p className="text-[#D93025] dark:text-[#f87171]">{error}</p>
      </div>
    );
  }

  const pendingAlerts = stats?.alerts.filter((a) => !a.is_acknowledged) || [];
  const activeDevices = stats?.devices.filter((d) => d.is_active) || [];

  const statCards = [
    {
      title: "Niños registrados",
      value: stats?.children.length || 0,
      icon: Users,
      color: "text-[#1E8E3E] dark:text-[#4ade80]",
      bgColor: "bg-[#DCF5E3] dark:bg-[#22c55e]/15",
      href: "/children",
    },
    {
      title: "Alertas pendientes",
      value: pendingAlerts.length,
      icon: Bell,
      color: pendingAlerts.length > 0 ? "text-[#D93025] dark:text-[#f87171]" : "text-[#1E8E3E] dark:text-[#4ade80]",
      bgColor: pendingAlerts.length > 0 ? "bg-[#FCE8E6] dark:bg-[#ef4444]/15" : "bg-[#DCF5E3] dark:bg-[#22c55e]/15",
      href: "/alerts",
    },
    {
      title: "Zonas seguras",
      value: stats?.safeZones.length || 0,
      icon: MapPin,
      color: "text-[#1A73E8] dark:text-[#60a5fa]",
      bgColor: "bg-[#E8F0FE] dark:bg-[#3b82f6]/15",
      href: "/safe-zones",
    },
    {
      title: "Dispositivos activos",
      value: activeDevices.length,
      icon: Smartphone,
      color: "text-[#0D5425] dark:text-[#4ade80]",
      bgColor: "bg-[#DCF5E3] dark:bg-[#22c55e]/15",
      href: "/children",
    },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[#202124] dark:text-[#fafafa]">Dashboard</h1>
          <p className="text-[#5F6368] dark:text-[#a3a3a3]">Resumen del sistema de monitoreo</p>
        </div>
        <div className="flex items-center gap-2 px-3 py-1.5 bg-[#DCF5E3] dark:bg-[#22c55e]/15 rounded-full">
          <ShieldCheck className="h-4 w-4 text-[#1E8E3E] dark:text-[#4ade80]" />
          <span className="text-sm font-medium text-[#0D5425] dark:text-[#4ade80]">Sistema activo</span>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {statCards.map((stat) => (
          <Link key={stat.title} href={stat.href}>
            <Card className="hover:shadow-md transition-shadow cursor-pointer">
              <CardContent className="pt-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-[#5F6368] dark:text-[#a3a3a3]">{stat.title}</p>
                    <p className="text-3xl font-bold mt-1 text-[#202124] dark:text-[#fafafa]">{stat.value}</p>
                  </div>
                  <div className={cn("p-3 rounded-full", stat.bgColor)}>
                    <stat.icon className={cn("h-6 w-6", stat.color)} />
                  </div>
                </div>
              </CardContent>
            </Card>
          </Link>
        ))}
      </div>

      {/* Content Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Alerts */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-lg text-[#202124] dark:text-[#fafafa]">Alertas recientes</CardTitle>
            <Link
              href="/alerts"
              className="text-sm text-[#1E8E3E] dark:text-[#4ade80] hover:underline flex items-center gap-1"
            >
              Ver todas <ChevronRight className="h-4 w-4" />
            </Link>
          </CardHeader>
          <CardContent>
            {stats?.alerts.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-8 text-[#5F6368] dark:text-[#a3a3a3]">
                <CheckCircle className="h-12 w-12 text-[#1E8E3E] dark:text-[#4ade80] mb-2" />
                <p>No hay alertas</p>
              </div>
            ) : (
              <div className="space-y-3">
                {stats?.alerts.slice(0, 5).map((alert) => (
                  <div
                    key={alert.id}
                    className="flex items-start gap-3 p-3 rounded-xl"
                  >
                    <div
                      className={cn(
                        "p-2 rounded-full",
                        alert.is_acknowledged 
                          ? "bg-[#E8EAED] dark:bg-[#404040]" 
                          : "bg-[#FCE8E6] dark:bg-[#ef4444]/15"
                      )}
                    >
                      <AlertTriangle
                        className={cn(
                          "h-4 w-4",
                          alert.is_acknowledged 
                            ? "text-[#5F6368] dark:text-[#a3a3a3]" 
                            : "text-[#D93025] dark:text-[#f87171]"
                        )}
                      />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <p className="font-medium text-sm truncate text-[#202124] dark:text-[#fafafa]">
                          {alert.child_name}
                        </p>
                        <Badge
                          variant={alert.is_acknowledged ? "default" : "danger"}
                          className="text-xs"
                        >
                          {getAlertTypeLabel(alert.alert_type)}
                        </Badge>
                      </div>
                      <p className="text-sm text-[#5F6368] dark:text-[#a3a3a3] truncate">
                        {alert.message}
                      </p>
                      <p className="text-xs text-[#9AA0A6] dark:text-[#737373] mt-1">
                        {formatTimeAgo(alert.created_at)}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Children Status */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-lg text-[#202124] dark:text-[#fafafa]">Niños registrados</CardTitle>
            <Link
              href="/children"
              className="text-sm text-[#1E8E3E] dark:text-[#4ade80] hover:underline flex items-center gap-1"
            >
              Ver todos <ChevronRight className="h-4 w-4" />
            </Link>
          </CardHeader>
          <CardContent>
            {stats?.children.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-8 text-[#5F6368] dark:text-[#a3a3a3]">
                <Users className="h-12 w-12 text-[#DADCE0] dark:text-[#404040] mb-2" />
                <p>No hay niños registrados</p>
                <Link href="/children/new" className="text-[#1E8E3E] dark:text-[#4ade80] hover:underline mt-2 text-sm">
                  Agregar niño
                </Link>
              </div>
            ) : (
              <div className="space-y-3">
                {stats?.children.slice(0, 5).map((child) => (
                  <Link
                    key={child.id}
                    href={`/children/${child.id}`}
                    className="flex items-center gap-3 p-3 rounded-xl hover:bg-[#F8F9FA] dark:hover:bg-[#171717] transition-colors"
                  >
                    <div className="w-10 h-10 rounded-full bg-[#DCF5E3] dark:bg-[#22c55e]/15 flex items-center justify-center overflow-hidden">
                      {child.photo ? (
                        <Image
                          src={child.photo}
                          alt={child.full_name || "Niño"}
                          width={40}
                          height={40}
                          className="w-10 h-10 rounded-full object-cover"
                          unoptimized
                        />
                      ) : (
                        <span className="text-[#1E8E3E] dark:text-[#4ade80] font-medium">
                          {(child.full_name || "N")[0]}
                        </span>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-sm text-[#202124] dark:text-[#fafafa]">
                        {child.full_name || `${child.first_name || ""} ${child.last_name || ""}`.trim() || "Sin nombre"}
                      </p>
                      <p className="text-xs text-[#5F6368] dark:text-[#a3a3a3]">{child.grade || "Sin grado"}</p>
                    </div>
                    <Badge variant={child.device ? "success" : "default"}>
                      {child.device ? "Conectado" : "Sin dispositivo"}
                    </Badge>
                  </Link>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
