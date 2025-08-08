import { z } from 'zod'

const configSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  // Database
  DATABASE_URL: z.string().url(),
  // Redis
  REDIS_URL: z.string().url(),
  // S3 / MinIO
  S3_ENDPOINT: z.string().url(),
  S3_ACCESS_KEY_ID: z.string().min(1),
  S3_SECRET_ACCESS_KEY: z.string().min(1),
  S3_BUCKET: z.string().min(1),
  // Langfuse
  LANGFUSE_HOST: z.string().url().optional().or(z.literal('')),
  LANGFUSE_PUBLIC_KEY: z.string().optional().or(z.literal('')),
  LANGFUSE_SECRET_KEY: z.string().optional().or(z.literal('')),
  // OpenAI-compatible
  OPENAI_API_BASE: z.string().url().optional().or(z.literal('')),
  OPENAI_API_KEY: z.string().optional().or(z.literal('')),
})

export type AppConfig = z.infer<typeof configSchema>

export const loadConfig = (): AppConfig => {
  const parsed = configSchema.safeParse(process.env)
  if (!parsed.success) {
    const issues = parsed.error.issues
      .map((i) => `${i.path.join('.')}: ${i.message}`)
      .join('\n')
    throw new Error(`Invalid configuration:\n${issues}`)
  }
  return parsed.data
}

export const config = loadConfig()


