import { getJwt, authHeaders } from "pages/util"

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
        const items = data.data || []
        if (items.length === 0) {
          const empty = document.createElement('p')
          empty.className = 'text-sm text-gray-600'
          empty.textContent = 'No items in your inventory.'
          inventoryDiv.appendChild(empty)
          return
        }
        items.forEach(item => {
          const card = document.createElement('div')
          card.className = 'rounded-md border border-gray-200 bg-white shadow-sm p-4 flex items-start justify-between gap-3'

          const left = document.createElement('div')
          const title = document.createElement('h3')
          title.className = 'font-medium text-gray-900'
          title.textContent = item.attributes.name
          const desc = document.createElement('p')
          desc.className = 'text-sm text-gray-600'
          desc.textContent = item.attributes.description
          left.appendChild(title)
          left.appendChild(desc)

          const right = document.createElement('div')
          const btn = document.createElement('button')
          btn.className = 'px-3 py-1.5 rounded-md bg-gray-100 text-gray-900 hover:bg-gray-200'
          btn.textContent = 'Use'
          btn.addEventListener('click', () => {
            btn.disabled = true
            btn.classList.add('opacity-50', 'cursor-not-allowed')
            fetch(`/api/v1/items/${item.id}/use`, { method: 'POST', headers: authHeaders(token) })
              .then(r => r.json())
              .finally(() => fetchInventory())
          })
          right.appendChild(btn)

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
