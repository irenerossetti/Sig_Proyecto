import axios, { AxiosError, InternalAxiosRequestConfig } from "axios";

// Backend desplegado en api.geoguard.site o usando URL local configurada
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL 
  ? `${process.env.NEXT_PUBLIC_API_URL}/api`
  : "https://api.geoguard.site/api";

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    "Content-Type": "application/json",
  },
});

// Request interceptor - añade el token a cada request
api.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    if (typeof window !== "undefined") {
      const token = localStorage.getItem("auth_token");
      if (token) {
        config.headers.Authorization = `Token ${token}`;
      }
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor - maneja errores 401
api.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (error.response?.status === 401) {
      if (typeof window !== "undefined") {
        localStorage.removeItem("auth_token");
        localStorage.removeItem("user");
        window.location.href = "/login";
      }
    }
    return Promise.reject(error);
  }
);

export default api;

// API Endpoints
export const API_ENDPOINTS = {
  // Auth
  LOGIN: "/auth/login/",
  REGISTER: "/auth/register/",
  LOGOUT: "/auth/logout/",
  PROFILE: "/auth/profile/",
  CHANGE_PASSWORD: "/auth/change-password/",
  USERS: "/auth/users/",
  
  // Monitoring
  CHILDREN: "/monitoring/children/",
  DEVICES: "/monitoring/devices/",
  SAFE_ZONES: "/monitoring/safe-zones/",
  LOCATIONS: "/monitoring/locations/",
  ALERTS: "/monitoring/alerts/",
  DASHBOARD: "/monitoring/dashboard/",
  NOTIFICATIONS: "/monitoring/notifications/",
  
  // Groups
  GROUPS: "/monitoring/groups/",
  GROUP_SAFE_ZONES: "/monitoring/group-safe-zones/",
};
