"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/contexts/AuthContext";
import { Button, Input, Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui";
import { Shield, Loader2, MapPin, Bell, Users, Lock, Eye, EyeOff, CheckCircle2 } from "lucide-react";
import { AxiosError } from "axios";

export default function LoginPage() {
  const router = useRouter();
  const { login } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setIsLoading(true);

    try {
      await login({ email, password });
      router.push("/dashboard");
    } catch (err) {
      const axiosError = err as AxiosError<{ detail?: string; error?: string }>;
      if (axiosError.response?.data) {
        setError(
          axiosError.response.data.detail ||
          axiosError.response.data.error ||
          "Credenciales inválidas"
        );
      } else {
        setError("Error de conexión. Verifica tu internet.");
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex bg-gradient-to-br from-[#DCF5E3] to-[#F8F9FA] dark:from-[#0f0f0f] dark:to-[#171717]">
      {/* Sección de información - Izquierda */}
      <div className="hidden lg:flex lg:w-1/2 flex-col justify-center px-12 xl:px-20">
        <div className="max-w-xl">
          {/* Logo y título */}
          <div className="flex items-center gap-3 mb-6">
            <div className="p-3 bg-[#1E8E3E] dark:bg-[#22c55e] rounded-2xl">
              <Shield className="h-10 w-10 text-white dark:text-[#0f0f0f]" />
            </div>
            <div>
              <h1 className="text-4xl font-bold text-[#202124] dark:text-[#fafafa]">
                GeoGuard
              </h1>
              <p className="text-sm text-[#5F6368] dark:text-[#a3a3a3]">
                Sistema de Monitoreo Infantil
              </p>
            </div>
          </div>

          {/* Descripción */}
          <p className="text-xl text-[#202124] dark:text-[#e5e5e5] mb-8 leading-relaxed">
            Monitorea la ubicación de niños preescolares en tiempo real. 
            Alertas automáticas cuando salen de zonas seguras.
          </p>

          {/* Características */}
          <div className="space-y-5">
            <div className="flex items-start gap-4">
              <div className="p-2 bg-[#DCF5E3] dark:bg-[#22c55e]/15 rounded-lg shrink-0">
                <MapPin className="h-5 w-5 text-[#1E8E3E] dark:text-[#4ade80]" />
              </div>
              <div>
                <h3 className="font-semibold text-[#202124] dark:text-[#fafafa] mb-1">
                  Rastreo en Tiempo Real
                </h3>
                <p className="text-sm text-[#5F6368] dark:text-[#a3a3a3]">
                  Ubicación GPS precisa actualizada cada segundo mediante WebSocket
                </p>
              </div>
            </div>

            <div className="flex items-start gap-4">
              <div className="p-2 bg-[#DCF5E3] dark:bg-[#22c55e]/15 rounded-lg shrink-0">
                <Bell className="h-5 w-5 text-[#1E8E3E] dark:text-[#4ade80]" />
              </div>
              <div>
                <h3 className="font-semibold text-[#202124] dark:text-[#fafafa] mb-1">
                  Alertas Instantáneas
                </h3>
                <p className="text-sm text-[#5F6368] dark:text-[#a3a3a3]">
                  Notificaciones push cuando un niño sale de su zona segura
                </p>
              </div>
            </div>

            <div className="flex items-start gap-4">
              <div className="p-2 bg-[#DCF5E3] dark:bg-[#22c55e]/15 rounded-lg shrink-0">
                <Users className="h-5 w-5 text-[#1E8E3E] dark:text-[#4ade80]" />
              </div>
              <div>
                <h3 className="font-semibold text-[#202124] dark:text-[#fafafa] mb-1">
                  Gestión de Grupos
                </h3>
                <p className="text-sm text-[#5F6368] dark:text-[#a3a3a3]">
                  Organiza niños por aulas con zonas seguras compartidas
                </p>
              </div>
            </div>

            <div className="flex items-start gap-4">
              <div className="p-2 bg-[#DCF5E3] dark:bg-[#22c55e]/15 rounded-lg shrink-0">
                <Lock className="h-5 w-5 text-[#1E8E3E] dark:text-[#4ade80]" />
              </div>
              <div>
                <h3 className="font-semibold text-[#202124] dark:text-[#fafafa] mb-1">
                  Seguro y Privado
                </h3>
                <p className="text-sm text-[#5F6368] dark:text-[#a3a3a3]">
                  Datos cifrados con acceso solo para tutores autorizados
                </p>
              </div>
            </div>
          </div>

          {/* Estadísticas */}
          <div className="grid grid-cols-3 gap-6 mt-12 pt-8 border-t border-[#DADCE0] dark:border-[#3c3c3c]">
            <div>
              <div className="text-3xl font-bold text-[#1E8E3E] dark:text-[#4ade80] mb-1">
                &lt;1s
              </div>
              <div className="text-sm text-[#5F6368] dark:text-[#a3a3a3]">
                Tiempo de alerta
              </div>
            </div>
            <div>
              <div className="text-3xl font-bold text-[#1E8E3E] dark:text-[#4ade80] mb-1">
                24/7
              </div>
              <div className="text-sm text-[#5F6368] dark:text-[#a3a3a3]">
                Monitoreo continuo
              </div>
            </div>
            <div>
              <div className="text-3xl font-bold text-[#1E8E3E] dark:text-[#4ade80] mb-1">
                100%
              </div>
              <div className="text-sm text-[#5F6368] dark:text-[#a3a3a3]">
                Precisión GPS
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Formulario de login - Derecha */}
      <div className="w-full lg:w-1/2 flex items-center justify-center p-6 lg:p-12">
        <Card className="w-full max-w-md">
          <CardHeader className="text-center">
            <div className="flex justify-center mb-4 lg:hidden">
              <div className="p-3 bg-[#DCF5E3] dark:bg-[#22c55e]/15 rounded-full">
                <Shield className="h-8 w-8 text-[#1E8E3E] dark:text-[#4ade80]" />
              </div>
            </div>
            <CardTitle className="text-2xl">Iniciar sesión</CardTitle>
            <CardDescription>
              Panel de administración para instituciones educativas
            </CardDescription>
          </CardHeader>

          <form onSubmit={handleSubmit}>
            <CardContent className="space-y-4">
              {error && (
                <div className="p-3 bg-[#FCE8E6] dark:bg-[#ef4444]/15 border border-[#F5C6CB] dark:border-[#ef4444]/30 rounded-xl text-[#C5221F] dark:text-[#f87171] text-sm">
                  {error}
                </div>
              )}

              <Input
                label="Correo electrónico"
                type="email"
                placeholder="admin@institucion.edu"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                autoComplete="email"
              />

              <Input
                label="Contraseña"
                type={showPassword ? "text" : "password"}
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                autoComplete="current-password"
                rightIcon={
                  <button
                    type="button"
                    aria-label={showPassword ? "Ocultar contraseña" : "Mostrar contraseña"}
                    onClick={() => setShowPassword((prev) => !prev)}
                    className="text-[#5F6368] dark:text-[#a3a3a3] hover:text-[#202124] dark:hover:text-white"
                  >
                    {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                  </button>
                }
              />

              <div className="flex items-start gap-2 p-3 bg-[#E8F5E9] dark:bg-[#22c55e]/10 rounded-xl">
                <CheckCircle2 className="h-4 w-4 text-[#1E8E3E] dark:text-[#4ade80] shrink-0 mt-0.5" />
                <p className="text-xs text-[#0D5425] dark:text-[#4ade80]">
                  Solo personal autorizado puede acceder al panel administrativo
                </p>
              </div>
            </CardContent>

            <CardFooter className="flex flex-col gap-4">
              <Button type="submit" className="w-full" disabled={isLoading}>
                {isLoading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Iniciando sesión...
                  </>
                ) : (
                  "Acceder al panel"
                )}
              </Button>

              <p className="text-xs text-center text-[#5F6368] dark:text-[#a3a3a3]">
                Al iniciar sesión, aceptas los términos de servicio y la política de privacidad de GeoGuard
              </p>
            </CardFooter>
          </form>
        </Card>
      </div>
    </div>
  );
}
