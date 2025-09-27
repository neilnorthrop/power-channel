import { Controller } from "@hotwired/stimulus"

// Rich typeahead with dropdown and keyboard navigation.
// Values:
// - data-typeahead-type-value: static type (Item/Resource/etc.)
// - data-typeahead-type-selector-value: CSS selector for a select that controls type

export default class extends Controller {
  static values = { type: String, typeSelector: String }

  connect() {
    this.items = []
    this.activeIndex = -1
    this.boundOnInput = this.onInput.bind(this)
    this.boundOnKeyDown = this.onKeyDown.bind(this)
    this.boundOnBlur = this.onBlur.bind(this)
    this.boundReposition = this.reposition.bind(this)
    this.element.addEventListener('input', this.boundOnInput)
    this.element.addEventListener('keydown', this.boundOnKeyDown)
    this.element.addEventListener('blur', this.boundOnBlur)

    const typeSel = this._findTypeSelector()
    if (typeSel) typeSel.addEventListener('change', () => { this.clear(); this.fetchSuggestions() })

    this.createDropdown()
  }

  disconnect() {
    this.element.removeEventListener('input', this.boundOnInput)
    this.element.removeEventListener('keydown', this.boundOnKeyDown)
    this.element.removeEventListener('blur', this.boundOnBlur)
    window.removeEventListener('resize', this.boundReposition)
    window.removeEventListener('scroll', this.boundReposition, true)
    if (this.dropdown) this.dropdown.remove()
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

  createDropdown() {
    this.dropdown = document.createElement('div')
    this.dropdown.className = 'fixed z-50 bg-white border border-gray-200 rounded shadow text-sm hidden max-h-64 overflow-auto'
    document.body.appendChild(this.dropdown)
    window.addEventListener('resize', this.boundReposition)
    window.addEventListener('scroll', this.boundReposition, true)
  }

  showDropdown() {
    this.dropdown.classList.remove('hidden')
    this.reposition()
  }

  hideDropdown() {
    this.dropdown.classList.add('hidden')
    this.activeIndex = -1
  }

  clear() {
    this.items = []
    this.dropdown.innerHTML = ''
    this.hideDropdown()
  }

  reposition() {
    const rect = this.element.getBoundingClientRect()
    this.dropdown.style.left = `${rect.left + window.scrollX}px`
    this.dropdown.style.top = `${rect.bottom + window.scrollY}px`
    this.dropdown.style.width = `${rect.width}px`
  }

  async onInput() {
    const q = this.element.value
    if (!q || q.length < 1) { this.clear(); return }
    const type = this.currentType()
    if (!type) { this.clear(); return }
    try {
      const url = `/owner/lookups/suggest?type=${encodeURIComponent(type)}&q=${encodeURIComponent(q)}`
      const res = await fetch(url, { headers: { 'Accept': 'application/json' } })
      if (!res.ok) return
      const json = await res.json()
      this.items = (json.results || []).slice(0, 20)
      this.render()
    } catch (_) { /* noop */ }
  }

  onKeyDown(e) {
    if (this.dropdown.classList.contains('hidden')) return
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      this.activeIndex = Math.min(this.activeIndex + 1, this.items.length - 1)
      this.highlight()
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      this.activeIndex = Math.max(this.activeIndex - 1, 0)
      this.highlight()
    } else if (e.key === 'Enter') {
      if (this.activeIndex >= 0 && this.items[this.activeIndex]) {
        e.preventDefault()
        this.choose(this.items[this.activeIndex])
      }
    } else if (e.key === 'Escape') {
      this.hideDropdown()
    }
  }

  onBlur() {
    // Delay to allow click selection
    setTimeout(() => this.hideDropdown(), 120)
  }

  render() {
    this.dropdown.innerHTML = ''
    this.items.forEach((name, idx) => {
      const btn = document.createElement('button')
      btn.type = 'button'
      btn.className = `block w-full text-left px-2 py-1 ${idx === this.activeIndex ? 'bg-gray-100' : ''}`
      btn.textContent = name
      btn.addEventListener('mousedown', (e) => { e.preventDefault(); this.choose(name) })
      this.dropdown.appendChild(btn)
    })
    if (this.items.length > 0) this.showDropdown(); else this.hideDropdown()
  }

  highlight() {
    Array.from(this.dropdown.children).forEach((el, i) => {
      el.classList.toggle('bg-gray-100', i === this.activeIndex)
      if (i === this.activeIndex) el.scrollIntoView({ block: 'nearest' })
    })
  }

  choose(name) {
    this.element.value = name
    this.hideDropdown()
    this.element.dispatchEvent(new Event('change', { bubbles: true }))
  }
}
