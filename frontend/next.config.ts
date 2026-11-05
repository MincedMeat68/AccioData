import type { NextConfig } from "next";

// The browser only ever talks to Next.js; /api/* is proxied to Sinatra.
// Same origin means no CORS configuration. 127.0.0.1 (not "localhost") avoids
// Node resolving to IPv6 ::1 while the Ruby server listens on IPv4.
const backendUrl = process.env.BACKEND_URL ?? "http://127.0.0.1:4567";

const nextConfig: NextConfig = {
  output: "standalone",
  // The repo root has its own package-lock.json (for `concurrently`); pin the
  // app root so Next doesn't guess the wrong workspace.
  outputFileTracingRoot: __dirname,
  async rewrites() {
    return [{ source: "/api/:path*", destination: `${backendUrl}/api/:path*` }];
  },
};

export default nextConfig;
