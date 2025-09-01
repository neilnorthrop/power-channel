import { getJwt, authHeaders } from "pages/util"

function initCrafting() {
  const token = getJwt()
  const craftingDiv = document.getElementById('crafting')
  if (!craftingDiv) return

  const fetchCrafting = () => {
    fetch('/api/v1/crafting', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        craftingDiv.innerHTML = ''
        const items = data.included.filter(inc => inc.type === 'item')
        data.data.forEach(recipe => {
          const item = items.find(i => i.id === recipe.relationships.item.data.id)
          const div = document.createElement('div')
          div.innerHTML = `<strong>${item.attributes.name}</strong>`
          const btn = document.createElement('button')
          btn.className = 'ml-3 px-3 py-1 rounded bg-green-600 text-white hover:bg-green-700 text-sm'
          btn.innerText = 'Craft'
          btn.addEventListener('click', () => {
            fetch('/api/v1/crafting', { method: 'POST', headers: { 'Content-Type': 'application/json', ...authHeaders(token) }, body: JSON.stringify({ recipe_id: recipe.id }) })
              .then(r => r.json()).then(() => fetchCrafting())
          })
          div.appendChild(btn)
          craftingDiv.appendChild(div)
        })
      })
  }

  fetchCrafting()
}

// Initialize on Turbo visits and full loads
document.addEventListener('turbo:load', initCrafting)
document.addEventListener('DOMContentLoaded', initCrafting)
