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
    // Resolve controller host and the actual aside#sidebar element. The
    // controller may be attached to a wrapper container that contains the
    // toggle button; we still want to operate on the aside element itself.
    this.hostElement = this.element
    this.sidebarElement = (this.hostElement && this.hostElement.id === 'sidebar') ? this.hostElement : document.getElementById('sidebar') || this.hostElement
    this.backdrop = this.hasBackdropTarget ? this.backdropTarget : document.getElementById('sidebar-backdrop')
    this.handleKeyDown = this._onKeyDown.bind(this)
    this.removeTrap = null
  this.lastActiveElement = null

    // debug log to confirm controller connection
  try { console.debug('Sidebar Stimulus controller connected', this.sidebarElement) } catch (e) {}

    // dev-friendly init log
    try {
      console.info('[SIDEBAR] init', { time: new Date().toISOString(), width: window.innerWidth, userAgent: navigator.userAgent })
  const sidebarFound = !!this.sidebarElement
  console.log('[SIDEBAR] DOM presence', { sidebarFound, id: this.sidebarElement && this.sidebarElement.id, classes: this.sidebarElement && this.sidebarElement.className, backdropFound: !!this.backdrop })
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
          console.log('[SIDEBAR] transitionend', { propertyName: e.propertyName, elapsed: e.elapsedTime, classes: this.sidebarElement && this.sidebarElement.className })
        } catch (inner) {}
      }
      this.sidebarElement.addEventListener('transitionend', this._onTransitionEnd)
    } catch (e) {}

    // Ensure initial ARIA state
  if (this.sidebarElement) this.sidebarElement.setAttribute('aria-hidden', 'true')

    // attach a native click logger to the toggle button to ensure clicks reach the DOM
    try {
      const tb = document.getElementById('sidebar-toggle')
      if (tb) {
        tb.addEventListener('click', (ev) => {
            try {
            console.log('[SIDEBAR] native-toggle-click', { id: tb.id, event: ev.type, classes: this.sidebarElement && this.sidebarElement.className })
          } catch (e) {}
        })
      }
    } catch (e) {}
  }

  open() {
    // show sidebar (mobile)
    const t0 = performance.now()
  try { console.log('[SIDEBAR] open - start', { width: window.innerWidth, beforeClasses: this.sidebarElement && this.sidebarElement.className }) } catch (e) {}

    // remember last focused element so we can return focus on close
  this.lastActiveElement = document.activeElement
  document.documentElement.classList.add('overflow-hidden')
  if (this.sidebarElement) this.sidebarElement.classList.remove('-translate-x-full')
  if (this.sidebarElement) this.sidebarElement.classList.add('translate-x-0')
  if (this.backdrop) this.backdrop.classList.remove('hidden')
  if (this.sidebarElement) this.sidebarElement.setAttribute('aria-hidden', 'false')

    // focus trap
  this.removeTrap = this.sidebarElement ? trapFocus(this.sidebarElement) : null

    // keyboard handling
    document.addEventListener('keydown', this.handleKeyDown)

    // computed styles after opening
    try {
  const cs = this.sidebarElement ? getComputedStyle(this.sidebarElement) : { display: 'none', visibility: 'hidden', opacity: '0', transform: 'none', zIndex: 'auto' }
      const elapsed = Math.round(performance.now() - t0)
      console.log('[SIDEBAR] open - end', {
        elapsedMs: elapsed,
        display: cs.display,
        visibility: cs.visibility,
        opacity: cs.opacity,
        transform: cs.transform,
        zIndex: cs.zIndex,
  classes: this.sidebarElement && this.sidebarElement.className,
  ariaHidden: this.sidebarElement && this.sidebarElement.getAttribute('aria-hidden')
      })
    } catch (e) {}
  }

  close() {
    const t0 = performance.now()
    try { console.log('[SIDEBAR] close - start', { width: window.innerWidth }) } catch (e) {}

  document.documentElement.classList.remove('overflow-hidden')
  if (this.sidebarElement) this.sidebarElement.classList.add('-translate-x-full')
  if (this.sidebarElement) this.sidebarElement.classList.remove('translate-x-0')
  if (this.backdrop) this.backdrop.classList.add('hidden')
  if (this.sidebarElement) this.sidebarElement.setAttribute('aria-hidden', 'true')

    if (this.removeTrap) {
      this.removeTrap()
      this.removeTrap = null
    }

    document.removeEventListener('keydown', this.handleKeyDown)

    // computed styles after close
    try {
  const cs = this.sidebarElement ? getComputedStyle(this.sidebarElement) : { display: 'none', visibility: 'hidden', opacity: '0', transform: 'none', zIndex: 'auto' }
      const elapsed = Math.round(performance.now() - t0)
      console.log('[SIDEBAR] close - end', {
        elapsedMs: elapsed,
        display: cs.display,
        visibility: cs.visibility,
        opacity: cs.opacity,
        transform: cs.transform,
        zIndex: cs.zIndex,
  classes: this.sidebarElement && this.sidebarElement.className,
  ariaHidden: this.sidebarElement && this.sidebarElement.getAttribute('aria-hidden')
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
  try { console.log('[SIDEBAR] toggle called (pre)', { id: this.sidebarElement && this.sidebarElement.id, classList: this.sidebarElement ? Array.from(this.sidebarElement.classList) : [], width: window.innerWidth }) } catch (e) {}
  const hidden = this.sidebarElement ? this.sidebarElement.classList.contains('-translate-x-full') : true
  try { console.log('[SIDEBAR] toggle computed hidden', { hidden }) } catch (e) {}
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
  try { if (this.sidebarElement) this.sidebarElement.removeEventListener('transitionend', this._onTransitionEnd) } catch (e) {}
    try { document.removeEventListener('keydown', this.handleKeyDown) } catch (e) {}
  }

  // Stimulus action for Escape key
  _onKeyDown(e) {
    if (e.key === 'Escape') this.close()
  }
}
