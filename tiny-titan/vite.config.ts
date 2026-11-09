import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Relative base so the built app also works when hosted from a sub-path
// (e.g. GitHub Pages) — there is no URL routing, tabs are in-app state.
export default defineConfig({
  base: './',
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:8787',
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
  },
  test: {
    environment: 'node',
    include: ['tests/**/*.test.ts'],
  },
});
