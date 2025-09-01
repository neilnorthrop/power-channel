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
        skillsDiv.className = 'space-y-3'

        const skills = data.data || []
        if (skills.length === 0) {
          const empty = document.createElement('p')
          empty.className = 'text-sm text-gray-600'
          empty.textContent = 'No skills available.'
          skillsDiv.appendChild(empty)
          return
        }

        skills.forEach(skill => {
          const card = document.createElement('div')
          card.className = 'rounded-md border border-gray-200 bg-white shadow-sm p-4'

          const row = document.createElement('div')
          row.className = 'flex items-start justify-between gap-3'

          const left = document.createElement('div')
          left.className = 'space-y-1'

          const titleRow = document.createElement('div')
          titleRow.className = 'flex items-center gap-2'

          const title = document.createElement('h3')
          title.className = 'font-medium text-gray-900'
          title.textContent = skill.attributes.name

          const cost = document.createElement('span')
          cost.className = 'text-xs px-1.5 py-0.5 rounded bg-indigo-100 text-indigo-800'
          cost.textContent = `${skill.attributes.cost} SP`

          titleRow.appendChild(title)
          titleRow.appendChild(cost)

          const desc = document.createElement('p')
          desc.className = 'text-sm text-gray-600'
          desc.textContent = skill.attributes.description

          left.appendChild(titleRow)
          left.appendChild(desc)

          const right = document.createElement('div')
          right.className = 'flex items-center gap-2'

          const btn = document.createElement('button')
          btn.className = 'px-3 py-1.5 rounded-md bg-blue-600 text-white hover:bg-blue-700'
          btn.textContent = 'Unlock'
          btn.addEventListener('click', () => {
            btn.disabled = true
            btn.classList.add('opacity-50', 'cursor-not-allowed')
            fetch('/api/v1/skills', { method: 'POST', headers: { 'Content-Type': 'application/json', ...authHeaders(token) }, body: JSON.stringify({ skill_id: skill.id }) })
              .then(r => r.json())
              .finally(() => fetchSkills())
          })

          right.appendChild(btn)

          row.appendChild(left)
          row.appendChild(right)
          card.appendChild(row)
          skillsDiv.appendChild(card)
        })
      })
  }

  fetchSkills()
}

// Initialize on Turbo visits and full loads
document.addEventListener('turbo:load', initSkills)
document.addEventListener('DOMContentLoaded', initSkills)
