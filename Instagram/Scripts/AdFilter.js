(function () {
  "use strict";
  const shield = window.IGShield;
  if (!shield) return;
  const sponsored = /^(sponsored|paid partnership|advertisement)$/i;
  shield.registerFilter("advertisements", () => {
    document.querySelectorAll("article, [role='listitem']").forEach((unit) => {
      const marker = Array.from(unit.querySelectorAll("span, a, [aria-label]")).find((element) =>
        sponsored.test(shield.text(element)) || /^(sponsored|advertisement)$/i.test((element.getAttribute("aria-label") || "").trim())
      );
      if (marker) shield.hide(unit, "advertisement");
    });
  });
})();
