import { describe, it, expect } from 'vitest'
import { parseJson } from '@/src/lib/http'
import { z } from 'zod'

const makeRequest = (body: unknown) =>
  new Request('http://localhost/test', {
    method: 'POST',
    body: typeof body === 'string' ? body : JSON.stringify(body),
    headers: { 'content-type': 'application/json' },
  })

describe('parseJson helper', () => {
  it('accepts valid body', async () => {
    const schema = z.object({ name: z.string() })
    const req = makeRequest({ name: 'dataset' })
    const res = await parseJson(req, schema)
    expect(res.ok).toBe(true)
    if (res.ok) expect(res.data.name).toBe('dataset')
  })

  it('rejects invalid body', async () => {
    const schema = z.object({ name: z.string() })
    const req = makeRequest({})
    const res = await parseJson(req, schema)
    // when invalid, returns { ok: false, res: NextResponse }
    expect('ok' in res && res.ok).toBe(false)
  })

  it('rejects malformed JSON', async () => {
    const schema = z.object({ name: z.string() })
    const req = makeRequest('{bad-json')
    const res = await parseJson(req, schema)
    expect('ok' in res && res.ok).toBe(false)
  })
})


