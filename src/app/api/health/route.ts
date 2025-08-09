import { NextResponse } from 'next/server'
import { config } from '@/src/lib/config'

export const GET = async () => {
  // Return minimal config summary to validate module loads without secrets
  return NextResponse.json({
    ok: true,
    env: config.NODE_ENV,
    hasDb: Boolean(config.DATABASE_URL),
    hasRedis: Boolean(config.REDIS_URL),
    hasS3: Boolean(config.S3_ENDPOINT && config.S3_BUCKET),
  })
}





