import { getJwt, authHeaders } from "pages/util"
import { createConsumer } from "@rails/actioncable"

function initHome() {
  const token = getJwt()
  const levelSpan = document.getElementById('level')
  const experienceSpan = document.getElementById('experience')
  const skillPointsSpan = document.getElementById('skill-points')
  const actionsDiv = document.getElementById('actions')
  if (!levelSpan || !experienceSpan || !skillPointsSpan || !actionsDiv) return

  const fetchUser = () => {
    fetch('/api/v1/user', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        levelSpan.innerText = data.data.attributes.level
        experienceSpan.innerText = data.data.attributes.experience
        skillPointsSpan.innerText = data.data.attributes.skill_points
      })
  }

  // lightweight toast helper
  const toast = (message, type = 'info') => {
    const container = document.getElementById('toast-container')
    if (!container || !message) return
    const el = document.createElement('div')
    el.className = `rounded-md shadow px-3 py-2 text-sm ${type === 'error' ? 'bg-red-600 text-white' : type === 'success' ? 'bg-emerald-600 text-white' : 'bg-gray-900 text-white'}`
    el.textContent = message
    container.appendChild(el)
    setTimeout(() => {
      el.classList.add('opacity-0', 'transition-opacity', 'duration-300')
      setTimeout(() => el.remove(), 300)
    }, 2000)
  }

  const updateCooldown = (userAction) => {
    const id = userAction.id || (userAction.data && userAction.data.id)
    const badge = document.getElementById(`cooldown-badge-${id}`)
    const bar = document.getElementById(`cooldown-bar-${id}`)
    const performBtn = document.getElementById(`perform-${id}`)
    if (!badge || !bar || !performBtn) return

    let attributes = userAction.attributes
    if (userAction.data && userAction.data.attributes) attributes = userAction.data.attributes

    const cooldown = attributes.cooldown || 0
    if (attributes.last_performed_at && cooldown > 0) {
      const lastPerformedAt = new Date(attributes.last_performed_at)
      const now = new Date()
      const elapsed = (now - lastPerformedAt) / 1000
      if (elapsed < cooldown) {
        const remaining = Math.ceil(cooldown - elapsed)
        const pct = Math.max(0, Math.min(100, Math.round((remaining / cooldown) * 100)))
        badge.classList.remove('hidden')
        badge.textContent = `Cooldown: ${remaining}s`
        bar.style.width = `${100 - pct}%`
        performBtn.disabled = true
        performBtn.classList.add('opacity-50', 'cursor-not-allowed')
        setTimeout(() => updateCooldown(userAction), 1000)
        return
      }
    }
    // Cooldown complete
    badge.classList.add('hidden')
    bar.style.width = '100%'
    performBtn.disabled = false
    performBtn.classList.remove('opacity-50', 'cursor-not-allowed')
  }

  const fetchActions = () => {
    fetch('/api/v1/actions', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        actionsDiv.innerHTML = ''
        actionsDiv.className = 'space-y-3'

        const actions = (data.included || []).filter(inc => inc.type === 'action')
        const list = data.data || []
        if (list.length === 0) {
          const empty = document.createElement('div')
          empty.className = 'rounded-md border border-dashed border-gray-300 bg-white p-6 text-center text-sm text-gray-600'
          empty.textContent = 'No actions available yet.'
          actionsDiv.appendChild(empty)
          return
        }

        list.forEach(userAction => {
          const action = actions.find(a => a.id === userAction.relationships.action.data.id)

          const wrapper = document.createElement('div')
          wrapper.className = 'rounded-md border border-gray-200 bg-white shadow-sm p-4'

          const topRow = document.createElement('div')
          topRow.className = 'flex items-start justify-between gap-3'

          const left = document.createElement('div')
          left.className = 'space-y-1'

          const titleRow = document.createElement('div')
          titleRow.className = 'flex items-center gap-2'

          const title = document.createElement('h3')
          title.className = 'font-medium text-gray-900'
          title.textContent = action.attributes.name

          const levelBadge = document.createElement('span')
          levelBadge.className = 'text-xs px-1.5 py-0.5 rounded bg-gray-100 text-gray-700'
          levelBadge.textContent = `Lvl ${userAction.attributes.level || 1}`

          const cooldownBadge = document.createElement('span')
          cooldownBadge.id = `cooldown-badge-${userAction.id}`
          cooldownBadge.className = 'hidden text-xs px-1.5 py-0.5 rounded bg-yellow-100 text-yellow-800'

          titleRow.appendChild(title)
          titleRow.appendChild(levelBadge)
          titleRow.appendChild(cooldownBadge)

          const desc = document.createElement('p')
          desc.className = 'text-sm text-gray-600'
          desc.textContent = action.attributes.description

          left.appendChild(titleRow)
          left.appendChild(desc)

          const right = document.createElement('div')
          right.className = 'flex items-center gap-2'

          const actionButton = document.createElement('button')
          actionButton.id = `perform-${userAction.id}`
          actionButton.className = 'px-3 py-1.5 rounded-md bg-blue-600 text-white hover:bg-blue-700 disabled:hover:bg-blue-600'
          actionButton.textContent = 'Perform'
          actionButton.addEventListener('click', () => performAction(action.id))

          const upgradeButton = document.createElement('button')
          upgradeButton.className = 'px-3 py-1.5 rounded-md bg-gray-100 text-gray-900 hover:bg-gray-200'
          upgradeButton.textContent = 'Upgrade'
          upgradeButton.addEventListener('click', () => upgradeAction(userAction.id))

          right.appendChild(actionButton)
          right.appendChild(upgradeButton)

          topRow.appendChild(left)
          topRow.appendChild(right)

          const barWrap = document.createElement('div')
          barWrap.className = 'h-1 bg-gray-200 rounded overflow-hidden mt-3'
          const bar = document.createElement('div')
          bar.id = `cooldown-bar-${userAction.id}`
          bar.className = 'h-full bg-yellow-400 w-full transition-all duration-200'
          bar.style.width = '100%'
          barWrap.appendChild(bar)

          wrapper.appendChild(topRow)
          wrapper.appendChild(barWrap)
          actionsDiv.appendChild(wrapper)

          updateCooldown(userAction)
        })
      })
  }

  const performAction = (actionId) => {
    fetch('/api/v1/actions', { method: 'POST', headers: { 'Content-Type': 'application/json', ...authHeaders(token) }, body: JSON.stringify({ action_id: actionId }) })
      .then(async r => {
        const data = await r.json()
        if (r.ok) {
          toast(data.message || 'Action performed.', 'success')
        } else {
          toast(data.error || 'Failed to perform action.', 'error')
        }
      })
      .finally(() => { fetchUser(); fetchActions() })
  }

  const upgradeAction = (userActionId) => {
    fetch(`/api/v1/actions/${userActionId}`, { method: 'PATCH', headers: { 'Content-Type': 'application/json', ...authHeaders(token) } })
      .then(async r => {
        const data = await r.json()
        if (r.ok) {
          toast(data.message || 'Action upgraded.', 'success')
        } else {
          toast(data.error || 'Failed to upgrade action.', 'error')
        }
      })
      .finally(() => fetchActions())
  }

  fetchUser()
  fetchActions()

  // Action Cable realtime updates
  if (token) {
    const cable = createConsumer(`/cable?token=${encodeURIComponent(token)}`)
    cable.subscriptions.create('UserUpdatesChannel', {
      received(data) {
        if (data.type === 'user_action_update') {
          // Update only the affected cooldown and reload actions if needed
          updateCooldown(data.data.data)
        } else if (data.type === 'user_update') {
          fetchUser()
        } else if (data.type === 'user_resource_update' || data.type === 'user_item_update' || data.type === 'user_building_update' || data.type === 'user_skill_update') {
          // Conservative refresh of actions; adjust if more granular signals are added
          fetchActions()
        }
      }
    })
  }
}

// Initialize on Turbo visits and full loads
document.addEventListener('turbo:load', initHome)
document.addEventListener('DOMContentLoaded', initHome)
