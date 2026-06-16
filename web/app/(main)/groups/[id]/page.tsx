"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import api, { API_ENDPOINTS } from "@/lib/api";
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  Button,
  Badge,
  Loading,
} from "@/components/ui";
import { formatDateTime } from "@/lib/utils";
import { ChildGroup, GroupSafeZone, GroupMembership, GroupTutor } from "@/lib/types";
import {
  ArrowLeft,
  Edit,
  UsersRound,
  Baby,
  Users,
  MapPin,
  Plus,
} from "lucide-react";

export default function GroupDetailPage() {
  const params = useParams();
  const id = params.id as string;

  const [group, setGroup] = useState<ChildGroup | null>(null);
  const [members, setMembers] = useState<GroupMembership[]>([]);
  const [tutors, setTutors] = useState<GroupTutor[]>([]);
  const [safeZones, setSafeZones] = useState<GroupSafeZone[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [groupRes, safeZonesRes] = await Promise.all([
          api.get(`${API_ENDPOINTS.GROUPS}${id}/`),
          api.get(API_ENDPOINTS.GROUP_SAFE_ZONES),
        ]);

        setGroup(groupRes.data);
        
        // Filter safe zones for this group
        const allZones = safeZonesRes.data.results || safeZonesRes.data;
        setSafeZones(allZones.filter((z: GroupSafeZone) => z.group === parseInt(id)));

        // Try to get members and tutors if available
        try {
          const membersRes = await api.get(`${API_ENDPOINTS.GROUPS}${id}/members/`);
          setMembers(membersRes.data.results || membersRes.data || []);
        } catch {
          setMembers([]);
        }

        try {
          const tutorsRes = await api.get(`${API_ENDPOINTS.GROUPS}${id}/tutors/`);
          setTutors(tutorsRes.data.results || tutorsRes.data || []);
        } catch {
          setTutors([]);
        }
      } catch (err) {
        console.error("Error fetching group:", err);
        setError("Error al cargar el grupo");
      } finally {
        setIsLoading(false);
      }
    };

    if (id) {
      fetchData();
    }
  }, [id]);

  if (isLoading) {
    return <Loading text="Cargando grupo..." />;
  }

  if (error || !group) {
    return (
      <div className="flex flex-col items-center justify-center h-64">
        <p className="text-[#D93025] mb-4">{error || "Grupo no encontrado"}</p>
        <Link href="/groups">
          <Button variant="outline">Volver a la lista</Button>
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link href="/groups">
            <Button variant="ghost" size="icon">
              <ArrowLeft className="h-5 w-5" />
            </Button>
          </Link>
          <div className="flex items-center gap-4">
            <div
              className="w-14 h-14 rounded-full flex items-center justify-center"
              style={{ backgroundColor: group.color + "20" }}
            >
              <UsersRound className="h-7 w-7" style={{ color: group.color }} />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-[#202124] dark:text-white">{group.name}</h1>
              <p className="text-[#5F6368] dark:text-[#9AA0A6]">{group.description || "Sin descripción"}</p>
            </div>
          </div>
        </div>
        <Link href={`/groups/${id}/edit`}>
          <Button variant="outline" className="gap-2">
            <Edit className="h-4 w-4" />
            Editar
          </Button>
        </Link>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card>
          <CardContent className="pt-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">Miembros</p>
                <p className="text-3xl font-bold text-[#202124] dark:text-white">
                  {group.members_count ?? members.length}
                </p>
              </div>
              <div className="p-3 bg-[#DCF5E3] dark:bg-[#1E3A2F] rounded-full">
                <Baby className="h-6 w-6 text-[#1E8E3E] dark:text-[#4ade80]" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="pt-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">Tutores</p>
                <p className="text-3xl font-bold text-[#202124] dark:text-white">
                  {group.tutors_count ?? tutors.length + 1}
                </p>
              </div>
              <div className="p-3 bg-[#E8F0FE] dark:bg-[#1A3A5C] rounded-full">
                <Users className="h-6 w-6 text-[#1A73E8]" />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="pt-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">Zonas seguras</p>
                <p className="text-3xl font-bold text-[#202124] dark:text-white">
                  {safeZones.length}
                </p>
              </div>
              <div className="p-3 bg-[#FEF7E0] dark:bg-[#3D3000] rounded-full">
                <MapPin className="h-6 w-6 text-[#B06000] dark:text-[#FDD663]" />
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Members */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="flex items-center gap-2 text-[#202124] dark:text-white">
            <Baby className="h-5 w-5 text-[#1E8E3E] dark:text-[#4ade80]" />
            Niños del grupo
          </CardTitle>
          <Button size="sm" className="gap-1">
            <Plus className="h-4 w-4" />
            Agregar
          </Button>
        </CardHeader>
        <CardContent>
          {members.length === 0 ? (
            <p className="text-center text-[#5F6368] dark:text-[#9AA0A6] py-4">
              No hay niños en este grupo
            </p>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {members.map((member) => (
                <div
                  key={member.id}
                  className="p-3 rounded-xl bg-[#F8F9FA] dark:bg-[#262626] flex items-center gap-3"
                >
                  <div className="w-10 h-10 rounded-full bg-[#DCF5E3] dark:bg-[#1E3A2F] flex items-center justify-center">
                    <span className="text-[#1E8E3E] dark:text-[#4ade80] font-medium">
                      {(member.child_name || "N")[0]}
                    </span>
                  </div>
                  <div className="flex-1">
                    <p className="font-medium text-[#202124] dark:text-white">
                      {member.child_name || `Niño #${member.child}`}
                    </p>
                    <p className="text-xs text-[#5F6368] dark:text-[#9AA0A6]">
                      Agregado: {formatDateTime(member.joined_at).split(" ")[0]}
                    </p>
                  </div>
                  <Badge variant={member.is_active ? "success" : "default"}>
                    {member.is_active ? "Activo" : "Inactivo"}
                  </Badge>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Safe Zones */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="flex items-center gap-2 text-[#202124] dark:text-white">
            <MapPin className="h-5 w-5 text-[#1E8E3E] dark:text-[#4ade80]" />
            Zonas seguras del grupo
          </CardTitle>
          <Button size="sm" className="gap-1">
            <Plus className="h-4 w-4" />
            Agregar
          </Button>
        </CardHeader>
        <CardContent>
          {safeZones.length === 0 ? (
            <p className="text-center text-[#5F6368] dark:text-[#9AA0A6] py-4">
              No hay zonas seguras configuradas para este grupo
            </p>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {safeZones.map((zone) => (
                <div
                  key={zone.id}
                  className="p-3 rounded-xl bg-[#F8F9FA] dark:bg-[#262626] flex items-start gap-3"
                >
                  <div
                    className="p-2 rounded-full"
                    style={{ backgroundColor: zone.color + "20" }}
                  >
                    <MapPin className="h-5 w-5" style={{ color: zone.color }} />
                  </div>
                  <div className="flex-1">
                    <p className="font-medium text-[#202124] dark:text-white">{zone.name}</p>
                    <p className="text-xs text-[#5F6368] dark:text-[#9AA0A6]">
                      {zone.zone_type === "circle"
                        ? `Radio: ${zone.radius_meters}m`
                        : `Polígono: ${zone.polygon_points?.length || 0} puntos`}
                    </p>
                  </div>
                  <Badge variant={zone.is_active ? "success" : "default"}>
                    {zone.is_active ? "Activa" : "Inactiva"}
                  </Badge>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Info */}
      <Card>
        <CardHeader>
          <CardTitle className="text-[#202124] dark:text-white">Información del grupo</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="flex justify-between">
            <span className="text-[#5F6368] dark:text-[#9AA0A6]">ID</span>
            <span className="font-mono text-[#202124] dark:text-white">{group.id}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-[#5F6368] dark:text-[#9AA0A6]">Propietario</span>
            <span className="text-[#202124] dark:text-white">
              {group.owner_name || `Usuario #${group.owner}`}
            </span>
          </div>
          <div className="flex justify-between">
            <span className="text-[#5F6368] dark:text-[#9AA0A6]">Creado</span>
            <span className="text-[#202124] dark:text-white">{formatDateTime(group.created_at)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-[#5F6368] dark:text-[#9AA0A6]">Actualizado</span>
            <span className="text-[#202124] dark:text-white">{formatDateTime(group.updated_at)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-[#5F6368] dark:text-[#9AA0A6]">Estado</span>
            <Badge variant={group.is_active ? "success" : "default"}>
              {group.is_active ? "Activo" : "Inactivo"}
            </Badge>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
