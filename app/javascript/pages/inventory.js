import { getJwt, authHeaders, toast } from "pages/util"
import { getConsumer } from "pages/cable"

function initInventory() {
  const token = getJwt()
  const resourcesDiv = document.getElementById('resources')
  const inventoryDiv = document.getElementById('inventory')
  if (!resourcesDiv || !inventoryDiv) return

  const refresh = () => {
    Promise.all([
      fetch('/api/v1/user_resources', { headers: authHeaders(token) }).then(r => r.json()),
      fetch('/api/v1/items', { headers: authHeaders(token) }).then(r => r.json()),
      fetch('/api/v1/crafting', { headers: authHeaders(token) }).then(r => r.json())
    ]).then(([resJson, invJson, craftJson]) => {
      // Render resources
      resourcesDiv.innerHTML = ''
      resourcesDiv.className = 'grid grid-cols-1 sm:grid-cols-2 gap-3'
      const resRows = resJson.data || []
      const resourceAmounts = new Map(resRows.map(r => [String(r.attributes.resource_id || r.id), r.attributes.amount]))
      if (resRows.length === 0) {
        const empty = document.createElement('p')
        empty.className = 'text-sm text-gray-600'
        empty.textContent = 'No resources yet.'
        resourcesDiv.appendChild(empty)
      } else {
        resRows.forEach(resource => {
          const card = document.createElement('div')
          card.className = 'rounded-md border border-gray-200 bg-white shadow-sm p-3 flex items-center justify-between'
          const name = document.createElement('span')
          name.className = 'font-medium text-gray-900'
          name.textContent = resource.attributes.name
          const amt = document.createElement('span')
          amt.className = 'text-sm text-gray-900 font-semibold'
          amt.textContent = resource.attributes.amount
          card.appendChild(name)
          card.appendChild(amt)
          resourcesDiv.appendChild(card)
        })
      }

      // Build inventory and recipes
      const userItems = invJson.data || []
      const invIncluded = invJson.included || []
      const itemsById = new Map(invIncluded.filter(i => i.type === 'item').map(i => [i.id, i]))
      const normalItemQty = new Map(userItems.filter(ui => ui.attributes.quality === 'normal').map(ui => [String(ui.attributes.item_id || (ui.relationships && ui.relationships.item && ui.relationships.item.data && ui.relationships.item.data.id)), ui.attributes.quantity || 0]))

      const recipes = craftJson.data || []
      const craftIncluded = craftJson.included || []
      craftIncluded.filter(i => i.type === 'item').forEach(i => itemsById.set(i.id, i))

      // Map recipes by item_id
      const recipeByItemId = new Map()
      recipes.forEach(r => {
        const itemId = String(r.attributes.item_id || (r.relationships && r.relationships.item && r.relationships.item.data && r.relationships.item.data.id))
        if (!itemId) return
        recipeByItemId.set(itemId, r)
      })

      // Unified item id list: inventory items + discovered recipe items
      const ids = new Set()
      userItems.forEach(ui => {
        const itemId = String(ui.attributes.item_id || (ui.relationships && ui.relationships.item && ui.relationships.item.data && ui.relationships.item.data.id))
        if (itemId) ids.add(itemId)
      })
      Array.from(recipeByItemId.keys()).forEach(id => ids.add(id))

      // Render unified inventory
      inventoryDiv.innerHTML = ''
      inventoryDiv.className = 'space-y-3'
      if (ids.size === 0) {
        const empty = document.createElement('p')
        empty.className = 'text-sm text-gray-600'
        empty.textContent = 'No items or craftable recipes yet.'
        inventoryDiv.appendChild(empty)
        return
      }

      const idList = Array.from(ids)
      idList.forEach(itemId => {
        const item = itemsById.get(itemId)
        const ui = userItems.find(row => String(row.attributes.item_id || (row.relationships && row.relationships.item && row.relationships.item.data && row.relationships.item.data.id)) === itemId)
        const qtyVal = ui ? (ui.attributes.quantity || 0) : 0
        const usable = ui ? !!ui.attributes.usable : false

        const card = document.createElement('div')
        card.className = 'rounded-md border border-gray-200 bg-white shadow-sm p-4 flex items-start justify-between gap-3'

        const left = document.createElement('div')
        const titleRow = document.createElement('div')
        titleRow.className = 'flex items-center gap-2'
        const title = document.createElement('h3')
        title.className = 'font-medium text-gray-900'
        title.textContent = item ? item.attributes.name : 'Unknown Item'
        const qty = document.createElement('span')
        qty.className = 'text-xs px-1.5 py-0.5 rounded bg-gray-100 text-gray-900 font-bold'
        qty.textContent = `x${qtyVal}`
        titleRow.appendChild(title)
        titleRow.appendChild(qty)

        const desc = document.createElement('p')
        desc.className = 'text-sm text-gray-600'
        desc.textContent = item ? item.attributes.description : ''
        left.appendChild(titleRow)
        left.appendChild(desc)

        const right = document.createElement('div')
        right.className = 'flex items-center gap-2'

        // Use button (green)
        if (usable) {
          const useBtn = document.createElement('button')
          useBtn.className = 'px-3 py-1.5 rounded-md bg-green-600 text-white hover:bg-green-700'
          useBtn.textContent = 'Use'
          useBtn.disabled = qtyVal <= 0
          if (useBtn.disabled) {
            useBtn.classList.add('opacity-50', 'cursor-not-allowed')
            useBtn.setAttribute('title', 'Not enough quantity')
            useBtn.setAttribute('aria-disabled', 'true')
          }
          useBtn.addEventListener('click', () => {
            useBtn.disabled = true
            useBtn.classList.add('opacity-50', 'cursor-not-allowed')
            fetch(`/api/v1/items/${itemId}/use`, { method: 'POST', headers: authHeaders(token) })
              .then(async r => {
                const data = await r.json()
                if (r.ok) {
                  toast(data.message || 'Item used.', 'item')
                } else {
                  toast(data.error || 'Failed to use item.', 'error')
                }
              })
              .finally(refresh)
          })
          right.appendChild(useBtn)
        }

        // Craft button (blue, disabled lighter when insufficient)
        const recipe = recipeByItemId.get(itemId)
        if (recipe && !recipe.attributes.locked) {
          // Determine craftable now by comparing requirements
          const includes = craftJson.included || []
          const rrs = includes.filter(x => x.type === 'recipe_resource' && String(x.attributes.recipe_id) === String(recipe.id))
          // Group by group_key; null/undefined means ungrouped AND
          const groups = new Map()
          rrs.forEach(rr => {
            const key = rr.attributes.group_key || null
            if (!groups.has(key)) groups.set(key, [])
            groups.get(key).push(rr)
          })
          const canCraft = Array.from(groups.entries()).every(([key, parts]) => {
            const hasOr = parts.some(rr => String(rr.attributes.logic || '').toUpperCase() === 'OR')
            const sufficient = rr => {
              const type = rr.attributes.component_type
              const compId = String(rr.attributes.component_id)
              const need = rr.attributes.quantity || 0
              if (type === 'Resource') {
                const have = Number(resourceAmounts.get(compId) || 0)
                return have >= need
              } else if (type === 'Item') {
                const have = Number(normalItemQty.get(compId) || 0)
                return have >= need
              } else {
                return false
              }
            }
            if (key === null) {
              return parts.every(sufficient)
            } else if (hasOr) {
              return parts.some(sufficient)
            } else {
              return parts.every(sufficient)
            }
          })

          const craftBtn = document.createElement('button')
          craftBtn.textContent = 'Craft'
          if (canCraft) {
            craftBtn.className = 'px-3 py-1.5 rounded-md bg-blue-600 text-white hover:bg-blue-700'
          } else {
            craftBtn.className = 'px-3 py-1.5 rounded-md bg-blue-300 text-white cursor-not-allowed'
            craftBtn.disabled = true
            craftBtn.setAttribute('title', 'Insufficient components')
            craftBtn.setAttribute('aria-disabled', 'true')
          }
          craftBtn.addEventListener('click', () => {
            if (craftBtn.disabled) return
            craftBtn.disabled = true
            craftBtn.classList.add('opacity-50', 'cursor-not-allowed')
            fetch('/api/v1/crafting', { method: 'POST', headers: { 'Content-Type': 'application/json', ...authHeaders(token) }, body: JSON.stringify({ recipe_id: recipe.id }) })
              .then(async r => {
                const data = await r.json()
                if (r.ok) {
                  toast(data.message || 'Item crafted.', 'craft')
                } else {
                  toast(data.error || 'Failed to craft item.', 'error')
                }
              })
              .finally(refresh)
          })
          right.appendChild(craftBtn)
        }

        card.appendChild(left)
        card.appendChild(right)
        inventoryDiv.appendChild(card)
      })
    })
  }

  // Debounced refresh to avoid flooding on multiple cable messages
  let refreshTimer = null
  const scheduleRefresh = (toastMsg = null) => {
    // Avoid generic toasts on background updates to reduce noise/dupes
    if (refreshTimer) return
    refreshTimer = setTimeout(() => { refreshTimer = null; refresh() }, 150)
  }

  // Initial load
  refresh()

  // Live updates via ActionCable
  if (token) {
    const cable = getConsumer(token)
    cable.subscriptions.create('UserUpdatesChannel', {
      received(data) {
        if (!data || !data.type) return
        switch (data.type) {
          case 'user_resource_update':
            scheduleRefresh()
            break
          case 'user_item_update':
            scheduleRefresh()
            break
          case 'user_skill_update':
          case 'user_building_update':
          case 'user_update':
            scheduleRefresh()
            break
          default:
            // ignore other message types here
            break
        }
      }
    })
  }
}

// Initialize on Turbo visits and full loads
document.addEventListener('turbo:load', initInventory)
document.addEventListener('DOMContentLoaded', initInventory)

document.addEventListener('turbo:frame-load', (event) => {
  if (event.target && event.target.id === 'main') {
    initInventory();
  }
})
