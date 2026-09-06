const storageKey = "aiusage.windows.providers";
const providerList = document.querySelector("#providerList");
const dialog = document.querySelector("#providerDialog");
const form = document.querySelector("#providerForm");
let providers = loadProviders();

function loadProviders() {
  try {
    const value = JSON.parse(localStorage.getItem(storageKey) ?? "[]");
    return Array.isArray(value) ? value.filter((item) => item && typeof item.name === "string") : [];
  } catch {
    return [];
  }
}

function save() {
  localStorage.setItem(storageKey, JSON.stringify(providers));
}

function render() {
  const spend = providers.reduce((sum, provider) => sum + Number(provider.spend || 0), 0);
  const tokens = providers.reduce((sum, provider) => sum + Number(provider.tokens || 0), 0);
  document.querySelector("#providerCount").textContent = providers.length;
  document.querySelector("#monthlySpend").textContent = `$${spend.toFixed(2)}`;
  document.querySelector("#tokenCount").textContent = tokens.toLocaleString();
  providerList.replaceChildren();

  if (providers.length === 0) {
    const empty = document.createElement("p");
    empty.className = "empty";
    empty.textContent = "No providers yet. Add one or load the sample data.";
    providerList.append(empty);
    return;
  }

  providers.forEach((provider, index) => {
    const row = document.createElement("article");
    row.className = "provider-row";
    row.innerHTML = `<span class="provider-icon">${provider.name.slice(0, 2).toUpperCase()}</span><div class="provider-name"><strong></strong><small>Tracked locally</small></div><div class="provider-metric"><strong></strong><small>monthly</small></div><div class="provider-metric"><strong></strong><small>tokens</small></div><button class="icon-button" title="Remove provider" aria-label="Remove provider">×</button>`;
    row.querySelector(".provider-name strong").textContent = provider.name;
    row.querySelector(".provider-metric strong").textContent = `$${Number(provider.spend || 0).toFixed(2)}`;
    row.querySelectorAll(".provider-metric")[1].querySelector("strong").textContent = Number(provider.tokens || 0).toLocaleString();
    row.querySelector("button").addEventListener("click", () => {
      providers.splice(index, 1);
      save();
      render();
    });
    providerList.append(row);
  });
}

document.querySelector("#addButton").addEventListener("click", () => {
  form.reset();
  dialog.showModal();
});

form.addEventListener("submit", (event) => {
  event.preventDefault();
  const data = new FormData(form);
  providers.push({
    name: String(data.get("name")).trim(),
    spend: Number(data.get("spend") || 0),
    tokens: Number(data.get("tokens") || 0),
  });
  save();
  dialog.close();
  render();
});

document.querySelector("#sampleButton").addEventListener("click", () => {
  providers = [
    { name: "Claude", spend: 20, tokens: 184000 },
    { name: "Codex", spend: 10, tokens: 92000 },
    { name: "Copilot", spend: 10, tokens: 67000 },
  ];
  save();
  render();
});

document.querySelector("#clearButton").addEventListener("click", () => {
  providers = [];
  save();
  render();
});

document.querySelector("#exportButton").addEventListener("click", () => {
  const blob = new Blob([JSON.stringify({ version: 1, providers }, null, 2)], { type: "application/json" });
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = "aiusage-data.json";
  link.click();
  URL.revokeObjectURL(link.href);
});

document.querySelector("#importInput").addEventListener("change", async (event) => {
  const [file] = event.target.files;
  if (!file) return;
  const imported = JSON.parse(await file.text());
  if (!Array.isArray(imported.providers)) throw new Error("The selected file is not an AIUsage export.");
  providers = imported.providers;
  save();
  render();
  event.target.value = "";
});

render();
