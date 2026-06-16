"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import api, { API_ENDPOINTS } from "@/lib/api";
import {
  Card,
  CardContent,
  CardFooter,
  Button,
  Input,
} from "@/components/ui";
import { ArrowLeft, Loader2 } from "lucide-react";
import Link from "next/link";
import { AxiosError } from "axios";

export default function NewChildPage() {
  const router = useRouter();
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [dateOfBirth, setDateOfBirth] = useState("");
  const [grade, setGrade] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setIsLoading(true);

    try {
      await api.post(API_ENDPOINTS.CHILDREN, {
        first_name: firstName,
        last_name: lastName,
        date_of_birth: dateOfBirth,
        grade: grade || undefined,
      });
      router.push("/children");
    } catch (err) {
      const axiosError = err as AxiosError<{ detail?: string }>;
      setError(
        axiosError.response?.data?.detail || "Error al crear el niño"
      );
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link href="/children">
          <Button variant="ghost" size="icon">
            <ArrowLeft className="h-5 w-5" />
          </Button>
        </Link>
        <div>
          <h1 className="text-2xl font-bold text-[#202124] dark:text-white">Agregar niño</h1>
          <p className="text-[#5F6368] dark:text-[#9AA0A6]">Registra un nuevo niño bajo tu cuidado</p>
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
            <Link href="/children" className="flex-1">
              <Button type="button" variant="outline" className="w-full">
                Cancelar
              </Button>
            </Link>
            <Button type="submit" className="flex-1" disabled={isLoading}>
              {isLoading ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Guardando...
                </>
              ) : (
                "Guardar"
              )}
            </Button>
          </CardFooter>
        </form>
      </Card>
    </div>
  );
}
