import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/src/lib/db'
import { ensureBucketExists, getPresignedUrl } from '@/src/lib/storage/s3Client'

export const POST = async (req: NextRequest) => {
  const { name, description } = await req.json()
  if (!name) return NextResponse.json({ error: 'name required' }, { status: 400 })

  const dataset = await prisma.dataset.create({
    data: {
      name,
      description: description ?? null,
      tags: [],
      storageLocation: '',
      parseConfig: { mode: 'text' },
      versionHash: 'v1',
    },
  })

  await ensureBucketExists()
  const key = `datasets/${dataset.id}/raw/${encodeURIComponent(name)}.pdf`
  const url = await getPresignedUrl(key, 'put', 'application/pdf')

  return NextResponse.json({ datasetId: dataset.id, upload: { url, key } })
}


