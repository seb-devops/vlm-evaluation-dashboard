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
    <div className="space-y-8">
      <section className="card p-6 space-y-4">
        <div>
          <h1 className="text-xl font-semibold">Create dataset</h1>
          <p className="text-sm text-slate-600">Upload a PDF and we’ll extract text per page.</p>
        </div>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-4">
          <input aria-label="Dataset name" className="input" placeholder="Name" value={name} onChange={(e) => setName(e.target.value)} />
          <input aria-label="Dataset description" className="input sm:col-span-2" placeholder="Description (optional)" value={description} onChange={(e) => setDescription(e.target.value)} />
          <input aria-label="PDF file" className="input" type="file" accept="application/pdf" onChange={(e) => setFile(e.target.files?.[0] ?? null)} />
        </div>
        <div>
          <button className="btn-primary disabled:opacity-50" onClick={handleCreate} disabled={!name || !file || creating}>
            {creating ? 'Processing…' : 'Create & Parse'}
          </button>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Datasets</h2>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {items.map((d) => (
            <a key={d.id} href={`/datasets/${d.id}`} className="card p-4 hover:shadow">
              <div className="flex items-center justify-between">
                <div className="font-medium">{d.name}</div>
                <div className="text-xs text-slate-500">{new Date(d.createdAt).toLocaleDateString()}</div>
              </div>
              <div className="mt-1 text-sm text-slate-600 line-clamp-2">{d.description}</div>
              <div className="mt-2 text-sm">Docs: {d._count.documents} • Samples: {d._count.samples}</div>
            </a>
          ))}
          {items.length === 0 && <div className="text-sm text-slate-500">No datasets yet.</div>}
        </div>
      </section>
    </div>
  )
}





