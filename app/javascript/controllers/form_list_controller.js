import { Controller } from "@hotwired/stimulus"

// Adds/removes nested form rows using a hidden template element
// Usage:
// <div data-controller="form-list" data-form-list-target="container">
//   <template data-form-list-target="template"> ... __INDEX__ ... </template>
//   <button data-action="click->form-list#add">Add</button>
// </div>
export default class extends Controller {
  static targets = ["container", "template"]

  add(event) {
    event.preventDefault()
    const html = this.templateTarget.innerHTML
    const index = Date.now().toString()
    const node = document.createElement('div')
    node.innerHTML = html.replaceAll('__INDEX__', index)
    this.containerTarget.appendChild(node)
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest('[data-form-list-row]')
    if (row) row.remove()
  }
}

