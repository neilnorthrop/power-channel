const avatar = document.getElementById('avatar');
const seats = document.querySelectorAll('.seat');
seats.forEach(seat => {
  seat.addEventListener('click', () => {
    const index = seat.dataset.seat - 1;
    const seatWidth = seat.offsetWidth;
    avatar.style.left = `${seat.offsetLeft + seatWidth / 2 - 10}px`;
  });
});

const conv = document.getElementById('conversations');
let page = 0;
document.getElementById('next').addEventListener('click', () => {
  page = Math.min(page + 1, conv.children.length - 1);
  conv.style.transform = `translateX(-${page * 100}%)`;
});

document.getElementById('prev').addEventListener('click', () => {
  page = Math.max(page - 1, 0);
  conv.style.transform = `translateX(-${page * 100}%)`;
});

document.getElementById('summon').addEventListener('click', () => {
  document.getElementById('advisor').classList.toggle('hidden');
});
