/**
 * FORM 19 — Interactive Controller (i18n, Morse Desk, Forms, Night/Day Polarity, Gallery Lightbox)
 */
(function (global, doc) {
  "use strict";

  const cfg = global.FORM19_CONFIG || { defaultLang: "en", buildStatus: {}, links: {} };
  const dict = global.FORM19_I18N || {};
  let currentLang = cfg.defaultLang || "en";
  let isSignalPlaying = false;
  let isTapeCompared = false;
  let isCopyAmended = false;
  let wire = null;

  function t(key) {
    const langSet = dict[currentLang] || dict.en || {};
    return langSet[key] !== undefined ? langSet[key] : (dict.en && dict.en[key]) || key;
  }

  function resolveInitialLang() {
    const params = new URLSearchParams(global.location.search);
    const qLang = params.get("lang");
    if (qLang === "ru" || qLang === "en") return qLang;
    try {
      const saved = global.localStorage.getItem("form19_lang");
      if (saved === "ru" || saved === "en") return saved;
    } catch (_e) {}
    return cfg.defaultLang === "ru" ? "ru" : "en";
  }

  function applyLanguage(lang) {
    currentLang = lang === "ru" ? "ru" : "en";
    doc.documentElement.lang = currentLang;
    try {
      global.localStorage.setItem("form19_lang", currentLang);
    } catch (_e) {}

    doc.title = t("metaTitle");
    const descMeta = doc.querySelector('meta[name="description"]');
    if (descMeta) descMeta.setAttribute("content", t("metaDesc"));

    doc.querySelectorAll("[data-i18n]").forEach((el) => {
      const key = el.getAttribute("data-i18n");
      el.textContent = t(key);
    });

    doc.querySelectorAll("[data-i18n-html]").forEach((el) => {
      const key = el.getAttribute("data-i18n-html");
      el.innerHTML = t(key);
    });

    doc.querySelectorAll(".locale-pill").forEach((btn) => {
      const active = btn.getAttribute("data-lang") === currentLang;
      btn.classList.toggle("is-active", active);
      btn.setAttribute("aria-pressed", String(active));
    });

    const statusEl = doc.getElementById("dossier-status-val");
    if (statusEl) {
      statusEl.textContent = (cfg.buildStatus && cfg.buildStatus[currentLang]) || "";
    }

    renderDynamicLinks();
    updateInteractiveLabels();
    if (lightboxState.open) updateLightboxText();
  }

  function updateInteractiveLabels() {
    const btnPlay = doc.getElementById("btn-play-signal");
    if (btnPlay) {
      btnPlay.textContent = isSignalPlaying ? t("btnStopSignal") : t("btnPlaySignal");
      btnPlay.setAttribute("aria-pressed", String(isSignalPlaying));
    }

    const btnCompare = doc.getElementById("btn-compare-tape");
    if (btnCompare) {
      btnCompare.textContent = isTapeCompared ? t("btnHideTape") : t("btnCompareTape");
      btnCompare.setAttribute("aria-pressed", String(isTapeCompared));
    }

    const btnAmend = doc.getElementById("btn-amend-copy");
    if (btnAmend) {
      btnAmend.textContent = isCopyAmended ? t("btnAmendRevert") : t("btnAmendToggle");
      btnAmend.setAttribute("aria-pressed", String(isCopyAmended));
    }

    const replyEl = doc.getElementById("sheet-reply");
    if (replyEl) {
      replyEl.textContent = isCopyAmended ? t("replyAmended") : t("replyWatched");
    }

    const tapeVerdict = doc.getElementById("tape-verdict");
    if (tapeVerdict) {
      tapeVerdict.textContent = isTapeCompared ? t("tapeHintRevealed") : t("tapeHintIdle");
      tapeVerdict.classList.toggle("is-revealed", isTapeCompared);
    }

    const deskStatusText = doc.getElementById("desk-status-text");
    if (deskStatusText) {
      if (isSignalPlaying) deskStatusText.textContent = t("deskStatusLive");
      else if (isTapeCompared) deskStatusText.textContent = t("deskStatusChecked");
      else deskStatusText.textContent = t("deskStatusIdle");
    }

    const audioBtn = doc.getElementById("btn-audio-toggle");
    if (audioBtn && wire) {
      const enabled = !wire.sound.muted;
      audioBtn.textContent = enabled ? t("soundOn") : t("soundMuted");
      audioBtn.setAttribute("aria-pressed", String(enabled));
    }

    const selectedForm = doc.querySelector(".train-form.is-selected");
    const formsText = doc.getElementById("forms-inspector-text");
    if (formsText && selectedForm) {
      const formType = selectedForm.getAttribute("data-form");
      formsText.innerHTML = formType === "31" ? t("formsInspect31") : t("formsInspect19");
    }
  }

  function renderDynamicLinks() {
    const container = doc.getElementById("dispatch-links");
    if (!container) return;
    const links = cfg.links || {};
    const htmlParts = [];

    if (links.steam) {
      htmlParts.push(`<a class="btn btn-primary" href="${links.steam}" target="_blank" rel="noopener">${t("btnSteamLive")}</a>`);
    } else {
      htmlParts.push(`<span class="btn btn-status-note">${t("steamSoon")}</span>`);
    }

    if (links.itch) {
      htmlParts.push(`<a class="btn btn-brass" href="${links.itch}" target="_blank" rel="noopener">${t("btnItchLive")}</a>`);
    } else if (links.demoDownload) {
      htmlParts.push(`<a class="btn btn-brass" href="${links.demoDownload}" target="_blank" rel="noopener">${t("btnDemoLive")}</a>`);
    } else {
      htmlParts.push(`<span class="btn btn-status-note">${t("itchSoon")}</span>`);
    }

    if (links.discord) {
      htmlParts.push(`<a class="btn" href="${links.discord}" target="_blank" rel="noopener">${t("btnDiscordLive")}</a>`);
    }
    if (links.telegram) {
      htmlParts.push(`<a class="btn" href="${links.telegram}" target="_blank" rel="noopener">${t("btnTelegramLive")}</a>`);
    }
    if (links.pressEmail) {
      htmlParts.push(`<a class="btn" href="${links.pressEmail}">${t("btnPressLive")}</a>`);
    }

    htmlParts.push(`<a class="btn" href="#wire">${t("openWireAgain")}</a>`);
    container.innerHTML = htmlParts.join("");
  }

  function initWireConsole() {
    const tapeCanvas = doc.getElementById("tape-canvas");
    const practiceCanvas = doc.getElementById("practice-tape-canvas");
    const armatureEl = doc.getElementById("sounder-armature");
    const dotEl = doc.getElementById("desk-status-dot");

    wire = new global.FORM19Morse.WireController({
      tapeCanvas: tapeCanvas,
      practiceCanvas: practiceCanvas,
      armatureEl: armatureEl,
      dotEl: dotEl,
      onStateChange: (playing) => {
        isSignalPlaying = playing;
        updateInteractiveLabels();
      }
    });

    const btnPlay = doc.getElementById("btn-play-signal");
    if (btnPlay) btnPlay.addEventListener("click", () => wire.playSignal());

    const btnCompare = doc.getElementById("btn-compare-tape");
    const alignmentEl = doc.getElementById("tape-alignment");
    if (btnCompare) {
      btnCompare.addEventListener("click", () => {
        isTapeCompared = !isTapeCompared;
        wire.setCompared(isTapeCompared);
        if (alignmentEl) alignmentEl.classList.toggle("is-visible", isTapeCompared);
        updateInteractiveLabels();
      });
    }

    const btnAmend = doc.getElementById("btn-amend-copy");
    const origWord = doc.getElementById("sheet-written-word");
    const corrWord = doc.getElementById("sheet-correction-word");
    if (btnAmend) {
      btnAmend.addEventListener("click", () => {
        isCopyAmended = !isCopyAmended;
        if (origWord) origWord.classList.toggle("is-amended", isCopyAmended);
        if (corrWord) corrWord.classList.toggle("is-visible", isCopyAmended);
        wire.sound.play("paper_turn", 0.55);
        updateInteractiveLabels();
      });
    }

    const brassKeyBtn = doc.getElementById("brass-key-btn");
    if (brassKeyBtn) {
      const pressDown = (e) => {
        if (e.type === "keydown" && (e.repeat || (e.code !== "Space" && e.code !== "Enter"))) return;
        if (e.type === "keydown") e.preventDefault();
        brassKeyBtn.classList.add("is-pressed");
        wire.keyDown(true);
      };
      const pressUp = (e) => {
        if (e.type === "keyup" && e.code !== "Space" && e.code !== "Enter") return;
        brassKeyBtn.classList.remove("is-pressed");
        wire.keyUp();
      };

      brassKeyBtn.addEventListener("pointerdown", pressDown);
      global.addEventListener("pointerup", () => {
        if (wire && wire.keyActive) {
          brassKeyBtn.classList.remove("is-pressed");
          wire.keyUp();
        }
      });
      brassKeyBtn.addEventListener("keydown", pressDown);
      brassKeyBtn.addEventListener("keyup", pressUp);
    }

    const btnMotif = doc.getElementById("btn-tap-motif");
    if (btnMotif) btnMotif.addEventListener("click", () => wire.tapMotif());

    const btnClear = doc.getElementById("btn-practice-clear");
    if (btnClear) btnClear.addEventListener("click", () => wire.clearPractice());

    const audioBtn = doc.getElementById("btn-audio-toggle");
    if (audioBtn) {
      audioBtn.addEventListener("click", () => {
        wire.sound.setMuted(!wire.sound.muted);
        if (!wire.sound.muted) wire.sound.play("key_click", 0.45);
        updateInteractiveLabels();
      });
    }

    global.addEventListener("resize", () => {
      if (wire) {
        wire.redrawMain();
        global.FORM19Morse.renderPracticeTape(practiceCanvas, wire.practiceSegments);
      }
    });
  }

  function initFormsSection() {
    const cards = doc.querySelectorAll(".train-form");
    cards.forEach((card) => {
      card.addEventListener("click", () => {
        cards.forEach((c) => {
          const isMatch = c === card;
          c.classList.toggle("is-selected", isMatch);
          c.setAttribute("aria-pressed", String(isMatch));
        });
        if (wire) wire.sound.play("paper_turn", 0.48);
        updateInteractiveLabels();
      });
    });
  }

  function initContrastSection() {
    const section = doc.getElementById("contrast");
    const buttons = doc.querySelectorAll(".polarity-btn");
    const panels = doc.querySelectorAll(".contrast-panel");
    if (!section) return;

    buttons.forEach((btn) => {
      btn.addEventListener("click", () => {
        const mode = btn.getAttribute("data-mode");
        section.setAttribute("data-polarity", mode);
        buttons.forEach((b) => {
          const active = b === btn;
          b.classList.toggle("is-active", active);
          b.setAttribute("aria-pressed", String(active));
        });
        panels.forEach((p) => {
          p.classList.toggle("is-active", p.getAttribute("data-panel") === mode);
        });
        if (wire) wire.sound.play("route_lever", 0.45);
      });
    });
  }

  /* ---------- Gallery & Lightbox ---------- */
  const lightboxState = {
    open: false,
    items: [],
    index: 0,
    lastFocus: null
  };

  function getVisibleGalleryItems() {
    return Array.from(doc.querySelectorAll(".gallery-item:not(.is-hidden)"));
  }

  function updateLightboxText() {
    const item = lightboxState.items[lightboxState.index];
    if (!item) return;
    const img = item.querySelector("img");
    const figEl = item.querySelector(".gallery-fig");
    const capEl = item.querySelector(".gallery-text");

    const lbImg = doc.getElementById("lightbox-img");
    const lbTag = doc.getElementById("lightbox-tag");
    const lbCap = doc.getElementById("lightbox-caption");

    if (lbImg && img) {
      lbImg.src = img.getAttribute("src");
      lbImg.alt = capEl ? capEl.textContent : img.alt;
    }
    if (lbTag && figEl) {
      const numStr = `${String(lightboxState.index + 1).padStart(2, "0")} / ${String(lightboxState.items.length).padStart(2, "0")}`;
      lbTag.textContent = `${figEl.textContent} · ${numStr}`;
    }
    if (lbCap && capEl) {
      lbCap.textContent = capEl.textContent;
    }
  }

  function openLightbox(item) {
    const lb = doc.getElementById("lightbox");
    if (!lb) return;
    lightboxState.items = getVisibleGalleryItems();
    lightboxState.index = Math.max(0, lightboxState.items.indexOf(item));
    lightboxState.open = true;
    lightboxState.lastFocus = doc.activeElement;

    updateLightboxText();
    lb.classList.add("is-open");
    lb.setAttribute("aria-hidden", "false");
    doc.body.style.overflow = "hidden";
    const closeBtn = doc.getElementById("lightbox-close");
    if (closeBtn) closeBtn.focus();
  }

  function closeLightbox() {
    const lb = doc.getElementById("lightbox");
    if (!lb || !lightboxState.open) return;
    lightboxState.open = false;
    lb.classList.remove("is-open");
    lb.setAttribute("aria-hidden", "true");
    doc.body.style.overflow = "";
    if (lightboxState.lastFocus && typeof lightboxState.lastFocus.focus === "function") {
      lightboxState.lastFocus.focus();
    }
  }

  function stepLightbox(delta) {
    if (!lightboxState.items.length) return;
    const len = lightboxState.items.length;
    lightboxState.index = (lightboxState.index + delta + len) % len;
    updateLightboxText();
    if (wire) wire.sound.play("paper_turn", 0.35);
  }

  function initGallery() {
    const filterBtns = doc.querySelectorAll(".filter-btn");
    const grid = doc.getElementById("gallery-grid");
    const items = doc.querySelectorAll(".gallery-item");

    filterBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        const cat = btn.getAttribute("data-filter");
        filterBtns.forEach((b) => {
          const active = b === btn;
          b.classList.toggle("is-active", active);
          b.setAttribute("aria-pressed", String(active));
        });
        if (grid) grid.classList.toggle("is-filtered", cat !== "all");
        items.forEach((item) => {
          const match = cat === "all" || item.getAttribute("data-category") === cat;
          item.classList.toggle("is-hidden", !match);
        });
        if (wire) wire.sound.play("key_click", 0.38);
      });
    });

    items.forEach((item) => {
      const trigger = item.querySelector(".gallery-trigger");
      if (trigger) {
        trigger.addEventListener("click", () => openLightbox(item));
      }
    });

    const lb = doc.getElementById("lightbox");
    const btnClose = doc.getElementById("lightbox-close");
    const btnPrev = doc.getElementById("lightbox-prev");
    const btnNext = doc.getElementById("lightbox-next");

    if (btnClose) btnClose.addEventListener("click", closeLightbox);
    if (btnPrev) btnPrev.addEventListener("click", () => stepLightbox(-1));
    if (btnNext) btnNext.addEventListener("click", () => stepLightbox(1));

    if (lb) {
      lb.addEventListener("click", (e) => {
        if (e.target === lb) closeLightbox();
      });
    }

    doc.addEventListener("keydown", (e) => {
      if (!lightboxState.open) return;
      if (e.key === "Escape") closeLightbox();
      else if (e.key === "ArrowLeft") stepLightbox(-1);
      else if (e.key === "ArrowRight") stepLightbox(1);
    });
  }

  function initNavigationAndReveal() {
    doc.querySelectorAll(".locale-pill").forEach((btn) => {
      btn.addEventListener("click", () => {
        applyLanguage(btn.getAttribute("data-lang"));
        if (wire) wire.sound.play("key_click", 0.35);
      });
    });

    const menuBtn = doc.getElementById("mobile-menu-btn");
    const drawer = doc.getElementById("mobile-drawer");
    if (menuBtn && drawer) {
      menuBtn.addEventListener("click", () => {
        const open = drawer.classList.toggle("is-open");
        menuBtn.setAttribute("aria-expanded", String(open));
      });
      drawer.querySelectorAll("a").forEach((a) => {
        a.addEventListener("click", () => {
          drawer.classList.remove("is-open");
          menuBtn.setAttribute("aria-expanded", "false");
        });
      });
    }

    const items = doc.querySelectorAll(".reveal");
    if ("IntersectionObserver" in global) {
      const io = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              entry.target.classList.add("in");
              io.unobserve(entry.target);
            }
          });
        },
        { rootMargin: "0px 0px -6% 0px", threshold: 0.08 }
      );
      items.forEach((el) => io.observe(el));
    } else {
      items.forEach((el) => el.classList.add("in"));
    }
  }

  doc.addEventListener("DOMContentLoaded", () => {
    initWireConsole();
    initFormsSection();
    initContrastSection();
    initGallery();
    initNavigationAndReveal();
    applyLanguage(resolveInitialLang());
  });
})(window, document);
