import { Controller } from "@hotwired/stimulus"

const THRESHOLD_PX = 20

// Puts the scrolled classes on its element once the page has scrolled.
export default class extends Controller {
  static classes = [ "scrolled" ]

  // A reload or Back lands scrolled with no scroll event to follow.
  connect() {
    this.update()
  }

  update() {
    const scrolled = window.scrollY > THRESHOLD_PX
    this.scrolledClasses.forEach((name) => this.element.classList.toggle(name, scrolled))
  }
}
