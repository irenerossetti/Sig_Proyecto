"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import api, { API_ENDPOINTS } from "@/lib/api";
import {
  Card,
  CardContent,
  CardFooter,
  Button,
  Input,
} from "@/components/ui";
import { ArrowLeft, Loader2, UsersRound } from "lucide-react";
import { AxiosError } from "axios";

const COLORS = [
  "#1E8E3E", // Green
  "#1A73E8", // Blue
  "#E8710A", // Orange
  "#D93025", // Red
  "#9334E6", // Purple
  "#00ACC1", // Cyan
  "#F9AB00", // Yellow
  "#5F6368", // Gray
];

export default function NewGroupPage() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [color, setColor] = useState(COLORS[0]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setIsLoading(true);

    try {
      await api.post(API_ENDPOINTS.GROUPS, {
        name,
        description,
        color,
        icon: "users",
        is_active: true,
      });
      router.push("/groups");
    } catch (err) {
      const axiosError = err as AxiosError<{ detail?: string }>;
      setError(
        axiosError.response?.data?.detail || "Error al crear el grupo"
      );
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link href="/groups">
          <Button variant="ghost" size="icon">
            <ArrowLeft className="h-5 w-5" />
          </Button>
        </Link>
        <div>
          <h1 className="text-2xl font-bold text-[#202124] dark:text-white">Nuevo grupo</h1>
          <p className="text-[#5F6368] dark:text-[#9AA0A6]">Crea un grupo para monitoreo colectivo</p>
        </div>
      </div>

      {/* Form */}
      <Card>
        <form onSubmit={handleSubmit}>
          <CardContent className="space-y-4 pt-6">
            {error && (
              <div className="p-3 bg-[#FCE8E6] dark:bg-[#5C2B29] border border-[#F5C6CB] dark:border-[#8B3A3A] rounded-xl text-[#C5221F] dark:text-[#F28B82] text-sm">
                {error}
              </div>
            )}

            <Input
              label="Nombre del grupo"
              type="text"
              placeholder="Ej: Kinder Los Angelitos"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
            />

            <div>
              <label className="block text-sm font-medium text-[#202124] dark:text-white mb-1">
                Descripción (opcional)
              </label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Descripción del grupo..."
                rows={3}
                className="flex w-full rounded-xl border border-[#DADCE0] dark:border-[#404040] bg-white dark:bg-[#262626] px-3 py-2 text-sm text-[#202124] dark:text-white placeholder:text-[#9AA0A6] focus:outline-none focus:ring-2 focus:ring-[#1E8E3E] focus:border-transparent"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-[#202124] dark:text-white mb-2">
                Color del grupo
              </label>
              <div className="flex gap-2 flex-wrap">
                {COLORS.map((c) => (
                  <button
                    key={c}
                    type="button"
                    onClick={() => setColor(c)}
                    className={`w-10 h-10 rounded-full transition-all ${
                      color === c
                        ? "ring-2 ring-offset-2 ring-[#202124] dark:ring-white dark:ring-offset-[#0a0a0a] scale-110"
                        : "hover:scale-105"
                    }`}
                    style={{ backgroundColor: c }}
                  />
                ))}
              </div>
            </div>

            {/* Preview */}
            <div className="p-4 bg-[#F8F9FA] dark:bg-[#262626] rounded-xl">
              <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6] mb-2">Vista previa:</p>
              <div className="flex items-center gap-3">
                <div
                  className="w-12 h-12 rounded-full flex items-center justify-center"
                  style={{ backgroundColor: color + "20" }}
                >
                  <UsersRound className="h-6 w-6" style={{ color: color }} />
                </div>
                <div>
                  <p className="font-medium text-[#202124] dark:text-white">
                    {name || "Nombre del grupo"}
                  </p>
                  <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">
                    {description || "Sin descripción"}
                  </p>
                </div>
              </div>
            </div>
          </CardContent>

          <CardFooter className="flex gap-3">
            <Link href="/groups" className="flex-1">
              <Button type="button" variant="outline" className="w-full">
                Cancelar
              </Button>
            </Link>
            <Button type="submit" className="flex-1" disabled={isLoading}>
              {isLoading ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Creando...
                </>
              ) : (
                "Crear grupo"
              )}
            </Button>
          </CardFooter>
        </form>
      </Card>
    </div>
  );
}
