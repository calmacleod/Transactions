import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    interval: { type: Number, default: 2000 },
    url: String
  }

  connect() {
    this.timer = setInterval(() => {
      this.element.src = this.urlValue
    }, this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }
}
