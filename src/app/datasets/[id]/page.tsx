import { prisma } from '@/src/lib/db'

export default async function DatasetDetail({ params }: { params: { id: string } }) {
  const dataset = await prisma.dataset.findUnique({
    where: { id: params.id },
    include: {
      documents: { select: { id: true, filename: true, pageCount: true } },
      samples: { select: { id: true, pageIndices: true, inputText: true }, take: 100 },
    },
  })

  if (!dataset) return <div className="p-6">Dataset not found</div>

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">{dataset.name}</h1>
        <p className="text-gray-600">{dataset.description}</p>
      </div>

      <div className="space-y-2">
        <h2 className="font-medium">Documents</h2>
        <div className="border rounded divide-y">
          {dataset.documents.map((doc) => (
            <div key={doc.id} className="p-3 flex items-center justify-between">
              <div>{doc.filename}</div>
              <div className="text-sm text-gray-600">{doc.pageCount} pages</div>
            </div>
          ))}
          {dataset.documents.length === 0 && (
            <div className="p-3 text-sm text-gray-500">No documents</div>
          )}
        </div>
      </div>

      <div className="space-y-2">
        <h2 className="font-medium">Samples (first 100)</h2>
        <div className="border rounded divide-y">
          {dataset.samples.map((s) => (
            <div key={s.id} className="p-3">
              <div className="text-xs text-gray-600">Page {s.pageIndices?.[0] ?? '-'}</div>
              <pre className="whitespace-pre-wrap text-sm">{s.inputText}</pre>
            </div>
          ))}
          {dataset.samples.length === 0 && (
            <div className="p-3 text-sm text-gray-500">No samples</div>
          )}
        </div>
      </div>
    </div>
  )
}


