declare module 'pdf-parse' {
  export interface PDFParseResult {
    numpages: number
    numrender: number
    info?: unknown
    metadata?: unknown
    version?: string
    text: string
  }

  export interface PDFParseOptions {
    pagerender?: (pageData: unknown) => Promise<string> | string
    max?: number
    version?: string
  }

  function pdfParse(
    data: Buffer | Uint8Array | ArrayBuffer | NodeJS.ReadableStream,
    options?: PDFParseOptions,
  ): Promise<PDFParseResult>

  export default pdfParse
}


