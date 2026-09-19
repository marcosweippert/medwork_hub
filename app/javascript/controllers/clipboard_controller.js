import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  async copy(event) {
    event.preventDefault()
    const original = this.element.textContent
    try {
      await navigator.clipboard.writeText(this.textValue)
      this.element.textContent = "Copied"
      setTimeout(() => { this.element.textContent = original }, 1600)
    } catch (_error) {
      this.element.textContent = "Copy failed"
    }
  }
}
