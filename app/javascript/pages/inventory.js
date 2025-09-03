import { getJwt, authHeaders, toast } from "pages/util"

function initInventory() {
  const token = getJwt()
  const resourcesDiv = document.getElementById('resources')
  const inventoryDiv = document.getElementById('inventory')
  if (!resourcesDiv || !inventoryDiv) return

  const fetchResources = () => {
    fetch('/api/v1/user_resources', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        resourcesDiv.innerHTML = ''
        resourcesDiv.className = 'grid grid-cols-1 sm:grid-cols-2 gap-3'
        const resources = data.data || []
        if (resources.length === 0) {
          const empty = document.createElement('p')
          empty.className = 'text-sm text-gray-600'
          empty.textContent = 'No resources yet.'
          resourcesDiv.appendChild(empty)
          return
        }
        resources.forEach(resource => {
          const card = document.createElement('div')
          card.className = 'rounded-md border border-gray-200 bg-white shadow-sm p-3 flex items-center justify-between'
          const name = document.createElement('span')
          name.className = 'font-medium text-gray-900'
          name.textContent = resource.attributes.name
          const amt = document.createElement('span')
          amt.className = 'text-sm text-gray-700'
          amt.textContent = resource.attributes.amount
          card.appendChild(name)
          card.appendChild(amt)
          resourcesDiv.appendChild(card)
        })
      })
  }

  const fetchInventory = () => {
    fetch('/api/v1/items', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        inventoryDiv.innerHTML = ''
        inventoryDiv.className = 'space-y-3'
        const userItems = data.data || []
        const included = data.included || []
        const itemsById = new Map(included.filter(i => i.type === 'item').map(i => [i.id, i]))

        if (userItems.length === 0) {
          const empty = document.createElement('p')
          empty.className = 'text-sm text-gray-600'
          empty.textContent = 'No items in your inventory.'
          inventoryDiv.appendChild(empty)
          return
        }

        userItems.forEach(ui => {
          const itemRel = ui.relationships && ui.relationships.item && ui.relationships.item.data
          const item = itemRel ? itemsById.get(itemRel.id) : null

          const card = document.createElement('div')
          card.className = 'rounded-md border border-gray-200 bg-white shadow-sm p-4 flex items-start justify-between gap-3'

          const left = document.createElement('div')
          const titleRow = document.createElement('div')
          titleRow.className = 'flex items-center gap-2'
          const title = document.createElement('h3')
          title.className = 'font-medium text-gray-900'
          title.textContent = item ? item.attributes.name : 'Unknown Item'
          const qty = document.createElement('span')
          qty.className = 'text-xs px-1.5 py-0.5 rounded bg-gray-100 text-gray-700'
          qty.textContent = `x${ui.attributes.quantity ?? 0}`
          titleRow.appendChild(title)
          titleRow.appendChild(qty)

          const desc = document.createElement('p')
          desc.className = 'text-sm text-gray-600'
          desc.textContent = item ? item.attributes.description : ''
          left.appendChild(titleRow)
          left.appendChild(desc)

          const right = document.createElement('div')
          const usable = !!ui.attributes.usable
          if (usable) {
            const btn = document.createElement('button')
            btn.className = 'px-3 py-1.5 rounded-md bg-gray-100 text-gray-900 hover:bg-gray-200'
            btn.textContent = 'Use'
            btn.disabled = (ui.attributes.quantity ?? 0) <= 0
            if (btn.disabled) {
              btn.classList.add('opacity-50', 'cursor-not-allowed')
              btn.setAttribute('title', 'Not enough quantity')
              btn.setAttribute('aria-disabled', 'true')
            }
            btn.addEventListener('click', () => {
              btn.disabled = true
              btn.classList.add('opacity-50', 'cursor-not-allowed')
              const itemId = itemRel ? itemRel.id : ui.attributes.item_id
              fetch(`/api/v1/items/${itemId}/use`, { method: 'POST', headers: authHeaders(token) })
                .then(async r => {
                  const data = await r.json()
                  if (r.ok) {
                    toast(data.message || 'Item used.', 'success')
                  } else {
                    toast(data.error || 'Failed to use item.', 'error')
                  }
                })
                .finally(() => fetchInventory())
            })
            right.appendChild(btn)
          }

          card.appendChild(left)
          card.appendChild(right)
          inventoryDiv.appendChild(card)
        })
      })
  }

  fetchResources()
  fetchInventory()
}

// Initialize on Turbo visits and full loads
document.addEventListener('turbo:load', initInventory)
document.addEventListener('DOMContentLoaded', initInventory)
