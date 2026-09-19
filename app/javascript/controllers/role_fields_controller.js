import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["professional", "role"]

  connect() {
    this.sync()
  }

  sync() {
    if (!this.hasProfessionalTarget) return

    const professional = this.hasRoleTarget ? this.roleTarget.value === "professional" : true
    this.professionalTarget.hidden = !professional
    this.professionalTarget.querySelectorAll("input, select, textarea").forEach((field) => {
      field.disabled = !professional
    })
  }
}
