import { Controller } from "@hotwired/stimulus"

// Product page gallery: clicking a thumbnail swaps the main photo.
export default class extends Controller {
  static targets = ["main", "thumb"]

  show(event) {
    this.mainTarget.src = event.params.url

    this.thumbTargets.forEach((thumb) => {
      const active = thumb === event.currentTarget
      thumb.classList.toggle("ring-emerald-500", active)
      thumb.classList.toggle("ring-transparent", !active)
      thumb.classList.toggle("hover:ring-zinc-300", !active)
    })
  }
}
