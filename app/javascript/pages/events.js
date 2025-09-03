import { getJwt, authHeaders } from "pages/util"

function initEvents() {
  const token = getJwt()
  const eventsDiv = document.getElementById('events')
  if (!eventsDiv) return

  const render = (events) => {
    eventsDiv.innerHTML = ''
    eventsDiv.className = 'space-y-2'
    if (events.length === 0) {
      const empty = document.createElement('p')
      empty.className = 'text-sm text-gray-600'
      empty.textContent = 'No events yet.'
      eventsDiv.appendChild(empty)
      return
    }
    events.forEach(e => {
      const card = document.createElement('div')
      card.className = 'rounded-md border border-gray-200 bg-white shadow-sm p-3 flex items-start gap-3'
      const level = e.attributes.level
      const badge = document.createElement('span')
      const color = level === 'error' || level === 'critical' ? 'red' : level === 'warning' ? 'yellow' : level === 'debug' ? 'gray' : 'blue'
      badge.className = `text-xs px-1.5 py-0.5 rounded bg-${color}-100 text-${color}-800`
      badge.textContent = level.toUpperCase()
      const text = document.createElement('div')
      const ts = new Date(e.attributes.created_at)
      text.innerHTML = `<div class="text-sm text-gray-900">${e.attributes.message}</div><div class="text-xs text-gray-500">${ts.toLocaleString()}</div>`
      card.appendChild(badge)
      card.appendChild(text)
      eventsDiv.appendChild(card)
    })
  }

  fetch('/api/v1/events?limit=50', { headers: authHeaders(token) })
    .then(r => r.json())
    .then(data => render(data.data || []))
}

document.addEventListener('turbo:load', initEvents)
document.addEventListener('DOMContentLoaded', initEvents)

