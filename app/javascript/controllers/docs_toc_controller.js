import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]

  connect() {
    this.observer = new IntersectionObserver((entries) => this.highlight(entries), {
      rootMargin: "-15% 0px -70% 0px",
      threshold: 0
    })
    this.headings().forEach((heading) => this.observer.observe(heading))
  }

  disconnect() {
    this.observer?.disconnect()
  }

  headings() {
    return this.linkTargets
      .map((link) => document.getElementById(link.hash.replace("#", "")))
      .filter(Boolean)
  }

  highlight(entries) {
    const visible = entries.find((entry) => entry.isIntersecting)
    if (!visible) return

    this.linkTargets.forEach((link) => {
      link.classList.toggle("is-active", link.hash === `#${visible.target.id}`)
    })
  }
}
