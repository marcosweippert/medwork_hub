import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slot", "count", "total", "hourlyRate"]
  static values = { minutes: { type: Number, default: 30 } }

  connect() {
    this.refresh()
  }

  refresh() {
    const selected = this.slotTargets.filter((el) => el.checked)
    if (this.hasCountTarget) this.countTarget.textContent = selected.length
    if (this.hasTotalTarget && this.hasHourlyRateTarget) {
      const rate = parseFloat(this.hourlyRateTarget.value || "0")
      const hours = selected.length * (this.minutesValue / 60)
      this.totalTarget.textContent = (hours * rate).toFixed(2).replace(".", ",")
    }
  }

  pick(event) {
    event.preventDefault()
    const input = event.currentTarget.querySelector(".slot-check")
    if (!input) return

    input.checked = !input.checked
    this.refresh()
  }

  selectDay(event) {
    event.preventDefault()
    const date = event.params.date
    this.slotTargets.forEach((el) => {
      if (el.dataset.date === date) el.checked = true
    })
    this.refresh()
  }
}
