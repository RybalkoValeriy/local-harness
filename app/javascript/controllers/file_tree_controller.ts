import { Controller } from "@hotwired/stimulus"
import { highlightFile } from "../highlight"

type Entry = { name: string; path: string; directory: boolean }
type Listing = { entries: Entry[]; truncated: boolean; error?: string }

export default class extends Controller {
  static targets = ["tree", "status", "viewer", "filename", "fileStatus", "code", "tabs", "empty", "lineNumbers"]
  static values = { url: String, fileUrl: String }
  declare treeTarget: HTMLElement
  declare statusTarget: HTMLElement
  declare urlValue: string
  declare fileUrlValue: string
  declare viewerTarget: HTMLElement
  declare tabsTarget: HTMLElement
  declare emptyTarget: HTMLElement
  declare lineNumbersTarget: HTMLElement
  declare filenameTarget: HTMLElement
  declare fileStatusTarget: HTMLElement
  declare codeTarget: HTMLElement
  private expanded = new Set<string>()
  private abort?: AbortController
  private fileAbort?: AbortController
  private interval?: number
  private selected?: string
  private openPaths: string[] = []
  private scrollPositions = new Map<string, number>()
  private displayed?: string
  private refreshing = false
  private onChange = () => { void this.refresh(); void this.refreshFile() }

  connect() {
    window.addEventListener("project:files-changed", this.onChange)
    void this.refresh()
    this.interval = window.setInterval(() => {
      if (document.visibilityState === "visible") this.onChange()
    }, 3000)
  }

  disconnect() {
    window.removeEventListener("project:files-changed", this.onChange)
    this.abort?.abort()
    this.fileAbort?.abort()
    window.clearInterval(this.interval)
  }

  async refresh() {
    if (this.refreshing) return
    this.refreshing = true
    this.abort?.abort()
    const abort = new AbortController()
    this.abort = abort
    if (!this.treeTarget.childElementCount) this.statusTarget.textContent = "Loading files…"
    try {
      await this.load("", this.treeTarget, abort.signal)
      this.statusTarget.textContent = "Click a file to view · syncs every 3 seconds"
    } catch (error) {
      if (!abort.signal.aborted) this.statusTarget.textContent = error instanceof Error ? error.message : "Could not load files."
    } finally { this.refreshing = false }
  }

  private async openFile(path: string) {
    if (this.selected && this.codeTarget.parentElement) this.scrollPositions.set(this.selected, this.codeTarget.parentElement.scrollTop)
    this.fileAbort?.abort()
    this.fileAbort = undefined
    this.selected = path
    if (!this.openPaths.includes(path)) this.openPaths.push(path)
    this.renderTabs()
    this.displayed = undefined
    this.filenameTarget.textContent = path
    this.codeTarget.textContent = ""
    this.lineNumbersTarget.textContent = ""
    this.fileStatusTarget.textContent = "Loading file…"
    this.viewerTarget.hidden = false
    this.emptyTarget.hidden = true
    await this.refreshFile()
  }

  private closeFile(path: string) {
    const index = this.openPaths.indexOf(path)
    this.openPaths = this.openPaths.filter(open => open !== path)
    this.scrollPositions.delete(path)
    if (this.selected === path) {
      this.fileAbort?.abort()
      this.fileAbort = undefined
      this.selected = undefined
      const next = this.openPaths[Math.min(index, this.openPaths.length - 1)]
      if (next) { void this.openFile(next); return }
      this.viewerTarget.hidden = true
      this.emptyTarget.hidden = false
      this.codeTarget.textContent = ""
    }
    this.renderTabs()
  }

  private renderTabs() {
    this.treeTarget.querySelectorAll<HTMLButtonElement>("button[data-path]").forEach(button => {
      button.setAttribute("aria-pressed", String(button.dataset.path === this.selected))
    })
    this.tabsTarget.replaceChildren()
    this.openPaths.forEach((path, index) => {
      const item = document.createElement("div")
      item.className = "editor-tab" + (path === this.selected ? " active" : "")
      item.setAttribute("role", "presentation")
      const tab = document.createElement("button")
      tab.type = "button"
      tab.id = `file-tab-${index}`
      tab.setAttribute("role", "tab")
      tab.setAttribute("aria-selected", String(path === this.selected))
      tab.setAttribute("aria-controls", "editor-document")
      tab.tabIndex = path === this.selected ? 0 : -1
      tab.textContent = path.split("/").pop() || path
      tab.title = path
      tab.addEventListener("click", () => { void this.openFile(path) })
      tab.addEventListener("keydown", event => {
        let next: number | undefined
        if (event.key === "ArrowRight") next = (index + 1) % this.openPaths.length
        if (event.key === "ArrowLeft") next = (index + this.openPaths.length - 1) % this.openPaths.length
        if (event.key === "Home") next = 0
        if (event.key === "End") next = this.openPaths.length - 1
        if (next !== undefined) {
          event.preventDefault()
          void this.openFile(this.openPaths[next]!)
          this.tabsTarget.querySelector<HTMLButtonElement>('[aria-selected="true"]')?.focus()
        }
      })
      const close = document.createElement("button")
      close.type = "button"
      close.className = "close-tab"
      close.textContent = "×"
      close.setAttribute("aria-label", `Close ${path}`)
      close.addEventListener("click", () => { this.closeFile(path) })
      item.append(tab, close)
      this.tabsTarget.append(item)
      if (path === this.selected) this.viewerTarget.setAttribute("aria-labelledby", tab.id)
    })
  }

  private async refreshFile() {
    if (!this.selected || this.viewerTarget.hidden || this.fileAbort) return
    const abort = new AbortController()
    this.fileAbort = abort
    const path = this.selected
    try {
      const url = new URL(this.fileUrlValue, window.location.origin)
      url.searchParams.set("path", path)
      const response = await fetch(url, { signal: abort.signal, cache: "no-store", headers: { Accept: "application/json" } })
      const data: { content?: string; truncated?: boolean; error?: string } = await response.json()
      if (!response.ok || typeof data.content !== "string") throw new Error(data.error || "Could not read this file.")
      if (this.displayed !== data.content) {
        const scroll = this.displayed === undefined ? this.scrollPositions.get(path) || 0 : this.codeTarget.parentElement?.scrollTop || 0
        highlightFile(this.codeTarget, path, data.content)
        this.displayed = data.content
        this.lineNumbersTarget.textContent = Array.from({ length: data.content.split("\n").length }, (_, index) => String(index + 1)).join("\n")
        if (this.codeTarget.parentElement) this.codeTarget.parentElement.scrollTop = scroll
      }
      this.fileStatusTarget.textContent = data.truncated ? "Preview: first 16,000 bytes · file is larger" : "Current contents from disk · read only"
    } catch (error) {
      if (!abort.signal.aborted) {
        this.codeTarget.textContent = ""
        this.lineNumbersTarget.textContent = ""
        this.displayed = undefined
        this.fileStatusTarget.textContent = error instanceof Error ? error.message : "Could not read file."
      }
    } finally {
      if (this.fileAbort === abort) this.fileAbort = undefined
    }
  }

  private async load(path: string, container: HTMLElement, signal: AbortSignal) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("path", path)
    const response = await fetch(url, { signal, headers: { Accept: "application/json" } })
    const data: Listing = await response.json()
    if (!response.ok) throw new Error(data.error || "Could not load project files.")
    if (!Array.isArray(data.entries)) throw new Error("Invalid file list.")
    const listing = JSON.stringify(data)
    if (container.dataset.listing === listing) {
      for (const child of Array.from(container.children)) {
        if (child instanceof HTMLDetailsElement && child.open && child.dataset.path) {
          const children = child.querySelector<HTMLElement>(".file-tree-children")
          if (children) await this.load(child.dataset.path, children, signal)
        }
      }
      return
    }
    container.dataset.listing = listing
    container.replaceChildren()
    if (data.entries.length === 0) {
      const empty = document.createElement("p")
      empty.className = "file-tree-empty"
      empty.textContent = "Empty folder"
      container.append(empty)
    }
    for (const entry of data.entries) {
      if (entry.directory) {
        const details = document.createElement("details")
        details.dataset.path = entry.path
        const summary = document.createElement("summary")
        summary.textContent = entry.name
        summary.title = entry.path
        const children = document.createElement("div")
        children.className = "file-tree-children"
        details.append(summary, children)
        container.append(details)
        let loaded = false
        details.addEventListener("toggle", async () => {
          if (!details.open) { this.expanded.delete(entry.path); return }
          this.expanded.add(entry.path)
          if (loaded || signal.aborted) return
          loaded = true
          try { await this.load(entry.path, children, signal) }
          catch (error) {
            loaded = false
            if (!signal.aborted) children.textContent = error instanceof Error ? error.message : "Could not load folder."
          }
        })
        details.open = this.expanded.has(entry.path)
      } else {
        const file = document.createElement("button")
        file.type = "button"
        file.dataset.path = entry.path
        file.setAttribute("aria-pressed", String(entry.path === this.selected))
        file.className = "file-tree-file"
        file.textContent = entry.name
        file.title = entry.path
        file.addEventListener("click", () => { void this.openFile(entry.path) })
        container.append(file)
      }
    }
    if (data.truncated) {
      const note = document.createElement("p")
      note.textContent = "Showing the first 500 entries."
      container.append(note)
    }
  }
}
