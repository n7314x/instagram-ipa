(function () {
  "use strict";
  const shield = window.IGShield;
  if (!shield) return;
  const storyRoute = /\/(stories\/create|create\/story)(\/|$)/i;
  const noteRoute = /\/(notes\/create|create\/note)(\/|$)/i;
  const isStoryEntry = (control) => storyRoute.test(control.getAttribute("href") || "") ||
    /^(add to story|add to your story|create story|new story)$/i.test(control.getAttribute("aria-label") || shield.text(control));
  const isNoteEntry = (control) => noteRoute.test(control.getAttribute("href") || "") ||
    /^(leave a note|create note|new note)$/i.test(control.getAttribute("aria-label") || shield.text(control));
  const contextText = (control) => shield.text(control.closest("[role='dialog'], main, form") || document.body);
  const isFinalStory = (control) => /^(share to story|your story|share story)$/i.test(shield.text(control)) ||
    (shield.text(control) === "share" && /story|audience|close friends/i.test(contextText(control)) && !/note/i.test(contextText(control)));
  const isFinalNote = (control) => /^(share note|post note)$/i.test(shield.text(control)) ||
    (shield.text(control) === "share" && /note|leave a note/i.test(contextText(control)));
  const approvedControls = new WeakSet();

  function askNativeThenReplay(control, kind, policy) {
    shield.request(kind === "story" ? "storyPublishAttempt" : "notePublishAttempt").then((allowed) => {
      if (!allowed) {
        shield.showBlockedNotice();
        return;
      }
      const update = kind === "story"
        ? { storyPostsRemaining: Math.max(0, policy.storyPostsRemaining - 1) }
        : { notePostsRemaining: Math.max(0, policy.notePostsRemaining - 1) };
      window.__IG_NATIVE_POLICY__ = Object.freeze(Object.assign({}, shield.policy(), update));
      approvedControls.add(control);
      control.click();
      shield.runFilters();
    });
  }

  shield.registerFilter("creation-limits", () => {
    const policy = shield.policy();
    if ((policy.storyPostsRemaining <= 0 && storyRoute.test(location.pathname)) ||
        (policy.notePostsRemaining <= 0 && noteRoute.test(location.pathname))) {
      location.replace("https://www.instagram.com/");
      return;
    }
    document.querySelectorAll("a[href], button, [role='button']").forEach((control) => {
      if (policy.storyPostsRemaining <= 0 && isStoryEntry(control)) shield.hide(control, "story-quota");
      if (policy.notePostsRemaining <= 0 && isNoteEntry(control)) shield.hide(control, "note-quota");
    });
  });
  shield.registerClickHandler((event) => {
    const control = event.target.closest && event.target.closest("a[href], button, [role='button']");
    if (!control) return false;
    if (approvedControls.has(control)) {
      approvedControls.delete(control);
      return false;
    }
    const policy = shield.policy();
    if (isStoryEntry(control) && policy.storyPostsRemaining <= 0) return true;
    if (isNoteEntry(control) && policy.notePostsRemaining <= 0) return true;
    if (isFinalStory(control)) {
      if (policy.storyPostsRemaining <= 0) return true;
      askNativeThenReplay(control, "story", policy);
      return "silent";
    } else if (isFinalNote(control)) {
      if (policy.notePostsRemaining <= 0) return true;
      askNativeThenReplay(control, "note", policy);
      return "silent";
    }
    return false;
  });
})();
