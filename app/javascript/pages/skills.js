import { getJwt, authHeaders } from "pages/util"

function initSkills() {
  const token = getJwt()
  const skillsDiv = document.getElementById('skills')
  if (!skillsDiv) return

  const fetchSkills = () => {
    fetch('/api/v1/skills', { headers: authHeaders(token) })
      .then(r => r.json())
      .then(data => {
        skillsDiv.innerHTML = ''
        data.data.forEach(skill => {
          const div = document.createElement('div')
          div.innerHTML = `<strong>${skill.attributes.name}</strong> (${skill.attributes.cost} SP): ${skill.attributes.description}`
          const btn = document.createElement('button')
          btn.className = 'ml-3 px-3 py-1 rounded bg-blue-600 text-white hover:bg-blue-700 text-sm'
          btn.innerText = 'Unlock'
          btn.addEventListener('click', () => {
            fetch('/api/v1/skills', { method: 'POST', headers: { 'Content-Type': 'application/json', ...authHeaders(token) }, body: JSON.stringify({ skill_id: skill.id }) })
              .then(r => r.json()).then(() => fetchSkills())
          })
          div.appendChild(btn)
          skillsDiv.appendChild(div)
        })
      })
  }

  fetchSkills()
}

// Initialize on Turbo visits and full loads
document.addEventListener('turbo:load', initSkills)
document.addEventListener('DOMContentLoaded', initSkills)
