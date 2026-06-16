"use client";

import { Libraries, useJsApiLoader } from "@react-google-maps/api";
import { ReactNode, createContext, useContext } from "react";

const libraries: Libraries = ["places", "drawing", "geometry"];

interface GoogleMapsContextType {
  isLoaded: boolean;
  loadError: Error | undefined;
}

const GoogleMapsContext = createContext<GoogleMapsContextType>({
  isLoaded: false,
  loadError: undefined,
});

export const useGoogleMaps = () => useContext(GoogleMapsContext);

interface GoogleMapsProviderProps {
  children: ReactNode;
}

export default function GoogleMapsProvider({ children }: GoogleMapsProviderProps) {
  const apiKey = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY || "";

  const { isLoaded, loadError } = useJsApiLoader({
    googleMapsApiKey: apiKey,
    libraries,
    // Previene cargas duplicadas
    id: "google-maps-script",
  });

  if (!apiKey) {
    console.warn("Google Maps API key not configured. Using fallback.");
    return (
      <div className="flex items-center justify-center h-full bg-[#F8F9FA] dark:bg-[#262626] rounded-xl p-4">
        <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">
          Mapa no disponible - API key no configurada
        </p>
      </div>
    );
  }

  if (loadError) {
    console.error("Google Maps failed to load:", loadError);
    return (
      <div className="flex items-center justify-center h-full bg-[#FCE8E6] dark:bg-[#5C2B29] rounded-xl p-4">
        <p className="text-sm text-[#D93025] dark:text-[#f87171]">
          Error al cargar Google Maps. Por favor, recarga la página.
        </p>
      </div>
    );
  }

  if (!isLoaded) {
    return (
      <div className="flex items-center justify-center h-full bg-[#F8F9FA] dark:bg-[#262626] rounded-xl">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#1E8E3E] mx-auto mb-2" />
          <p className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">Cargando mapa...</p>
        </div>
      </div>
    );
  }

  return (
    <GoogleMapsContext.Provider value={{ isLoaded, loadError }}>
      {children}
    </GoogleMapsContext.Provider>
  );
}
