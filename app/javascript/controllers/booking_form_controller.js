import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["professional", "room", "hourlyRate"]
  static values = { calendarUrl: String }

  connect() {
    this.filterRooms()
    this.syncRate()
    if (this.hasRoomTarget && this.roomTarget.value) this.loadCalendar()
  }

  professionalChanged() {
    this.filterRooms()
    this.loadCalendar()
  }

  roomChanged() {
    this.syncRate()
    this.loadCalendar()
  }

  filterRooms() {
    if (!this.hasRoomTarget || !this.hasProfessionalTarget) return
    const allowed = this.allowedTypes()
    this.roomTarget.querySelectorAll("option").forEach((option) => {
      if (!option.value) {
        option.hidden = false
        return
      }
      const types = (option.dataset.types || "").split(",").filter(Boolean)
      const ok = allowed.length === 0 || types.some((type) => allowed.includes(type))
      option.hidden = !ok
      option.disabled = !ok
    })
    const selected = this.roomTarget.selectedOptions[0]
    if (selected?.hidden || selected?.disabled) this.roomTarget.value = ""
  }

  allowedTypes() {
    const el = this.professionalTarget
    if (el.tagName === "SELECT") {
      const option = el.selectedOptions[0]
      return (option?.dataset.roomTypes || "").split(",").filter(Boolean)
    }
    return (el.dataset.roomTypes || "").split(",").filter(Boolean)
  }

  syncRate() {
    const option = this.roomTarget.selectedOptions[0]
    const rateInput = this.element.querySelector("[data-slot-picker-target='hourlyRate']")
    if (rateInput) rateInput.value = option?.dataset.hourlyRate || "0"
  }

  loadCalendar() {
    const frame = document.getElementById("booking_calendar")
    if (!frame || !this.calendarUrlValue) return
    const roomId = this.roomTarget.value
    if (!roomId) {
      frame.innerHTML = `<p class="field-help" style="margin:8px 0;">Select a professional and a compatible room to load the weekly calendar.</p>`
      return
    }
    const url = new URL(this.calendarUrlValue, window.location.origin)
    url.searchParams.set("room_id", roomId)
    url.searchParams.set("professional_id", this.professionalTarget.value)
    frame.src = url.toString()
  }
}
