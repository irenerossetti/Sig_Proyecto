"use client";

import { useAuth } from "@/contexts/AuthContext";
import { useTheme } from "@/contexts/ThemeContext";
import { Button } from "@/components/ui";
import { Menu, LogOut, User, ShieldCheck, Sun, Moon } from "lucide-react";

interface HeaderProps {
  onMenuClick: () => void;
}

export function Header({ onMenuClick }: HeaderProps) {
  const { user, logout } = useAuth();
  const { theme, toggleTheme } = useTheme();

  return (
    <header className="sticky top-0 z-30 flex h-16 items-center gap-4 bg-[#F8F9FA] dark:bg-[#0f0f0f] px-4 sm:px-6">
      {/* Menu button for mobile */}
      <button
        onClick={onMenuClick}
        className="lg:hidden p-2 rounded-md text-[#5F6368] dark:text-[#a3a3a3] hover:text-[#202124] dark:hover:text-white hover:bg-[#F8F9FA] dark:hover:bg-[#262626]"
      >
        <Menu className="h-6 w-6" />
      </button>

      {/* Admin badge */}
      <div className="hidden sm:flex items-center gap-2 px-3 py-1.5 bg-[#DCF5E3] dark:bg-[#22c55e]/15 rounded-full">
        <ShieldCheck className="h-4 w-4 text-[#1E8E3E] dark:text-[#4ade80]" />
        <span className="text-xs font-medium text-[#0D5425] dark:text-[#4ade80]">Administrador</span>
      </div>

      {/* Spacer */}
      <div className="flex-1" />

      {/* Theme toggle, User info and logout */}
      <div className="flex items-center gap-2 sm:gap-4">
        {/* Theme toggle button */}
        <button
          onClick={toggleTheme}
          className="p-2 rounded-full text-[#5F6368] dark:text-[#a3a3a3] hover:text-[#202124] dark:hover:text-white hover:bg-[#F8F9FA] dark:hover:bg-[#262626] transition-colors"
          title={theme === "light" ? "Cambiar a modo oscuro" : "Cambiar a modo claro"}
        >
          {theme === "light" ? (
            <Moon className="h-5 w-5" />
          ) : (
            <Sun className="h-5 w-5" />
          )}
        </button>

        {user && (
          <div className="hidden sm:flex items-center gap-2 text-sm text-[#5F6368] dark:text-[#a3a3a3]">
            <User className="h-4 w-4" />
            <span>{user.full_name}</span>
          </div>
        )}
        <Button variant="ghost" size="sm" onClick={logout} className="gap-2 text-[#5F6368] dark:text-[#a3a3a3] hover:text-[#D93025]">
          <LogOut className="h-4 w-4" />
          <span className="hidden sm:inline">Salir</span>
        </Button>
      </div>
    </header>
  );
}
