(function () {
  "use strict";
  const shield = window.IGShield;
  if (!shield) return;
  const activityRoute = () => /\/(accounts\/activity|notifications)\/?/i.test(location.pathname);
  const isCommentReply = (value) => /\breplied to (your|a) comment\b/i.test(value) ||
    /\breplied to a comment (you wrote|you left|from you)\b/i.test(value);
  function notificationRow(node) {
    const semantic = node.closest("[role='listitem'], article");
    if (semantic) return semantic;
    let current = node.parentElement;
    let candidate = current;
    for (let depth = 0; current && depth < 7 && current.tagName !== "MAIN"; depth += 1) {
      const height = current.getBoundingClientRect().height;
      if (height >= 36 && height <= 200 && current.querySelector("a[href]")) candidate = current;
      current = current.parentElement;
    }
    return candidate;
  }
  shield.registerFilter("notifications", () => {
    if (!activityRoute()) return;
    const rows = new Set();
    document.querySelectorAll("main [role='listitem'], main article").forEach((row) => rows.add(row));
    document.querySelectorAll("main a[href*='/p/'], main a[href*='/reel/'], main time").forEach((node) => {
      const row = notificationRow(node);
      if (row) rows.add(row);
    });
    rows.forEach((row) => {
      if (!isCommentReply(shield.text(row))) shield.hide(row, "notification-policy");
    });
  });
})();
