"use client";

import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import {
  LayoutDashboard,
  Users,
  Baby,
  Bell,
  MapPin,
  Settings,
  Smartphone,
  UsersRound,
  X,
  Megaphone,
  ChevronLeft,
  BarChart3,
  Map,
} from "lucide-react";

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
  isCollapsed: boolean;
  onToggleCollapse: () => void;
}

const mainNavigation = [
  { name: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  { name: "Tutores", href: "/tutors", icon: Users },
  { name: "Niños", href: "/children", icon: Baby },
  { name: "Dispositivos", href: "/devices", icon: Smartphone },
  { name: "Grupos", href: "/groups", icon: UsersRound },
];

const monitoringNavigation = [
  { name: "Mapa en vivo", href: "/live-map", icon: Map },
  { name: "Zonas Seguras", href: "/safe-zones", icon: MapPin },
  { name: "Alertas", href: "/alerts", icon: Bell },
  { name: "Notificaciones", href: "/notifications", icon: Megaphone },
  { name: "Reportes", href: "/reports", icon: BarChart3 },
];

const systemNavigation = [
  { name: "Configuración", href: "/settings", icon: Settings },
];

export function Sidebar({ isOpen, onClose, isCollapsed, onToggleCollapse }: SidebarProps) {
  const pathname = usePathname();

  const NavLink = ({ item }: { item: { name: string; href: string; icon: React.ComponentType<{ className?: string }> } }) => {
    const isActive = pathname === item.href || pathname.startsWith(item.href + "/");
    return (
      <Link
        href={item.href}
        onClick={onClose}
        title={isCollapsed ? item.name : undefined}
        className={cn(
          "group flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200",
          isActive
            ? "text-[#1E8E3E] dark:text-[#4ade80]"
            : "text-[#5F6368] dark:text-[#a3a3a3] hover:text-[#202124] dark:hover:text-white",
          isCollapsed && "justify-center px-2"
        )}
      >
        <item.icon className={cn(
          "h-5 w-5 flex-shrink-0 transition-transform duration-200 group-hover:scale-110",
          isActive ? "text-[#1E8E3E] dark:text-[#4ade80]" : ""
        )} />
        {!isCollapsed && (
          <>
            <span className="flex-1">{item.name}</span>
          </>
        )}
      </Link>
    );
  };

  return (
    <>
      {/* Overlay para móvil */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/60 backdrop-blur-sm lg:hidden"
          onClick={onClose}
        />
      )}

      {/* Sidebar */}
      <aside
        className={cn(
          "fixed inset-y-0 left-0 z-50 bg-[#F8F9FA] dark:bg-[#0f0f0f] transform transition-all duration-300 ease-out lg:translate-x-0 lg:static lg:z-auto flex flex-col",
          isOpen ? "translate-x-0" : "-translate-x-full",
          isCollapsed ? "w-[72px]" : "w-72"
        )}
      >
        {/* Header */}
        <div className={cn(
          "flex items-center h-16 px-5",
          isCollapsed ? "justify-center px-2" : "justify-between"
        )}>
          <div className="flex items-center gap-3">
            {isCollapsed ? (
              <button
                onClick={onToggleCollapse}
                className="group"
                title="Expandir menú"
              >
                <Image
                  src="/icon.png"
                  alt="GeoGuard"
                  width={40}
                  height={40}
                  className="rounded-xl dark:shadow-sm dark:group-hover:shadow-md transition-shadow"
                />
              </button>
            ) : (
              <>
                <Link href="/dashboard" className="group">
                  <Image
                    src="/icon.png"
                    alt="GeoGuard"
                    width={40}
                    height={40}
                    className="rounded-xl dark:shadow-sm dark:group-hover:shadow-md transition-shadow"
                  />
                </Link>
                <div className="flex items-center gap-2">
                  <div>
                    <span className="text-lg font-bold text-[#202124] dark:text-white">GeoGuard</span>
                  </div>
                  <button
                    onClick={onToggleCollapse}
                    className="hidden lg:flex p-1.5 rounded-lg text-[#5F6368] dark:text-[#a3a3a3] hover:text-[#202124] dark:hover:text-white hover:bg-white dark:hover:bg-[#171717] transition-colors"
                    title="Contraer menú"
                  >
                    <ChevronLeft className="h-4 w-4" />
                  </button>
                </div>
              </>
            )}
          </div>
          {!isCollapsed && (
            <button
              onClick={onClose}
              className="lg:hidden p-2 rounded-xl text-[#5F6368] dark:text-[#a3a3a3] hover:text-[#202124] dark:hover:text-white hover:bg-white dark:hover:bg-[#171717] transition-colors"
            >
              <X className="h-5 w-5" />
            </button>
          )}
        </div>

        {/* Navigation */}
        <nav className={cn(
          "flex-1 px-4 py-6 space-y-6 overflow-y-auto",
          isCollapsed && "px-2"
        )}>
          {/* Main Section */}
          <div className="space-y-1">
            {!isCollapsed && (
              <p className="px-3 text-[10px] font-semibold text-[#9AA0A6] dark:text-[#525252] uppercase tracking-wider mb-2">
                Principal
              </p>
            )}
            {mainNavigation.map((item) => (
              <NavLink key={item.name} item={item} />
            ))}
          </div>

          {/* Monitoring Section */}
          <div className="space-y-1">
            {!isCollapsed && (
              <p className="px-3 text-[10px] font-semibold text-[#9AA0A6] dark:text-[#525252] uppercase tracking-wider mb-2">
                Monitoreo
              </p>
            )}
            {monitoringNavigation.map((item) => (
              <NavLink key={item.name} item={item} />
            ))}
          </div>

          {/* System Section */}
          <div className="space-y-1">
            {!isCollapsed && (
              <p className="px-3 text-[10px] font-semibold text-[#9AA0A6] dark:text-[#525252] uppercase tracking-wider mb-2">
                Sistema
              </p>
            )}
            {systemNavigation.map((item) => (
              <NavLink key={item.name} item={item} />
            ))}
          </div>
        </nav>
      </aside>
    </>
  );
}
