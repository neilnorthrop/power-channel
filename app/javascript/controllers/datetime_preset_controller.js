import { Controller } from "@hotwired/stimulus"

// Provides helpers to set a datetime-local input to now or +N hours.
// Usage: wrap container with data-controller="datetime-preset"
// and mark the input with data-datetime-preset-target="input".
// Buttons trigger: data-action="click->datetime-preset#setNow" or setPreset with hours param.

export default class extends Controller {
  static targets = ["input"]

  setNow() {
    if (!this.hasInputTarget) return
    this.inputTarget.value = this.toLocalDatetime(new Date())
    this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }))
  }

  setPreset(event) {
    if (!this.hasInputTarget) return
    const hours = parseInt(event.params.hours || '0', 10)
    const dt = new Date(Date.now() + hours * 3600 * 1000)
    this.inputTarget.value = this.toLocalDatetime(dt)
    this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }))
  }

  toLocalDatetime(date) {
    const pad = (n) => String(n).padStart(2, '0')
    const y = date.getFullYear()
    const m = pad(date.getMonth() + 1)
    const d = pad(date.getDate())
    const hh = pad(date.getHours())
    const mm = pad(date.getMinutes())
    return `${y}-${m}-${d}T${hh}:${mm}`
  }
}

