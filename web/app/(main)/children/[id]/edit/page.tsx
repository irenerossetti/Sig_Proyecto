"use client";

import { useState, useEffect } from "react";
import { useRouter, useParams } from "next/navigation";
import api, { API_ENDPOINTS } from "@/lib/api";
import {
  Card,
  CardContent,
  CardFooter,
  Button,
  Input,
  Loading,
} from "@/components/ui";
import { ArrowLeft, Loader2 } from "lucide-react";
import Link from "next/link";
import { AxiosError } from "axios";
import { Child } from "@/lib/types";

export default function EditChildPage() {
  const router = useRouter();
  const params = useParams();
  const id = params.id as string;

  const [child, setChild] = useState<Child | null>(null);
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [dateOfBirth, setDateOfBirth] = useState("");
  const [grade, setGrade] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    const fetchChild = async () => {
      try {
        const response = await api.get(`${API_ENDPOINTS.CHILDREN}${id}/`);
        const childData = response.data;
        setChild(childData);
        setFirstName(childData.first_name || "");
        setLastName(childData.last_name || "");
        setDateOfBirth(childData.date_of_birth || "");
        setGrade(childData.grade || "");
      } catch (err) {
        console.error("Error fetching child:", err);
        setError("Error al cargar los datos del niño");
      } finally {
        setIsLoading(false);
      }
    };

    if (id) {
      fetchChild();
    }
  }, [id]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setIsSaving(true);

    try {
      await api.patch(`${API_ENDPOINTS.CHILDREN}${id}/`, {
        first_name: firstName,
        last_name: lastName,
        date_of_birth: dateOfBirth,
        grade: grade || null,
      });
      router.push(`/children/${id}`);
    } catch (err) {
      const axiosError = err as AxiosError<{ detail?: string }>;
      setError(
        axiosError.response?.data?.detail || "Error al actualizar el niño"
      );
    } finally {
      setIsSaving(false);
    }
  };

  if (isLoading) {
    return <Loading text="Cargando datos..." />;
  }

  if (!child && !isLoading) {
    return (
      <div className="max-w-2xl mx-auto">
        <Card className="border-[#E8EAED] dark:border-[#404040]">
          <CardContent className="py-12 text-center">
            <p className="text-[#D93025]">No se encontró el niño</p>
            <Link href="/children">
              <Button className="mt-4">Volver a la lista</Button>
            </Link>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link href={`/children/${id}`}>
          <Button variant="ghost" size="icon">
            <ArrowLeft className="h-5 w-5" />
          </Button>
        </Link>
        <div>
          <h1 className="text-2xl font-bold text-[#202124] dark:text-white">Editar niño</h1>
          <p className="text-[#5F6368] dark:text-[#9AA0A6]">
            Actualiza la información de {child?.first_name} {child?.last_name}
          </p>
        </div>
      </div>

      {/* Form */}
      <Card className="border-[#E8EAED] dark:border-[#404040]">
        <form onSubmit={handleSubmit}>
          <CardContent className="space-y-4 pt-6">
            {error && (
              <div className="p-3 bg-[#FCE8E6] dark:bg-[#5C2B29] border border-[#F5C6CB] dark:border-[#8B3A3A] rounded-xl text-[#C5221F] dark:text-[#F28B82] text-sm">
                {error}
              </div>
            )}

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <Input
                label="Nombre"
                type="text"
                placeholder="Juan"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                required
              />

              <Input
                label="Apellido"
                type="text"
                placeholder="Pérez"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                required
              />
            </div>

            <Input
              label="Fecha de nacimiento"
              type="date"
              value={dateOfBirth}
              onChange={(e) => setDateOfBirth(e.target.value)}
              required
            />

            <Input
              label="Grado/Curso (opcional)"
              type="text"
              placeholder="Kinder, 1ro primaria, etc."
              value={grade}
              onChange={(e) => setGrade(e.target.value)}
            />
          </CardContent>

          <CardFooter className="flex gap-3">
            <Link href={`/children/${id}`} className="flex-1">
              <Button type="button" variant="outline" className="w-full">
                Cancelar
              </Button>
            </Link>
            <Button type="submit" className="flex-1" disabled={isSaving}>
              {isSaving ? (
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
    </div>
  );
}
