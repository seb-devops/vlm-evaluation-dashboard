#!/usr/bin/env -S node --loader ts-node/esm
import { PrismaClient } from '@prisma/client'

const main = async () => {
  const prisma = new PrismaClient()
  try {
    const stamp = new Date().toISOString()
    await prisma.appMeta.upsert({
      where: { key: 'smoke' },
      update: { value: stamp },
      create: { key: 'smoke', value: stamp },
    })
    const row = await prisma.appMeta.findUnique({ where: { key: 'smoke' } })
    if (!row) {
      throw new Error('Smoke key not found')
    }
    console.log('DB smoke OK', row)
  } finally {
    await prisma.$disconnect()
  }
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})


