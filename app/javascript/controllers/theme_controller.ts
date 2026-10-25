import { Controller } from "@hotwired/stimulus"
import { saveTheme, themeMode } from "../theme"

export default class extends Controller<HTMLSelectElement> {
  connect() { this.element.value = themeMode() }
  change() {
    const mode = this.element.value
    if (mode === "light" || mode === "dark" || mode === "system") saveTheme(mode)
  }
}
