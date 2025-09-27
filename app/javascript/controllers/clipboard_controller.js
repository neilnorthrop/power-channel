import { Controller } from "@hotwired/stimulus"

// Copies the provided value to clipboard and shows a tiny feedback text.
// Usage: data-controller="clipboard" data-clipboard-value-value="text"
// Button: data-action="click->clipboard#copy"

export default class extends Controller {
  static values = { value: String }

  async copy(e) {
    e.preventDefault()
    const text = this.valueValue || this.element.getAttribute('data-value') || this.element.textContent.trim()
    try {
      await navigator.clipboard.writeText(text)
      this.flash('Copied!')
    } catch (err) {
      this.flash('Copy failed')
    }
  }

  flash(msg) {
    const tip = document.createElement('span')
    tip.className = 'ml-2 text-xs text-gray-500'
    tip.textContent = msg
    this.element.insertAdjacentElement('afterend', tip)
    setTimeout(() => tip.remove(), 1200)
  }
}

