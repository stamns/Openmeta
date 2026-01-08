const form = document.getElementById('searchForm');
const output = document.getElementById('output');
const qInput = document.getElementById('q');

function setOutput(obj) {
  output.textContent = JSON.stringify(obj, null, 2);
}

form.addEventListener('submit', async (e) => {
  e.preventDefault();
  const q = qInput.value.trim();
  if (!q) {
    setOutput({ error: '请输入关键词' });
    return;
  }

  setOutput({ loading: true });

  try {
    const res = await fetch(`/api/search?q=${encodeURIComponent(q)}`);
    const data = await res.json();
    setOutput(data);
  } catch (err) {
    setOutput({ error: String(err) });
  }
});
