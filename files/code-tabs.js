(function () {
  var STORAGE_KEY = "mics-guide-code-lang";
  var DEFAULT_LANG = "Stata";

  function preferredLang() {
    try {
      return localStorage.getItem(STORAGE_KEY) || DEFAULT_LANG;
    } catch (e) {
      return DEFAULT_LANG;
    }
  }

  function rememberLang(lang) {
    try {
      localStorage.setItem(STORAGE_KEY, lang);
    } catch (e) {
      /* ignore quota / private mode */
    }
  }

  function panelsOf(tabs) {
    return Array.prototype.filter.call(tabs.children, function (el) {
      return el.classList && el.classList.contains("code-panel");
    });
  }

  function applyLang(tabs, lang) {
    var panels = panelsOf(tabs);
    var chosen = lang;
    var langs = panels.map(function (p) {
      return p.getAttribute("data-lang");
    });
    if (langs.indexOf(chosen) === -1) {
      chosen = langs[0];
    }

    panels.forEach(function (panel) {
      var on = panel.getAttribute("data-lang") === chosen;
      panel.classList.toggle("is-active", on);
      panel.hidden = !on;
    });

    var buttons = tabs.querySelectorAll(".code-tab-bar [role='tab']");
    Array.prototype.forEach.call(buttons, function (btn) {
      var on = btn.getAttribute("data-lang") === chosen;
      btn.classList.toggle("is-active", on);
      btn.setAttribute("aria-selected", on ? "true" : "false");
      btn.tabIndex = on ? 0 : -1;
    });
  }

  function applyAll(lang) {
    var groups = document.querySelectorAll(".code-tabs");
    Array.prototype.forEach.call(groups, function (tabs) {
      applyLang(tabs, lang);
    });
  }

  function buildBar(tabs) {
    var existing = tabs.querySelector(".code-tab-bar");
    if (existing) existing.remove();

    var panels = panelsOf(tabs);
    if (panels.length < 2) return;

    var bar = document.createElement("div");
    bar.className = "code-tab-bar";
    bar.setAttribute("role", "tablist");
    bar.setAttribute("aria-label", "Code language");

    panels.forEach(function (panel, i) {
      var lang = panel.getAttribute("data-lang") || ("Code " + (i + 1));
      var id = "code-tab-" + lang.toLowerCase().replace(/\s+/g, "-") + "-" +
        String(Math.random()).slice(2, 8);
      panel.id = panel.id || id + "-panel";
      panel.setAttribute("role", "tabpanel");
      panel.setAttribute("aria-labelledby", id);

      var btn = document.createElement("button");
      btn.type = "button";
      btn.id = id;
      btn.className = "code-tab";
      btn.setAttribute("role", "tab");
      btn.setAttribute("data-lang", lang);
      btn.setAttribute("aria-controls", panel.id);
      btn.textContent = lang;
      btn.addEventListener("click", function () {
        rememberLang(lang);
        applyAll(lang);
      });
      bar.appendChild(btn);
    });

    bar.addEventListener("keydown", function (ev) {
      var buttons = bar.querySelectorAll("[role='tab']");
      var i = Array.prototype.indexOf.call(buttons, document.activeElement);
      if (i < 0) return;
      var next = i;
      if (ev.key === "ArrowRight" || ev.key === "ArrowDown") {
        next = (i + 1) % buttons.length;
      } else if (ev.key === "ArrowLeft" || ev.key === "ArrowUp") {
        next = (i - 1 + buttons.length) % buttons.length;
      } else if (ev.key === "Home") {
        next = 0;
      } else if (ev.key === "End") {
        next = buttons.length - 1;
      } else {
        return;
      }
      ev.preventDefault();
      buttons[next].focus();
      buttons[next].click();
    });

    tabs.insertBefore(bar, tabs.firstChild);
  }

  function initCodeTabs() {
    var groups = document.querySelectorAll(".code-tabs");
    Array.prototype.forEach.call(groups, function (tabs) {
      buildBar(tabs);
    });
    applyAll(preferredLang());
  }

  function bindGitbook() {
    try {
      if (window.gitbook && gitbook.events && gitbook.events.bind) {
        gitbook.events.bind("page.change", initCodeTabs);
        return;
      }
    } catch (e) {
      /* fall through */
    }
    if (typeof require === "function") {
      try {
        require(["gitbook"], function (gitbook) {
          gitbook.events.bind("page.change", initCodeTabs);
        });
      } catch (e) {
        /* preview pages without gitbook */
      }
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initCodeTabs);
  } else {
    initCodeTabs();
  }
  bindGitbook();
})();
