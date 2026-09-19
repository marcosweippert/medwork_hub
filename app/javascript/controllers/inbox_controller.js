import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  select(event) {
    this.itemTargets.forEach((el) => el.classList.remove("is-active"))
    event.currentTarget.classList.add("is-active")
  }
}
