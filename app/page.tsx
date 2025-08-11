import Link from "next/link";

export default function Home() {
  return (
    <div className="p-8 space-y-4">
      <h1 className="text-2xl font-semibold">VLM Evaluation Dashboard</h1>
      <Link className="text-blue-600 underline" href="/datasets/">
        Go to Datasets
      </Link>
    </div>
  )
}
