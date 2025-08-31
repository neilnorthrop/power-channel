export function getJwt() {
  const meta = document.querySelector('meta[name="jwt-token"]')
  return meta ? meta.content : null
}

export function authHeaders(token) {
  return token ? { Authorization: `Bearer ${token}` } : {}
}

