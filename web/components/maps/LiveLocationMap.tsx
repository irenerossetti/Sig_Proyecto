"use client";

import { useEffect, useState, useCallback, useRef } from "react";
import GoogleMapsContainer from "./GoogleMapsContainer";
import type { MapPolygonData, MapCircleData, MapMarker } from "./GoogleMapView";
import { webSocketService, LocationUpdate, AlertUpdate, WebSocketMessage } from "@/lib/websocket";
import { Child, SafeZone } from "@/lib/types";
import { Badge, Button } from "@/components/ui";
import { 
  Wifi, WifiOff, Battery, BatteryLow, BatteryWarning, 
  MapPin, AlertTriangle, RefreshCw, Users, Clock
} from "lucide-react";
import { formatDistanceToNow } from "date-fns";
import { es } from "date-fns/locale";

export interface ChildLocation {
  childId: number;
  childName: string;
  latitude: number;
  longitude: number;
  batteryLevel: number | null;
  isInSafeZone: boolean;
  lastUpdate: Date;
}

export interface LiveLocationMapProps {
  childrenData: Child[];
  safeZones: SafeZone[];
  height?: string;
  showChildList?: boolean;
  onAlertReceived?: (alert: AlertUpdate) => void;
  className?: string;
}

export default function LiveLocationMap({
  childrenData,
  safeZones,
  height = "500px",
  showChildList = true,
  onAlertReceived,
  className = "",
}: LiveLocationMapProps) {
  const [isConnected, setIsConnected] = useState(false);
  const [childLocations, setChildLocations] = useState<Map<number, ChildLocation>>(new Map());
  const [recentAlerts, setRecentAlerts] = useState<AlertUpdate[]>([]);
  const [selectedChild, setSelectedChild] = useState<number | null>(null);
  const [autoCenter] = useState(true);
  const connectAttempted = useRef(false);

  // Initialize locations from device data
  useEffect(() => {
    const initialLocations = new Map<number, ChildLocation>();
    
    childrenData.forEach((child) => {
      if (child.device?.last_latitude && child.device?.last_longitude) {
        initialLocations.set(child.id, {
          childId: child.id,
          childName: child.full_name,
          latitude: child.device.last_latitude,
          longitude: child.device.last_longitude,
          batteryLevel: child.device.battery_level,
          isInSafeZone: child.device.is_in_safe_zone ?? true,
          lastUpdate: child.device.last_seen ? new Date(child.device.last_seen) : new Date(),
        });
      }
    });
    
    if (initialLocations.size > 0) {
      setChildLocations(initialLocations);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [childrenData.length]);

  // Connect to WebSocket
  useEffect(() => {
    if (connectAttempted.current) return;
    connectAttempted.current = true;

    const handleMessage = (message: WebSocketMessage) => {
      if (message.type === "location_update") {
        const update = message as LocationUpdate;
        setChildLocations((prev) => {
          const newMap = new Map(prev);
          newMap.set(update.child_id, {
            childId: update.child_id,
            childName: update.child_name,
            latitude: update.latitude,
            longitude: update.longitude,
            batteryLevel: update.battery_level,
            isInSafeZone: update.is_in_safe_zone,
            lastUpdate: new Date(update.timestamp),
          });
          return newMap;
        });
      } else if (message.type === "alert") {
        const alert = message as AlertUpdate;
        setRecentAlerts((prev) => [alert, ...prev.slice(0, 9)]);
        onAlertReceived?.(alert);
      }
    };

    const handleConnection = (connected: boolean) => {
      setIsConnected(connected);
      
      if (connected) {
        // Subscribe to all children
        const childIds = childrenData.map((c) => c.id);
        webSocketService.subscribeToAllChildren(childIds);
      }
    };

    const unsubMessage = webSocketService.onMessage(handleMessage);
    const unsubConnection = webSocketService.onConnectionChange(handleConnection);
    
    webSocketService.connect();

    return () => {
      unsubMessage();
      unsubConnection();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [childrenData.length, onAlertReceived]);

  // Prepare map markers
  const markers: MapMarker[] = Array.from(childLocations.values()).map((loc) => ({
    id: String(loc.childId),
    position: { lat: loc.latitude, lng: loc.longitude },
    label: loc.childName,
    icon: loc.isInSafeZone ? "child" : "alert",
    color: loc.isInSafeZone ? "#1E8E3E" : "#D93025",
    popup: `
      <div style="min-width: 150px; font-family: Roboto, sans-serif;">
        <strong>${loc.childName}</strong><br/>
        <span style="color: ${loc.isInSafeZone ? '#1E8E3E' : '#D93025'}">
          ${loc.isInSafeZone ? '✓ En zona segura' : '⚠ Fuera de zona'}
        </span><br/>
        ${loc.batteryLevel !== null ? `🔋 ${loc.batteryLevel}%<br/>` : ''}
        <small>Actualizado: ${formatDistanceToNow(loc.lastUpdate, { addSuffix: true, locale: es })}</small>
      </div>
    `,
  }));

  // Prepare safe zone polygons and circles
  const mapPolygons: MapPolygonData[] = safeZones
    .filter((z) => z.zone_type === "polygon" && z.polygon_points && z.polygon_points.length >= 3)
    .map((zone) => ({
      id: String(zone.id),
      points: zone.polygon_points!.map((p) => ({ lat: p.lat, lng: p.lng })),
      color: zone.color || "#1E8E3E",
      fillOpacity: 0.2,
      label: zone.name,
    }));

  const mapCircles: MapCircleData[] = safeZones
    .filter((z) => z.zone_type === "circle" && z.center_latitude && z.center_longitude)
    .map((zone) => ({
      id: String(zone.id),
      center: { lat: zone.center_latitude!, lng: zone.center_longitude! },
      radius: zone.radius_meters || zone.radius || 100,
      color: zone.color || "#1E8E3E",
      fillOpacity: 0.2,
      label: zone.name,
    }));

  // Calculate map center
  const getMapCenter = useCallback((): { lat: number; lng: number } => {
    if (selectedChild) {
      const loc = childLocations.get(selectedChild);
      if (loc) return { lat: loc.latitude, lng: loc.longitude };
    }
    
    if (childLocations.size > 0 && autoCenter) {
      const locs = Array.from(childLocations.values());
      const avgLat = locs.reduce((sum, l) => sum + l.latitude, 0) / locs.length;
      const avgLng = locs.reduce((sum, l) => sum + l.longitude, 0) / locs.length;
      return { lat: avgLat, lng: avgLng };
    }
    
    return { lat: -17.7833, lng: -63.1821 }; // Santa Cruz default
  }, [selectedChild, childLocations, autoCenter]);

  const getBatteryIcon = (level: number | null) => {
    if (level === null) return Battery;
    if (level <= 20) return BatteryWarning;
    if (level <= 40) return BatteryLow;
    return Battery;
  };

  const reconnect = () => {
    webSocketService.disconnect();
    setTimeout(() => webSocketService.connect(), 500);
  };

  return (
    <div className={`flex flex-col lg:flex-row gap-4 ${className}`}>
      {/* Map */}
      <div className={`flex-1 ${showChildList ? "lg:w-2/3" : "w-full"}`}>
        <div className="bg-white dark:bg-[#171717] rounded-xl shadow-sm overflow-hidden">
          {/* Connection status bar */}
          <div className="flex items-center justify-between px-4 py-2 bg-[#F8F9FA] dark:bg-[#262626] border-b border-[#E8EAED] dark:border-[#404040]">
            <div className="flex items-center gap-2">
              {isConnected ? (
                <>
                  <Wifi className="h-4 w-4 text-[#1E8E3E]" />
                  <span className="text-sm text-[#1E8E3E] font-medium">Conectado en tiempo real</span>
                </>
              ) : (
                <>
                  <WifiOff className="h-4 w-4 text-[#D93025]" />
                  <span className="text-sm text-[#D93025] font-medium">Desconectado</span>
                </>
              )}
            </div>
            
            <div className="flex items-center gap-2">
              <Badge variant={isConnected ? "success" : "danger"}>
                <Users className="h-3 w-3 mr-1" />
                {childLocations.size} ubicaciones
              </Badge>
              
              <Button
                variant="ghost"
                size="icon"
                onClick={reconnect}
                title="Reconectar"
              >
                <RefreshCw className={`h-4 w-4 ${!isConnected ? "animate-spin" : ""}`} />
              </Button>
            </div>
          </div>
          
          <GoogleMapsContainer
            center={getMapCenter()}
            zoom={15}
            height={height}
            markers={markers}
            polygons={mapPolygons}
            circles={mapCircles}
            mapTypeId="hybrid"
          />
        </div>
      </div>

      {/* Child list sidebar */}
      {showChildList && (
        <div className="lg:w-1/3 space-y-4">
          {/* Children status */}
          <div className="bg-white dark:bg-[#171717] rounded-xl shadow-sm p-4">
            <h3 className="text-sm font-semibold text-[#202124] dark:text-white mb-3 flex items-center gap-2">
              <MapPin className="h-4 w-4 text-[#1E8E3E]" />
              Ubicaciones de niños
            </h3>
            
            <div className="space-y-2 max-h-[300px] overflow-y-auto">
              {Array.from(childLocations.values()).map((loc) => {
                const BatteryIcon = getBatteryIcon(loc.batteryLevel);
                
                return (
                  <button
                    key={loc.childId}
                    onClick={() => setSelectedChild(loc.childId === selectedChild ? null : loc.childId)}
                    className={`w-full p-3 rounded-xl text-left transition-colors ${
                      selectedChild === loc.childId
                        ? "bg-[#DCF5E3] dark:bg-[#1E3A2F]"
                        : "bg-[#F8F9FA] dark:bg-[#262626] hover:bg-[#E8EAED] dark:hover:bg-[#404040]"
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <div className={`w-2 h-2 rounded-full ${loc.isInSafeZone ? "bg-[#1E8E3E]" : "bg-[#D93025] animate-pulse"}`} />
                        <span className="font-medium text-[#202124] dark:text-white text-sm">
                          {loc.childName}
                        </span>
                      </div>
                      
                      {loc.batteryLevel !== null && (
                        <div className={`flex items-center gap-1 text-xs ${
                          loc.batteryLevel <= 20 ? "text-[#D93025]" : "text-[#5F6368] dark:text-[#9AA0A6]"
                        }`}>
                          <BatteryIcon className="h-3 w-3" />
                          {loc.batteryLevel}%
                        </div>
                      )}
                    </div>
                    
                    <div className="flex items-center gap-2 mt-1">
                      <Badge
                        variant={loc.isInSafeZone ? "success" : "danger"}
                        className="text-xs"
                      >
                        {loc.isInSafeZone ? "En zona" : "Fuera"}
                      </Badge>
                      
                      <span className="text-xs text-[#9AA0A6] flex items-center gap-1">
                        <Clock className="h-3 w-3" />
                        {formatDistanceToNow(loc.lastUpdate, { addSuffix: true, locale: es })}
                      </span>
                    </div>
                  </button>
                );
              })}
              
              {childLocations.size === 0 && (
                <div className="text-center py-8 text-[#5F6368] dark:text-[#9AA0A6]">
                  <MapPin className="h-8 w-8 mx-auto mb-2 opacity-50" />
                  <p className="text-sm">No hay ubicaciones disponibles</p>
                  <p className="text-xs mt-1">Los niños aparecerán cuando sus dispositivos envíen ubicación</p>
                </div>
              )}
            </div>
          </div>

          {/* Recent alerts */}
          {recentAlerts.length > 0 && (
            <div className="bg-white dark:bg-[#171717] rounded-xl shadow-sm p-4">
              <h3 className="text-sm font-semibold text-[#202124] dark:text-white mb-3 flex items-center gap-2">
                <AlertTriangle className="h-4 w-4 text-[#D93025]" />
                Alertas recientes
              </h3>
              
              <div className="space-y-2 max-h-[200px] overflow-y-auto">
                {recentAlerts.map((alert, index) => (
                  <div
                    key={`${alert.alert_id}-${index}`}
                    className="p-2 bg-[#FCE8E6] dark:bg-[#5C2B29] rounded-lg"
                  >
                    <p className="text-sm font-medium text-[#D93025] dark:text-[#f87171]">
                      {alert.child_name}
                    </p>
                    <p className="text-xs text-[#5F6368] dark:text-[#9AA0A6] mt-0.5">
                      {alert.message}
                    </p>
                    <p className="text-xs text-[#9AA0A6] mt-1">
                      {formatDistanceToNow(new Date(alert.created_at), { addSuffix: true, locale: es })}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
