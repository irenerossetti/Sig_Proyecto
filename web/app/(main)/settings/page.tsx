"use client";

import { useState } from "react";
import { useAuth } from "@/contexts/AuthContext";
import api, { API_ENDPOINTS } from "@/lib/api";
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  CardFooter,
  Button,
  Input,
} from "@/components/ui";
import { Settings, User, Lock, Loader2 } from "lucide-react";
import { AxiosError } from "axios";

export default function SettingsPage() {
  const { user, updateUser, logout } = useAuth();
  
  const [fullName, setFullName] = useState(user?.full_name || "");
  const [phone, setPhone] = useState(user?.phone || "");
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  
  const [isUpdatingProfile, setIsUpdatingProfile] = useState(false);
  const [isUpdatingPassword, setIsUpdatingPassword] = useState(false);
  const [profileMessage, setProfileMessage] = useState({ type: "", text: "" });
  const [passwordMessage, setPasswordMessage] = useState({ type: "", text: "" });

  const handleUpdateProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    setProfileMessage({ type: "", text: "" });
    setIsUpdatingProfile(true);

    try {
      const response = await api.patch(API_ENDPOINTS.PROFILE, {
        full_name: fullName,
        phone: phone || null,
      });
      updateUser(response.data);
      setProfileMessage({ type: "success", text: "Perfil actualizado correctamente" });
    } catch (err) {
      const axiosError = err as AxiosError<{ detail?: string }>;
      setProfileMessage({
        type: "error",
        text: axiosError.response?.data?.detail || "Error al actualizar el perfil",
      });
    } finally {
      setIsUpdatingProfile(false);
    }
  };

  const handleUpdatePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordMessage({ type: "", text: "" });

    if (newPassword !== confirmPassword) {
      setPasswordMessage({ type: "error", text: "Las contraseñas no coinciden" });
      return;
    }

    if (newPassword.length < 8) {
      setPasswordMessage({
        type: "error",
        text: "La contraseña debe tener al menos 8 caracteres",
      });
      return;
    }

    setIsUpdatingPassword(true);

    try {
      await api.post(API_ENDPOINTS.CHANGE_PASSWORD, {
        current_password: currentPassword,
        new_password: newPassword,
      });
      setPasswordMessage({ type: "success", text: "Contraseña actualizada correctamente" });
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
    } catch (err) {
      const axiosError = err as AxiosError<{ detail?: string }>;
      setPasswordMessage({
        type: "error",
        text: axiosError.response?.data?.detail || "Error al cambiar la contraseña",
      });
    } finally {
      setIsUpdatingPassword(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-[#202124] dark:text-[#fafafa] flex items-center gap-2">
          <Settings className="h-6 w-6 text-[#1E8E3E] dark:text-[#4ade80]" />
          Configuración
        </h1>
        <p className="text-[#5F6368] dark:text-[#a3a3a3]">Gestiona tu cuenta y preferencias</p>
      </div>

      {/* Profile Card */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <User className="h-5 w-5" />
            Información del perfil
          </CardTitle>
        </CardHeader>
        <form onSubmit={handleUpdateProfile}>
          <CardContent className="space-y-4">
            {profileMessage.text && (
              <div
                className={`p-3 rounded-xl text-sm ${
                  profileMessage.type === "success"
                    ? "bg-[#DCF5E3] dark:bg-[#22c55e]/15 border border-[#A8DAB5] dark:border-[#22c55e]/30 text-[#0D5425] dark:text-[#4ade80]"
                    : "bg-[#FCE8E6] dark:bg-[#ef4444]/15 border border-[#F5C6CB] dark:border-[#ef4444]/30 text-[#C5221F] dark:text-[#f87171]"
                }`}
              >
                {profileMessage.text}
              </div>
            )}

            <Input
              label="Correo electrónico"
              type="email"
              value={user?.email || ""}
              disabled
              className="bg-[#F8F9FA] dark:bg-[#262626]"
            />

            <Input
              label="Nombre completo"
              type="text"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              required
            />

            <Input
              label="Teléfono"
              type="tel"
              placeholder="+591 70000000"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
            />
          </CardContent>
          <CardFooter>
            <Button type="submit" disabled={isUpdatingProfile}>
              {isUpdatingProfile ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Guardando...
                </>
              ) : (
                "Guardar cambios"
              )}
            </Button>
          </CardFooter>
        </form>
      </Card>

      {/* Password Card */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Lock className="h-5 w-5" />
            Cambiar contraseña
          </CardTitle>
        </CardHeader>
        <form onSubmit={handleUpdatePassword}>
          <CardContent className="space-y-4">
            {passwordMessage.text && (
              <div
                className={`p-3 rounded-xl text-sm ${
                  passwordMessage.type === "success"
                    ? "bg-[#DCF5E3] dark:bg-[#22c55e]/15 border border-[#A8DAB5] dark:border-[#22c55e]/30 text-[#0D5425] dark:text-[#4ade80]"
                    : "bg-[#FCE8E6] dark:bg-[#ef4444]/15 border border-[#F5C6CB] dark:border-[#ef4444]/30 text-[#C5221F] dark:text-[#f87171]"
                }`}
              >
                {passwordMessage.text}
              </div>
            )}

            <Input
              label="Contraseña actual"
              type="password"
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
              required
            />

            <Input
              label="Nueva contraseña"
              type="password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              required
            />

            <Input
              label="Confirmar nueva contraseña"
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              required
            />
          </CardContent>
          <CardFooter>
            <Button type="submit" disabled={isUpdatingPassword}>
              {isUpdatingPassword ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Actualizando...
                </>
              ) : (
                "Cambiar contraseña"
              )}
            </Button>
          </CardFooter>
        </form>
      </Card>

      {/* Danger Zone */}
      <Card className="border-[#F5C6CB] dark:border-[#ef4444]/30">
        <CardHeader>
          <CardTitle className="text-[#D93025] dark:text-[#f87171]">Zona de peligro</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-[#5F6368] dark:text-[#a3a3a3] mb-4">
            Ten cuidado con estas acciones, no se pueden deshacer.
          </p>
          <Button variant="destructive" onClick={logout}>
            Cerrar sesión
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
