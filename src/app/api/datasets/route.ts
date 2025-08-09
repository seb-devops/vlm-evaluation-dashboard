import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/src/lib/db'
import { ensureBucketExists, getPresignedUrl } from '@/src/lib/storage/s3Client'
import { z } from 'zod'
import { parseJson, badRequest } from '@/src/lib/http'

export const GET = async () => {
  const datasets = await prisma.dataset.findMany({
    orderBy: { createdAt: 'desc' },
    select: {
      id: true,
      name: true,
      description: true,
      createdAt: true,
      _count: { select: { documents: true, samples: true } },
    },
  })
  return NextResponse.json({ datasets })
}

export const POST = async (req: NextRequest) => {
  const Body = z.object({ name: z.string().min(1), description: z.string().optional() })
  const parsed = await parseJson(req, Body)
  if (!('ok' in parsed) || !parsed.ok) return parsed.res
  const { name, description } = parsed.data

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


