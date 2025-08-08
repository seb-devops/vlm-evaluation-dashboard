import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
  // Seed minimal records helpful for development
  await prisma.appMeta.upsert({
    where: { key: 'seed_version' },
    update: { value: '1' },
    create: { key: 'seed_version', value: '1' },
  })
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })


