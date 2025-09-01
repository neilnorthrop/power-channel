import { getJwt, authHeaders } from "pages/util"

function initBuildings() {
  const token = getJwt()
  const buildingsDiv = document.getElementById('buildings')
  if (!buildingsDiv) return

  const fetchBuildings = () => {
    fetch('/api/v1/buildings', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        buildingsDiv.innerHTML = ''
        data.data.forEach(building => {
          const div = document.createElement('div')
          div.innerHTML = `<strong>${building.attributes.name}</strong> (Level ${building.attributes.level}): ${building.attributes.description}`
          const btn = document.createElement('button')
          btn.className = 'ml-3 px-3 py-1 rounded bg-purple-600 text-white hover:bg-purple-700 text-sm'
          btn.innerText = 'Upgrade'
          btn.addEventListener('click', () => {
            fetch(`/api/v1/buildings/${building.id}`, { method: 'PATCH', headers: { 'Content-Type': 'application/json', ...authHeaders(token) } })
              .then(r => r.json()).then(() => fetchBuildings())
          })
          div.appendChild(btn)
          buildingsDiv.appendChild(div)
        })
      })
  }

  fetchBuildings()
}

// Initialize on Turbo visits and full loads
document.addEventListener('turbo:load', initBuildings)
document.addEventListener('DOMContentLoaded', initBuildings)
