import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
import { format, formatDistanceToNow } from "date-fns";
import { es } from "date-fns/locale";
import { Child } from "./types";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDate(date: string | Date): string {
  return format(new Date(date), "dd/MM/yyyy", { locale: es });
}

export function formatDateTime(date: string | Date): string {
  return format(new Date(date), "dd/MM/yyyy HH:mm", { locale: es });
}

export function formatTimeAgo(date: string | Date): string {
  return formatDistanceToNow(new Date(date), { addSuffix: true, locale: es });
}

export function getAlertTypeLabel(type: string): string {
  const labels: Record<string, string> = {
    exit: "Salida de zona",
    enter: "Entrada a zona",
    low_battery: "Batería baja",
    device_offline: "Dispositivo desconectado",
  };
  return labels[type] || type;
}

export function getAlertTypeColor(type: string): string {
  const colors: Record<string, string> = {
    exit: "bg-red-100 text-red-800",
    enter: "bg-green-100 text-green-800",
    low_battery: "bg-yellow-100 text-yellow-800",
    device_offline: "bg-gray-100 text-gray-800",
  };
  return colors[type] || "bg-gray-100 text-gray-800";
}

export function getZoneTypeLabel(type: string): string {
  const labels: Record<string, string> = {
    school: "Escuela",
    home: "Casa",
    other: "Otro",
  };
  return labels[type] || type;
}

export function getBatteryColor(level: number | null): string {
  if (level === null) return "text-gray-400";
  if (level > 60) return "text-green-500";
  if (level > 20) return "text-yellow-500";
  return "text-red-500";
}

export function truncateText(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return text.slice(0, maxLength) + "...";
}

// Normalize child photo coming from photo_url (backend) or photo (legacy)
export function normalizeChildPhoto(child: Child): Child {
  return {
    ...child,
    photo: child.photo || child.photo_url || null,
  };
}
