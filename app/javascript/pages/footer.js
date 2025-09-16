import { getJwt } from "pages/util"

function adjustPaddingForFooter() {
  const main = document.getElementById('main-scroll')
  const footer = document.getElementById('event-log')
  if (!main || !footer) return
  const h = footer.offsetHeight || 0
  // Add a small visual gap
  main.style.paddingBottom = `${h + 16}px`
  const frame = document.getElementById('main')
  if (frame) {
    frame.style.paddingBottom = `${h + 16}px`
  }
  const page = document.getElementById('page-container')
  if (page) {
    page.style.paddingBottom = `${h + 16}px`
  }
  const sidebar = document.getElementById('sidebar')
  if (sidebar) {
    // Ensure sidebar content isn't hidden behind footer and can scroll independently
    sidebar.style.paddingBottom = `${h + 16}px`
  }
}

function initFooterPadding() {
  adjustPaddingForFooter()
  const footer = document.getElementById('event-log')
  if (!footer) return

  // React to footer size changes (responsive)
  if (window.ResizeObserver) {
    const ro = new ResizeObserver(() => adjustPaddingForFooter())
    ro.observe(footer)
  }
  window.addEventListener('resize', adjustPaddingForFooter)
}

document.addEventListener('turbo:load', initFooterPadding)
document.addEventListener('DOMContentLoaded', initFooterPadding)
document.addEventListener('turbo:frame-load', (event) => {
  if (event.target && event.target.id === 'main') {
    adjustPaddingForFooter()
  }
})
