import { NextResponse } from 'next/server'
import { ZodSchema } from 'zod'

export const badRequest = (message: string, details?: unknown) =>
  NextResponse.json({ error: message, details }, { status: 400 })

export const notFound = (message = 'Not found') =>
  NextResponse.json({ error: message }, { status: 404 })

export const serverError = (message = 'Internal server error') =>
  NextResponse.json({ error: message }, { status: 500 })

export const parseJson = async <T>(req: Request, schema: ZodSchema<T>) => {
  try {
    const json = await req.json()
    const result = schema.safeParse(json)
    if (!result.success) {
      return { ok: false as const, res: badRequest('Invalid request body', result.error.issues) }
    }
    return { ok: true as const, data: result.data }
  } catch (e) {
    return { ok: false as const, res: badRequest('Malformed JSON') }
  }
}






