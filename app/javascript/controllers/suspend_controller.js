import { Controller } from "@hotwired/stimulus"

// Controls the inline Suspend form (reasons + presets)
// Expects targets: reason, until
// Buttons call actions: addReason, setPreset

export default class extends Controller {
  static targets = ["reason", "until"]

  addReason(event) {
    const template = event.params.template || ''
    if (!template) return
    const current = this.reasonTarget.value || ''
    this.reasonTarget.value = current ? (current + '\n' + template) : template
    this.reasonTarget.dispatchEvent(new Event('input', { bubbles: true }))
  }

  setPreset(event) {
    const hours = parseInt(event.params.hours || '0', 10)
    if (!hours || !this.untilTarget) return
    const dt = new Date(Date.now() + hours * 3600 * 1000)
    this.untilTarget.value = this.toLocalDatetime(dt)
    this.untilTarget.dispatchEvent(new Event('change', { bubbles: true }))
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

