import { Controller } from "@hotwired/stimulus"

// Keeps the component selector list in sync with the chosen component type.
export default class extends Controller {
  static targets = ["type", "component"]

  connect() {
    this.resourceOptions = this.parseOptions(this.element.dataset.resourceOptions)
    this.itemOptions = this.parseOptions(this.element.dataset.itemOptions)
    this.initialComponent = this.element.dataset.initialComponentId || null

    if (this.hasTypeTarget && this.element.dataset.initialType) {
      this.typeTarget.value = this.element.dataset.initialType
    }

    this.populateOptions()
  }

  changeType() {
    this.populateOptions()
  }

  populateOptions() {
    if (!this.hasComponentTarget || !this.hasTypeTarget) return

    const type = (this.typeTarget.value || "Resource").trim()
    const options = type === "Item" ? this.itemOptions : this.resourceOptions
    const previousValue = this.initialComponent || this.componentTarget.value

    this.componentTarget.innerHTML = ""

    const blankOption = document.createElement("option")
    blankOption.value = ""
    blankOption.textContent = ""
    this.componentTarget.appendChild(blankOption)

    options.forEach(([value, label]) => {
      const option = document.createElement("option")
      option.value = String(value)
      option.textContent = label
      this.componentTarget.appendChild(option)
    })

    if (previousValue) {
      this.componentTarget.value = previousValue
    }

    this.initialComponent = null
  }

  parseOptions(json) {
    if (!json) return []
    try {
      return JSON.parse(json)
    } catch (error) {
      console.warn("component-select: unable to parse options", error)
      return []
    }
  }
}
