import { Controller } from "@hotwired/stimulus"

type Folder = { name: string; path: string }
type Listing = { path: string; parent: string; directories: Folder[]; shortcuts: Folder[]; truncated: boolean }

export default class extends Controller<HTMLFormElement> {
  static targets = ["path", "name", "dialog", "location", "entries", "shortcuts", "error", "current", "choose"]
  declare pathTarget: HTMLInputElement
  declare nameTarget: HTMLInputElement
  declare dialogTarget: HTMLDialogElement
  declare locationTarget: HTMLInputElement
  declare entriesTarget: HTMLElement
  declare shortcutsTarget: HTMLElement
  declare errorTarget: HTMLElement
  declare currentTarget: HTMLElement
  declare chooseTarget: HTMLButtonElement
  private currentPath = ""
  private parentPath = ""
  private request?: AbortController

  disconnect() { this.request?.abort(); this.dialogTarget.close() }
  open() {
    this.dialogTarget.showModal()
    void this.load(this.pathTarget.value.trim())
  }
  close() { this.request?.abort(); this.dialogTarget.close() }
  go(event: Event) { event.preventDefault(); void this.load(this.locationTarget.value) }
  up() { void this.load(this.parentPath) }
  choose() {
    if (!this.currentPath || this.chooseTarget.disabled) return
    this.pathTarget.value = this.currentPath
    if (!this.nameTarget.value.trim()) this.nameTarget.value = this.currentPath.split("/").filter(Boolean).at(-1) ?? "Project"
    this.pathTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.close()
  }

  private folderButton(folder: Folder): HTMLButtonElement {
    const button = document.createElement("button")
    button.type = "button"
    button.textContent = folder.name
    button.title = folder.path
    button.addEventListener("click", () => { void this.load(folder.path) })
    return button
  }

  private async load(path: string) {
    this.request?.abort()
    const request = new AbortController()
    this.request = request
    this.chooseTarget.disabled = true
    this.errorTarget.textContent = ""
    this.currentTarget.textContent = "Loading folders…"
    try {
      const response = await fetch(`/directories?${new URLSearchParams({ path })}`, { signal: request.signal, headers: { Accept: "application/json" } })
      const result = await response.json()
      if (!response.ok) throw new Error(result.error ?? "Could not list folders")
      const listing = result as Listing
      if (typeof listing.path !== "string" || typeof listing.parent !== "string" || !Array.isArray(listing.directories) || !Array.isArray(listing.shortcuts)) throw new Error("Invalid directory response")
      this.currentPath = listing.path
      this.parentPath = listing.parent
      this.locationTarget.value = listing.path
      this.currentTarget.textContent = listing.path
      this.entriesTarget.replaceChildren(...listing.directories.map(folder => this.folderButton(folder)))
      if (listing.directories.length === 0) this.entriesTarget.textContent = "No visible subfolders. You can select this folder."
      this.shortcutsTarget.replaceChildren(...listing.shortcuts.map(folder => this.folderButton(folder)))
      if (listing.truncated) this.errorTarget.textContent = "Showing the first 200 folders. Enter a more specific path to browse further."
      this.chooseTarget.disabled = false
    } catch (error) {
      if (request.signal.aborted) return
      this.errorTarget.textContent = error instanceof Error ? error.message : "Could not load folders"
      this.currentTarget.textContent = "Enter a folder path or use a shortcut."
      this.entriesTarget.replaceChildren()
    }
  }
}
