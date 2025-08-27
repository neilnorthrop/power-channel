import { Controller } from "@hotwired/stimulus"

// Minimal focus trap helper
function trapFocus(container) {
  const focusable = container.querySelectorAll('a[href], button, textarea, input, select, [tabindex]:not([tabindex="-1"])')
  const first = focusable[0]
  const last = focusable[focusable.length - 1]

  // If no focusable elements, focus the container itself
  if (focusable.length === 0) {
    container.setAttribute('tabindex', '-1')
    container.focus()
  }

  function handleKey(e) {
    if (e.key === 'Tab') {
      if (e.shiftKey) {
        if (document.activeElement === first) {
          e.preventDefault()
          last.focus()
        }
      } else {
        if (document.activeElement === last) {
          e.preventDefault()
          first.focus()
        }
      }
    }
  }

  container.addEventListener('keydown', handleKey)
  return () => container.removeEventListener('keydown', handleKey)
}

export default class extends Controller {
  static targets = ["backdrop"]

  connect() {
    this.backdrop = this.hasBackdropTarget ? this.backdropTarget : document.getElementById('sidebar-backdrop')
    this.handleKeyDown = this._onKeyDown.bind(this)
    this.removeTrap = null

    // Ensure initial ARIA state
    this.element.setAttribute('aria-hidden', 'true')
  }

  open() {
    // show sidebar (mobile)
    document.documentElement.classList.add('overflow-hidden')
    this.element.classList.remove('-translate-x-full', 'hidden')
    this.element.classList.add('translate-x-0')
    if (this.backdrop) this.backdrop.classList.remove('hidden')
    this.element.setAttribute('aria-hidden', 'false')

    // focus trap
    this.removeTrap = trapFocus(this.element)

    // keyboard handling
    document.addEventListener('keydown', this.handleKeyDown)
  }

  close() {
    document.documentElement.classList.remove('overflow-hidden')
    this.element.classList.add('-translate-x-full')
    this.element.classList.remove('translate-x-0')
    if (this.backdrop) this.backdrop.classList.add('hidden')
    this.element.setAttribute('aria-hidden', 'true')

    if (this.removeTrap) {
      this.removeTrap()
      this.removeTrap = null
    }

    document.removeEventListener('keydown', this.handleKeyDown)
  }

  toggle() {
    const hidden = this.element.classList.contains('-translate-x-full') || this.element.classList.contains('hidden')
    if (hidden) this.open(); else this.close();
  }

  // Stimulus action for Escape key
  _onKeyDown(e) {
    if (e.key === 'Escape') this.close()
  }
}
