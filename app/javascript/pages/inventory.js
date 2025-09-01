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
        data.data.forEach(resource => {
          const div = document.createElement('div')
          div.innerHTML = `<strong>${resource.attributes.name}:</strong> ${resource.attributes.amount}`
          resourcesDiv.appendChild(div)
        })
      })
  }

  const fetchInventory = () => {
    fetch('/api/v1/items', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        inventoryDiv.innerHTML = ''
        data.data.forEach(item => {
          const div = document.createElement('div')
          div.innerHTML = `<strong>${item.attributes.name}</strong>: ${item.attributes.description}`
          const btn = document.createElement('button')
          btn.className = 'ml-3 px-3 py-1 rounded bg-gray-100 hover:bg-gray-200 text-sm'
          btn.innerText = 'Use'
          btn.addEventListener('click', () => {
            fetch(`/api/v1/items/${item.id}/use`, { method: 'POST', headers: authHeaders(token) })
              .then(r => r.json()).then(() => fetchInventory())
          })
          div.appendChild(btn)
          inventoryDiv.appendChild(div)
        })
      })
  }

  fetchResources()
  fetchInventory()
}

// Initialize on Turbo visits and full loads
document.addEventListener('turbo:load', initInventory)
document.addEventListener('DOMContentLoaded', initInventory)
