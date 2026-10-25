import { Controller } from "@hotwired/stimulus"

type MessageRole = "user" | "assistant" | "error"
type RunEvent =
  | { type: "step"; number: number }
  | { type: "token" | "reasoning"; text: string }
  | { type: "tool"; name: string; arguments: string; result: string }
  | { type: "done" }
  | { type: "error"; message: string }
type ConnectionStatus = { connected: boolean; error?: string; model: string }

export default class extends Controller {
  static targets = ["input", "messages", "scroll", "submit", "status", "connection", "welcome"]
  static values = { url: String }

  declare inputTarget: HTMLTextAreaElement
  declare messagesTarget: HTMLElement
  declare scrollTarget: HTMLElement
  declare submitTarget: HTMLButtonElement
  declare statusTarget: HTMLElement
  declare connectionTarget: HTMLElement
  declare welcomeTargets: HTMLElement[]
  declare urlValue: string
  private busy = false
  private abort?: AbortController
  private answer: HTMLDivElement | null = null
  private thinking: HTMLPreElement | null = null

  connect() { this.checkConnection(); this.scrollDown() }
  disconnect() { this.abort?.abort() }

  switchProject(event: Event) {
    if (event.currentTarget instanceof HTMLSelectElement) window.location.assign(event.currentTarget.value)
  }

  async checkConnection() {
    try {
      const response = await fetch("/connection", { headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error(`Connection check failed (${response.status})`)
      const result: ConnectionStatus = await response.json()
      this.connectionTarget.textContent = result.connected ? "● LM Studio connected" : "○ Check LM Studio"
      this.connectionTarget.classList.toggle("connected", result.connected)
      this.connectionTarget.title = result.error || (result.connected ? result.model : "Selected model is not available")
    } catch { this.connectionTarget.textContent = "○ Connection unavailable" }
  }

  suggest(event: Event) {
    if (!(event.currentTarget instanceof HTMLElement)) return
    this.inputTarget.value = event.currentTarget.dataset.prompt ?? ""
    this.inputTarget.focus()
  }
  keydown(event: KeyboardEvent) {
    if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
      event.preventDefault()
      this.inputTarget.form?.requestSubmit()
    }
  }

  async send(event: Event) {
    event.preventDefault()
    if (this.busy) return
    const prompt = this.inputTarget.value.trim()
    if (!prompt) return
    this.busy = true
    this.submitTarget.disabled = true
    this.inputTarget.disabled = true
    this.welcomeTargets.forEach(element => element.remove())
    this.addMessage("user", prompt)
    this.inputTarget.value = ""
    this.answer = null
    this.thinking = null
    this.abort = new AbortController()
    this.statusTarget.textContent = "Connecting to your model…"
    let done = false
    try {
      const csrfToken = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content
      if (!csrfToken) throw new Error("Missing session token. Reload and try again.")
      const response = await fetch(this.urlValue, {
        method: "POST", signal: this.abort.signal,
        headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken },
        body: JSON.stringify({ prompt })
      })
      if (!response.ok) throw new Error(`Request failed (${response.status}). Reload and try again.`)
      if (!response.body) throw new Error("The response has no stream.")
      const reader = response.body.getReader()
      const decoder = new TextDecoder()
      let buffer = ""
      while (true) {
        const chunk = await reader.read()
        buffer += decoder.decode(chunk.value || new Uint8Array(), { stream: !chunk.done })
        let newline
        while ((newline = buffer.indexOf("\n")) !== -1) {
          const line = buffer.slice(0, newline)
          buffer = buffer.slice(newline + 1)
          if (!line.trim()) continue
          const payload: RunEvent = JSON.parse(line)
          this.receive(payload)
          if (["done", "error"].includes(payload.type)) done = true
        }
        if (chunk.done) break
      }
      if (!done) throw new Error("The connection ended before the response finished. Please retry.")
    } catch (error) {
      if (!(error instanceof Error && error.name === "AbortError")) {
        this.addMessage("error", error instanceof Error ? error.message : String(error))
        this.statusTarget.textContent = "Run interrupted."
      }
    } finally {
      this.busy = false
      this.submitTarget.disabled = false
      this.inputTarget.disabled = false
      this.inputTarget.focus()
    }
  }

  receive(event: RunEvent) {
    switch (event.type) {
      case "step":
        this.answer = null; this.thinking = null
        this.statusTarget.textContent = `Working · step ${event.number}`
        break
      case "token":
        this.answer ||= this.addMessage("assistant", "")
        this.answer.textContent += event.text
        break
      case "reasoning":
        this.thinking ||= this.addDetail("Thinking", "")
        this.thinking.textContent += event.text
        break
      case "tool":
        this.addDetail(`◇ ${event.name}`, `${event.arguments}\n\n${event.result}`)
        if (["create_file", "edit_file"].includes(event.name)) window.dispatchEvent(new Event("project:files-changed"))
        break
      case "done": this.statusTarget.textContent = "Finished · saved to this conversation."; break
      case "error": this.addMessage("error", event.message); this.statusTarget.textContent = "Run stopped."; break
    }
    this.scrollDown()
  }

  addMessage(role: MessageRole, text: string): HTMLDivElement {
    const article = document.createElement("article")
    article.className = `message ${role}`
    const label = document.createElement("div")
    label.className = "message-label"
    label.textContent = { user: "YOU", assistant: "QWEN", error: "RUN ERROR" }[role]
    const content = document.createElement("div")
    content.className = "message-content"
    content.textContent = text
    article.append(label, content)
    this.messagesTarget.append(article)
    this.scrollDown()
    return content
  }

  addDetail(title: string, text: string): HTMLPreElement {
    const details = document.createElement("details")
    details.className = "tool"
    const summary = document.createElement("summary")
    summary.textContent = title
    const pre = document.createElement("pre")
    pre.textContent = text
    details.append(summary, pre)
    this.messagesTarget.append(details)
    return pre
  }
  scrollDown() { this.scrollTarget.scrollTop = this.scrollTarget.scrollHeight }
}
