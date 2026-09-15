(function () {
  "use strict";
  const shield = window.IGShield;
  if (!shield) return;
  const viewerRoute = /\/(viewers|story[_-]?viewers|seen[_-]?by)(\/|$)/i;
  const viewerText = /^(seen by|viewers?|\d+[,.]?\d* views?)$/i;
  shield.registerFilter("story-viewers", () => {
    if (location.pathname.split("/").filter(Boolean).length > 1 && viewerRoute.test(location.pathname)) {
      location.replace("https://www.instagram.com/");
      return;
    }
    if (!location.pathname.toLowerCase().startsWith("/stories/")) return;
    document.querySelectorAll("a[href], button, [role='button']").forEach((element) => {
      const href = element.getAttribute("href") || "";
      const label = element.getAttribute("aria-label") || "";
      if (viewerRoute.test(href) || viewerText.test(shield.text(element)) || /seen by|story viewers?/i.test(label)) {
        shield.hide(shield.rowFor(element), "story-viewers");
      }
    });
  });
  shield.registerClickHandler((event) => {
    if (!location.pathname.toLowerCase().startsWith("/stories/")) return false;
    const control = event.target.closest && event.target.closest("a[href], button, [role='button']");
    return Boolean(control && (viewerRoute.test(control.getAttribute("href") || "") ||
      viewerText.test(shield.text(control)) || /seen by/i.test(control.getAttribute("aria-label") || "")));
  });
})();
