"use client";

import { useEffect, useState } from "react";
import api, { API_ENDPOINTS } from "@/lib/api";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
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
import { formatDateTime, formatTimeAgo } from "@/lib/utils";
import { Notification, User } from "@/lib/types";
import { Bell, Send, Plus, X, Users, User as UserIcon, Megaphone } from "lucide-react";

interface NotificationForm {
  title: string;
  message: string;
  recipient_type: "all" | "tutors" | "specific";
  specific_user: number | null;
}

export default function NotificationsPage() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [isSending, setIsSending] = useState<number | null>(null);
  const [isCreating, setIsCreating] = useState(false);

  const [form, setForm] = useState<NotificationForm>({
    title: "",
    message: "",
    recipient_type: "all",
    specific_user: null,
  });

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setIsLoading(true);
      const [notifResponse, usersResponse] = await Promise.all([
        api.get(API_ENDPOINTS.NOTIFICATIONS),
        api.get(API_ENDPOINTS.USERS),
      ]);

      setNotifications(notifResponse.data.results || notifResponse.data);
      setUsers(usersResponse.data.results || usersResponse.data);
    } catch (err: unknown) {
      console.error("Error fetching data:", err);
      const axiosErr = err as { response?: { status?: number } };
      if (axiosErr.response?.status === 403) {
        setError("No tienes permisos para acceder a esta sección");
      } else {
        setError("Error al cargar las notificaciones");
      }
    } finally {
      setIsLoading(false);
    }
  };

  const createNotification = async () => {
    if (!form.title.trim() || !form.message.trim()) {
      setError("El título y mensaje son requeridos");
      return;
    }

    if (form.recipient_type === "specific" && !form.specific_user) {
      setError("Debes seleccionar un usuario específico");
      return;
    }

    try {
      setIsCreating(true);
      setError(null);

      const payload = {
        title: form.title,
        message: form.message,
        recipient_type: form.recipient_type,
        specific_user: form.recipient_type === "specific" ? form.specific_user : null,
      };

      const response = await api.post(API_ENDPOINTS.NOTIFICATIONS, payload);
      setNotifications([response.data, ...notifications]);
      setShowForm(false);
      setForm({
        title: "",
        message: "",
        recipient_type: "all",
        specific_user: null,
      });
    } catch (err: unknown) {
      console.error("Error creating notification:", err);
      const axiosErr = err as { response?: { data?: { detail?: string } } };
      setError(axiosErr.response?.data?.detail || "Error al crear la notificación");
    } finally {
      setIsCreating(false);
    }
  };

  const sendNotification = async (notificationId: number) => {
    try {
      setIsSending(notificationId);
      setError(null);

      const response = await api.post(
        `${API_ENDPOINTS.NOTIFICATIONS}${notificationId}/send/`
      );

      // Update notification in list
      setNotifications(
        notifications.map((n) =>
          n.id === notificationId
            ? {
                ...n,
                status: response.data.status,
                sent_count: response.data.sent_count,
                failed_count: response.data.failed_count,
                sent_at: new Date().toISOString(),
              }
            : n
        )
      );

      alert(response.data.message);
    } catch (err: unknown) {
      console.error("Error sending notification:", err);
      const axiosErr = err as { response?: { data?: { error?: string } } };
      setError(
        axiosErr.response?.data?.error || "Error al enviar la notificación"
      );
    } finally {
      setIsSending(null);
    }
  };

  const deleteNotification = async (notificationId: number) => {
    if (!confirm("¿Estás seguro de eliminar esta notificación?")) {
      return;
    }

    try {
      await api.delete(`${API_ENDPOINTS.NOTIFICATIONS}${notificationId}/`);
      setNotifications(notifications.filter((n) => n.id !== notificationId));
    } catch (err: unknown) {
      console.error("Error deleting notification:", err);
      setError("Error al eliminar la notificación");
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case "sent":
        return <Badge variant="success">Enviada</Badge>;
      case "failed":
        return <Badge variant="danger">Fallida</Badge>;
      default:
        return <Badge variant="warning">Borrador</Badge>;
    }
  };

  const getRecipientIcon = (type: string) => {
    switch (type) {
      case "all":
        return <Megaphone className="h-4 w-4" />;
      case "tutors":
        return <Users className="h-4 w-4" />;
      case "specific":
        return <UserIcon className="h-4 w-4" />;
      default:
        return <Bell className="h-4 w-4" />;
    }
  };

  if (isLoading) {
    return <Loading text="Cargando notificaciones..." />;
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[#202124] dark:text-white">
            Notificaciones Push
          </h1>
          <p className="text-[#5F6368] dark:text-[#9AA0A6]">
            Envía notificaciones manuales a los usuarios
          </p>
        </div>
        <Button onClick={() => setShowForm(true)} className="gap-2">
          <Plus className="h-4 w-4" />
          Nueva Notificación
        </Button>
      </div>

      {error && (
        <div className="p-4 bg-[#FCE8E6] dark:bg-red-900/30 border border-[#F5C6CB] dark:border-red-800 rounded-xl text-[#C5221F] dark:text-red-400">
          {error}
          <button
            onClick={() => setError(null)}
            className="ml-2 text-sm underline"
          >
            Cerrar
          </button>
        </div>
      )}

      {/* Create Form Modal */}
      {showForm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <Card className="w-full max-w-lg mx-4 bg-white dark:bg-[#1f1f1f] border-[#E8EAED] dark:border-[#404040] shadow-xl">
            <CardHeader className="flex flex-row items-center justify-between border-b border-[#E8EAED] dark:border-[#404040]">
              <CardTitle className="text-[#202124] dark:text-white">Nueva Notificación</CardTitle>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setShowForm(false)}
              >
                <X className="h-4 w-4" />
              </Button>
            </CardHeader>
            <CardContent className="space-y-4 pt-4">
              {/* Title */}
              <div>
                <label className="block text-sm font-medium text-[#202124] dark:text-[#e8eaed] mb-1">
                  Título *
                </label>
                <input
                  type="text"
                  value={form.title}
                  onChange={(e) =>
                    setForm({ ...form, title: e.target.value })
                  }
                  className="w-full px-3 py-2 border border-[#E8EAED] dark:border-[#404040] rounded-lg focus:outline-none focus:ring-2 focus:ring-[#1A73E8] bg-white dark:bg-[#2d2d2d] text-[#202124] dark:text-white"
                  placeholder="Ej: Aviso importante"
                  maxLength={100}
                />
              </div>

              {/* Message */}
              <div>
                <label className="block text-sm font-medium text-[#202124] dark:text-[#e8eaed] mb-1">
                  Mensaje *
                </label>
                <textarea
                  value={form.message}
                  onChange={(e) =>
                    setForm({ ...form, message: e.target.value })
                  }
                  className="w-full px-3 py-2 border border-[#E8EAED] dark:border-[#404040] rounded-lg focus:outline-none focus:ring-2 focus:ring-[#1A73E8] bg-white dark:bg-[#2d2d2d] text-[#202124] dark:text-white resize-none"
                  placeholder="Escribe el mensaje de la notificación..."
                  rows={4}
                />
              </div>

              {/* Recipient Type */}
              <div>
                <label className="block text-sm font-medium text-[#202124] dark:text-[#e8eaed] mb-1">
                  Destinatarios
                </label>
                <select
                  value={form.recipient_type}
                  onChange={(e) =>
                    setForm({
                      ...form,
                      recipient_type: e.target.value as "all" | "tutors" | "specific",
                      specific_user: null,
                    })
                  }
                  className="w-full px-3 py-2 border border-[#E8EAED] dark:border-[#404040] rounded-lg focus:outline-none focus:ring-2 focus:ring-[#1A73E8] bg-white dark:bg-[#2d2d2d] text-[#202124] dark:text-white"
                >
                  <option value="all">Todos los usuarios</option>
                  <option value="tutors">Solo tutores</option>
                  <option value="specific">Usuario específico</option>
                </select>
              </div>

              {/* Specific User Select */}
              {form.recipient_type === "specific" && (
                <div>
                  <label className="block text-sm font-medium text-[#202124] dark:text-[#e8eaed] mb-1">
                    Seleccionar Usuario
                  </label>
                  <select
                    value={form.specific_user || ""}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        specific_user: e.target.value
                          ? parseInt(e.target.value)
                          : null,
                      })
                    }
                    className="w-full px-3 py-2 border border-[#E8EAED] dark:border-[#404040] rounded-lg focus:outline-none focus:ring-2 focus:ring-[#1A73E8] bg-white dark:bg-[#2d2d2d] text-[#202124] dark:text-white"
                  >
                    <option value="">Seleccionar...</option>
                    {users.map((user) => (
                      <option key={user.id} value={user.id}>
                        {user.full_name || user.email} ({user.email})
                      </option>
                    ))}
                  </select>
                </div>
              )}

              {/* Actions */}
              <div className="flex justify-end gap-2 pt-4 border-t border-[#E8EAED] dark:border-[#404040]">
                <Button
                  variant="outline"
                  onClick={() => setShowForm(false)}
                >
                  Cancelar
                </Button>
                <Button
                  onClick={createNotification}
                  disabled={isCreating}
                  className="gap-2"
                >
                  {isCreating ? (
                    "Creando..."
                  ) : (
                    <>
                      <Plus className="h-4 w-4" />
                      Crear Notificación
                    </>
                  )}
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Notifications List */}
      {notifications.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <div className="p-4 bg-[#E8F0FE] dark:bg-[#1A3A5C] rounded-full mb-4">
              <Bell className="h-8 w-8 text-[#1A73E8] dark:text-[#60a5fa]" />
            </div>
            <h3 className="text-lg font-medium text-[#202124] dark:text-white mb-2">
              No hay notificaciones
            </h3>
            <p className="text-[#5F6368] dark:text-[#9AA0A6] text-center">
              Crea una nueva notificación para enviar mensajes a los usuarios
            </p>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Estado</TableHead>
                  <TableHead>Título</TableHead>
                  <TableHead>Destinatarios</TableHead>
                  <TableHead>Resultados</TableHead>
                  <TableHead>Creado por</TableHead>
                  <TableHead>Fecha</TableHead>
                  <TableHead className="text-right">Acciones</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {notifications.map((notification) => (
                  <TableRow
                    key={notification.id}
                  >
                    <TableCell>
                      {getStatusBadge(notification.status)}
                    </TableCell>
                    <TableCell>
                      <div>
                        <div className="font-medium text-[#202124] dark:text-white">
                          {notification.title}
                        </div>
                        <div className="text-sm text-[#5F6368] dark:text-[#9AA0A6] max-w-xs truncate">
                          {notification.message}
                        </div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        {getRecipientIcon(notification.recipient_type)}
                        <span className="text-[#5F6368] dark:text-[#9AA0A6]">
                          {notification.recipient_type_display ||
                            (notification.recipient_type === "all"
                              ? "Todos"
                              : notification.recipient_type === "tutors"
                              ? "Tutores"
                              : notification.specific_user_email || "Específico")}
                        </span>
                      </div>
                    </TableCell>
                    <TableCell>
                      {notification.status === "sent" ? (
                        <div className="text-sm">
                          <span className="text-[#1E8E3E]">
                            ✓ {notification.sent_count}
                          </span>
                          {notification.failed_count > 0 && (
                            <span className="text-[#D93025] ml-2">
                              ✗ {notification.failed_count}
                            </span>
                          )}
                        </div>
                      ) : (
                        <span className="text-[#9AA0A6] dark:text-[#737373]">-</span>
                      )}
                    </TableCell>
                    <TableCell className="text-[#5F6368] dark:text-[#9AA0A6]">
                      {notification.created_by_name || "-"}
                    </TableCell>
                    <TableCell>
                      <div>
                        <div className="text-sm text-[#202124] dark:text-white">
                          {formatTimeAgo(notification.created_at)}
                        </div>
                        {notification.sent_at && (
                          <div className="text-xs text-[#9AA0A6] dark:text-[#737373]">
                            Enviada: {formatDateTime(notification.sent_at)}
                          </div>
                        )}
                      </div>
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-2">
                        {notification.status === "draft" && (
                          <Button
                            variant="default"
                            size="sm"
                            onClick={() => sendNotification(notification.id)}
                            disabled={isSending === notification.id}
                            className="gap-1"
                          >
                            <Send className="h-4 w-4" />
                            {isSending === notification.id
                              ? "Enviando..."
                              : "Enviar"}
                          </Button>
                        )}
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => deleteNotification(notification.id)}
                          className="text-[#D93025] hover:text-[#B31412] hover:bg-[#FCE8E6] dark:hover:bg-red-900/30"
                        >
                          <X className="h-4 w-4" />
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
