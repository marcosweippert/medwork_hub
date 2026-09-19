import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "all", "bar", "count", "matching"]
  static values = { matching: Number }

  connect() {
    this.refresh()
  }

  toggleAll(event) {
    this.rowTargets.forEach((input) => { input.checked = event.target.checked })
    this.setMatching(event.target.checked && this.usesMatchingScope)
    this.refresh()
  }

  refresh() {
    const selected = this.rowTargets.filter((input) => input.checked)
    if (this.matchingActive && selected.length < this.rowTargets.length) {
      this.setMatching(false)
    }

    const count = this.displayCount(selected.length)
    if (this.hasBarTarget) this.barTarget.hidden = selected.length === 0
    if (this.hasCountTarget) this.countTarget.textContent = this.countLabel(count)
    this.updateConfirms(count)

    if (this.hasAllTarget) {
      this.allTarget.checked = selected.length > 0 && selected.length === this.rowTargets.length
      this.allTarget.indeterminate = selected.length > 0 && selected.length < this.rowTargets.length
    }
    this.rowTargets.forEach((input) => {
      input.closest("tr, [data-email-item]")?.classList.toggle("is-selected", input.checked)
    })
  }

  get usesMatchingScope() {
    return this.hasMatchingValue && this.matchingValue > this.rowTargets.length
  }

  get matchingActive() {
    return this.hasMatchingTarget && this.matchingTarget.value === "1"
  }

  setMatching(enabled) {
    if (this.hasMatchingTarget) this.matchingTarget.value = enabled ? "1" : "0"
  }

  displayCount(pageSelected) {
    if (this.matchingActive) return this.matchingValue
    return pageSelected
  }

  countLabel(count) {
    if (this.matchingActive) {
      return count === 1 ? "1 matching this filter" : `${count} matching this filter`
    }
    return count === 1 ? "1 selected" : `${count} selected`
  }

  updateConfirms(count) {
    const noun = this.matchingActive
      ? `${count} invoices matching this filter`
      : (count === 1 ? "1 selected invoice" : `${count} selected invoices`)

    this.element.querySelectorAll("button[name='bulk_action']").forEach((button) => {
      switch (button.value) {
        case "pay":
          button.dataset.turboConfirm = `Mark ${noun} as paid?`
          break
        case "cancel":
          button.dataset.turboConfirm = `Cancel ${noun}? Paid invoices are refunded according to the cancellation policy.`
          break
        case "refund":
          button.dataset.turboConfirm = `Refund ${noun} and release remaining slots?`
          break
      }
    })
  }
}
