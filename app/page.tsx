import Image from "next/image";

export default function Home() {
  return (
    <div className="p-8 space-y-4">
      <h1 className="text-2xl font-semibold">VLM Evaluation Dashboard</h1>
      <a className="text-blue-600 underline" href="/datasets">
        Go to Datasets
      </a>
    </div>
  )
}
