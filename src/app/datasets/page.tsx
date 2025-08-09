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
  const [file, setFile] = useState<File | null>(null)
  const [creating, setCreating] = useState(false)

  useEffect(() => {
    fetch('/api/datasets')
      .then((r) => r.json())
      .then((d) => setItems(d.datasets))
      .catch(() => setItems([]))
  }, [])

  const handleCreate = async () => {
    if (!name || !file) return
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
        await fetch(upload.url, { method: 'PUT', body: file, headers: { 'content-type': 'application/pdf' } })
        await fetch(`/api/datasets/${datasetId}/parse`, { method: 'POST' })
        // reload list
        const list = await fetch('/api/datasets').then((r) => r.json())
        setItems(list.datasets)
        setName('')
        setDescription('')
        setFile(null)
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
          <input
            aria-label="PDF file"
            className="border rounded px-3 py-2"
            type="file"
            accept="application/pdf"
            onChange={(e) => setFile(e.target.files?.[0] ?? null)}
          />
          <button
            className="bg-black text-white rounded px-4 py-2 disabled:opacity-50"
            onClick={handleCreate}
            disabled={!name || !file || creating}
          >
            {creating ? 'Creating…' : 'Create & Parse'}
          </button>
        </div>
      </div>

      <div className="divide-y border rounded">
        {items.map((d) => (
          <a key={d.id} href={`/datasets/${d.id}`} className="block p-4 hover:bg-gray-50">
            <div className="font-medium">{d.name}</div>
            <div className="text-sm text-gray-600">{d.description}</div>
            <div className="text-sm">Docs: {d._count.documents} • Samples: {d._count.samples}</div>
          </a>
        ))}
        {items.length === 0 && <div className="p-4 text-sm text-gray-500">No datasets yet.</div>}
      </div>
    </div>
  )
}





