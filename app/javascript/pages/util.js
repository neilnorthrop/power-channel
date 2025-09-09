export function getJwt() {
  const meta = document.querySelector('meta[name="jwt-token"]')
  return meta ? meta.content : null
}

export function authHeaders(token) {
  return token ? { Authorization: `Bearer ${token}` } : {}
}

// Global toast utility for all pages
export function toast(message, type = 'info') {
  const container = document.getElementById('toast-container')
  if (!container || !message) return
  const el = document.createElement('div')
  // Extended types for richer UX: action (blue), craft/item (green), skill (indigo), building (purple)
  let classes = 'bg-gray-900 text-white'
  if (type === 'error') classes = 'bg-red-600 text-white'
  else if (type === 'success') classes = 'bg-emerald-600 text-white'
  else if (type === 'action') classes = 'bg-blue-600 text-white'
  else if (type === 'craft' || type === 'item') classes = 'bg-green-600 text-white'
  else if (type === 'skill') classes = 'bg-indigo-600 text-white'
  else if (type === 'building') classes = 'bg-purple-600 text-white'
  el.className = `rounded-md shadow px-3 py-2 text-sm ${classes}`
  el.textContent = message
  container.appendChild(el)
  setTimeout(() => {
    el.classList.add('opacity-0', 'transition-opacity', 'duration-300')
    setTimeout(() => el.remove(), 300)
  }, 2000)
}
