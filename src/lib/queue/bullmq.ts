// Simple in-process task runner for local/internal tooling.
// Provides enqueue + drain with concurrency=1 semantics.

export type Task<T> = () => Promise<T> | T

export class TaskQueue {
  private queue: Array<{ name: string; fn: Task<unknown> }>
  private running: boolean

  constructor() {
    this.queue = []
    this.running = false
  }

  enqueue<T>(name: string, fn: Task<T>) {
    this.queue.push({ name, fn })
    if (!this.running) {
      void this.drain()
    }
  }

  private async drain() {
    this.running = true
    try {
      while (this.queue.length > 0) {
        const item = this.queue.shift()!
        await item.fn()
      }
    } finally {
      this.running = false
    }
  }
}

export const defaultTaskQueue = new TaskQueue()


