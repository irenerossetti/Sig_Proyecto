"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import api, { API_ENDPOINTS } from "@/lib/api";
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  Button,
  Input,
  Loading,
} from "@/components/ui";
import { ChildGroup } from "@/lib/types";
import { ArrowLeft, Save, UsersRound } from "lucide-react";

const PRESET_COLORS = [
  "#1E8E3E", // Green
  "#1A73E8", // Blue
  "#9C27B0", // Purple
  "#F57C00", // Orange
  "#E91E63", // Pink
  "#00BCD4", // Cyan
  "#795548", // Brown
  "#607D8B", // Gray
];

export default function GroupEditPage() {
  const params = useParams();
  const router = useRouter();
  const id = params.id as string;

  const [group, setGroup] = useState<ChildGroup | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [formData, setFormData] = useState({
    name: "",
    description: "",
    color: "#1E8E3E",
    is_active: true,
  });

  useEffect(() => {
    const fetchGroup = async () => {
      try {
        const response = await api.get(`${API_ENDPOINTS.GROUPS}${id}/`);
        setGroup(response.data);
        setFormData({
          name: response.data.name,
          description: response.data.description || "",
          color: response.data.color || "#1E8E3E",
          is_active: response.data.is_active,
        });
      } catch (err) {
        console.error("Error fetching group:", err);
        setError("Error al cargar el grupo");
      } finally {
        setIsLoading(false);
      }
    };

    if (id) {
      fetchGroup();
    }
  }, [id]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);
    setError(null);

    try {
      await api.patch(`${API_ENDPOINTS.GROUPS}${id}/`, formData);
      router.push(`/groups/${id}`);
    } catch (err: unknown) {
      console.error("Error updating group:", err);
      const axiosErr = err as { response?: { data?: { detail?: string; message?: string } } };
      setError(
        axiosErr.response?.data?.detail ||
          axiosErr.response?.data?.message ||
          "Error al actualizar el grupo"
      );
    } finally {
      setIsSaving(false);
    }
  };

  if (isLoading) {
    return <Loading text="Cargando grupo..." />;
  }

  if (error && !group) {
    return (
      <div className="flex flex-col items-center justify-center h-64">
        <p className="text-[#D93025] mb-4">{error}</p>
        <Link href="/groups">
          <Button variant="outline">Volver a la lista</Button>
        </Link>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link href={`/groups/${id}`}>
          <Button variant="ghost" size="icon">
            <ArrowLeft className="h-5 w-5" />
          </Button>
        </Link>
        <h1 className="text-2xl font-bold text-[#202124] dark:text-white">Editar grupo</h1>
      </div>

      <form onSubmit={handleSubmit}>
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-[#202124] dark:text-white">
              <UsersRound className="h-5 w-5 text-[#1E8E3E] dark:text-[#4ade80]" />
              Información del grupo
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            {error && (
              <div className="p-3 bg-[#FBECED] dark:bg-[#5C2B29] border border-[#D93025] dark:border-[#8B3A3A] rounded-lg text-[#D93025] dark:text-[#F28B82] text-sm">
                {error}
              </div>
            )}

            {/* Preview */}
            <div className="flex items-center gap-4 p-4 bg-[#F8F9FA] dark:bg-[#262626] rounded-xl">
              <div
                className="w-14 h-14 rounded-full flex items-center justify-center transition-colors"
                style={{ backgroundColor: formData.color + "20" }}
              >
                <UsersRound
                  className="h-7 w-7 transition-colors"
                  style={{ color: formData.color }}
                />
              </div>
              <div>
                <p className="font-medium text-[#202124] dark:text-white">
                  {formData.name || "Nombre del grupo"}
                </p>
                <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">
                  {formData.description || "Sin descripción"}
                </p>
              </div>
            </div>

            {/* Name */}
            <div className="space-y-2">
              <label className="text-sm font-medium text-[#202124] dark:text-white">
                Nombre <span className="text-[#D93025]">*</span>
              </label>
              <Input
                value={formData.name}
                onChange={(e) =>
                  setFormData({ ...formData, name: e.target.value })
                }
                placeholder="Ej: Sala Amarilla"
                required
              />
            </div>

            {/* Description */}
            <div className="space-y-2">
              <label className="text-sm font-medium text-[#202124] dark:text-white">
                Descripción
              </label>
              <textarea
                value={formData.description}
                onChange={(e) =>
                  setFormData({ ...formData, description: e.target.value })
                }
                placeholder="Descripción opcional del grupo"
                rows={3}
                className="w-full px-4 py-2 border border-[#E8EAED] dark:border-[#404040] rounded-xl focus:outline-none focus:ring-2 focus:ring-[#1E8E3E]/20 focus:border-[#1E8E3E] bg-white dark:bg-[#262626] text-[#202124] dark:text-white"
              />
            </div>

            {/* Color */}
            <div className="space-y-2">
              <label className="text-sm font-medium text-[#202124] dark:text-white">Color</label>
              <div className="flex flex-wrap gap-3">
                {PRESET_COLORS.map((color) => (
                  <button
                    key={color}
                    type="button"
                    onClick={() => setFormData({ ...formData, color })}
                    className={`w-10 h-10 rounded-full transition-all ${
                      formData.color === color
                        ? "ring-2 ring-offset-2 ring-[#202124] dark:ring-white dark:ring-offset-[#0a0a0a]"
                        : "hover:scale-110"
                    }`}
                    style={{ backgroundColor: color }}
                  />
                ))}
              </div>
            </div>

            {/* Active Status */}
            <div className="flex items-center justify-between p-4 bg-[#F8F9FA] dark:bg-[#262626] rounded-xl">
              <div>
                <p className="font-medium text-[#202124] dark:text-white">Estado del grupo</p>
                <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">
                  {formData.is_active
                    ? "El grupo está activo"
                    : "El grupo está inactivo"}
                </p>
              </div>
              <button
                type="button"
                onClick={() =>
                  setFormData({ ...formData, is_active: !formData.is_active })
                }
                className={`relative w-14 h-7 rounded-full transition-colors ${
                  formData.is_active ? "bg-[#1E8E3E]" : "bg-[#E8EAED] dark:bg-[#404040]"
                }`}
              >
                <span
                  className={`absolute top-0.5 w-6 h-6 bg-white rounded-full shadow transition-transform ${
                    formData.is_active ? "left-7" : "left-0.5"
                  }`}
                />
              </button>
            </div>

            {/* Actions */}
            <div className="flex gap-3 pt-4">
              <Link href={`/groups/${id}`} className="flex-1">
                <Button variant="outline" className="w-full">
                  Cancelar
                </Button>
              </Link>
              <Button
                type="submit"
                disabled={isSaving || !formData.name}
                className="flex-1 gap-2"
              >
                {isSaving ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white/20 border-t-white rounded-full animate-spin" />
                    Guardando...
                  </>
                ) : (
                  <>
                    <Save className="h-4 w-4" />
                    Guardar cambios
                  </>
                )}
              </Button>
            </div>
          </CardContent>
        </Card>
      </form>
    </div>
  );
}
