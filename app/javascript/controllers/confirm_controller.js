import { Controller } from "@hotwired/stimulus"

// Usage:
// <form data-controller="confirm"
//       data-confirm-message-value="Are you sure?"
//       data-action="submit->confirm#intercept">
// </form>
// or
// <button data-controller="confirm" data-confirm-message-value="..." data-action="click->confirm#intercept"></button>

export default class extends Controller {
  static values = { message: String }

  intercept(event) {
    // If a native confirm has already been asked, skip
    if (this._confirmed) return
    event.preventDefault()
    this.showModal()
  }

  showModal() {
    const msg = this.messageValue || this.element.getAttribute('data-confirm') || 'Are you sure?'
    const backdrop = document.createElement('div')
    backdrop.className = 'fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50'
    backdrop.setAttribute('role', 'dialog')
    backdrop.setAttribute('aria-modal', 'true')

    const box = document.createElement('div')
    box.className = 'bg-white rounded shadow-lg w-96 max-w-[90vw]'
    box.innerHTML = `
      <div class="p-4 border-b">
        <h3 class="text-base font-semibold">Please Confirm</h3>
      </div>
      <div class="p-4 text-sm">${this.escapeHtml(msg)}</div>
      <div class="p-3 border-t flex justify-end gap-2">
        <button type="button" data-ref="cancel" class="px-3 py-1.5 rounded border">Cancel</button>
        <button type="button" data-ref="ok" class="px-3 py-1.5 rounded bg-gray-800 text-white">Confirm</button>
      </div>
    `
    backdrop.appendChild(box)
    document.body.appendChild(backdrop)

    const cleanup = () => backdrop.remove()
    const cancelBtn = box.querySelector('[data-ref="cancel"]')
    const okBtn = box.querySelector('[data-ref="ok"]')
    cancelBtn.addEventListener('click', cleanup)
    backdrop.addEventListener('click', (e) => { if (e.target === backdrop) cleanup() })
    okBtn.addEventListener('click', () => {
      cleanup()
      this._confirmed = true
      // Submit form or trigger original click
      if (this.element.tagName === 'FORM') {
        this.element.requestSubmit()
      } else {
        // find nearest form and submit, or re-trigger click
        const form = this.element.closest('form')
        if (form) form.requestSubmit(); else this.element.click()
      }
      this._confirmed = false
    })
  }

  escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]))
  }
}

