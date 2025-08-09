"use client"
import { useEffect, useState } from 'react'

type DatasetItem = {
  id: string
  name: string
  description?: string | null
  createdAt: string
  _count: { documents: number; samples: number }
}

export default function DatasetsPage() {
  const [items, setItems] = useState<DatasetItem[]>([])
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [creating, setCreating] = useState(false)

  useEffect(() => {
    fetch('/api/datasets')
      .then((r) => r.json())
      .then((d) => setItems(d.datasets))
      .catch(() => setItems([]))
  }, [])

  const handleCreate = async () => {
    if (!name) return
    setCreating(true)
    try {
      const res = await fetch('/api/datasets', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ name, description }),
      })
      const data = await res.json()
      if (res.ok) {
        const { datasetId, upload } = data
        // create an empty Blob to test presigned flow; user will replace with real PDF
        const testBlob = new Blob([new Uint8Array([1, 2, 3])], { type: 'application/pdf' })
        await fetch(upload.url, { method: 'PUT', body: testBlob, headers: { 'content-type': 'application/pdf' } })
        await fetch(`/api/datasets/${datasetId}/parse`, { method: 'POST' })
        // reload list
        const list = await fetch('/api/datasets').then((r) => r.json())
        setItems(list.datasets)
        setName('')
        setDescription('')
      } else {
        console.error(data)
      }
    } finally {
      setCreating(false)
    }
  }

  return (
    <div className="p-6 space-y-6">
      <div className="space-y-2">
        <h1 className="text-2xl font-semibold">Datasets</h1>
        <div className="flex flex-col gap-2 sm:flex-row">
          <input
            aria-label="Dataset name"
            className="border rounded px-3 py-2"
            placeholder="Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
          <input
            aria-label="Dataset description"
            className="border rounded px-3 py-2 flex-1"
            placeholder="Description (optional)"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
          <button
            className="bg-black text-white rounded px-4 py-2 disabled:opacity-50"
            onClick={handleCreate}
            disabled={!name || creating}
          >
            {creating ? 'Creating…' : 'Create & Parse (demo)'}
          </button>
        </div>
      </div>

      <div className="divide-y border rounded">
        {items.map((d) => (
          <div key={d.id} className="p-4">
            <div className="font-medium">{d.name}</div>
            <div className="text-sm text-gray-600">{d.description}</div>
            <div className="text-sm">Docs: {d._count.documents} • Samples: {d._count.samples}</div>
          </div>
        ))}
        {items.length === 0 && <div className="p-4 text-sm text-gray-500">No datasets yet.</div>}
      </div>
    </div>
  )
}


