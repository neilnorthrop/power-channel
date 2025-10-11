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

  connect() {
    this.state = 'idle' // idle | pending | confirming
  }

  intercept(event) {
    const form = this._form()

    // If we just approved the modal, allow this submit through and reset the state.
    if (this.state === 'confirming') {
      this.state = 'idle'
      return
    }

    // Prevent double opening while we already have a modal on screen.
    if (this.state === 'pending') {
      event.preventDefault()
      return
    }

    event.preventDefault()
    this.state = 'pending'
    this.showModal(form)
  }

  showModal(form) {
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

    const closeModal = () => {
      backdrop.remove()
      if (this.state === 'pending') this.state = 'idle'
    }

    const cancelBtn = box.querySelector('[data-ref="cancel"]')
    const okBtn = box.querySelector('[data-ref="ok"]')

    cancelBtn.addEventListener('click', closeModal)
    backdrop.addEventListener('click', (event) => {
      if (event.target !== backdrop) return
      closeModal()
    })

    okBtn.addEventListener('click', () => {
      closeModal()
      this.state = 'confirming'

      if (!form) {
        // Fall back to retriggering the original element for non-form usage.
        requestAnimationFrame(() => this.element.click())
        return
      }

      form.dataset.confirmBypass = 'true'
      form.dataset.skipValidate = 'true'

      requestAnimationFrame(() => {
        form.requestSubmit()
        // Allow validate-form to run again on future submits.
        setTimeout(() => {
          delete form.dataset.confirmBypass
          delete form.dataset.skipValidate
        }, 0)
      })
    })
  }

  _form() {
    if (this.element.tagName === 'FORM') return this.element
    return this.element.closest('form')
  }

  escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]))
  }
}
