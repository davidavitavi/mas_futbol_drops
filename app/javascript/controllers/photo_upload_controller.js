import { Controller } from "@hotwired/stimulus"

// Depop-style photo picker for the admin jersey form.
//
// - Pick several photos at once, or drag a batch in from a folder.
// - Each pick is added to the photos already chosen instead of replacing them.
// - Photos preview instantly and can be removed before saving.
// - The first photo in the grid is the cover.
//
// Already-saved photos are rendered by the server as tiles with a hidden
// signed_id input; removing the tile removes the input, so Rails detaches it.
export default class extends Controller {
  static targets = ["input", "grid", "dropzone", "count", "error"]
  static values = { max: Number, maxBytes: Number, types: String }

  connect() {
    this.files = []
    this.previewUrls = []
    this.refresh()
  }

  disconnect() {
    this.previewUrls.forEach((url) => URL.revokeObjectURL(url))
  }

  // The file dialog replaces input.files with just the new pick, so merge it in.
  pick() {
    this.add(Array.from(this.inputTarget.files))
  }

  dragOver(event) {
    event.preventDefault()
    this.element.classList.add("border-emerald-500", "bg-emerald-50")
  }

  dragLeave(event) {
    if (this.element.contains(event.relatedTarget)) return
    this.element.classList.remove("border-emerald-500", "bg-emerald-50")
  }

  drop(event) {
    event.preventDefault()
    this.element.classList.remove("border-emerald-500", "bg-emerald-50")
    this.add(Array.from(event.dataTransfer.files))
  }

  removeExisting(event) {
    event.currentTarget.closest("[data-photo-tile]").remove()
    this.refresh()
  }

  removeNew(event) {
    const index = Number(event.currentTarget.dataset.index)
    this.files.splice(index, 1)
    this.syncInput()
    this.renderNew()
  }

  // --- internals -----------------------------------------------------------

  add(incoming) {
    const allowed = this.typesValue.split(",")
    const problems = []
    let room = this.maxValue - this.photoCount

    for (const file of incoming) {
      if (!allowed.includes(file.type)) {
        problems.push(`${file.name} isn't a JPG, PNG or WEBP`)
      } else if (file.size > this.maxBytesValue) {
        problems.push(`${file.name} is over 10 MB`)
      } else if (this.isDuplicate(file)) {
        continue
      } else if (room <= 0) {
        problems.push(`Only ${this.maxValue} photos per jersey, so some were skipped`)
        break
      } else {
        this.files.push(file)
        room--
      }
    }

    this.syncInput()
    this.renderNew()
    this.showError(problems)
  }

  isDuplicate(file) {
    return this.files.some((f) =>
      f.name === file.name && f.size === file.size && f.lastModified === file.lastModified
    )
  }

  // Put the merged list back on the real <input> so it's what the form submits.
  syncInput() {
    const transfer = new DataTransfer()
    this.files.forEach((file) => transfer.items.add(file))
    this.inputTarget.files = transfer.files
  }

  renderNew() {
    this.gridTarget.querySelectorAll("[data-new-photo]").forEach((tile) => tile.remove())
    this.previewUrls.forEach((url) => URL.revokeObjectURL(url))
    this.previewUrls = []

    this.files.forEach((file, index) => {
      const url = URL.createObjectURL(file)
      this.previewUrls.push(url)
      this.dropzoneTarget.before(this.buildTile(url, index))
    })

    this.refresh()
  }

  buildTile(url, index) {
    const tile = document.createElement("div")
    tile.dataset.photoTile = ""
    tile.dataset.newPhoto = ""
    tile.className = "group relative aspect-square overflow-hidden rounded-xl bg-zinc-200"

    const img = document.createElement("img")
    img.src = url
    img.alt = ""
    img.className = "h-full w-full object-cover"

    const badge = document.createElement("span")
    badge.dataset.coverBadge = ""
    badge.className = "absolute bottom-2 left-2 hidden rounded-full bg-zinc-950/80 px-2 py-0.5 text-xs font-bold text-white"
    badge.textContent = "Cover"

    const remove = document.createElement("button")
    remove.type = "button"
    remove.dataset.index = index
    remove.dataset.action = "photo-upload#removeNew"
    remove.setAttribute("aria-label", "Remove photo")
    remove.className = "absolute right-1.5 top-1.5 flex h-7 w-7 cursor-pointer items-center justify-center rounded-full bg-white/90 text-sm font-bold text-zinc-900 shadow transition hover:bg-red-500 hover:text-white"
    remove.textContent = "✕"

    const tag = document.createElement("span")
    tag.className = "absolute left-2 top-2 rounded-full bg-emerald-500 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-zinc-950"
    tag.textContent = "New"

    tile.append(img, tag, badge, remove)
    return tile
  }

  get tiles() {
    return Array.from(this.gridTarget.querySelectorAll("[data-photo-tile]"))
  }

  get photoCount() {
    return this.tiles.length
  }

  refresh() {
    const tiles = this.tiles
    tiles.forEach((tile, i) => {
      tile.querySelector("[data-cover-badge]")?.classList.toggle("hidden", i !== 0)
    })
    this.countTarget.textContent = tiles.length
    this.dropzoneTarget.classList.toggle("hidden", tiles.length >= this.maxValue)
  }

  showError(problems) {
    this.errorTarget.textContent = problems.join(" · ")
    this.errorTarget.classList.toggle("hidden", problems.length === 0)
  }
}
