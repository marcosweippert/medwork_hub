import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["aside"]

  toggle() {
    document.body.classList.toggle("has-drawer-open")
    this.asideTarget?.classList.toggle("is-open")
  }

  close() {
    document.body.classList.remove("has-drawer-open")
    this.asideTarget?.classList.remove("is-open")
  }
}
