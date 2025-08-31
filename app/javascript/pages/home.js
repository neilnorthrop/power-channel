import { getJwt, authHeaders } from "pages/util"
import { createConsumer } from "@rails/actioncable"

document.addEventListener('DOMContentLoaded', () => {
  const token = getJwt()
  const levelSpan = document.getElementById('level')
  const experienceSpan = document.getElementById('experience')
  const skillPointsSpan = document.getElementById('skill-points')
  const actionsDiv = document.getElementById('actions')

  const fetchUser = () => {
    fetch('/api/v1/user', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        levelSpan.innerText = data.data.attributes.level
        experienceSpan.innerText = data.data.attributes.experience
        skillPointsSpan.innerText = data.data.attributes.skill_points
      })
  }

  const updateCooldown = (userAction) => {
    const cooldownSpan = document.getElementById(`cooldown-${userAction.id}`)
    if (!cooldownSpan) return
    let attributes = userAction.attributes
    if (userAction.data && userAction.data.attributes) attributes = userAction.data.attributes
    if (attributes.last_performed_at) {
      const lastPerformedAt = new Date(attributes.last_performed_at)
      const cooldown = attributes.cooldown
      const now = new Date()
      const diff = (now - lastPerformedAt) / 1000
      if (diff < cooldown) {
        const remaining = Math.ceil(cooldown - diff)
        cooldownSpan.innerText = ` (Cooldown: ${remaining}s)`
        setTimeout(() => updateCooldown(userAction), 1000)
      } else {
        cooldownSpan.innerText = ''
      }
    } else {
      cooldownSpan.innerText = ''
    }
  }

  const fetchActions = () => {
    fetch('/api/v1/actions', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        actionsDiv.innerHTML = ''
        const actions = data.included.filter(inc => inc.type === 'action')
        data.data.forEach(userAction => {
          const action = actions.find(a => a.id === userAction.relationships.action.data.id)
          const container = document.createElement('div')
          const actionButton = document.createElement('button')
          actionButton.innerText = action.attributes.name
          actionButton.addEventListener('click', () => performAction(action.id))
          container.appendChild(actionButton)
          const upgradeButton = document.createElement('button')
          upgradeButton.innerText = 'Upgrade'
          upgradeButton.addEventListener('click', () => upgradeAction(userAction.id))
          container.appendChild(upgradeButton)
          const cooldownSpan = document.createElement('span')
          cooldownSpan.id = `cooldown-${userAction.id}`
          cooldownSpan.className = 'cooldown-visual'
          container.appendChild(cooldownSpan)
          actionsDiv.appendChild(container)
          updateCooldown(userAction)
        })
      })
  }

  const performAction = (actionId) => {
    fetch('/api/v1/actions', { method: 'POST', headers: { 'Content-Type': 'application/json', ...authHeaders(token) }, body: JSON.stringify({ action_id: actionId }) })
      .then(r => r.json()).then(() => { fetchUser(); fetchActions() })
  }

  const upgradeAction = (userActionId) => {
    fetch(`/api/v1/actions/${userActionId}`, { method: 'PATCH', headers: { 'Content-Type': 'application/json', ...authHeaders(token) } })
      .then(r => r.json()).then(() => fetchActions())
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
})
