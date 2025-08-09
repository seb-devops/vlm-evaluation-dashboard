import { defineConfig } from 'vitest/config'
import { fileURLToPath } from 'url'
import { dirname, resolve } from 'path'

const rootDir = dirname(fileURLToPath(new URL(import.meta.url)))

export default defineConfig({
  test: {
    environment: 'node',
    include: ['tests/**/*.test.ts'],
    passWithNoTests: false,
  },
  resolve: {
    alias: [{ find: /^@\//, replacement: resolve(rootDir, './') + '/' }],
  },
  css: {
    postcss: {},
  },
})


