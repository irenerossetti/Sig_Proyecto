"use client";

import { useState, useEffect } from "react";
import api, { API_ENDPOINTS } from "@/lib/api";
import { Card, CardContent, Loading } from "@/components/ui";
import { LiveLocationMap } from "@/components/maps";
import { Child, SafeZone } from "@/lib/types";
import { MapPin, AlertTriangle, Users } from "lucide-react";

export default function LiveMapPage() {
  const [children, setChildren] = useState<Child[]>([]);
  const [safeZones, setSafeZones] = useState<SafeZone[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [childrenRes, zonesRes] = await Promise.all([
          api.get(API_ENDPOINTS.CHILDREN),
          api.get(API_ENDPOINTS.SAFE_ZONES),
        ]);

        setChildren(childrenRes.data.results || childrenRes.data);
        setSafeZones(zonesRes.data.results || zonesRes.data);
      } catch (err) {
        console.error("Error fetching data:", err);
        setError("Error al cargar los datos");
      } finally {
        setIsLoading(false);
      }
    };

    fetchData();
  }, []);

  const handleAlertReceived = (alert: { child_name: string; message: string }) => {
    // Show browser notification if permitted
    if (Notification.permission === "granted") {
      new Notification(`⚠️ Alerta: ${alert.child_name}`, {
        body: alert.message,
        icon: "/icons/icon-192.png",
      });
    }
  };

  // Request notification permission on mount
  useEffect(() => {
    if (Notification.permission === "default") {
      Notification.requestPermission();
    }
  }, []);

  if (isLoading) {
    return <Loading text="Cargando mapa en tiempo real..." />;
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-center">
          <AlertTriangle className="h-12 w-12 text-[#D93025] mx-auto mb-4" />
          <p className="text-[#D93025]">{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[#202124] dark:text-white flex items-center gap-2">
            <MapPin className="h-6 w-6 text-[#1E8E3E] dark:text-[#4ade80]" />
            Mapa en tiempo real
          </h1>
          <p className="text-[#5F6368] dark:text-[#9AA0A6]">
            Visualiza la ubicación de todos los niños en tiempo real
          </p>
        </div>
        
        <div className="flex items-center gap-2 px-4 py-2 bg-[#F8F9FA] dark:bg-[#262626] rounded-xl">
          <Users className="h-4 w-4 text-[#5F6368] dark:text-[#9AA0A6]" />
          <span className="text-sm font-medium text-[#202124] dark:text-white">
            {children.length} niños registrados
          </span>
        </div>
      </div>

      {/* Live map */}
      <LiveLocationMap
        childrenData={children}
        safeZones={safeZones}
        height="calc(100vh - 250px)"
        showChildList={true}
        onAlertReceived={handleAlertReceived}
      />

      {/* Legend */}
      <Card>
        <CardContent className="py-4">
          <div className="flex flex-wrap items-center justify-center gap-6 text-sm">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-[#1E8E3E]" />
              <span className="text-[#5F6368] dark:text-[#9AA0A6]">En zona segura</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-[#D93025] animate-pulse" />
              <span className="text-[#5F6368] dark:text-[#9AA0A6]">Fuera de zona</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-6 h-3 rounded bg-[#1E8E3E] opacity-30" />
              <span className="text-[#5F6368] dark:text-[#9AA0A6]">Zona segura</span>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
