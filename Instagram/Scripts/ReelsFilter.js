(function () {
  "use strict";
  const shield = window.IGShield;
  if (!shield) return;
  const onReels = () => /^\/(reels?|reel)\//i.test(location.pathname);
  shield.registerFilter("reels-follow", () => {
    if (!onReels()) return;
    document.querySelectorAll("button, [role='button']").forEach((button) => {
      const label = shield.normalize(button.getAttribute("aria-label"));
      if (shield.text(button) === "follow" || label === "follow") shield.disable(button, "reels-follow");
    });
  });
  shield.registerClickHandler((event) => {
    if (!onReels()) return false;
    const button = event.target.closest && event.target.closest("button, [role='button']");
    return Boolean(button && (shield.text(button) === "follow" ||
      shield.normalize(button.getAttribute("aria-label")) === "follow"));
  });
})();
