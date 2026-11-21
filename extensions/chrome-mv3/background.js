// SPDX-License-Identifier: MPL-2.0
const IPC_URL = "http://127.0.0.1:48192/v1/tab-audio";

async function postTabUpdate(payload) {
  const { timbreToken } = await chrome.storage.local.get(["timbreToken"]);
  if (!timbreToken) return { ok: false, reason: "missing_token" };
  try {
    const res = await fetch(IPC_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${timbreToken}`
      },
      body: JSON.stringify(payload)
    });
    return { ok: res.ok, status: res.status };
  } catch (err) {
    return { ok: false, reason: String(err) };
  }
}

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg && msg.type === "TIMBRE_SET_TAB_AUDIO") {
    const tabId = msg.tabId ?? sender.tab?.id ?? "active";
    const browserName = navigator.userAgent.includes("Safari") && !navigator.userAgent.includes("Chrome") ? "safari" : "chrome";
    postTabUpdate({
      browser: browserName,
      tabID: String(tabId),
      title: msg.title || sender.tab?.title || "Browser Tab",
      origin: msg.origin || (sender.tab?.url ? new URL(sender.tab.url).origin : "unknown"),
      volume: Number(msg.volume ?? 1.0),
      isMuted: Boolean(msg.isMuted)
    }).then(sendResponse);
    return true;
  }
});
