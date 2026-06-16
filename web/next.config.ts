import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "storage.googleapis.com",
        pathname: "/geoguard-media/**",
      },
      {
        protocol: "http",
        hostname: "34.45.10.241",
        pathname: "/media/**",
      },
    ],
    unoptimized: true,
  },
};

export default nextConfig;
