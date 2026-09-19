import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "button", "frame", "htmlPane", "textPane", "htmlTab", "textTab"]
  static values = { src: String }

  connect() {
    this.closedText = this.hasButtonTarget ? this.buttonTarget.textContent.trim() : "Open"
  }

  toggle(event) {
    event.preventDefault()
    const opening = !this.panelTarget.classList.contains("is-open")
    this.panelTarget.classList.toggle("is-open", opening)
    this.panelTarget.hidden = !opening
    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = opening ? "Hide" : this.closedText
      this.buttonTarget.classList.toggle("is-open", opening)
    }
    if (opening) this.#loadFrame()
  }

  showHtml(event) {
    event?.preventDefault()
    this.#activate("html")
  }

  showText(event) {
    event?.preventDefault()
    this.#activate("text")
  }

  #loadFrame() {
    if (!this.hasFrameTarget || !this.srcValue) return
    if (this.frameTarget.hasAttribute("src") && this.frameTarget.getAttribute("src") !== "") return
    this.frameTarget.setAttribute("src", this.srcValue)
  }

  #activate(kind) {
    if (this.hasHtmlPaneTarget) this.htmlPaneTarget.hidden = kind !== "html"
    if (this.hasTextPaneTarget) this.textPaneTarget.hidden = kind !== "text"
    if (this.hasHtmlTabTarget) this.htmlTabTarget.classList.toggle("is-active", kind === "html")
    if (this.hasTextTabTarget) this.textTabTarget.classList.toggle("is-active", kind === "text")
  }
}
