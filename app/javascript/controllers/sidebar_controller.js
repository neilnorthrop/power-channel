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
  this.lastActiveElement = null

    // debug log to confirm controller connection
    try { console.debug('Sidebar Stimulus controller connected', this.element) } catch (e) {}

    // dev-friendly init log
    try {
      console.info('[SIDEBAR] init', { time: new Date().toISOString(), width: window.innerWidth, userAgent: navigator.userAgent })
      const sidebarFound = !!this.element
      console.log('[SIDEBAR] DOM presence', { sidebarFound, id: this.element.id, classes: this.element.className, backdropFound: !!this.backdrop })
    } catch (e) {}

    // media query for mobile breakpoint (adjust breakpoint if your CSS uses a different one)
    try {
      this.mq = window.matchMedia('(max-width: 767px)')
      console.log('[SIDEBAR] media query match on connect', { mqMatches: this.mq.matches })
      this._onMqChange = (e) => console.log('[SIDEBAR] mq change', { matches: e.matches })
      if (this.mq.addEventListener) this.mq.addEventListener('change', this._onMqChange)
      else if (this.mq.addListener) this.mq.addListener(this._onMqChange)
    } catch (e) {}

    // listen for transitionend so we can surface final states
    try {
      this._onTransitionEnd = (e) => {
        try {
          console.log('[SIDEBAR] transitionend', { propertyName: e.propertyName, elapsed: e.elapsedTime, classes: this.element.className })
        } catch (inner) {}
      }
      this.element.addEventListener('transitionend', this._onTransitionEnd)
    } catch (e) {}

    // Ensure initial ARIA state
    this.element.setAttribute('aria-hidden', 'true')
  }

  open() {
    // show sidebar (mobile)
    const t0 = performance.now()
    try { console.log('[SIDEBAR] open - start', { width: window.innerWidth }) } catch (e) {}

    // remember last focused element so we can return focus on close
    this.lastActiveElement = document.activeElement
    document.documentElement.classList.add('overflow-hidden')
    this.element.classList.remove('-translate-x-full')
    this.element.classList.add('translate-x-0')
    if (this.backdrop) this.backdrop.classList.remove('hidden')
    this.element.setAttribute('aria-hidden', 'false')

    // focus trap
    this.removeTrap = trapFocus(this.element)

    // keyboard handling
    document.addEventListener('keydown', this.handleKeyDown)

    // computed styles after opening
    try {
      const cs = getComputedStyle(this.element)
      const elapsed = Math.round(performance.now() - t0)
      console.log('[SIDEBAR] open - end', {
        elapsedMs: elapsed,
        display: cs.display,
        visibility: cs.visibility,
        opacity: cs.opacity,
        transform: cs.transform,
        zIndex: cs.zIndex,
        classes: this.element.className,
        ariaHidden: this.element.getAttribute('aria-hidden')
      })
    } catch (e) {}
  }

  close() {
    const t0 = performance.now()
    try { console.log('[SIDEBAR] close - start', { width: window.innerWidth }) } catch (e) {}

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

    // computed styles after close
    try {
      const cs = getComputedStyle(this.element)
      const elapsed = Math.round(performance.now() - t0)
      console.log('[SIDEBAR] close - end', {
        elapsedMs: elapsed,
        display: cs.display,
        visibility: cs.visibility,
        opacity: cs.opacity,
        transform: cs.transform,
        zIndex: cs.zIndex,
        classes: this.element.className,
        ariaHidden: this.element.getAttribute('aria-hidden')
      })
    } catch (e) {}

    // return focus to the toggle button if possible
    try {
      const toggle = document.getElementById('sidebar-toggle')
      if (toggle) {
        console.log('[SIDEBAR] returning focus to toggle', { toggleId: 'sidebar-toggle' })
        toggle.focus()
      } else if (this.lastActiveElement) {
        console.log('[SIDEBAR] returning focus to lastActiveElement', { tag: this.lastActiveElement && this.lastActiveElement.tagName })
        this.lastActiveElement.focus()
      }
    } catch (e) {
      // ignore focus errors in some test environments
    }
  }

  toggle() {
    const hidden = this.element.classList.contains('-translate-x-full')
    try { console.log('[SIDEBAR] toggle called', { hidden, width: window.innerWidth }) } catch (e) {}
    if (hidden) this.open(); else this.close();
  }

  disconnect() {
    try { console.log('[SIDEBAR] disconnecting controller') } catch (e) {}
    try {
      if (this.mq) {
        if (this.mq.removeEventListener) this.mq.removeEventListener('change', this._onMqChange)
        else if (this.mq.removeListener) this.mq.removeListener(this._onMqChange)
      }
    } catch (e) {}
    try { this.element.removeEventListener('transitionend', this._onTransitionEnd) } catch (e) {}
    try { document.removeEventListener('keydown', this.handleKeyDown) } catch (e) {}
  }

  // Stimulus action for Escape key
  _onKeyDown(e) {
    if (e.key === 'Escape') this.close()
  }
}
