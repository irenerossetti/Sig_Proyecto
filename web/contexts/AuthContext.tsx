"use client";

import React, { createContext, useContext, useState, useEffect, useCallback } from "react";
import api, { API_ENDPOINTS } from "@/lib/api";
import { User, AuthResponse, LoginCredentials, RegisterData } from "@/lib/types";

interface AuthContextType {
  user: User | null;
  token: string | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (credentials: LoginCredentials) => Promise<void>;
  register: (data: RegisterData) => Promise<void>;
  logout: () => Promise<void>;
  updateUser: (user: User) => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  // Cargar token y usuario al iniciar
  useEffect(() => {
    const storedToken = localStorage.getItem("auth_token");
    const storedUser = localStorage.getItem("user");
    
    if (storedToken && storedUser) {
      setToken(storedToken);
      setUser(JSON.parse(storedUser));
    }
    setIsLoading(false);
  }, []);

  const login = useCallback(async (credentials: LoginCredentials) => {
    const response = await api.post<AuthResponse>(API_ENDPOINTS.LOGIN, credentials);
    const { token: authToken, user: authUser } = response.data;
    
    localStorage.setItem("auth_token", authToken);
    localStorage.setItem("user", JSON.stringify(authUser));
    
    setToken(authToken);
    setUser(authUser);
  }, []);

  const register = useCallback(async (data: RegisterData) => {
    const response = await api.post<AuthResponse>(API_ENDPOINTS.REGISTER, data);
    const { token: authToken, user: authUser } = response.data;
    
    localStorage.setItem("auth_token", authToken);
    localStorage.setItem("user", JSON.stringify(authUser));
    
    setToken(authToken);
    setUser(authUser);
  }, []);

  const logout = useCallback(async () => {
    try {
      await api.post(API_ENDPOINTS.LOGOUT);
    } catch {
      // Ignorar errores de logout
    } finally {
      localStorage.removeItem("auth_token");
      localStorage.removeItem("user");
      setToken(null);
      setUser(null);
    }
  }, []);

  const updateUser = useCallback((updatedUser: User) => {
    localStorage.setItem("user", JSON.stringify(updatedUser));
    setUser(updatedUser);
  }, []);

  return (
    <AuthContext.Provider
      value={{
        user,
        token,
        isLoading,
        isAuthenticated: !!token && !!user,
        login,
        register,
        logout,
        updateUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
