"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
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
import { formatDate, getBatteryColor, normalizeChildPhoto } from "@/lib/utils";
import { Child } from "@/lib/types";
import { Plus, Battery, Smartphone, Eye, Edit } from "lucide-react";

export default function ChildrenPage() {
  const [children, setChildren] = useState<Child[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchChildren = async () => {
      try {
        const response = await api.get(API_ENDPOINTS.CHILDREN);
        const data = response.data.results || response.data;
        setChildren((data as Child[]).map(normalizeChildPhoto));
      } catch (err) {
        console.error("Error fetching children:", err);
        setError("Error al cargar los niños");
      } finally {
        setIsLoading(false);
      }
    };

    fetchChildren();
  }, []);

  if (isLoading) {
    return <Loading text="Cargando niños..." />;
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[#202124] dark:text-white">Niños</h1>
          <p className="text-[#5F6368] dark:text-[#9AA0A6]">Gestiona los niños bajo tu cuidado</p>
        </div>
        <Link href="/children/new">
          <Button className="gap-2">
            <Plus className="h-4 w-4" />
            Agregar niño
          </Button>
        </Link>
      </div>

      {error && (
        <div className="p-4 bg-[#FCE8E6] dark:bg-[#5C2B29] border border-[#F5C6CB] dark:border-[#8B3A3A] rounded-xl text-[#C5221F] dark:text-[#F28B82]">
          {error}
        </div>
      )}

      {/* Children List */}
      {children.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="p-4 bg-[#DCF5E3] dark:bg-[#1E3A2F] rounded-full mb-4">
              <Plus className="h-8 w-8 text-[#1E8E3E] dark:text-[#4ade80]" />
            </div>
            <h3 className="text-lg font-medium text-[#202124] dark:text-white mb-2">
              No hay niños registrados
            </h3>
            <p className="text-[#5F6368] dark:text-[#9AA0A6] mb-4">
              Comienza agregando tu primer niño
            </p>
            <Link href="/children/new">
              <Button>Agregar niño</Button>
            </Link>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Niño</TableHead>
                  <TableHead>Grado</TableHead>
                  <TableHead>Fecha de nacimiento</TableHead>
                  <TableHead>Dispositivo</TableHead>
                  <TableHead>Batería</TableHead>
                  <TableHead className="text-right">Acciones</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {children.map((child) => (
                  <TableRow key={child.id}>
                    <TableCell>
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-[#DCF5E3] dark:bg-[#1E3A2F] flex items-center justify-center flex-shrink-0 overflow-hidden">
                          {child.photo ? (
                            <Image
                              src={child.photo}
                              alt={child.full_name}
                              width={40}
                              height={40}
                              className="w-10 h-10 rounded-full object-cover"
                              unoptimized
                            />
                          ) : (
                            <span className="text-[#1E8E3E] dark:text-[#4ade80] font-medium">
                              {(child.full_name || "N")[0]}
                            </span>
                          )}
                        </div>
                        <div>
                          <p className="font-medium text-[#202124] dark:text-white">
                            {child.full_name}
                          </p>
                          {child.tutor_name && (
                            <p className="text-xs text-[#5F6368] dark:text-[#9AA0A6]">Tutor: {child.tutor_name}</p>
                          )}
                        </div>
                      </div>
                    </TableCell>
                    <TableCell className="text-[#202124] dark:text-white">{child.grade || "-"}</TableCell>
                    <TableCell className="text-[#202124] dark:text-white">{formatDate(child.date_of_birth)}</TableCell>
                    <TableCell>
                      {child.device ? (
                        <div className="flex items-center gap-2">
                          <Smartphone className="h-4 w-4 text-[#1E8E3E] dark:text-[#4ade80]" />
                          <Badge variant="success">Conectado</Badge>
                        </div>
                      ) : (
                        <Badge variant="default">Sin dispositivo</Badge>
                      )}
                    </TableCell>
                    <TableCell>
                      {child.device?.battery_level !== null &&
                      child.device?.battery_level !== undefined ? (
                        <div className="flex items-center gap-1 text-[#202124] dark:text-white">
                          <Battery
                            className={`h-4 w-4 ${getBatteryColor(
                              child.device.battery_level
                            )}`}
                          />
                          <span>{child.device.battery_level}%</span>
                        </div>
                      ) : (
                        <span className="text-[#9AA0A6]">-</span>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex items-center justify-end gap-2">
                        <Link href={`/children/${child.id}`}>
                          <Button variant="ghost" size="icon" title="Ver detalles">
                            <Eye className="h-4 w-4" />
                          </Button>
                        </Link>
                        <Link href={`/children/${child.id}/edit`}>
                          <Button variant="ghost" size="icon" title="Editar">
                            <Edit className="h-4 w-4" />
                          </Button>
                        </Link>
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
