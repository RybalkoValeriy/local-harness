export type ThemeMode = "light" | "dark" | "system"
const storageKey = "local-harness-theme"
const media = window.matchMedia("(prefers-color-scheme: dark)")

export function themeMode(): ThemeMode {
  try {
    const saved = localStorage.getItem(storageKey)
    if (saved === "light" || saved === "dark") return saved
  } catch { /* Browser storage can be unavailable. System mode remains usable. */ }
  return "system"
}

export function applyTheme(mode: ThemeMode = themeMode()) {
  document.documentElement.dataset.theme = mode === "system" ? (media.matches ? "dark" : "light") : mode
}

export function saveTheme(mode: ThemeMode) {
  try { localStorage.setItem(storageKey, mode) } catch { /* Apply for this page even without storage. */ }
  applyTheme(mode)
}

applyTheme()
media.addEventListener("change", () => { if (themeMode() === "system") applyTheme() })
window.addEventListener("storage", event => { if (event.key === storageKey) applyTheme() })
document.addEventListener("turbo:load", () => applyTheme())
