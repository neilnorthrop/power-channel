import { getJwt, authHeaders, toast } from "pages/util"
import { getConsumer } from "pages/cable"

function initBuildings() {
  const token = getJwt()
  const buildingsDiv = document.getElementById('buildings')
  if (!buildingsDiv) return

  const fetchBuildings = () => {
    fetch('/api/v1/buildings', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        buildingsDiv.innerHTML = ''
        buildingsDiv.className = 'space-y-3'

        const buildings = data.data || []
        if (buildings.length === 0) {
          const empty = document.createElement('p')
          empty.className = 'text-sm text-gray-600'
          empty.textContent = 'No buildings available.'
          buildingsDiv.appendChild(empty)
          return
        }

        buildings.forEach(building => {
          const card = document.createElement('div')
          card.className = 'rounded-md border border-gray-200 bg-white shadow-sm p-4 flex items-start justify-between gap-3'

          const left = document.createElement('div')
          const titleRow = document.createElement('div')
          titleRow.className = 'flex items-center gap-2'
          const title = document.createElement('h3')
          title.className = 'font-medium text-gray-900'
          title.textContent = building.attributes.name
          const lvl = document.createElement('span')
          lvl.className = 'text-xs px-1.5 py-0.5 rounded bg-gray-100 text-gray-700'
          lvl.textContent = `Lvl ${building.attributes.level || 1}`
          titleRow.appendChild(title)
          titleRow.appendChild(lvl)
          const desc = document.createElement('p')
          desc.className = 'text-sm text-gray-600'
          desc.textContent = building.attributes.description
          left.appendChild(titleRow)
          left.appendChild(desc)

          const right = document.createElement('div')
          const btn = document.createElement('button')
          btn.className = 'px-3 py-1.5 rounded-md bg-purple-600 text-white hover:bg-purple-700'
          btn.textContent = 'Upgrade'
          btn.addEventListener('click', () => {
            btn.disabled = true
            btn.classList.add('opacity-50', 'cursor-not-allowed')
            fetch(`/api/v1/buildings/${building.id}`, { method: 'PATCH', headers: { 'Content-Type': 'application/json', ...authHeaders(token) } })
              .then(async r => {
                const data = await r.json()
                if (r.ok) {
                  toast(data.message || 'Building upgraded.', 'building')
                } else {
                  toast(data.error || 'Failed to upgrade building.', 'error')
                }
              })
              .finally(() => fetchBuildings())
          })
          right.appendChild(btn)

          card.appendChild(left)
          card.appendChild(right)
          buildingsDiv.appendChild(card)
        })
      })
  }

  // Debounced refresh
  let refreshTimer = null
  const scheduleRefresh = (msg = null) => {
    if (msg) toast(msg, 'info')
    if (refreshTimer) return
    refreshTimer = setTimeout(() => { refreshTimer = null; fetchBuildings() }, 150)
  }

  fetchBuildings()

  // Live updates via ActionCable
  if (token) {
    const cable = getConsumer(token)
    cable.subscriptions.create('UserUpdatesChannel', {
      received(data) {
        if (!data || !data.type) return
        switch (data.type) {
          case 'user_building_update':
            scheduleRefresh('Buildings updated')
            break
          case 'user_resource_update':
          case 'user_item_update':
          case 'user_skill_update':
          case 'user_update':
          case 'user_resource_delta':
          case 'user_item_delta':
            scheduleRefresh()
            break
          default:
            break
        }
      }
    })
  }
}

// Initialize on Turbo visits and full loads
document.addEventListener('turbo:load', initBuildings)
document.addEventListener('DOMContentLoaded', initBuildings)

document.addEventListener('turbo:frame-load', (event) => {
  if (event.target && event.target.id === 'main') {
    initBuildings();
  }
})
