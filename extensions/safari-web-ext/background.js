// SPDX-License-Identifier: MPL-2.0
const IPC_URL = "http://127.0.0.1:48192/v1/tab-audio";
const CMD_URL = "http://127.0.0.1:48192/v1/tab-commands";

async function applyReturnedCommands(commands) {
  if (!Array.isArray(commands)) return;
  for (const cmd of commands) {
    const numId = Number(cmd.tabID);
    if (!Number.isFinite(numId)) continue;
    try {
      await chrome.tabs.sendMessage(numId, {
        type: "TIMBRE_APPLY_LOCAL_GAIN",
        volume: Number(cmd.volume ?? 1.0),
        isMuted: Boolean(cmd.isMuted)
      });
    } catch (_) {
      // Tab may have closed
    }
  }
}

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
    if (res.ok) {
      const data = await res.json().catch(() => null);
      if (data?.commands) await applyReturnedCommands(data.commands);
    }
    return { ok: res.ok, status: res.status };
  } catch (err) {
    return { ok: false, reason: String(err) };
  }
}

async function pollCommandsFromApp() {
  const { timbreToken } = await chrome.storage.local.get(["timbreToken"]);
  if (!timbreToken) return;
  try {
    const res = await fetch(CMD_URL, {
      method: "GET",
      headers: { "Authorization": `Bearer ${timbreToken}` }
    });
    if (res.ok) {
      const data = await res.json().catch(() => null);
      if (data?.commands) await applyReturnedCommands(data.commands);
    }
  } catch (_) {
    // App offline
  }
}

setInterval(pollCommandsFromApp, 1500);

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
