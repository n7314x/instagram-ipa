(function () {
  "use strict";
  if (window.IGShield) return;

  const filters = new Map();
  const clickHandlers = [];
  let scheduled = false;
  let lastSessionState = "";
  let lastProfileURL = "";
  const normalize = (value) => String(value || "").replace(/\s+/g, " ").trim().toLowerCase();
  const text = (node) => normalize(node && (node.innerText || node.textContent));
  const policy = () => window.__IG_NATIVE_POLICY__ || {
    allowedStoryUsernames: [], storyPostsRemaining: 0, notePostsRemaining: 0
  };

  function send(event, payload) {
    try {
      const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.instagramPolicy;
      if (handler) handler.postMessage(Object.assign({ event: event }, payload || {}));
    } catch (_) {}
  }

  function request(event, payload) {
    try {
      const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.instagramPolicy;
      if (!handler) return Promise.resolve(false);
      return Promise.resolve(handler.postMessage(Object.assign({ event: event }, payload || {})))
        .then((value) => value === true).catch(() => false);
    } catch (_) { return Promise.resolve(false); }
  }

  function hide(node, reason) {
    if (!(node instanceof HTMLElement)) return;
    node.dataset.igShieldHidden = reason || "policy";
    node.style.setProperty("display", "none", "important");
    node.setAttribute("aria-hidden", "true");
  }

  function disable(node, reason) {
    if (!(node instanceof HTMLElement)) return;
    node.dataset.igShieldDisabled = reason || "policy";
    node.setAttribute("aria-disabled", "true");
    node.style.setProperty("filter", "grayscale(1)", "important");
    node.style.setProperty("opacity", "0.48", "important");
  }

  function rowFor(node) {
    return node && (node.closest("article, li, [role='listitem']") || node.closest("div[role='button']") || node.parentElement);
  }

  function runFilters() {
    scheduled = false;
    for (const [name, filter] of filters) {
      try { filter(); } catch (error) { console.debug("IGShield filter failed", name, error); }
    }
    try { assessPage(); } catch (_) {}
  }

  function schedule() {
    if (scheduled) return;
    scheduled = true;
    window.setTimeout(runFilters, 140);
  }

  function registerFilter(name, filter) { filters.set(name, filter); schedule(); }
  function registerClickHandler(handler) { clickHandlers.push(handler); }

  function assessPage() {
    const path = location.pathname.toLowerCase();
    const hasPassword = Boolean(document.querySelector("input[type='password']"));
    const authSignal = Boolean(document.querySelector(
      "a[href^='/direct/inbox'], a[href*='/accounts/activity'], a[aria-label*='Profile' i]"
    ));
    let state = "unknown";
    if (hasPassword || path.startsWith("/accounts/login")) state = "loggedOut";
    else if (authSignal) state = "authenticated";
    if (state !== "unknown" && state !== lastSessionState) {
      lastSessionState = state;
      send("sessionState", { state: state });
    }

    const candidates = Array.from(document.querySelectorAll("a[href^='/']"));
    const profileLink = candidates.find((link) => {
      const href = link.getAttribute("href") || "";
      const parts = href.split("?")[0].split("/").filter(Boolean);
      const label = normalize(link.getAttribute("aria-label"));
      return parts.length === 1 && /^[a-z0-9._]+$/i.test(parts[0]) &&
        (label.includes("profile") || Boolean(link.querySelector("img[alt*='profile picture' i]")));
    });
    if (profileLink) {
      try {
        const profileURL = new URL(profileLink.href, location.origin).href;
        if (profileURL !== lastProfileURL) {
          lastProfileURL = profileURL;
          send("profileDiscovered", { url: profileURL });
        }
      } catch (_) {}
    }
  }

  function showBlockedNotice() {
    const existing = document.getElementById("ig-shield-notice");
    if (existing) existing.remove();
    const notice = document.createElement("div");
    notice.id = "ig-shield-notice";
    notice.setAttribute("role", "alert");
    notice.textContent = "This feature is unavailable in this app.";
    Object.assign(notice.style, {
      position: "fixed", top: "max(12px, env(safe-area-inset-top))", left: "50%",
      transform: "translateX(-50%)", zIndex: "2147483647", background: "#222",
      color: "white", padding: "10px 16px", borderRadius: "18px", font: "14px -apple-system",
      boxShadow: "0 4px 18px rgba(0,0,0,.25)"
    });
    document.documentElement.appendChild(notice);
    window.setTimeout(() => notice.remove(), 2200);
  }

  document.addEventListener("click", (event) => {
    for (const handler of clickHandlers) {
      try {
        const result = handler(event);
        if (result) {
          event.preventDefault();
          event.stopImmediatePropagation();
          if (result !== "silent") showBlockedNotice();
          return;
        }
      } catch (error) { console.debug("IGShield click handler failed", error); }
    }
  }, true);

  const originalPushState = history.pushState.bind(history);
  const originalReplaceState = history.replaceState.bind(history);
  history.pushState = function () { const result = originalPushState(...arguments); schedule(); return result; };
  history.replaceState = function () { const result = originalReplaceState(...arguments); schedule(); return result; };
  addEventListener("popstate", schedule);
  addEventListener("pageshow", schedule);
  const observe = () => {
    if (document.documentElement) {
      new MutationObserver(schedule).observe(document.documentElement, {
        childList: true,
        subtree: true,
        characterData: true,
        attributes: true,
        attributeFilter: ["href", "aria-label", "role", "title"]
      });
    }
    schedule();
  };
  if (document.documentElement) observe();
  else document.addEventListener("DOMContentLoaded", observe, { once: true });

  window.IGShield = Object.freeze({
    normalize, text, policy, send, request, hide, disable, rowFor,
    registerFilter, registerClickHandler, runFilters, assessPage, showBlockedNotice
  });
})();
