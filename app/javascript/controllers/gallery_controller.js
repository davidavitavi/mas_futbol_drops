import { Controller } from "@hotwired/stimulus"

// Product page gallery.
// - Thumbnails switch the main (cropped) photo.
// - Clicking the main photo opens a fullscreen viewer with the full, uncropped photo.
// - In the viewer, click/tap zooms in where you pointed; moving around pans.
export default class extends Controller {
  static targets = ["slide", "thumb", "lightbox", "zoomImage", "counter"]
  static values = { zoomUrls: Array, index: Number }

  static ZOOM = 2.5

  disconnect() {
    this.unlockScroll()
  }

  show(event) {
    this.indexValue = event.params.index
  }

  indexValueChanged() {
    this.slideTargets.forEach((slide, i) => slide.classList.toggle("hidden", i !== this.indexValue))

    this.thumbTargets.forEach((thumb, i) => {
      const active = i === this.indexValue
      thumb.classList.toggle("ring-emerald-500", active)
      thumb.classList.toggle("ring-transparent", !active)
      thumb.classList.toggle("hover:ring-zinc-300", !active)
    })

    if (this.isOpen) this.loadZoomImage()
  }

  // --- fullscreen viewer ---------------------------------------------------

  open() {
    if (!this.hasLightboxTarget) return
    this.lightboxTarget.classList.remove("hidden")
    this.lightboxTarget.classList.add("flex")
    this.lockScroll()
    this.loadZoomImage()
  }

  close() {
    this.lightboxTarget.classList.add("hidden")
    this.lightboxTarget.classList.remove("flex")
    this.unlockScroll()
  }

  next() {
    this.indexValue = (this.indexValue + 1) % this.zoomUrlsValue.length
  }

  previous() {
    this.indexValue = (this.indexValue - 1 + this.zoomUrlsValue.length) % this.zoomUrlsValue.length
  }

  key(event) {
    if (!this.isOpen) return
    if (event.key === "Escape") this.close()
    if (event.key === "ArrowRight") this.next()
    if (event.key === "ArrowLeft") this.previous()
  }

  toggleZoom(event) {
    this.zoomed = !this.zoomed
    const img = this.zoomImageTarget

    if (this.zoomed) {
      this.setOrigin(event)
      img.style.transform = `scale(${this.constructor.ZOOM})`
      img.style.touchAction = "none" // let a finger drag pan instead of scrolling
      img.classList.replace("cursor-zoom-in", "cursor-zoom-out")
    } else {
      this.resetZoom()
    }
  }

  pan(event) {
    if (!this.zoomed) return
    // Mouse: just moving pans. Touch/pen: only while pressing.
    if (event.pointerType !== "mouse" && event.buttons === 0) return
    this.setOrigin(event)
  }

  // --- internals -----------------------------------------------------------

  get isOpen() {
    return this.hasLightboxTarget && !this.lightboxTarget.classList.contains("hidden")
  }

  loadZoomImage() {
    this.resetZoom()
    this.zoomImageTarget.src = this.zoomUrlsValue[this.indexValue]
    this.counterTarget.textContent = this.indexValue + 1
  }

  resetZoom() {
    this.zoomed = false
    const img = this.zoomImageTarget
    img.style.transform = ""
    img.style.touchAction = ""
    img.classList.replace("cursor-zoom-out", "cursor-zoom-in")
  }

  setOrigin(event) {
    // Measure the unscaled frame, not the (already scaled) image.
    const rect = this.zoomImageTarget.parentElement.getBoundingClientRect()
    const x = ((event.clientX - rect.left) / rect.width) * 100
    const y = ((event.clientY - rect.top) / rect.height) * 100
    this.zoomImageTarget.style.transformOrigin = `${clamp(x)}% ${clamp(y)}%`
  }

  lockScroll() {
    document.body.style.overflow = "hidden"
  }

  unlockScroll() {
    document.body.style.overflow = ""
  }
}

const clamp = (n) => Math.min(100, Math.max(0, n))
