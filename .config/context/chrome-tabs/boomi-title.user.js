// ==UserScript==
// @name         Boomi tab titles
// @namespace    context-based-mac
// @version      1.0
// @description  Put the page first in a Boomi platform tab's title: "Account - Page - Boomi Enterprise Platform" becomes "Page — Account".
// @match        https://platform.boomi.com/*
// @match        https://*.platform.boomi.com/*
// @run-at       document-start
// @grant        none
// ==/UserScript==

// The tab strip is narrow and every Boomi title starts with the account, so the page
// name was cut off. The em dash is deliberate: the chrome-tabs panel's producer
// (tab_label.py) reads "<page> — <account>" and splits at the last em dash.
(function () {
  const PRODUCT = "Boomi Enterprise Platform";
  const DASH = / [-–—] /g;

  // The new title, or null when this title is not the Boomi shape (fewer than three
  // parts, an empty part, or not ending in the product): such a title is left alone,
  // and so is one already rewritten, which keeps the observer from looping.
  function rewrite(title) {
    const parts = title.split(DASH);
    if (parts.length < 3 || parts.some((p) => !p.trim())) return null;
    if (parts[parts.length - 1].trim() !== PRODUCT) return null;
    const dashes = [...title.matchAll(DASH)];
    const page = title.slice(dashes[0].index + dashes[0][0].length, dashes[dashes.length - 1].index).trim();
    return page + " — " + parts[0].trim();
  }

  if (typeof module !== "undefined") module.exports = { rewrite };
  if (typeof document === "undefined") return;

  function apply() {
    const next = rewrite(document.title);
    if (next && next !== document.title) document.title = next;
  }

  // Boomi's page is a single-page app: it sets the title again on every navigation,
  // sometimes by replacing the <title> element, so watch the whole <head>.
  function start() {
    apply();
    new MutationObserver(apply).observe(document.head || document.documentElement, {
      childList: true, subtree: true, characterData: true,
    });
  }
  if (document.head) start();
  else new MutationObserver((_, obs) => { if (document.head) { obs.disconnect(); start(); } })
    .observe(document.documentElement, { childList: true });
})();
