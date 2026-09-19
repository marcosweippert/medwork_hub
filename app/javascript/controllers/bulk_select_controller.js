import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "all", "bar", "count"]

  connect() {
    this.refresh()
  }

  toggleAll(event) {
    this.rowTargets.forEach((input) => { input.checked = event.target.checked })
    this.refresh()
  }

  refresh() {
    const selected = this.rowTargets.filter((input) => input.checked)
    if (this.hasBarTarget) this.barTarget.hidden = selected.length === 0
    if (this.hasCountTarget) {
      this.countTarget.textContent = selected.length === 1 ? "1 selected" : `${selected.length} selected`
    }
    if (this.hasAllTarget) {
      this.allTarget.checked = selected.length > 0 && selected.length === this.rowTargets.length
      this.allTarget.indeterminate = selected.length > 0 && selected.length < this.rowTargets.length
    }
    this.rowTargets.forEach((input) => {
      input.closest("tr, [data-email-item]")?.classList.toggle("is-selected", input.checked)
    })
  }
}
