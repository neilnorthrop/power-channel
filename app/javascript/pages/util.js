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
  el.className = `rounded-md shadow px-3 py-2 text-sm ${type === 'error' ? 'bg-red-600 text-white' : type === 'success' ? 'bg-emerald-600 text-white' : 'bg-gray-900 text-white'}`
  el.textContent = message
  container.appendChild(el)
  setTimeout(() => {
    el.classList.add('opacity-0', 'transition-opacity', 'duration-300')
    setTimeout(() => el.remove(), 300)
  }, 2000)
}
