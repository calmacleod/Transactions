import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["apply", "bar", "checkbox", "count", "ids", "selectAll", "total"]

  connect() {
    this.dragging = false
    this.stopDrag = this.stopDrag.bind(this)
    this.selectRowUnderPointer = this.selectRowUnderPointer.bind(this)
    document.addEventListener("pointermove", this.selectRowUnderPointer)
    document.addEventListener("pointerup", this.stopDrag)
    this.update()
  }

  disconnect() {
    document.removeEventListener("pointermove", this.selectRowUnderPointer)
    document.removeEventListener("pointerup", this.stopDrag)
  }

  toggle() {
    this.update()
  }

  startDrag(event) {
    if (!event.shiftKey) return

    this.dragging = true
    this.selectRow(event.currentTarget)
    event.preventDefault()
  }

  dragSelect(event) {
    if (!this.dragging && !event.shiftKey) return

    this.selectRow(event.currentTarget)
    event.preventDefault()
  }

  stopDrag() {
    this.dragging = false
  }

  selectRowUnderPointer(event) {
    if (!this.dragging && !event.shiftKey) return

    const row = document.elementFromPoint(event.clientX, event.clientY)?.closest("tr")
    if (!row || !this.element.contains(row)) return

    this.selectRow(row)
    event.preventDefault()
  }

  toggleAll() {
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = this.selectAllTarget.checked
    })
    this.update()
  }

  clear() {
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false
    })

    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = false
    }

    this.update()
  }

  submitEnd(event) {
    if (event.detail.success) {
      this.clear()
    }
  }

  update() {
    const selected = this.checkboxTargets.filter((checkbox) => checkbox.checked)
    const totalCents = selected.reduce((sum, checkbox) => sum + Number.parseInt(checkbox.dataset.amountCents || "0", 10), 0)

    this.countTarget.textContent = selected.length.toString()
    this.totalTarget.textContent = this.formatMoney(totalCents)
    this.barTarget.hidden = selected.length === 0
    this.applyTarget.disabled = selected.length === 0
    this.idsTarget.replaceChildren(...selected.map((checkbox) => this.hiddenIdInput(checkbox.value)))
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.closest("tr")?.classList.toggle("is-selected", checkbox.checked)
    })

    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = selected.length > 0 && selected.length === this.checkboxTargets.length
      this.selectAllTarget.indeterminate = selected.length > 0 && selected.length < this.checkboxTargets.length
    }
  }

  hiddenIdInput(id) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = "bulk_transaction[transaction_ids][]"
    input.value = id
    return input
  }

  selectRow(row) {
    const checkbox = row.querySelector('[data-bulk-transactions-target="checkbox"]')
    if (!checkbox) return

    checkbox.checked = true
    this.update()
  }

  formatMoney(cents) {
    return new Intl.NumberFormat("en-CA", {
      style: "currency",
      currency: "CAD"
    }).format(cents / 100)
  }
}
