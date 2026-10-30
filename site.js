"use strict";

(() => {
  const strings = window.SKILL_MONITOR_SITE_STRINGS;
  const supported = ["ru", "en", "zh"];
  if (!strings || !supported.every((language) => strings[language])) return;

  const textNodes = Array.from(document.querySelectorAll("[data-text]"));
  const labelNodes = Array.from(document.querySelectorAll("[data-label]"));
  const buttons = Array.from(document.querySelectorAll("[data-language]"));
  const description = document.querySelector('meta[name="description"]');
  const getText = (locale, path) => path.split(".").reduce((value, key) => value?.[key], locale);

  function setLanguage(language) {
    if (!supported.includes(language)) return;
    const locale = strings[language];
    document.documentElement.lang = language === "zh" ? "zh-CN" : language;
    document.title = `${locale.brand} | ${locale.hero.eyebrow}`;
    description?.setAttribute("content", locale.metaDescription);
    for (const node of textNodes) {
      const value = getText(locale, node.dataset.text);
      if (typeof value === "string") node.textContent = value;
    }
    for (const node of labelNodes) {
      const value = getText(locale, node.dataset.label);
      if (typeof value === "string") node.setAttribute("aria-label", value);
    }
    for (const button of buttons) {
      const option = button.dataset.language;
      button.textContent = strings[option].languageName;
      button.setAttribute("aria-pressed", String(option === language));
    }
  }

  for (const button of buttons) {
    button.addEventListener("click", () => setLanguage(button.dataset.language));
  }

  const browserLanguage = (navigator.language || "en").toLowerCase().split("-")[0];
  setLanguage(supported.includes(browserLanguage) ? browserLanguage : "en");
})();
