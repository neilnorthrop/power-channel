let scale = 1;
const map = document.getElementById('map');
let pos = { x: 0, y: 0 };
let isDragging = false;
let start = { x: 0, y: 0 };

function updateTransform() {
  map.style.transform = `translate(${pos.x}px, ${pos.y}px) scale(${scale})`;
}

document.getElementById('zoom-in').addEventListener('click', () => {
  scale = Math.min(scale + 0.1, 2);
  updateTransform();
});

document.getElementById('zoom-out').addEventListener('click', () => {
  scale = Math.max(scale - 0.1, 0.5);
  updateTransform();
});

map.addEventListener('mousedown', e => {
  isDragging = true;
  start = { x: e.clientX - pos.x, y: e.clientY - pos.y };
});

window.addEventListener('mousemove', e => {
  if (!isDragging) return;
  pos = { x: e.clientX - start.x, y: e.clientY - start.y };
  updateTransform();
});

window.addEventListener('mouseup', () => { isDragging = false; });

document.querySelectorAll('.fog').forEach(f => {
  f.addEventListener('click', () => f.remove());
});
