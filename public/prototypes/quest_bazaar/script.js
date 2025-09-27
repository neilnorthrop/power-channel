const quests = document.getElementById('quests');
const detail = document.getElementById('quest-detail');
quests.addEventListener('click', e => {
  if (e.target.tagName === 'LI') {
    detail.textContent = e.target.dataset.detail;
  }
});

document.querySelectorAll('.item').forEach(item => {
  item.addEventListener('dragstart', e => {
    e.dataTransfer.setData('text/plain', e.target.textContent);
  });
});

const cart = document.getElementById('cart');
cart.addEventListener('dragover', e => {
  e.preventDefault();
  cart.classList.add('over');
});
cart.addEventListener('dragleave', () => cart.classList.remove('over'));
cart.addEventListener('drop', e => {
  e.preventDefault();
  const itemName = e.dataTransfer.getData('text/plain');
  cart.textContent = `Cart: ${itemName}`;
  cart.classList.remove('over');
  document.getElementById('advisor').classList.remove('hidden');
});
