import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.boundClose = this.closeOnOutside.bind(this)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    const open = this.panelTarget.hasAttribute("hidden")
    this.panelTarget.toggleAttribute("hidden", !open)
    if (open) {
      document.addEventListener("click", this.boundClose)
    } else {
      document.removeEventListener("click", this.boundClose)
    }
  }

  closeOnOutside(event) {
    if (this.element.contains(event.target)) return
    this.panelTarget.hidden = true
    document.removeEventListener("click", this.boundClose)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }
}
