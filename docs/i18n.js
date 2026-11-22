// Tiny translation helper: elements with data-i18n="key" get their text from
// the dictionary of the chosen language. The choice is remembered per visitor.
(function () {
  const languages = ["en", "es", "pt"];
  function pick() {
    try {
      const saved = localStorage.getItem("lang");
      if (languages.includes(saved)) return saved;
    } catch (e) {}
    const browser = (navigator.language || "en").slice(0, 2);
    return languages.includes(browser) ? browser : "en";
  }
  function apply(lang) {
    const strings = window.STRINGS[lang];
    document.documentElement.lang = lang === "pt" ? "pt-BR" : lang;
    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const value = strings[el.dataset.i18n];
      if (value !== undefined) el.innerHTML = value;
    });
    document.querySelectorAll("nav button").forEach((b) => {
      b.setAttribute("aria-pressed", String(b.dataset.lang === lang));
    });
    if (strings.title) document.title = strings.title;
  }
  document.addEventListener("DOMContentLoaded", () => {
    document.querySelectorAll("nav button").forEach((b) => {
      b.addEventListener("click", () => {
        try { localStorage.setItem("lang", b.dataset.lang); } catch (e) {}
        apply(b.dataset.lang);
      });
    });
    apply(pick());
  });
})();
