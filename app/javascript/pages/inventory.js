import { getJwt, authHeaders, toast } from "pages/util"
import { getConsumer } from "pages/cable"

function initInventory() {
  const token = getJwt()
  const inventoryDiv = document.getElementById('inventory')
  if (!inventoryDiv) return

  const refresh = () => {
    Promise.all([
      fetch('/api/v1/user_resources', { headers: authHeaders(token) }).then(r => r.json()),
      fetch('/api/v1/items', { headers: authHeaders(token) }).then(r => r.json()),
      fetch('/api/v1/crafting', { headers: authHeaders(token) }).then(r => r.json())
    ]).then(([resJson, invJson, craftJson]) => {
      const resRows = resJson.data || []
      const userItems = invJson.data || []
      const invIncluded = invJson.included || []
      const itemsById = new Map(invIncluded.filter(i => i.type === 'item').map(i => [i.id, i]))
      const normalItemQty = new Map(userItems.filter(ui => ui.attributes.quality === 'normal').map(ui => [String(ui.attributes.item_id || (ui.relationships && ui.relationships.item && ui.relationships.item.data && ui.relationships.item.data.id)), ui.attributes.quantity || 0]))

      const recipes = craftJson.data || []
      const craftIncluded = craftJson.included || []
      craftIncluded.filter(i => i.type === 'item').forEach(i => itemsById.set(i.id, i))

      const recipeByItemId = new Map()
      recipes.forEach(r => {
        const itemId = String(r.attributes.item_id || (r.relationships && r.relationships.item && r.relationships.item.data && r.relationships.item.data.id))
        if (!itemId) return
        recipeByItemId.set(itemId, r)
      })

      const entries = []
      resRows.forEach(r => entries.push({ kind: 'resource', id: String(r.attributes.resource_id || r.id), name: r.attributes.name, qty: r.attributes.amount }))
      const ids = new Set()
      userItems.forEach(ui => { const id = String(ui.attributes.item_id || (ui.relationships && ui.relationships.item && ui.relationships.item.data && ui.relationships.item.data.id)); if (id) ids.add(id) })
      Array.from(recipeByItemId.keys()).forEach(id => ids.add(id))
      Array.from(ids).forEach(itemId => {
        const item = itemsById.get(itemId)
        const qty = normalItemQty.get(itemId) || 0
        entries.push({ kind: 'item', id: itemId, name: item ? item.attributes.name : `Item ${itemId}`, qty, usable: false, recipe: recipeByItemId.get(itemId) })
      })

      entries.sort((a,b) => (a.name || '').localeCompare(b.name || '') || a.kind.localeCompare(b.kind))

      inventoryDiv.innerHTML = ''
      inventoryDiv.className = 'space-y-3'
      if (entries.length === 0) {
        const empty = document.createElement('p')
        empty.className = 'text-sm text-gray-600'
        empty.textContent = 'No items or craftable recipes yet.'
        inventoryDiv.appendChild(empty)
        return
      }

      entries.forEach(entry => {
        const isItem = entry.kind === 'item'
        const itemId = entry.id
        const qtyVal = entry.qty || 0

        const card = document.createElement('div')
        card.className = 'rounded-md border border-gray-200 bg-white shadow-sm p-4 flex items-start justify-between gap-3'

        const left = document.createElement('div')
        const titleRow = document.createElement('div')
        titleRow.className = 'flex items-center gap-2'
        const title = document.createElement('h3')
        title.className = 'font-medium text-gray-900'
        title.textContent = entry.name
        const qty = document.createElement('span')
        qty.className = 'text-xs px-1.5 py-0.5 rounded bg-gray-100 text-gray-900 font-bold'
        qty.id = isItem ? `item-qty-${itemId}` : `resource-amount-${itemId}`
        qty.textContent = `x${qtyVal}`
        titleRow.appendChild(title)
        titleRow.appendChild(qty)

        const desc = document.createElement('p')
        desc.className = 'text-sm text-gray-600'
        desc.textContent = (isItem && itemsById.get(itemId)) ? itemsById.get(itemId).attributes.description : ''
        left.appendChild(titleRow)
        left.appendChild(desc)

        const right = document.createElement('div')
        right.className = 'flex items-center gap-2'

        if (isItem) {
          const ui = userItems.find(row => String(row.attributes.item_id || (row.relationships && row.relationships.item && row.relationships.item.data && row.relationships.item.data.id)) === itemId)
          const usable = ui ? !!ui.attributes.usable : false
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
            })
            right.appendChild(useBtn)
          }
        }

        const recipe = isItem ? recipeByItemId.get(itemId) : null
        if (recipe && !recipe.attributes.locked) {
          const canCraft = !!recipe.attributes.craftable_now
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
              .finally(() => {
                // Recompute craftability and rebuild list for correct button states
                refresh()
              })
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
          case 'user_resource_delta': {
            const changes = (data.data && data.data.changes) || []
            let patched = false
            changes.forEach(ch => {
              const el = document.getElementById(`resource-amount-${ch.resource_id}`)
              if (el) { el.textContent = ch.amount; patched = true }
            })
            // Always refresh to recompute craftability and button states
            scheduleRefresh()
            break
          }
          case 'user_item_delta': {
            const changes = (data.data && data.data.changes) || []
            let patched = false
            changes.forEach(ch => {
              const el = document.getElementById(`item-qty-${ch.item_id}`)
              if (el) { el.textContent = `x${ch.quantity}`; patched = true }
            })
            scheduleRefresh()
            break
          }
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
