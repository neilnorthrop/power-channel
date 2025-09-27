import { Controller } from "@hotwired/stimulus"

// Prevent submits when any validate-ref inputs are invalid.
// Usage: data-controller="validate-form" data-action="submit->validate-form#intercept"

export default class extends Controller {
  async intercept(event) {
    const inputs = this.element.querySelectorAll('[data-controller~="validate-ref"]')
    if (inputs.length === 0) return
    event.preventDefault()
    const checks = Array.from(inputs).map((el) => this.checkOne(el))
    const results = await Promise.all(checks)
    const firstInvalid = results.find((r) => !r.ok)
    if (firstInvalid) {
      try { firstInvalid.el.focus() } catch (_) {}
      return // keep form blocked
    }
    // All ok; submit for real
    this.element.requestSubmit()
  }

  async checkOne(el) {
    // Ask the validate-ref controller to validate now
    const ctrl = this.findStimulusController(el, 'validate-ref')
    if (ctrl && typeof ctrl.validate === 'function') ctrl.validate()
    const typeSel = el.getAttribute('data-validate-ref-type-selector-value')
    const typeFixed = el.getAttribute('data-validate-ref-type-value')
    const type = typeSel ? (el.closest('[data-form-list-row]')?.querySelector(typeSel)?.value || '') : (typeFixed || '')
    const name = (el.value || '').trim()
    if (!type || !name) return { ok: true, el }
    try {
      const url = `/owner/lookups/exists?type=${encodeURIComponent(type)}&name=${encodeURIComponent(name)}`
      const res = await fetch(url, { headers: { 'Accept': 'application/json' } })
      if (!res.ok) return { ok: false, el }
      const json = await res.json()
      if (!json.exists) {
        // Set error style if available
        el.classList.add('border', 'border-red-500')
        return { ok: false, el }
      }
      return { ok: true, el }
    } catch (_) {
      return { ok: false, el }
    }
  }

  findStimulusController(el, identifier) {
    const app = window.Stimulus || window.application
    if (!app) return null
    // Stimulus v3 keeps controllers on el.controllers array; do a best-effort
    return (el.controllers || []).find((c) => c.identifier === identifier) || null
  }
}

