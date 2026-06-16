"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
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
import { ChildGroup } from "@/lib/types";
import {
  UsersRound,
  Plus,
  Eye,
  Edit,
  Trash2,
  Baby,
  Users,
} from "lucide-react";

export default function GroupsPage() {
  const [groups, setGroups] = useState<ChildGroup[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchGroups = async () => {
      try {
        const response = await api.get(API_ENDPOINTS.GROUPS);
        setGroups(response.data.results || response.data);
      } catch (err) {
        console.error("Error fetching groups:", err);
        setError("Error al cargar los grupos");
      } finally {
        setIsLoading(false);
      }
    };

    fetchGroups();
  }, []);

  const deleteGroup = async (id: number) => {
    if (!confirm("¿Estás seguro de eliminar este grupo?")) return;

    try {
      await api.delete(`${API_ENDPOINTS.GROUPS}${id}/`);
      setGroups(groups.filter((g) => g.id !== id));
    } catch (err) {
      console.error("Error deleting group:", err);
      alert("Error al eliminar el grupo");
    }
  };

  if (isLoading) {
    return <Loading text="Cargando grupos..." />;
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[#202124] dark:text-white">Grupos</h1>
          <p className="text-[#5F6368] dark:text-[#9AA0A6]">
            Gestiona grupos de niños para monitoreo colectivo
          </p>
        </div>
        <Link href="/groups/new">
          <Button className="gap-2">
            <Plus className="h-4 w-4" />
            Nuevo grupo
          </Button>
        </Link>
      </div>

      {error && (
        <div className="p-4 bg-[#FCE8E6] dark:bg-[#5C2B29] border border-[#F5C6CB] dark:border-[#8B3A3A] rounded-xl text-[#C5221F] dark:text-[#F28B82]">
          {error}
        </div>
      )}

      {/* Groups List */}
      {groups.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="p-4 bg-[#DCF5E3] dark:bg-[#1E3A2F] rounded-full mb-4">
              <UsersRound className="h-8 w-8 text-[#1E8E3E] dark:text-[#4ade80]" />
            </div>
            <h3 className="text-lg font-medium text-[#202124] dark:text-white mb-2">
              No hay grupos creados
            </h3>
            <p className="text-[#5F6368] dark:text-[#9AA0A6] mb-4">
              Crea grupos para monitorear múltiples niños juntos
            </p>
            <Link href="/groups/new">
              <Button>Crear grupo</Button>
            </Link>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Grupo</TableHead>
                  <TableHead>Descripción</TableHead>
                  <TableHead>Propietario</TableHead>
                  <TableHead>Miembros</TableHead>
                  <TableHead>Tutores</TableHead>
                  <TableHead>Estado</TableHead>
                  <TableHead>Creado</TableHead>
                  <TableHead className="text-right">Acciones</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {groups.map((group) => (
                  <TableRow key={group.id}>
                    <TableCell>
                      <div className="flex items-center gap-3">
                        <div
                          className="w-10 h-10 rounded-full flex items-center justify-center"
                          style={{ backgroundColor: group.color + "20" }}
                        >
                          <UsersRound
                            className="h-5 w-5"
                            style={{ color: group.color }}
                          />
                        </div>
                        <div>
                          <p className="font-medium text-[#202124] dark:text-white">{group.name}</p>
                          <p className="text-xs text-[#5F6368] dark:text-[#9AA0A6]">ID: {group.id}</p>
                        </div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <span className="text-[#5F6368] dark:text-[#9AA0A6] truncate max-w-[200px] block">
                        {group.description || "-"}
                      </span>
                    </TableCell>
                    <TableCell>
                      <span className="text-[#202124] dark:text-white">
                        {group.owner_name || `Usuario #${group.owner}`}
                      </span>
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Baby className="h-4 w-4 text-[#1E8E3E] dark:text-[#4ade80]" />
                        <span className="text-[#202124] dark:text-white">
                          {group.members_count ?? 0}
                        </span>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Users className="h-4 w-4 text-[#1A73E8]" />
                        <span className="text-[#202124] dark:text-white">
                          {group.tutors_count ?? 1}
                        </span>
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant={group.is_active ? "success" : "default"}>
                        {group.is_active ? "Activo" : "Inactivo"}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <span className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">
                        {formatDateTime(group.created_at).split(" ")[0]}
                      </span>
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex items-center justify-end gap-1">
                        <Link href={`/groups/${group.id}`}>
                          <Button variant="ghost" size="icon" title="Ver">
                            <Eye className="h-4 w-4" />
                          </Button>
                        </Link>
                        <Link href={`/groups/${group.id}/edit`}>
                          <Button variant="ghost" size="icon" title="Editar">
                            <Edit className="h-4 w-4" />
                          </Button>
                        </Link>
                        <Button
                          variant="ghost"
                          size="icon"
                          title="Eliminar"
                          onClick={() => deleteGroup(group.id)}
                        >
                          <Trash2 className="h-4 w-4 text-[#D93025]" />
                        </Button>
                      </div>
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
