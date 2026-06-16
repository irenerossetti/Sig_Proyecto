"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
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
import { formatDateTime } from "@/lib/utils";
import { User, Child } from "@/lib/types";
import { Users, Mail, Phone, Calendar, Baby, Shield, ShieldCheck } from "lucide-react";

export default function TutorsPage() {
  const [tutors, setTutors] = useState<User[]>([]);
  const [children, setChildren] = useState<Child[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [endpointMissing, setEndpointMissing] = useState(false);

  useEffect(() => {
    const fetchData = async () => {
      try {
        // Primero intentar obtener usuarios (requiere admin)
        const [tutorsRes, childrenRes] = await Promise.all([
          api.get(API_ENDPOINTS.USERS),
          api.get(API_ENDPOINTS.CHILDREN),
        ]);
        setTutors(tutorsRes.data.results || tutorsRes.data);
        setChildren(childrenRes.data.results || childrenRes.data);
      } catch (err: unknown) {
        console.error("Error fetching tutors:", err);
        const axiosErr = err as { response?: { status?: number } };
        // Si falla la petición de usuarios, intentar solo con children
        if (axiosErr.response?.status === 404) {
          setEndpointMissing(true);
          setError("El endpoint de usuarios no está disponible. Despliega el backend actualizado.");
        } else if (axiosErr.response?.status === 403) {
          setError("Acceso denegado. Se requiere una cuenta con permisos de administrador (is_staff=True).");
          // Aún así, cargar los niños para mostrar algo útil
          try {
            const childrenRes = await api.get(API_ENDPOINTS.CHILDREN);
            setChildren(childrenRes.data.results || childrenRes.data);
          } catch {
            // Ignorar
          }
        } else {
          setError("Error al cargar los tutores");
        }
      } finally {
        setIsLoading(false);
      }
    };

    fetchData();
  }, []);

  const getChildrenCount = (tutorId: number) => {
    return children.filter((c) => c.tutor === tutorId).length;
  };

  const toggleUserStatus = async (userId: number, currentStatus: boolean) => {
    try {
      await api.patch(`${API_ENDPOINTS.USERS}${userId}/`, {
        is_active: !currentStatus,
      });
      setTutors(
        tutors.map((t) =>
          t.id === userId ? { ...t, is_active: !currentStatus } : t
        )
      );
    } catch (err) {
      console.error("Error updating user:", err);
      alert("Error al actualizar el usuario");
    }
  };

  if (isLoading) {
    return <Loading text="Cargando tutores..." />;
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[#202124] dark:text-white">Tutores</h1>
          <p className="text-[#5F6368] dark:text-[#9AA0A6]">
            Gestiona los tutores registrados en el sistema
          </p>
        </div>
        <div className="flex items-center gap-2 px-3 py-1.5 bg-[#DCF5E3] dark:bg-[#1E3A2F] rounded-full">
          <Users className="h-4 w-4 text-[#1E8E3E] dark:text-[#4ade80]" />
          <span className="text-sm font-medium text-[#0D5425] dark:text-[#4ade80]">
            {tutors.length} tutores
          </span>
        </div>
      </div>

      {error && (
        <div className={`p-4 border rounded-xl ${endpointMissing ? 'bg-[#FEF7E0] dark:bg-[#3D3000] border-[#F9AB00] dark:border-[#F9AB00]/50 text-[#B06000] dark:text-[#FDD663]' : 'bg-[#FCE8E6] dark:bg-[#5C2B29] border-[#F5C6CB] dark:border-[#8B3A3A] text-[#C5221F] dark:text-[#F28B82]'}`}>
          <p className="font-medium">{error}</p>
          {endpointMissing && (
            <p className="text-sm mt-2">
              Para habilitar esta funcionalidad, despliega el backend actualizado con el endpoint <code className="bg-black/10 dark:bg-white/10 px-1.5 py-0.5 rounded">/api/auth/users/</code>
            </p>
          )}
        </div>
      )}

      {/* Tutors List */}
      {tutors.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="p-4 bg-[#DCF5E3] dark:bg-[#1E3A2F] rounded-full mb-4">
              <Users className="h-8 w-8 text-[#1E8E3E] dark:text-[#4ade80]" />
            </div>
            <h3 className="text-lg font-medium text-[#202124] dark:text-white mb-2">
              No hay tutores registrados
            </h3>
            <p className="text-[#5F6368] dark:text-[#9AA0A6]">
              Los tutores aparecerán aquí cuando se registren
            </p>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Tutor</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Teléfono</TableHead>
                  <TableHead>Niños</TableHead>
                  <TableHead>Rol</TableHead>
                  <TableHead>Registro</TableHead>
                  <TableHead>Estado</TableHead>
                  <TableHead className="text-right">Acciones</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {tutors.map((tutor) => (
                  <TableRow key={tutor.id}>
                    <TableCell>
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-[#DCF5E3] dark:bg-[#1E3A2F] flex items-center justify-center flex-shrink-0 overflow-hidden relative">
                          {tutor.photo_url ? (
                            <Image
                              src={tutor.photo_url}
                              alt={tutor.full_name}
                              fill
                              className="rounded-full object-cover"
                            />
                          ) : (
                            <span className="text-[#1E8E3E] dark:text-[#4ade80] font-medium">
                              {(tutor.full_name || tutor.email)[0].toUpperCase()}
                            </span>
                          )}
                        </div>
                        <div>
                          <p className="font-medium text-[#202124] dark:text-white">
                            {tutor.full_name || "Sin nombre"}
                          </p>
                          <p className="text-xs text-[#5F6368] dark:text-[#9AA0A6]">ID: {tutor.id}</p>
                        </div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2 text-[#5F6368] dark:text-[#9AA0A6]">
                        <Mail className="h-4 w-4" />
                        {tutor.email}
                      </div>
                    </TableCell>
                    <TableCell>
                      {tutor.phone ? (
                        <div className="flex items-center gap-2 text-[#5F6368] dark:text-[#9AA0A6]">
                          <Phone className="h-4 w-4" />
                          {tutor.phone}
                        </div>
                      ) : (
                        <span className="text-[#9AA0A6]">-</span>
                      )}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Baby className="h-4 w-4 text-[#1E8E3E] dark:text-[#4ade80]" />
                        <span className="text-[#202124] dark:text-white">{getChildrenCount(tutor.id)}</span>
                      </div>
                    </TableCell>
                    <TableCell>
                      {tutor.is_superuser ? (
                        <Badge variant="info" className="gap-1">
                          <ShieldCheck className="h-3 w-3" />
                          Admin
                        </Badge>
                      ) : tutor.is_staff ? (
                        <Badge variant="warning" className="gap-1">
                          <Shield className="h-3 w-3" />
                          Staff
                        </Badge>
                      ) : (
                        <Badge variant="default">Tutor</Badge>
                      )}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2 text-[#5F6368] dark:text-[#9AA0A6]">
                        <Calendar className="h-4 w-4" />
                        <span className="text-sm">
                          {tutor.date_joined
                            ? formatDateTime(tutor.date_joined).split(" ")[0]
                            : "-"}
                        </span>
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant={tutor.is_active ? "success" : "danger"}>
                        {tutor.is_active ? "Activo" : "Inactivo"}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right">
                      <Button
                        variant={tutor.is_active ? "outline" : "default"}
                        size="sm"
                        onClick={() => toggleUserStatus(tutor.id, tutor.is_active)}
                      >
                        {tutor.is_active ? "Desactivar" : "Activar"}
                      </Button>
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
