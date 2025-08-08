-- CreateEnum
CREATE TYPE "EvaluatorType" AS ENUM ('LLM_JUDGE', 'HEURISTIC', 'SCHEMA', 'PAIRWISE');

-- CreateEnum
CREATE TYPE "RunStatus" AS ENUM ('PENDING', 'RUNNING', 'PAUSED', 'COMPLETED', 'FAILED', 'CANCELED', 'BUDGET_EXCEEDED');

-- CreateEnum
CREATE TYPE "RunItemStatus" AS ENUM ('PENDING', 'SUCCESS', 'ERROR', 'SKIPPED');

-- AppMeta already created in initial migration; skip duplicate

-- CreateTable
CREATE TABLE "Dataset" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "tags" TEXT[],
    "storageLocation" TEXT NOT NULL,
    "parseConfig" JSONB,
    "versionHash" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Dataset_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Document" (
    "id" TEXT NOT NULL,
    "datasetId" TEXT NOT NULL,
    "filename" TEXT NOT NULL,
    "fileHash" TEXT NOT NULL,
    "pageCount" INTEGER NOT NULL,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Document_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Sample" (
    "id" TEXT NOT NULL,
    "datasetId" TEXT NOT NULL,
    "documentId" TEXT,
    "pageIndices" INTEGER[],
    "inputText" TEXT,
    "expectedAnswer" TEXT,
    "metadata" JSONB,
    "tags" TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Sample_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PromptBinding" (
    "id" TEXT NOT NULL,
    "promptSlug" TEXT NOT NULL,
    "promptVersion" TEXT,
    "variablesSchema" JSONB,
    "defaultVariables" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PromptBinding_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ModelConfig" (
    "id" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "modelId" TEXT NOT NULL,
    "temperature" DOUBLE PRECISION,
    "maxOutputTokens" INTEGER,
    "visionInputMode" TEXT,
    "systemPrompt" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ModelConfig_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Evaluator" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" "EvaluatorType" NOT NULL,
    "config" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Evaluator_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Run" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "datasetId" TEXT NOT NULL,
    "datasetVersionHash" TEXT NOT NULL,
    "promptBindingId" TEXT,
    "modelConfigId" TEXT NOT NULL,
    "status" "RunStatus" NOT NULL DEFAULT 'PENDING',
    "runParams" JSONB,
    "baselineRunId" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Run_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RunEvaluator" (
    "id" TEXT NOT NULL,
    "runId" TEXT NOT NULL,
    "evaluatorId" TEXT NOT NULL,

    CONSTRAINT "RunEvaluator_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RunItem" (
    "id" TEXT NOT NULL,
    "runId" TEXT NOT NULL,
    "sampleId" TEXT NOT NULL,
    "inputPayload" JSONB,
    "promptVariables" JSONB,
    "modelOutput" JSONB,
    "error" TEXT,
    "status" "RunItemStatus" NOT NULL DEFAULT 'PENDING',
    "timings" JSONB,
    "tokenUsage" JSONB,
    "providerCostEstimate" DOUBLE PRECISION,
    "langfuseTraceIds" TEXT[],
    "evalResults" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RunItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AggregateMetrics" (
    "id" TEXT NOT NULL,
    "runId" TEXT NOT NULL,
    "metrics" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AggregateMetrics_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProviderCredential" (
    "id" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "alias" TEXT,
    "encryptedKey" TEXT NOT NULL,
    "rpm" INTEGER,
    "tpm" INTEGER,
    "budget" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ProviderCredential_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PriceBook" (
    "id" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "modelId" TEXT NOT NULL,
    "inputPer1kTokens" DOUBLE PRECISION,
    "outputPer1kTokens" DOUBLE PRECISION,
    "imagePricing" JSONB,
    "effectiveDate" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PriceBook_pkey" PRIMARY KEY ("id")
);

-- AppMeta unique index already created; skip duplicate

-- CreateIndex
CREATE UNIQUE INDEX "RunEvaluator_runId_evaluatorId_key" ON "RunEvaluator"("runId", "evaluatorId");

-- CreateIndex
CREATE UNIQUE INDEX "AggregateMetrics_runId_key" ON "AggregateMetrics"("runId");

-- AddForeignKey
ALTER TABLE "Document" ADD CONSTRAINT "Document_datasetId_fkey" FOREIGN KEY ("datasetId") REFERENCES "Dataset"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Sample" ADD CONSTRAINT "Sample_datasetId_fkey" FOREIGN KEY ("datasetId") REFERENCES "Dataset"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Sample" ADD CONSTRAINT "Sample_documentId_fkey" FOREIGN KEY ("documentId") REFERENCES "Document"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Run" ADD CONSTRAINT "Run_datasetId_fkey" FOREIGN KEY ("datasetId") REFERENCES "Dataset"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Run" ADD CONSTRAINT "Run_promptBindingId_fkey" FOREIGN KEY ("promptBindingId") REFERENCES "PromptBinding"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Run" ADD CONSTRAINT "Run_modelConfigId_fkey" FOREIGN KEY ("modelConfigId") REFERENCES "ModelConfig"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RunEvaluator" ADD CONSTRAINT "RunEvaluator_runId_fkey" FOREIGN KEY ("runId") REFERENCES "Run"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RunEvaluator" ADD CONSTRAINT "RunEvaluator_evaluatorId_fkey" FOREIGN KEY ("evaluatorId") REFERENCES "Evaluator"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RunItem" ADD CONSTRAINT "RunItem_runId_fkey" FOREIGN KEY ("runId") REFERENCES "Run"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RunItem" ADD CONSTRAINT "RunItem_sampleId_fkey" FOREIGN KEY ("sampleId") REFERENCES "Sample"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AggregateMetrics" ADD CONSTRAINT "AggregateMetrics_runId_fkey" FOREIGN KEY ("runId") REFERENCES "Run"("id") ON DELETE CASCADE ON UPDATE CASCADE;

