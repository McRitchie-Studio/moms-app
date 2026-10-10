import { Controller } from "@hotwired/stimulus"
import { nextScroll, prevScroll, stepWidth } from "slideshow/carousel"

const INTERVAL_MS = 3000

// The photo carousel: autoplays, pauses under the pointer, steps by button.
export default class extends Controller {
  static targets = [ "track", "toggle" ]

  connect() {
    this.start()
  }

  disconnect() {
    this.stop()
  }

  start() {
    this.stop()
    this.timer = setInterval(() => this.next(), INTERVAL_MS)
    this.label(true)
  }

  stop() {
    if (this.timer) clearInterval(this.timer)
    this.timer = null
    this.label(false)
  }

  toggle() {
    this.timer ? this.stop() : this.start()
  }

  next() {
    this.scroll(nextScroll(this.trackTarget, this.step))
  }

  prev() {
    this.scroll(prevScroll(this.trackTarget, this.step))
  }

  get step() {
    const card = this.trackTarget.querySelector(".snap-start")
    return stepWidth(card ? card.offsetWidth : null, this.trackTarget.clientWidth)
  }

  scroll(move) {
    if ("to" in move) {
      this.trackTarget.scrollTo({ left: move.to, behavior: "smooth" })
    } else {
      this.trackTarget.scrollBy({ left: move.by, behavior: "smooth" })
    }
  }

  label(playing) {
    if (this.hasToggleTarget) this.toggleTarget.textContent = playing ? "Pause" : "Play"
  }
}
