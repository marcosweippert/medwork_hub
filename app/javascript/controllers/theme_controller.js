import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.apply(this.stored())
  }

  toggle() {
    const next = this.current() === "dark" ? "light" : "dark"
    this.apply(next)
  }

  current() {
    return document.documentElement.getAttribute("data-theme") || "light"
  }

  stored() {
    try {
      return localStorage.getItem("dash26-theme") || "light"
    } catch {
      return "light"
    }
  }

  apply(theme) {
    document.documentElement.setAttribute("data-theme", theme)
    localStorage.setItem("dash26-theme", theme)
  }
}
