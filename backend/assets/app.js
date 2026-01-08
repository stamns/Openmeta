const form = document.getElementById('search-form');
const qInput = document.getElementById('q');
const output = document.getElementById('output');

function render(obj) {
  output.textContent = JSON.stringify(obj, null, 2);
}

async function runSearch(q) {
  if (!q) {
    render({ error: 'Missing query' });
    return;
  }

  render({ loading: true });

  try {
    const url = `/api/search?q=${encodeURIComponent(q)}`;
    const res = await fetch(url, { headers: { Accept: 'application/json' } });
    const data = await res.json();

    render({ status: res.status, data });
  } catch (err) {
    render({ error: String(err) });
  }
}

form.addEventListener('submit', (e) => {
  e.preventDefault();
  runSearch(qInput.value.trim());
});

// Auto-fill from URL ?q=
const params = new URLSearchParams(window.location.search);
if (params.get('q')) {
  qInput.value = params.get('q');
  runSearch(qInput.value.trim());
}
