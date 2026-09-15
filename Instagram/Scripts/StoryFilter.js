(function () {
  "use strict";
  const shield = window.IGShield;
  if (!shield) return;
  function storyUsername(url) {
    try {
      const parts = new URL(url, location.origin).pathname.split("/").filter(Boolean);
      if (parts.length < 2 || parts[0].toLowerCase() !== "stories") return null;
      const username = parts[1].toLowerCase();
      if (["archive", "create", "highlights"].includes(username)) return null;
      return /^[a-z0-9._]+$/i.test(username) ? username : null;
    } catch (_) { return null; }
  }
  function removeStoryRing(element) {
    shield.disable(element, "disallowed-profile-story");
    let layer = element;
    for (let depth = 0; layer && depth < 3; depth += 1) {
      layer.style.setProperty("border-color", "transparent", "important");
      layer.style.setProperty("box-shadow", "none", "important");
      if (depth > 0) layer.style.setProperty("background-image", "none", "important");
      layer = layer.parentElement;
    }
  }
  shield.registerFilter("stories", () => {
    const allowed = new Set(shield.policy().allowedStoryUsernames.map((name) => name.toLowerCase()));
    const currentStoryUsername = storyUsername(location.href);
    if (currentStoryUsername && !allowed.has(currentStoryUsername)) {
      location.replace("https://www.instagram.com/");
      return;
    }
    document.querySelectorAll("a[href*='/stories/']").forEach((link) => {
      const username = storyUsername(link.href);
      if (username && !allowed.has(username)) {
        shield.hide(link.closest("li, [role='listitem']") || link, "story-allowlist");
      }
    });
    const currentUsername = location.pathname.split("/").filter(Boolean)[0];
    if (currentUsername && /^[a-z0-9._]+$/i.test(currentUsername) && !allowed.has(currentUsername.toLowerCase())) {
      document.querySelectorAll("[aria-label*='story' i], button").forEach((element) => {
        const label = shield.normalize(element.getAttribute("aria-label"));
        if (label.includes("view story") || label.includes("profile photo story")) {
          removeStoryRing(element);
        }
      });
    }
  });
  shield.registerClickHandler((event) => {
    const link = event.target.closest && event.target.closest("a[href*='/stories/']");
    if (!link) return false;
    const username = storyUsername(link.href);
    return Boolean(username && !new Set(shield.policy().allowedStoryUsernames.map((name) => name.toLowerCase())).has(username));
  });
})();
