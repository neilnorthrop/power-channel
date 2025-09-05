import { getJwt, authHeaders, toast } from "pages/util"

function initCrafting() {
  const token = getJwt()
  const craftingDiv = document.getElementById('crafting')
  if (!craftingDiv) return

  const fetchCrafting = () => {
    fetch('/api/v1/crafting', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        craftingDiv.innerHTML = ''
        craftingDiv.className = 'space-y-3'
        const recipes = data.data || []
        const items = (data.included || []).filter(inc => inc.type === 'item')
        if (recipes.length === 0) {
          const empty = document.createElement('p')
          empty.className = 'text-sm text-gray-600'
          empty.textContent = 'No craftable recipes available.'
          craftingDiv.appendChild(empty)
          return
        }
        recipes.forEach(recipe => {
          const item = items.find(i => i.id === recipe.relationships.item.data.id)
          const card = document.createElement('div')
          card.className = 'rounded-md border border-gray-200 bg-white shadow-sm p-4 flex items-start justify-between gap-3'

          const left = document.createElement('div')
          const title = document.createElement('h3')
          title.className = 'font-medium text-gray-900'
          title.textContent = item ? item.attributes.name : 'Unknown Item'
          const meta = document.createElement('p')
          meta.className = 'text-sm text-gray-600'
          meta.textContent = 'Crafting consumes required resources.'
          left.appendChild(title)
          left.appendChild(meta)

          const right = document.createElement('div')
          const btn = document.createElement('button')
          btn.className = 'px-3 py-1.5 rounded-md bg-green-600 text-white hover:bg-green-700'
          btn.textContent = 'Craft'
          btn.addEventListener('click', () => {
            btn.disabled = true
            btn.classList.add('opacity-50', 'cursor-not-allowed')
            fetch('/api/v1/crafting', { method: 'POST', headers: { 'Content-Type': 'application/json', ...authHeaders(token) }, body: JSON.stringify({ recipe_id: recipe.id }) })
              .then(async r => {
                const data = await r.json()
                if (r.ok) {
                  toast(data.message || 'Item crafted.', 'success')
                } else {
                  toast(data.error || 'Failed to craft item.', 'error')
                }
              })
              .finally(() => fetchCrafting())
          })
          right.appendChild(btn)

          card.appendChild(left)
          card.appendChild(right)
          craftingDiv.appendChild(card)
        })
      })
  }

  fetchCrafting()
}

// Initialize on Turbo visits and full loads
document.addEventListener('turbo:load', initCrafting)
document.addEventListener('DOMContentLoaded', initCrafting)

document.addEventListener('turbo:frame-load', (event) => {
  if (event.target && event.target.id === 'main') {
    initCrafting();
  }
})
