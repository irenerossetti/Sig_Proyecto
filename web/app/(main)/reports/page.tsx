"use client";

import { useEffect, useState, useMemo } from "react";
import api, { API_ENDPOINTS } from "@/lib/api";
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  Button,
  Loading,
} from "@/components/ui";
import { Child, Alert, SafeZone, Device, User } from "@/lib/types";
import {
  BarChart3,
  TrendingUp,
  Users,
  Baby,
  Bell,
  MapPin,
  Smartphone,
  AlertTriangle,
  CheckCircle,
  Activity,
  Download,
  FileText,
  RefreshCw,
} from "lucide-react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Legend,
  AreaChart,
  Area,
} from "recharts";
import { format } from "date-fns";

interface ReportStats {
  children: Child[];
  alerts: Alert[];
  safeZones: SafeZone[];
  devices: Device[];
  users: User[];
}

type DateRange = "today" | "week" | "month";

// Custom colors for charts
const COLORS = {
  primary: "#1E8E3E",
  primaryLight: "#4ade80",
  secondary: "#1A73E8",
  secondaryLight: "#60a5fa",
  warning: "#F9AB00",
  warningLight: "#FDD663",
  danger: "#D93025",
  dangerLight: "#f87171",
  purple: "#7C3AED",
  purpleLight: "#a78bfa",
};

const PIE_COLORS = [COLORS.primary, COLORS.secondary, COLORS.warning, COLORS.purple, COLORS.danger];

export default function ReportsPage() {
  const [stats, setStats] = useState<ReportStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [dateRange, setDateRange] = useState<DateRange>("week");
  const [isExporting, setIsExporting] = useState(false);

  const fetchData = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [childrenRes, alertsRes, safeZonesRes, devicesRes, usersRes] = await Promise.all([
        api.get(API_ENDPOINTS.CHILDREN),
        api.get(API_ENDPOINTS.ALERTS),
        api.get(API_ENDPOINTS.SAFE_ZONES),
        api.get(API_ENDPOINTS.DEVICES),
        api.get(API_ENDPOINTS.USERS),
      ]);

      setStats({
        children: childrenRes.data.results || childrenRes.data,
        alerts: alertsRes.data.results || alertsRes.data,
        safeZones: safeZonesRes.data.results || safeZonesRes.data,
        devices: devicesRes.data.results || devicesRes.data,
        users: usersRes.data.results || usersRes.data,
      });
    } catch (err) {
      console.error("Error fetching report data:", err);
      setError("Error al cargar los datos del reporte");
    } finally {
      setIsLoading(false);
    }
  };

  // Export handler - uses local data with optional backend export
  const handleExport = async (exportFormat: "csv" | "json") => {
    if (!stats) return;
    
    setIsExporting(true);
    try {
      // Prepare report data from current stats
      const reportData = {
        generated_at: new Date().toISOString(),
        period: dateRange === "today" ? "Hoy" : dateRange === "week" ? "7 días" : "30 días",
        summary: {
          total_children: stats.children.length,
          total_alerts: stats.alerts.length,
          pending_alerts: stats.alerts.filter(a => !a.is_acknowledged).length,
          total_safe_zones: stats.safeZones.length,
          total_devices: stats.devices.length,
          active_devices: stats.devices.filter(d => d.is_active).length,
        },
        children: stats.children.map(c => ({
          id: c.id,
          name: c.full_name,
          has_device: !!c.device,
          device_status: c.device?.is_active ? "active" : "inactive",
        })),
        alerts: stats.alerts.map(a => ({
          id: a.id,
          child_id: a.child,
          type: a.alert_type,
          message: a.message,
          status: a.is_acknowledged ? "acknowledged" : "pending",
          created_at: a.created_at,
        })),
      };

      let blob: Blob;
      
      if (exportFormat === "csv") {
        // Convert to CSV format
        const csvRows: string[] = [];
        
        // Header section
        csvRows.push("REPORTE GEOGUARD");
        csvRows.push(`Generado: ${reportData.generated_at}`);
        csvRows.push(`Período: ${reportData.period}`);
        csvRows.push("");
        
        // Summary section
        csvRows.push("RESUMEN");
        csvRows.push(`Total de niños,${reportData.summary.total_children}`);
        csvRows.push(`Total de alertas,${reportData.summary.total_alerts}`);
        csvRows.push(`Alertas pendientes,${reportData.summary.pending_alerts}`);
        csvRows.push(`Zonas seguras,${reportData.summary.total_safe_zones}`);
        csvRows.push(`Dispositivos activos,${reportData.summary.active_devices}/${reportData.summary.total_devices}`);
        csvRows.push("");
        
        // Children section
        csvRows.push("NIÑOS");
        csvRows.push("ID,Nombre,Tiene Dispositivo,Estado Dispositivo");
        reportData.children.forEach(c => {
          csvRows.push(`${c.id},${c.name},${c.has_device ? "Sí" : "No"},${c.device_status}`);
        });
        csvRows.push("");
        
        // Alerts section
        csvRows.push("ALERTAS");
        csvRows.push("ID,Niño ID,Tipo,Estado,Fecha");
        reportData.alerts.forEach(a => {
          csvRows.push(`${a.id},${a.child_id},${a.type},${a.status},${a.created_at}`);
        });
        
        blob = new Blob([csvRows.join("\n")], { type: "text/csv;charset=utf-8" });
      } else {
        blob = new Blob([JSON.stringify(reportData, null, 2)], { type: "application/json" });
      }
      
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `reporte_geoguard_${format(new Date(), "yyyyMMdd")}.${exportFormat}`;
      a.click();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error("Error exporting report:", err);
    } finally {
      setIsExporting(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  // Calculate statistics
  const reportData = useMemo(() => {
    if (!stats) return null;

    // Alerts by type
    const alertsByType = stats.alerts.reduce((acc, alert) => {
      const type = alert.alert_type || "other";
      acc[type] = (acc[type] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    const alertTypeLabels: Record<string, string> = {
      zone_exit: "Salida de zona",
      zone_entry: "Entrada a zona",
      exit: "Salida",
      enter: "Entrada",
      low_battery: "Batería baja",
      device_offline: "Dispositivo offline",
      other: "Otro",
    };

    const alertsByTypeData = Object.entries(alertsByType).map(([type, count]) => ({
      name: alertTypeLabels[type] || type,
      value: count,
      type,
    }));

    // Alerts by status
    const pendingAlerts = stats.alerts.filter((a) => !a.is_acknowledged).length;
    const acknowledgedAlerts = stats.alerts.filter((a) => a.is_acknowledged).length;

    const alertsByStatusData = [
      { name: "Pendientes", value: pendingAlerts, color: COLORS.danger },
      { name: "Reconocidas", value: acknowledgedAlerts, color: COLORS.primary },
    ];

    // Devices status
    const activeDevices = stats.devices.filter((d) => d.is_active).length;
    const inactiveDevices = stats.devices.filter((d) => !d.is_active).length;

    const devicesStatusData = [
      { name: "Activos", value: activeDevices, color: COLORS.primary },
      { name: "Inactivos", value: inactiveDevices, color: COLORS.warning },
    ];

    // Children with devices vs without
    const childrenWithDevices = stats.children.filter((c) => c.device).length;
    const childrenWithoutDevices = stats.children.filter((c) => !c.device).length;

    const childrenDeviceData = [
      { name: "Con dispositivo", value: childrenWithDevices, color: COLORS.primary },
      { name: "Sin dispositivo", value: childrenWithoutDevices, color: COLORS.warning },
    ];

    // Alerts over time (last 7 days)
    const last7Days = Array.from({ length: 7 }, (_, i) => {
      const date = new Date();
      date.setDate(date.getDate() - (6 - i));
      return date.toISOString().split("T")[0];
    });

    const alertsByDay = last7Days.map((day) => {
      const count = stats.alerts.filter((a) => a.created_at.startsWith(day)).length;
      const dayName = new Date(day).toLocaleDateString("es-ES", { weekday: "short" });
      return {
        date: day,
        name: dayName.charAt(0).toUpperCase() + dayName.slice(1),
        alertas: count,
      };
    });

    // Safe zones by type
    const zonesByType = stats.safeZones.reduce((acc, zone) => {
      const type = zone.zone_type || "other";
      acc[type] = (acc[type] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    const zoneTypeLabels: Record<string, string> = {
      circle: "Circular",
      polygon: "Polígono",
      school: "Escuela",
      home: "Hogar",
      other: "Otro",
    };

    const zonesByTypeData = Object.entries(zonesByType).map(([type, count]) => ({
      name: zoneTypeLabels[type] || type,
      value: count,
    }));

    // Children per tutor (top 5)
    const childrenPerTutor = stats.users
      .map((user) => ({
        name: user.full_name?.split(" ")[0] || user.email.split("@")[0],
        niños: stats.children.filter((c) => c.tutor === user.id).length,
      }))
      .filter((t) => t.niños > 0)
      .sort((a, b) => b.niños - a.niños)
      .slice(0, 5);

    // Battery levels distribution
    const batteryLevels = stats.devices
      .filter((d) => d.battery_level !== null)
      .map((d) => d.battery_level!);

    const batteryDistribution = [
      { name: "Crítico (0-20%)", value: batteryLevels.filter((b) => b <= 20).length, color: COLORS.danger },
      { name: "Bajo (21-40%)", value: batteryLevels.filter((b) => b > 20 && b <= 40).length, color: COLORS.warning },
      { name: "Medio (41-70%)", value: batteryLevels.filter((b) => b > 40 && b <= 70).length, color: COLORS.secondary },
      { name: "Alto (71-100%)", value: batteryLevels.filter((b) => b > 70).length, color: COLORS.primary },
    ].filter((d) => d.value > 0);

    return {
      alertsByTypeData,
      alertsByStatusData,
      devicesStatusData,
      childrenDeviceData,
      alertsByDay,
      zonesByTypeData,
      childrenPerTutor,
      batteryDistribution,
      totals: {
        children: stats.children.length,
        alerts: stats.alerts.length,
        pendingAlerts,
        safeZones: stats.safeZones.length,
        devices: stats.devices.length,
        activeDevices,
        users: stats.users.length,
      },
    };
  }, [stats]);

  if (isLoading) {
    return <Loading text="Cargando reportes..." />;
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-4">
        <p className="text-[#D93025] dark:text-[#f87171]">{error}</p>
        <Button onClick={fetchData} className="gap-2">
          <RefreshCw className="h-4 w-4" />
          Reintentar
        </Button>
      </div>
    );
  }

  if (!reportData) {
    return null;
  }

  const StatCard = ({
    title,
    value,
    icon: Icon,
    color,
    bgColor,
    subtitle,
  }: {
    title: string;
    value: number;
    icon: React.ComponentType<{ className?: string }>;
    color: string;
    bgColor: string;
    subtitle?: string;
  }) => (
    <Card>
      <CardContent className="pt-6">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">{title}</p>
            <p className="text-3xl font-bold mt-1 text-[#202124] dark:text-white">{value}</p>
            {subtitle && (
              <p className="text-xs text-[#9AA0A6] dark:text-[#737373] mt-1">{subtitle}</p>
            )}
          </div>
          <div className={`p-3 rounded-full ${bgColor}`}>
            <Icon className={`h-6 w-6 ${color}`} />
          </div>
        </div>
      </CardContent>
    </Card>
  );

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-[#202124] dark:text-white flex items-center gap-2">
            <BarChart3 className="h-6 w-6 text-[#1E8E3E] dark:text-[#4ade80]" />
            Reportes y Estadísticas
          </h1>
          <p className="text-[#5F6368] dark:text-[#9AA0A6]">
            Análisis detallado del sistema de monitoreo
          </p>
        </div>
        
        <div className="flex flex-wrap items-center gap-3">
          {/* Date range selector */}
          <div className="flex items-center gap-1 bg-[#F8F9FA] dark:bg-[#262626] rounded-xl p-1">
            {(["today", "week", "month"] as DateRange[]).map((range) => (
              <button
                key={range}
                onClick={() => setDateRange(range)}
                className={`px-3 py-1.5 text-sm rounded-lg transition-colors ${
                  dateRange === range
                    ? "bg-[#1E8E3E] text-white"
                    : "text-[#5F6368] dark:text-[#9AA0A6] hover:bg-[#E8EAED] dark:hover:bg-[#404040]"
                }`}
              >
                {range === "today" ? "Hoy" : range === "week" ? "7 días" : "30 días"}
              </button>
            ))}
          </div>
          
          {/* Export buttons */}
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => handleExport("csv")}
              disabled={isExporting}
              className="gap-2"
            >
              <Download className="h-4 w-4" />
              CSV
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => handleExport("json")}
              disabled={isExporting}
              className="gap-2"
            >
              <FileText className="h-4 w-4" />
              JSON
            </Button>
          </div>
          
          <Button
            variant="ghost"
            size="sm"
            onClick={fetchData}
            title="Actualizar datos"
            className="gap-2"
          >
            <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin' : ''}`} />
          </Button>
        </div>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Total de niños"
          value={reportData.totals.children}
          icon={Baby}
          color="text-[#1E8E3E] dark:text-[#4ade80]"
          bgColor="bg-[#DCF5E3] dark:bg-[#22c55e]/15"
        />
        <StatCard
          title={`Alertas (${dateRange === "today" ? "hoy" : dateRange === "week" ? "7 días" : "30 días"})`}
          value={reportData.totals.alerts}
          icon={Bell}
          color="text-[#D93025] dark:text-[#f87171]"
          bgColor="bg-[#FCE8E6] dark:bg-[#ef4444]/15"
          subtitle={`${reportData.totals.pendingAlerts} pendientes`}
        />
        <StatCard
          title="Zonas seguras"
          value={reportData.totals.safeZones}
          icon={MapPin}
          color="text-[#1A73E8] dark:text-[#60a5fa]"
          bgColor="bg-[#E8F0FE] dark:bg-[#3b82f6]/15"
        />
        <StatCard
          title="Dispositivos"
          value={reportData.totals.devices}
          icon={Smartphone}
          color="text-[#7C3AED] dark:text-[#a78bfa]"
          bgColor="bg-[#EDE9FE] dark:bg-[#7C3AED]/15"
          subtitle={`${reportData.totals.activeDevices} activos`}
        />
      </div>

      {/* Charts Row 1 */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Alerts over time */}
        <Card>
          <CardHeader>
            <CardTitle className="text-[#202124] dark:text-white flex items-center gap-2">
              <TrendingUp className="h-5 w-5 text-[#1E8E3E] dark:text-[#4ade80]" />
              Alertas últimos 7 días
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={reportData.alertsByDay}>
                  <defs>
                    <linearGradient id="colorAlertas" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor={COLORS.primary} stopOpacity={0.3} />
                      <stop offset="95%" stopColor={COLORS.primary} stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#E8EAED" className="dark:stroke-[#404040]" />
                  <XAxis 
                    dataKey="name" 
                    stroke="#5F6368" 
                    fontSize={12}
                    tickLine={false}
                  />
                  <YAxis 
                    stroke="#5F6368" 
                    fontSize={12}
                    tickLine={false}
                    allowDecimals={false}
                  />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "var(--tooltip-bg, #fff)",
                      border: "1px solid #E8EAED",
                      borderRadius: "12px",
                      boxShadow: "0 4px 6px -1px rgba(0, 0, 0, 0.1)",
                    }}
                    labelStyle={{ color: "#202124", fontWeight: 600 }}
                  />
                  <Area
                    type="monotone"
                    dataKey="alertas"
                    stroke={COLORS.primary}
                    strokeWidth={2}
                    fillOpacity={1}
                    fill="url(#colorAlertas)"
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* Alerts by Type */}
        <Card>
          <CardHeader>
            <CardTitle className="text-[#202124] dark:text-white flex items-center gap-2">
              <AlertTriangle className="h-5 w-5 text-[#F9AB00] dark:text-[#FDD663]" />
              Alertas por tipo
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={reportData.alertsByTypeData}
                    cx="50%"
                    cy="50%"
                    labelLine={false}
                    label={({ name, percent }) => `${name} (${percent ? (percent * 100).toFixed(0) : 0}%)`}
                    outerRadius={100}
                    fill="#8884d8"
                    dataKey="value"
                  >
                    {reportData.alertsByTypeData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={PIE_COLORS[index % PIE_COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "var(--tooltip-bg, #fff)",
                      border: "1px solid #E8EAED",
                      borderRadius: "12px",
                    }}
                  />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Charts Row 2 */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Alert Status */}
        <Card>
          <CardHeader>
            <CardTitle className="text-[#202124] dark:text-white flex items-center gap-2">
              <CheckCircle className="h-5 w-5 text-[#1E8E3E] dark:text-[#4ade80]" />
              Estado de alertas
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[250px]">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={reportData.alertsByStatusData}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={90}
                    paddingAngle={5}
                    dataKey="value"
                  >
                    {reportData.alertsByStatusData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "var(--tooltip-bg, #fff)",
                      border: "1px solid #E8EAED",
                      borderRadius: "12px",
                    }}
                  />
                  <Legend />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* Devices Status */}
        <Card>
          <CardHeader>
            <CardTitle className="text-[#202124] dark:text-white flex items-center gap-2">
              <Smartphone className="h-5 w-5 text-[#7C3AED] dark:text-[#a78bfa]" />
              Estado de dispositivos
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[250px]">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={reportData.devicesStatusData}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={90}
                    paddingAngle={5}
                    dataKey="value"
                  >
                    {reportData.devicesStatusData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "var(--tooltip-bg, #fff)",
                      border: "1px solid #E8EAED",
                      borderRadius: "12px",
                    }}
                  />
                  <Legend />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* Children with Devices */}
        <Card>
          <CardHeader>
            <CardTitle className="text-[#202124] dark:text-white flex items-center gap-2">
              <Baby className="h-5 w-5 text-[#1E8E3E] dark:text-[#4ade80]" />
              Niños con dispositivo
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[250px]">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={reportData.childrenDeviceData}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={90}
                    paddingAngle={5}
                    dataKey="value"
                  >
                    {reportData.childrenDeviceData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "var(--tooltip-bg, #fff)",
                      border: "1px solid #E8EAED",
                      borderRadius: "12px",
                    }}
                  />
                  <Legend />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Charts Row 3 */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Children per Tutor */}
        <Card>
          <CardHeader>
            <CardTitle className="text-[#202124] dark:text-white flex items-center gap-2">
              <Users className="h-5 w-5 text-[#1A73E8] dark:text-[#60a5fa]" />
              Niños por tutor (Top 5)
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={reportData.childrenPerTutor} layout="vertical">
                  <CartesianGrid strokeDasharray="3 3" stroke="#E8EAED" className="dark:stroke-[#404040]" />
                  <XAxis type="number" stroke="#5F6368" fontSize={12} allowDecimals={false} />
                  <YAxis 
                    type="category" 
                    dataKey="name" 
                    stroke="#5F6368" 
                    fontSize={12}
                    width={80}
                  />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "var(--tooltip-bg, #fff)",
                      border: "1px solid #E8EAED",
                      borderRadius: "12px",
                    }}
                  />
                  <Bar dataKey="niños" fill={COLORS.secondary} radius={[0, 4, 4, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* Battery Levels */}
        <Card>
          <CardHeader>
            <CardTitle className="text-[#202124] dark:text-white flex items-center gap-2">
              <Activity className="h-5 w-5 text-[#F9AB00] dark:text-[#FDD663]" />
              Niveles de batería
            </CardTitle>
          </CardHeader>
          <CardContent>
            {reportData.batteryDistribution.length > 0 ? (
              <div className="h-[300px]">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={reportData.batteryDistribution}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#E8EAED" className="dark:stroke-[#404040]" />
                    <XAxis 
                      dataKey="name" 
                      stroke="#5F6368" 
                      fontSize={11}
                      tickLine={false}
                      angle={-15}
                      textAnchor="end"
                      height={60}
                    />
                    <YAxis stroke="#5F6368" fontSize={12} allowDecimals={false} />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: "var(--tooltip-bg, #fff)",
                        border: "1px solid #E8EAED",
                        borderRadius: "12px",
                      }}
                    />
                    <Bar dataKey="value" radius={[4, 4, 0, 0]}>
                      {reportData.batteryDistribution.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center h-[300px] text-[#5F6368] dark:text-[#9AA0A6]">
                <Smartphone className="h-12 w-12 text-[#DADCE0] dark:text-[#404040] mb-2" />
                <p>No hay datos de batería disponibles</p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Zone Types */}
      <Card>
        <CardHeader>
          <CardTitle className="text-[#202124] dark:text-white flex items-center gap-2">
            <MapPin className="h-5 w-5 text-[#1A73E8] dark:text-[#60a5fa]" />
            Zonas seguras por tipo
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="h-[250px]">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={reportData.zonesByTypeData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#E8EAED" className="dark:stroke-[#404040]" />
                <XAxis dataKey="name" stroke="#5F6368" fontSize={12} />
                <YAxis stroke="#5F6368" fontSize={12} allowDecimals={false} />
                <Tooltip
                  contentStyle={{
                    backgroundColor: "var(--tooltip-bg, #fff)",
                    border: "1px solid #E8EAED",
                    borderRadius: "12px",
                  }}
                />
                <Bar dataKey="value" fill={COLORS.secondary} radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
