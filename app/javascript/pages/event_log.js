import { getJwt, authHeaders } from "pages/util"
import { getConsumer } from "pages/cable"

function initEventLog() {
  const list = document.getElementById('event-log-list')
  if (!list) return
  // Prevent double-initialization (DOMContentLoaded + turbo:load)
  if (list.dataset.initialized === '1') return
  list.dataset.initialized = '1'

  const token = getJwt()
  const limit = 50
  let sinceHours = 24
  let since = new Date(Date.now() - sinceHours * 60 * 60 * 1000)
  let level = 'info'
  let paused = false

  let oldestTs = null
  let loading = false

  const render = (events, { prepend = false } = {}) => {
    if (!events || events.length === 0) return
    const prevScrollHeight = list.scrollHeight
    const prevScrollTop = list.scrollTop
    events.forEach(e => {
      const row = document.createElement('div')
      const lvl = e.attributes.level
      const color = lvl === 'error' || lvl === 'critical' ? 'red' : lvl === 'warning' ? 'yellow' : lvl === 'debug' ? 'gray' : 'blue'
      row.className = 'text-sm flex items-start gap-2'
      const badge = document.createElement('span')
      badge.className = `shrink-0 text-[10px] leading-5 px-1.5 rounded bg-${color}-100 text-${color}-800`
      badge.textContent = lvl.toUpperCase()
      const msg = document.createElement('div')
      const ts = new Date(e.attributes.created_at)
      msg.innerHTML = `<span class=\"text-gray-900\">${e.attributes.message}</span> <span class=\"text-[10px] text-gray-500\">${ts.toLocaleTimeString()}</span>`
      row.appendChild(badge)
      row.appendChild(msg)
      if (prepend) list.prepend(row); else list.appendChild(row)
    })
    if (prepend) {
      const newScrollHeight = list.scrollHeight
      list.scrollTop = newScrollHeight - prevScrollHeight + prevScrollTop
    } else if (!paused) {
      list.scrollTop = list.scrollHeight
    }
  }

  const fetchEvents = ({ before = null, initial = false, replace = false } = {}) => {
    if (loading) return
    loading = true
    const params = new URLSearchParams()
    params.set('limit', String(limit))
    params.set('since', since.toISOString())
    if (level) params.set('level', level)
    if (before) params.set('before', before)
    fetch(`/api/v1/events?${params.toString()}`, { headers: authHeaders(token) })
      .then(r => { if (!r.ok) return { data: [] }; return r.json() })
      .then(data => {
        const events = data.data || []
        if (events.length > 0) {
          oldestTs = events[0].attributes.created_at
          if (replace) list.innerHTML = ''
          render(events, { prepend: !initial && !!before })
        }
      })
      .finally(() => { loading = false })
  }

  // initial load
  fetchEvents({ initial: true })

  // infinite scroll (load older when near top)
  list.addEventListener('scroll', () => {
    if (list.scrollTop <= 10 && oldestTs) {
      fetchEvents({ before: oldestTs })
    }
  })

  // live updates via ActionCable
  if (token) {
    const cable = getConsumer(token)
    cable.subscriptions.create('UserUpdatesChannel', {
      received(data) {
        if (data.type === 'event') {
          const ev = data.data && data.data.data
          if (ev) render([ev])
        }
      }
    })
  }

  // Controls
  const levelEl = document.getElementById('event-filter-level')
  const hoursEl = document.getElementById('event-filter-hours')
  const pauseEl = document.getElementById('event-pause')
  const clearEl = document.getElementById('event-clear')
  const applyEl = document.getElementById('event-apply')

  if (levelEl) levelEl.addEventListener('change', () => { level = levelEl.value || '' })
  if (hoursEl) hoursEl.addEventListener('change', () => {
    const v = parseInt(hoursEl.value, 10)
    if (!Number.isNaN(v) && v > 0 && v <= 168) { sinceHours = v; since = new Date(Date.now() - sinceHours * 60 * 60 * 1000) }
  })
  if (pauseEl) pauseEl.addEventListener('change', () => { paused = pauseEl.checked })
  if (clearEl) clearEl.addEventListener('click', () => { list.innerHTML = '' })
  if (applyEl) applyEl.addEventListener('click', () => { oldestTs = null; fetchEvents({ replace: true, initial: true }) })
}

document.addEventListener('turbo:load', initEventLog)
document.addEventListener('DOMContentLoaded', initEventLog)
