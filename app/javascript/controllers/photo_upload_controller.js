import { Controller } from "@hotwired/stimulus"

// Depop-style photo picker for the admin jersey form.
//
// - Pick several photos at once, or drag a batch in from a folder.
// - Each pick is added to the photos already chosen instead of replacing them.
// - Photos preview instantly and can be removed before saving.
// - The first photo in the grid is the cover.
// - "Crop" opens an editor to zoom in/out and drag the photo within its square frame.
//   Only the framing is saved (as "x,y,zoom"); the original upload is never changed.
//
// Already-saved photos are rendered by the server as tiles with hidden
// signed_id + crop inputs; removing the tile removes them, so Rails detaches it.
export default class extends Controller {
  static targets = ["input", "grid", "dropzone", "count", "error", "cropper", "cropFrame", "cropImage", "zoom"]
  static values = { max: Number, maxBytes: Number, types: String }

  static MIN_ZOOM = 0.5
  static MAX_ZOOM = 4

  connect() {
    this.files = []
    this.crops = [] // crop for each new file, parallel to this.files
    this.previewUrls = []
    this.tiles.forEach((tile) => this.applyTileCrop(tile))
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
    if (!event.dataTransfer?.types.includes("Files")) return
    event.preventDefault()
    this.element.classList.add("border-emerald-500", "bg-emerald-50")
  }

  dragLeave(event) {
    if (this.element.contains(event.relatedTarget)) return
    this.element.classList.remove("border-emerald-500", "bg-emerald-50")
  }

  drop(event) {
    if (!event.dataTransfer?.files.length) return
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
    this.crops.splice(index, 1)
    this.syncInput()
    this.renderNew()
  }

  // --- crop editor ---------------------------------------------------------

  openCropper(event) {
    this.editingTile = event.currentTarget.closest("[data-photo-tile]")
    this.crop = parseCrop(this.editingTile.querySelector("[data-crop-input]").value)

    const img = this.cropImageTarget
    const src = this.editingTile.dataset.cropSrc
    const ready = () => {
      this.natural = { width: img.naturalWidth, height: img.naturalHeight }
      this.renderCrop()
      img.style.visibility = ""
    }

    this.natural = null
    img.style.visibility = "hidden"
    if (img.getAttribute("src") === src && img.complete && img.naturalWidth) {
      ready() // same photo as last time: already loaded, so no load event will fire
    } else {
      img.onload = ready
      img.src = src
    }

    this.cropperTarget.classList.remove("hidden")
    this.cropperTarget.classList.add("flex")
  }

  closeCropper() {
    this.cropperTarget.classList.add("hidden")
    this.cropperTarget.classList.remove("flex")
    this.editingTile = null
  }

  cropKey(event) {
    if (this.editingTile && event.key === "Escape") this.closeCropper()
  }

  cropZoom() {
    this.crop.zoom = Number(this.zoomTarget.value)
    this.renderCrop()
  }

  cropWheel(event) {
    event.preventDefault()
    this.crop.zoom = clampZoom(this.crop.zoom * Math.exp(-event.deltaY * 0.0015))
    this.renderCrop()
  }

  cropReset() {
    this.crop = { ...DEFAULT_CROP }
    this.renderCrop()
  }

  cropStart(event) {
    if (!this.natural) return
    event.preventDefault()

    const frame = this.cropFrameTarget.getBoundingClientRect()
    const start = { x: event.clientX, y: event.clientY, box: cropBox(this.natural, this.crop) }

    const move = (e) => {
      const left = start.box.left + ((e.clientX - start.x) / frame.width) * 100
      const top = start.box.top + ((e.clientY - start.y) / frame.height) * 100
      this.crop.x = (50 - left) / start.box.width
      this.crop.y = (50 - top) / start.box.height
      this.renderCrop()
    }
    const stop = () => {
      window.removeEventListener("pointermove", move)
      window.removeEventListener("pointerup", stop)
      window.removeEventListener("pointercancel", stop)
    }
    window.addEventListener("pointermove", move)
    window.addEventListener("pointerup", stop)
    window.addEventListener("pointercancel", stop)
  }

  cropDone() {
    const tile = this.editingTile
    const value = formatCrop(this.crop)
    tile.querySelector("[data-crop-input]").value = value

    if (tile.hasAttribute("data-new-photo")) {
      this.crops[Number(tile.dataset.index)] = value
    }

    this.applyTileCrop(tile)
    this.closeCropper()
  }

  // Draw the editor image and snap the crop back inside the photo's edges.
  renderCrop() {
    if (!this.natural) return
    const box = cropBox(this.natural, this.crop)
    this.crop.x = (50 - box.left) / box.width
    this.crop.y = (50 - box.top) / box.height
    placeImage(this.cropImageTarget, box)
    this.zoomTarget.value = this.crop.zoom
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
        this.crops.push(formatCrop(DEFAULT_CROP))
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
      const tile = this.buildTile(url, index)
      this.dropzoneTarget.before(tile)
      this.applyTileCrop(tile)
    })

    this.refresh()
  }

  buildTile(url, index) {
    const tile = document.createElement("div")
    tile.dataset.photoTile = ""
    tile.dataset.newPhoto = ""
    tile.dataset.index = index
    tile.dataset.cropSrc = url
    tile.className = "group relative aspect-square overflow-hidden rounded-xl bg-zinc-200"

    const img = document.createElement("img")
    img.src = url
    img.alt = ""
    img.dataset.tileImage = ""
    img.className = "absolute inset-0 h-full w-full object-cover"

    // Sent alongside the files, in the same order, so the server knows each photo's crop.
    const cropInput = document.createElement("input")
    cropInput.type = "hidden"
    cropInput.name = "photo_crops[]"
    cropInput.value = this.crops[index]
    cropInput.dataset.cropInput = ""

    const tag = document.createElement("span")
    tag.className = "absolute left-2 top-2 rounded-full bg-emerald-500 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-zinc-950"
    tag.textContent = "New"

    const badge = document.createElement("span")
    badge.dataset.coverBadge = ""
    badge.className = "absolute bottom-2 left-2 hidden rounded-full bg-zinc-950/80 px-2 py-0.5 text-xs font-bold text-white"
    badge.textContent = "Cover"

    const crop = document.createElement("button")
    crop.type = "button"
    crop.dataset.action = "photo-upload#openCropper"
    crop.setAttribute("aria-label", "Crop photo")
    crop.className = "absolute bottom-1.5 right-1.5 cursor-pointer rounded-full bg-white/90 px-2.5 py-1 text-xs font-bold text-zinc-900 shadow transition hover:bg-emerald-500 hover:text-white"
    crop.textContent = "Crop"

    const remove = document.createElement("button")
    remove.type = "button"
    remove.dataset.index = index
    remove.dataset.action = "photo-upload#removeNew"
    remove.setAttribute("aria-label", "Remove photo")
    remove.className = "absolute right-1.5 top-1.5 flex h-7 w-7 cursor-pointer items-center justify-center rounded-full bg-white/90 text-sm font-bold text-zinc-900 shadow transition hover:bg-red-500 hover:text-white"
    remove.textContent = "✕"

    tile.append(img, cropInput, tag, badge, crop, remove)
    return tile
  }

  // Frame a tile's preview the same way the shop will show it.
  applyTileCrop(tile) {
    const img = tile.querySelector("[data-tile-image]")
    const crop = parseCrop(tile.querySelector("[data-crop-input]").value)
    const apply = () => {
      if (!img.naturalWidth) return
      img.classList.remove("inset-0", "h-full", "w-full", "object-cover")
      placeImage(img, cropBox({ width: img.naturalWidth, height: img.naturalHeight }, crop))
    }
    img.complete ? apply() : img.addEventListener("load", apply, { once: true })
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

// --- crop math (mirrors Jersey.crop_box in app/models/jersey.rb) ------------

const DEFAULT_CROP = { x: 0.5, y: 0.5, zoom: 1 }

function clampZoom(zoom) {
  return Math.min(4, Math.max(0.5, zoom))
}

function parseCrop(value) {
  const [x, y, zoom] = String(value || "").split(",").map(Number)
  if (![x, y, zoom].every(Number.isFinite)) return { ...DEFAULT_CROP }
  return { x, y, zoom: clampZoom(zoom) }
}

function formatCrop({ x, y, zoom }) {
  return [x, y, zoom].map((n) => Number(n.toFixed(4))).join(",")
}

// Where the photo sits inside a square frame, in % of the frame.
function cropBox({ width, height }, { x, y, zoom }) {
  const aspect = width / height
  const w = Math.max(aspect, 1) * 100 * zoom
  const h = Math.max(1 / aspect, 1) * 100 * zoom

  let left = 50 - x * w
  let top = 50 - y * h
  left = w >= 100 ? Math.min(0, Math.max(100 - w, left)) : (100 - w) / 2
  top = h >= 100 ? Math.min(0, Math.max(100 - h, top)) : (100 - h) / 2

  return { left, top, width: w, height: h }
}

function placeImage(img, box) {
  img.classList.add("absolute", "max-w-none")
  img.style.left = `${box.left}%`
  img.style.top = `${box.top}%`
  img.style.width = `${box.width}%`
  img.style.height = `${box.height}%`
}
