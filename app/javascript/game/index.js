import { createConsumer } from "@rails/actioncable"

function getJwtToken() {
  const meta = document.querySelector('meta[name="jwt-token"]')
  return meta ? meta.content : null
}

function showToast(message, type = 'success') {
  const toastContainer = document.getElementById('toast-container')
  if (!toastContainer) return
  const toast = document.createElement('div')
  toast.className = `toast ${type}`
  toast.innerText = message
  toastContainer.appendChild(toast)
  setTimeout(() => toast.classList.add('show'), 100)
  setTimeout(() => {
    toast.classList.remove('show')
    setTimeout(() => toast.remove(), 300)
  }, 3000)
}

function authHeaders(token) {
  return { 'Authorization': `Bearer ${token}` }
}

function initGame() {
  const token = getJwtToken()
  if (!token) return

  const levelSpan = document.getElementById('level')
  const experienceSpan = document.getElementById('experience')
  const skillPointsSpan = document.getElementById('skill-points')
  const resourcesDiv = document.getElementById('resources')
  const actionsDiv = document.getElementById('actions')
  const skillsDiv = document.getElementById('skills')
  const inventoryDiv = document.getElementById('inventory')
  const craftingDiv = document.getElementById('crafting')
  const buildingsDiv = document.getElementById('buildings')

  const fetchUser = () => {
    fetch('/api/v1/user', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        levelSpan.innerText = data.data.attributes.level
        experienceSpan.innerText = data.data.attributes.experience
        skillPointsSpan.innerText = data.data.attributes.skill_points
      })
  }

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

  const updateCooldown = (userAction) => {
    const cooldownSpan = document.getElementById(`cooldown-${userAction.id}`)
    if (!cooldownSpan) return
    let attributes = userAction.attributes
    if (userAction.data && userAction.data.attributes) {
      attributes = userAction.data.attributes
    }
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

  const fetchSkills = () => {
    fetch('/api/v1/skills', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        skillsDiv.innerHTML = ''
        data.data.forEach(skill => {
          const div = document.createElement('div')
          div.innerHTML = `<strong>${skill.attributes.name}</strong> (${skill.attributes.cost} SP): ${skill.attributes.description}`
          const btn = document.createElement('button')
          btn.innerText = 'Unlock'
          btn.addEventListener('click', () => unlockSkill(skill.id))
          div.appendChild(btn)
          skillsDiv.appendChild(div)
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
          btn.innerText = 'Use'
          btn.addEventListener('click', () => useItem(item.id))
          div.appendChild(btn)
          inventoryDiv.appendChild(div)
        })
      })
  }

  const fetchCrafting = () => {
    fetch('/api/v1/crafting', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        craftingDiv.innerHTML = ''
        const items = data.included.filter(inc => inc.type === 'item')
        data.data.forEach(recipe => {
          const item = items.find(i => i.id === recipe.relationships.item.data.id)
          const div = document.createElement('div')
          div.innerHTML = `<strong>${item.attributes.name}</strong>: `
          const btn = document.createElement('button')
          btn.innerText = 'Craft'
          btn.addEventListener('click', () => craftItem(recipe.id))
          div.appendChild(btn)
          craftingDiv.appendChild(div)
        })
      })
  }

  const fetchBuildings = () => {
    fetch('/api/v1/buildings', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        buildingsDiv.innerHTML = ''
        data.data.forEach(building => {
          const div = document.createElement('div')
          div.innerHTML = `<strong>${building.attributes.name}</strong> (Level ${building.attributes.level}): ${building.attributes.description}`
          const btn = document.createElement('button')
          btn.innerText = 'Upgrade'
          btn.addEventListener('click', () => upgradeBuilding(building.id))
          div.appendChild(btn)
          buildingsDiv.appendChild(div)
        })
      })
  }

  const performAction = (actionId) => {
    fetch('/api/v1/actions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders(token) },
      body: JSON.stringify({ action_id: actionId })
    }).then(r => r.json()).then(data => {
      if (data.error) showToast(data.error, 'error')
      else { showToast(data.message); fetchResources(); fetchUser(); fetchActions() }
    })
  }

  const upgradeAction = (actionId) => {
    fetch(`/api/v1/actions/${actionId}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', ...authHeaders(token) }
    }).then(r => r.json()).then(data => {
      if (data.error) showToast(data.error, 'error')
      else showToast(data.message)
    })
  }

  const unlockSkill = (skillId) => {
    fetch('/api/v1/skills', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders(token) },
      body: JSON.stringify({ skill_id: skillId })
    }).then(r => r.json()).then(data => {
      if (data.error) showToast(data.error, 'error')
      else showToast(data.message)
    })
  }

  const useItem = (itemId) => {
    fetch(`/api/v1/items/${itemId}/use`, { method: 'POST', headers: authHeaders(token) })
      .then(r => r.json()).then(data => {
        if (data.error) showToast(data.error, 'error')
        else { showToast(data.message); fetchInventory() }
      })
  }

  const craftItem = (recipeId) => {
    fetch('/api/v1/crafting', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authHeaders(token) },
      body: JSON.stringify({ recipe_id: recipeId })
    }).then(r => r.json()).then(data => {
      if (data.error) showToast(data.error, 'error')
      else showToast(data.message)
    })
  }

  const upgradeBuilding = (buildingId) => {
    fetch(`/api/v1/buildings/${buildingId}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', ...authHeaders(token) }
    }).then(r => r.json()).then(data => {
      if (data.error) showToast(data.error, 'error')
      else showToast(data.message)
    })
  }

  // initial data fetches
  fetchUser(); fetchResources(); fetchActions(); fetchSkills(); fetchInventory(); fetchCrafting(); fetchBuildings()

  // Action Cable
  const cable = createConsumer(`/cable?token=${encodeURIComponent(token)}`)
  cable.subscriptions.create('UserUpdatesChannel', {
    connected() { /* noop */ },
    disconnected() { /* noop */ },
    received(data) {
      if (data.type === 'user_action_update') updateCooldown(data.data.data)
      else if (data.type === 'user_resource_update') fetchResources()
      else if (data.type === 'user_item_update') fetchInventory()
      else if (data.type === 'user_building_update') fetchBuildings()
      else if (data.type === 'user_skill_update') fetchSkills()
      else if (data.type === 'user_update') fetchUser()
    }
  })
}

document.addEventListener('DOMContentLoaded', initGame)

