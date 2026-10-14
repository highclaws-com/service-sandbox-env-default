import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  // Relative asset URLs, so dist/ works wherever server.py serves it.
  base: './'
})
