(function () {
  "use strict";
  const shield = window.IGShield;
  if (!shield) return;
  const mapRoute = /\/(instagram-map|direct\/map|location[_-]sharing)(\/|$)/i;
  const mapLabel = /^(instagram map|map|share location|location sharing|open map)$/i;
  shield.registerFilter("instagram-map", () => {
    if (mapRoute.test(location.pathname)) {
      location.replace("https://www.instagram.com/");
      return;
    }
    document.querySelectorAll("a[href], button, [role='button'], [role='dialog']").forEach((element) => {
      const href = element.getAttribute("href") || "";
      const label = element.getAttribute("aria-label") || shield.text(element);
      if (mapRoute.test(href) || mapLabel.test(label)) shield.hide(shield.rowFor(element), "instagram-map");
    });
  });
  shield.registerClickHandler((event) => {
    const control = event.target.closest && event.target.closest("a[href], button, [role='button']");
    return Boolean(control && (mapRoute.test(control.getAttribute("href") || "") ||
      mapLabel.test(control.getAttribute("aria-label") || shield.text(control))));
  });
})();
