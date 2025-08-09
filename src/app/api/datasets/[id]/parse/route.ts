import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/src/lib/db'
import { getObjectStream } from '@/src/lib/storage/s3Client'
import pdf from 'pdf-parse'
import { badRequest, notFound } from '@/src/lib/http'

export const POST = async (_req: NextRequest, { params }: { params: { id: string } }) => {
  const datasetId = params.id
  const dataset = await prisma.dataset.findUnique({ where: { id: datasetId } })
  if (!dataset) return notFound('dataset not found')

  const keyPrefix = `datasets/${datasetId}/raw/`
  // For MVP, assume single file named after dataset
  const key = `${keyPrefix}${encodeURIComponent(dataset.name)}.pdf`
  const stream: any = await getObjectStream(key)
  if (!stream) return notFound('pdf not found in storage')

  const buf = await streamToBuffer(stream as NodeJS.ReadableStream)
  const data = await pdf(buf)

  const textByPage = data.text.split('\f')

  const doc = await prisma.document.create({
    data: {
      datasetId,
      filename: `${dataset.name}.pdf`,
      fileHash: 'na',
      pageCount: textByPage.length,
    },
  })

  for (let i = 0; i < textByPage.length; i += 1) {
    await prisma.sample.create({
      data: {
        datasetId,
        documentId: doc.id,
        pageIndices: [i],
        inputText: textByPage[i].trim(),
        expectedAnswer: null,
        tags: [],
      },
    })
  }

  return NextResponse.json({ ok: true, documentId: doc.id, samples: textByPage.length })
}

const streamToBuffer = (stream: NodeJS.ReadableStream): Promise<Buffer> => {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = []
    stream.on('data', (chunk) => chunks.push(Buffer.from(chunk)))
    stream.on('error', (err) => reject(err))
    stream.on('end', () => resolve(Buffer.concat(chunks)))
  })
}


