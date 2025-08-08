import { NextRequest, NextResponse } from 'next/server'
import { ensureBucketExists, getPresignedUrl } from '@/src/lib/storage/s3Client'

export const POST = async (req: NextRequest) => {
  const { key, method, contentType } = await req.json()
  if (!key || !method) {
    return NextResponse.json({ error: 'key and method are required' }, { status: 400 })
  }
  await ensureBucketExists()
  const url = await getPresignedUrl(key, method, contentType)
  return NextResponse.json({ url })
}


