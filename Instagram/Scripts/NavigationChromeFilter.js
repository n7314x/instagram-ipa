(function () {
  "use strict";
  const shield = window.IGShield;
  if (!shield || window.__IG_NAVIGATION_CHROME_FILTER__) return;
  window.__IG_NAVIGATION_CHROME_FILTER__ = true;

  const reported = new Set();
  const appOpenText = /^(open instagram|open the instagram app|open in instagram|view in instagram app)$/i;
  const labelSignals = new Map([
    ["home", "home"],
    ["search", "search"],
    ["explore", "explore"],
    ["reels", "reels"],
    ["messages", "messages"],
    ["profile", "profile"]
  ]);

  function reportOnce(code) {
    if (reported.has(code)) return;
    reported.add(code);
    shield.send("diagnostic", { code: code });
  }

  function normalizedLabel(control) {
    return shield.normalize([
      control.getAttribute("aria-label"),
      control.getAttribute("title"),
      shield.text(control)
    ].filter(Boolean).join(" "));
  }

  function routeSignal(control) {
    const href = control.getAttribute("href");
    if (!href) return null;
    try {
      const url = new URL(href, location.origin);
      if (!/(^|\.)instagram\.com$/i.test(url.hostname)) return null;
      const path = url.pathname.toLowerCase().replace(/\/{2,}/g, "/");
      if (path === "/") return "home";
      if (path === "/explore/search" || path.startsWith("/explore/search/")) return "search";
      if (path === "/explore" || path.startsWith("/explore/")) return "explore";
      if (path === "/reels" || path.startsWith("/reels/")) return "reels";
      if (path === "/direct/inbox" || path.startsWith("/direct/inbox/")) return "messages";

      const parts = path.split("/").filter(Boolean);
      const label = normalizedLabel(control);
      if (parts.length === 1 && /^[a-z0-9._]+$/i.test(parts[0]) &&
          (label.includes("profile") || control.querySelector("img[alt*='profile picture' i]"))) {
        return "profile";
      }
    } catch (_) {}
    return null;
  }

  function signalsFor(control) {
    const signals = new Set();
    const route = routeSignal(control);
    if (route) signals.add(route);
    const words = normalizedLabel(control).split(/[^a-z]+/).filter(Boolean);
    words.forEach((word) => {
      const signal = labelSignals.get(word);
      if (signal) signals.add(signal);
    });
    return signals;
  }

  function isBottomBarGeometry(element) {
    const viewportHeight = window.innerHeight;
    const viewportWidth = window.innerWidth;
    const rect = element.getBoundingClientRect();
    if (!viewportHeight || !viewportWidth || rect.width <= 0 || rect.height <= 0) return false;
    if (rect.width < viewportWidth * 0.45 || rect.height > Math.min(180, viewportHeight * 0.28)) return false;
    const bottomBand = Math.min(240, viewportHeight * 0.38);
    return rect.top >= viewportHeight - bottomBand && rect.top < viewportHeight &&
      rect.bottom >= viewportHeight - 120;
  }

  function hideWebNavigation() {
    const ancestorSignals = new Map();
    document.querySelectorAll("a[href], button, [role='button']").forEach((control) => {
      const signals = signalsFor(control);
      if (!signals.size) return;
      let ancestor = control.parentElement;
      for (; ancestor; ancestor = ancestor.parentElement) {
        if (ancestor === document.body || ancestor === document.documentElement) break;
        if (!ancestorSignals.has(ancestor)) ancestorSignals.set(ancestor, new Set());
        const aggregate = ancestorSignals.get(ancestor);
        signals.forEach((signal) => aggregate.add(signal));
      }
    });

    const matches = Array.from(ancestorSignals.entries())
      .filter(([element, signals]) => signals.size >= 3 && isBottomBarGeometry(element))
      .sort(([first], [second]) => {
        const a = first.getBoundingClientRect();
        const b = second.getBoundingClientRect();
        return (b.width * b.height) - (a.width * a.height);
      });

    if (!matches.length) return;
    const bar = matches[0][0];
    bar.dataset.igShieldWebNavigation = "true";
    shield.hide(bar, "native-navigation");
    reportOnce("web-navigation-hidden");
  }

  function isInstagramAppDeepLink(href) {
    const value = String(href || "").trim();
    if (/^instagram(?:-stories)?:\/\//i.test(value)) return true;
    if (/^intent:\/\//i.test(value) && /(?:instagram|com\.instagram\.android)/i.test(value)) return true;
    try {
      const url = new URL(value, location.origin);
      return /^(apps\.apple\.com|itunes\.apple\.com)$/i.test(url.hostname) &&
        /instagram/i.test(url.pathname + url.search);
    } catch (_) { return false; }
  }

  function isAppOpenControl(control) {
    if (!(control instanceof HTMLElement)) return false;
    if (isInstagramAppDeepLink(control.getAttribute("href"))) return true;
    return [
      control.getAttribute("aria-label"),
      control.getAttribute("title"),
      shield.text(control)
    ].some((value) => {
      const label = shield.normalize(value);
      return label.length <= 80 && appOpenText.test(label);
    });
  }

  function hideAppOpenCTAs() {
    document.querySelectorAll("a[href], button, [role='button']").forEach((control) => {
      if (!isAppOpenControl(control)) return;
      shield.hide(control, "app-open-cta");
      reportOnce("app-open-cta-hidden");
    });
  }

  shield.registerFilter("navigation-chrome", () => {
    hideWebNavigation();
    hideAppOpenCTAs();
  });

  shield.registerClickHandler((event) => {
    const control = event.target.closest && event.target.closest("a[href], button, [role='button']");
    if (!control || !isAppOpenControl(control)) return false;
    reportOnce("app-open-cta-blocked");
    return "silent";
  });
})();
