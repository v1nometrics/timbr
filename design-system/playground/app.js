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
  compact: `<span class="ear left">♪ Spot</span><span class="hardware-notch">179 pt</span><span class="ear right">|||||</span>`,
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

// ADR-0016 Achromatic + Semantic Swatches
const palette = [
  ["signal", "#F2F2F2"], ["positive", "#4CCC8E"], ["warning", "#E8B259"], ["negative", "#E86B75"]
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

// audiocn Whole-Segment Quantized LCD Meter
const SEG_COUNT = 32;
let clipCount = 0;
function renderLCDSegments(containerId, readoutId, db, peakDB) {
  const container = document.getElementById(containerId);
  const readout = document.getElementById(readoutId);
  if (!container || !readout) return;
  container.innerHTML = "";
  const norm = Math.pow(Math.max(0, Math.min(1, (db + 60) / 60)), 1 / 1.65);
  const lit = Math.round(norm * SEG_COUNT);
  const peakNorm = Math.pow(Math.max(0, Math.min(1, (peakDB + 60) / 60)), 1 / 1.65);
  const peakIdx = Math.min(SEG_COUNT - 1, Math.max(0, Math.round(peakNorm * SEG_COUNT) - 1));
  for (let i = 0; i < SEG_COUNT; i++) {
    const seg = document.createElement("div");
    let cls = "lcd-seg";
    if (i < lit) {
      if (i >= 30) cls += " lit-clip";
      else if (i >= 25) cls += " lit-warn";
      else cls += " lit-safe";
    } else if (i === peakIdx && peakDB > -59) {
      cls += " peak-hold";
    }
    seg.className = cls;
    container.appendChild(seg);
  }
  readout.textContent = `${db >= 0 ? "+" : ""}${db.toFixed(1)} dB`;
}

function updateClipBadge() {
  const btn = document.getElementById("clipResetBtn");
  const lbl = document.getElementById("clipLabel");
  if (!btn || !lbl) return;
  if (clipCount > 0) {
    btn.classList.add("latched");
    lbl.textContent = clipCount > 1 ? `CLIP ×${clipCount}` : "CLIP";
  } else {
    btn.classList.remove("latched");
    lbl.textContent = "CLIP";
  }
}

renderLCDSegments("lcdSegsL", "lcdReadoutL", -14.2, -9.5);
renderLCDSegments("lcdSegsR", "lcdReadoutR", -14.6, -9.8);

document.getElementById("simNormalBtn")?.addEventListener("click", (e) => {
  renderLCDSegments("lcdSegsL", "lcdReadoutL", -14.2, -9.5);
  renderLCDSegments("lcdSegsR", "lcdReadoutR", -14.6, -9.8);
});
document.getElementById("simHotBtn")?.addEventListener("click", () => {
  renderLCDSegments("lcdSegsL", "lcdReadoutL", -3.5, -1.2);
  renderLCDSegments("lcdSegsR", "lcdReadoutR", -3.8, -1.4);
});
document.getElementById("simClipBtn")?.addEventListener("click", () => {
  clipCount += 1;
  updateClipBadge();
  renderLCDSegments("lcdSegsL", "lcdReadoutL", 0.4, 0.4);
  renderLCDSegments("lcdSegsR", "lcdReadoutR", 0.2, 0.2);
});
document.getElementById("clipResetBtn")?.addEventListener("click", () => {
  clipCount = 0;
  updateClipBadge();
});

// Bipolar Knobs rotation (-135deg to +135deg for -6..+6 dB)
function setKnobAngle(ptrId, val) {
  const el = document.getElementById(ptrId);
  if (!el) return;
  const deg = (val / 6) * 135;
  el.style.transform = `rotate(${deg}deg)`;
}
setKnobAngle("knobPtrBass", 1.5);
setKnobAngle("knobPtrPresence", 0.0);
setKnobAngle("knobPtrAir", -1.0);

document.getElementById("muteToggleBtn")?.addEventListener("click", (e) => {
  e.currentTarget.classList.toggle("muted");
});
document.getElementById("soloToggleBtn")?.addEventListener("click", (e) => {
  e.currentTarget.classList.toggle("solo");
});
