import { S3Client, CreateBucketCommand, HeadBucketCommand, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3'
import { getSignedUrl } from '@aws-sdk/s3-request-presigner'
import { config } from '@/app/lib/config'

let cachedClient: S3Client | null = null

export const getS3Client = (): S3Client => {
  if (cachedClient) return cachedClient
  const endpoint = new URL(config.S3_ENDPOINT)
  cachedClient = new S3Client({
    region: 'us-east-1',
    endpoint: `${endpoint.protocol}//${endpoint.host}`,
    forcePathStyle: true,
    credentials: {
      accessKeyId: config.S3_ACCESS_KEY_ID,
      secretAccessKey: config.S3_SECRET_ACCESS_KEY,
    },
  })
  return cachedClient
}

export const ensureBucketExists = async (): Promise<void> => {
  const s3 = getS3Client()
  try {
    await s3.send(new HeadBucketCommand({ Bucket: config.S3_BUCKET }))
    return
  } catch (_) {
    await s3.send(new CreateBucketCommand({ Bucket: config.S3_BUCKET }))
  }
}

export const uploadObject = async (key: string, body: Buffer | Uint8Array | string, contentType?: string): Promise<void> => {
  const s3 = getS3Client()
  await s3.send(
    new PutObjectCommand({
      Bucket: config.S3_BUCKET,
      Key: key,
      Body: body,
      ContentType: contentType,
    }),
  )
}

export const getObjectStream = async (key: string) => {
  const s3 = getS3Client()
  const res = await s3.send(
    new GetObjectCommand({
      Bucket: config.S3_BUCKET,
      Key: key,
    }),
  )
  return res.Body
}

export const getPresignedUrl = async (key: string, method: 'get' | 'put', contentType?: string, expiresInSeconds = 900): Promise<string> => {
  const s3 = getS3Client()
  if (method === 'get') {
    const cmd = new GetObjectCommand({ Bucket: config.S3_BUCKET, Key: key })
    return getSignedUrl(s3, cmd, { expiresIn: expiresInSeconds })
  }
  const cmd = new PutObjectCommand({ Bucket: config.S3_BUCKET, Key: key, ContentType: contentType })
  return getSignedUrl(s3, cmd, { expiresIn: expiresInSeconds })
}





