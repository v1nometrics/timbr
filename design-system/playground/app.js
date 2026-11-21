const root = document.documentElement;
document.querySelectorAll("[data-surface-btn]").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll("[data-surface-btn]").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    root.dataset.surface = btn.dataset.surfaceBtn;
  });
});

const notch = document.getElementById("notchPreview");
const states = {
  resting: `<span class="hardware-notch">179 pt (Repouso)</span>`,
  compact: `<span class="ear left">♪ Spot</span><span class="hardware-notch">179 pt</span><span class="ear right">EQ</span>`,
  hud: `<span class="mono-val">Momentum 4</span><span class="mono-val">68%</span>`,
  peek: `<span class="mono-val">Spotify · 100%</span><span class="badge accent">EQ On</span>`,
  expanded: `<span class="mono-val">Mixer · Outputs · Guardian</span>`
};
document.querySelectorAll("[data-notch-state]").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll("[data-notch-state]").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    const st = btn.dataset.notchState;
    notch.className = `notch-box state-${st}`;
    notch.innerHTML = states[st];
  });
});

const palette = [
  ["accent", "#A78BFF"], ["positive", "#55D69F"], ["warning", "#F2BD68"], ["negative", "#F0738F"]
];
const swatchesEl = document.getElementById("swatches");
palette.forEach(([name, hex]) => {
  const el = document.createElement("div");
  el.className = "swatch";
  el.style.background = hex;
  el.style.color = "#0B0B0B";
  el.textContent = name;
  swatchesEl.appendChild(el);
});
