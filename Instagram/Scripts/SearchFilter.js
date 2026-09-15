(function () {
  "use strict";
  const shield = window.IGShield;
  if (!shield) return;
  const onSearch = () => /^\/explore(\/search)?\/?$/i.test(location.pathname);
  const recommendationHeading = /^(explore|suggested|recommended|for you|popular)$/i;
  shield.registerFilter("search-not-explore", () => {
    if (!onSearch()) return;
    const searchInput = document.querySelector("input[type='search'], input[placeholder*='search' i]");
    if (searchInput && searchInput.value.trim()) return;
    document.querySelectorAll("h1, h2, h3, [role='heading']").forEach((heading) => {
      if (!recommendationHeading.test(shield.text(heading))) return;
      const section = heading.closest("section") || heading.parentElement;
      if (section && !section.querySelector("input[type='search'], input[placeholder*='search' i]")) {
        shield.hide(section, "explore-recommendations");
      }
    });
    document.querySelectorAll("[aria-label*='explore posts' i], [aria-label*='suggested posts' i]").forEach((grid) => {
      if (!grid.querySelector("input[type='search']")) shield.hide(grid, "explore-grid");
    });
  });
})();
