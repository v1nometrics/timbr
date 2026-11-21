// SPDX-License-Identifier: MPL-2.0
const tokenEl = document.getElementById("token");
const volEl = document.getElementById("vol");
const volLabel = document.getElementById("volLabel");
const muteBtn = document.getElementById("muteBtn");
const saveTokenBtn = document.getElementById("saveTokenBtn");
const statusEl = document.getElementById("status");
let isMuted = false;

chrome.storage.local.get(["timbreToken"]).then(({ timbreToken }) => {
  if (timbreToken) tokenEl.value = timbreToken;
});

saveTokenBtn.addEventListener("click", async () => {
  await chrome.storage.local.set({ timbreToken: tokenEl.value.trim() });
  statusEl.textContent = "Paired";
});

async function pushUpdate() {
  const volume = Number(volEl.value) / 100.0;
  volLabel.textContent = isMuted ? "MUTE" : `${volEl.value}%`;
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab) return;
  chrome.tabs.sendMessage(tab.id, { type: "TIMBRE_APPLY_LOCAL_GAIN", volume, isMuted }).catch(() => {});
  const res = await chrome.runtime.sendMessage({
    type: "TIMBRE_SET_TAB_AUDIO",
    tabId: tab.id,
    title: tab.title,
    origin: tab.url ? new URL(tab.url).origin : "unknown",
    volume,
    isMuted
  });
  statusEl.textContent = res?.ok ? "Synced" : (res?.reason || "Offline");
}

volEl.addEventListener("input", pushUpdate);
muteBtn.addEventListener("click", () => {
  isMuted = !isMuted;
  muteBtn.textContent = isMuted ? "Unmute Tab" : "Mute Tab";
  pushUpdate();
});
