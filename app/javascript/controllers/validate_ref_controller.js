import { Controller } from "@hotwired/stimulus"

// Inline reference validation for text fields that refer to named records.
// Attributes:
// - data-validate-ref-type-value: fixed type (Item/Resource/Skill/Building/Flag/Action/Recipe)
// - data-validate-ref-type-selector-value: CSS selector to read a dynamic type from a nearby <select>
// - data-validate-ref-message-value: custom error message

export default class extends Controller {
  static values = { type: String, typeSelector: String, message: String }

  connect() {
    this.bound = this.validate.bind(this)
    this.element.addEventListener('input', this.bound)
    this.element.addEventListener('change', this.bound)
    const sel = this._findTypeSelector()
    if (sel) sel.addEventListener('change', this.bound)
    this.errorEl = null
    this.suggestEl = null
  }

  disconnect() {
    this.element.removeEventListener('input', this.bound)
    this.element.removeEventListener('change', this.bound)
    const sel = this._findTypeSelector()
    if (sel) sel.removeEventListener('change', this.bound)
    if (this.errorEl) this.errorEl.remove()
  }

  _findTypeSelector() {
    if (!this.typeSelectorValue) return null
    return this.element.closest('[data-form-list-row]')?.querySelector(this.typeSelectorValue) || document.querySelector(this.typeSelectorValue)
  }

  currentType() {
    const sel = this._findTypeSelector()
    if (sel) return sel.value
    return this.typeValue || ''
  }

  setError(msg) {
    this.element.classList.add('border', 'border-red-500')
    if (!this.errorEl) {
      this.errorEl = document.createElement('div')
      this.errorEl.className = 'text-xs text-red-600 mt-1'
      this.element.parentElement.appendChild(this.errorEl)
    }
    this.errorEl.textContent = msg || this.messageValue || 'Unknown reference'
  }

  clearError() {
    this.element.classList.remove('border-red-500')
    if (this.errorEl) this.errorEl.remove()
    this.errorEl = null
    if (this.suggestEl) this.suggestEl.remove()
    this.suggestEl = null
  }

  validate() {
    const value = (this.element.value || '').trim()
    const type = this.currentType()
    if (!type || value.length === 0) {
      this.clearError()
      return
    }
    clearTimeout(this._t)
    this._t = setTimeout(async () => {
      try {
        const url = `/owner/lookups/exists?type=${encodeURIComponent(type)}&name=${encodeURIComponent(value)}`
        const res = await fetch(url, { headers: { 'Accept': 'application/json' } })
        if (!res.ok) return
        const json = await res.json()
        const ok = !!json.exists
        if (ok) {
          this.clearError()
        } else {
          this.setError()
          // Fetch suggestions for convenience
          try {
            const surl = `/owner/lookups/suggest?type=${encodeURIComponent(type)}&q=${encodeURIComponent(value)}`
            const sres = await fetch(surl, { headers: { 'Accept': 'application/json' } })
            if (sres.ok) {
              const sjson = await sres.json()
              const items = (sjson.results || []).slice(0, 5)
              if (items.length > 0) this.renderSuggestions(items)
            }
          } catch (_) { /* ignore */ }
        }
      } catch (_) { /* ignore fetch errors */ }
    }, 250)
  }

  renderSuggestions(items) {
    if (this.suggestEl) this.suggestEl.remove()
    this.suggestEl = document.createElement('div')
    this.suggestEl.className = 'mt-1 flex flex-wrap gap-1'
    items.forEach((name) => {
      const btn = document.createElement('button')
      btn.type = 'button'
      btn.className = 'px-2 py-0.5 rounded border text-xs'
      btn.textContent = name
      btn.addEventListener('click', () => {
        this.element.value = name
        this.clearError()
        this.element.dispatchEvent(new Event('change', { bubbles: true }))
      })
      this.suggestEl.appendChild(btn)
    })
    this.element.parentElement.appendChild(this.suggestEl)
  }
}
