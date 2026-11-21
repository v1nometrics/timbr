// SPDX-License-Identifier: MPL-2.0
(() => {
  let audioCtx = null;
  let gainNode = null;
  const hookedElements = new WeakSet();

  function ensureGraph() {
    if (!audioCtx) {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) return null;
      audioCtx = new Ctx();
      gainNode = audioCtx.createGain();
      gainNode.connect(audioCtx.destination);
    }
    if (audioCtx.state === "suspended") {
      audioCtx.resume().catch(() => {});
    }
    return gainNode;
  }

  function applyGain(volume, isMuted) {
    const effective = isMuted ? 0.0 : Math.min(Math.max(Number(volume) || 1.0, 0.0), 2.0);
    const mediaEls = document.querySelectorAll("audio, video");
    mediaEls.forEach((el) => {
      if (effective <= 1.0) {
        el.muted = Boolean(isMuted);
        el.volume = effective;
      } else {
        el.muted = false;
        el.volume = 1.0;
        const g = ensureGraph();
        if (g && !hookedElements.has(el)) {
          try {
            const src = audioCtx.createMediaElementSource(el);
            src.connect(g);
            hookedElements.add(el);
          } catch (_) {
            // Cross-origin media elements fall back cleanly to 1.0 native volume
          }
        }
        if (g) g.gain.value = effective;
      }
    });
  }

  chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
    if (msg && msg.type === "TIMBRE_APPLY_LOCAL_GAIN") {
      applyGain(msg.volume, msg.isMuted);
      sendResponse({ ok: true });
    }
  });
})();
