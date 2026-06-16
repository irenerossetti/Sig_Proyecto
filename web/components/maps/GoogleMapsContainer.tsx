"use client";

import { useEffect, useState } from "react";
import dynamic from "next/dynamic";
import type { GoogleMapViewProps } from "./GoogleMapView";

// Lazy load the Google Maps components to avoid SSR issues
const GoogleMapsWrapper = dynamic(() => import("./GoogleMapsProvider"), {
  ssr: false,
});

const GoogleMapViewComponent = dynamic(() => import("./GoogleMapView"), {
  ssr: false,
  loading: () => (
    <div className="flex items-center justify-center h-full bg-[#F8F9FA] dark:bg-[#262626] rounded-xl">
      <div className="flex flex-col items-center gap-2">
        <div className="w-8 h-8 border-4 border-[#1E8E3E] border-t-transparent rounded-full animate-spin" />
        <span className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">Cargando mapa...</span>
      </div>
    </div>
  ),
});

export default function GoogleMapsContainer(props: GoogleMapViewProps) {
  const [isMounted, setIsMounted] = useState(false);

  useEffect(() => {
    const timer = requestAnimationFrame(() => setIsMounted(true));
    return () => cancelAnimationFrame(timer);
  }, []);

  if (!isMounted) {
    return (
      <div 
        className={`bg-[#F8F9FA] dark:bg-[#262626] rounded-xl ${props.className || ""}`}
        style={{ height: props.height || "400px" }}
      >
        <div className="flex items-center justify-center h-full">
          <span className="text-sm text-[#5F6368] dark:text-[#9AA0A6]">Inicializando mapa...</span>
        </div>
      </div>
    );
  }

  return (
    <GoogleMapsWrapper>
      <GoogleMapViewComponent {...props} />
    </GoogleMapsWrapper>
  );
}
