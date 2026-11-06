import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    // Used only by `npm run dev`. The image serves through nginx.
    proxy: {
      "/api": "http://localhost:8000",
    },
  },
});
