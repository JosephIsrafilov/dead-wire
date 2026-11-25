/**
 * FORM 19 — Authentic 1890s American Morse Engine, Dual-Mode Sounder Audio & Paper Tape Register
 * Matches data/morse/m1_american_morse_alphabet.tres unit-for-unit.
 */
(function (global) {
  "use strict";

  // Positive integers = MARK duration in units; negative integers = GAP duration in units
  const AMERICAN_MORSE = {
    A: [1, -1, 3],
    B: [3, -1, 1, -1, 1, -1, 1],
    C: [1, -1, 1, -2, 1],
    D: [3, -1, 1, -1, 1],
    E: [1],
    F: [1, -1, 3, -1, 1],
    G: [3, -1, 3, -1, 1],
    H: [1, -1, 1, -1, 1, -1, 1],
    I: [1, -1, 1],
    J: [3, -1, 1, -1, 3, -1, 1],
    K: [3, -1, 1, -1, 3],
    L: [6],
    M: [3, -1, 3],
    N: [3, -1, 1],
    O: [1, -2, 1],
    P: [1, -1, 1, -1, 1, -1, 1, -1, 1],
    R: [1, -2, 1, -1, 1],
    S: [1, -1, 1, -1, 1],
    T: [3],
    U: [1, -1, 1, -1, 3],
    W: [1, -1, 3, -1, 3],
    Y: [1, -1, 1, -2, 1, -1, 1],
    "1": [1, -1, 3, -1, 3, -1, 1],
    "4": [1, -1, 1, -1, 1, -1, 1, -1, 3],
    "7": [3, -1, 3, -1, 1, -1, 1]
  };

  const INTER_LETTER_GAP = 3;
  const INTER_WORD_GAP = 6;
  const UNIT_MS = 90;

  function encodeMessage(message) {
    const tokens = [];
    const words = message.trim().toUpperCase().split(/\s+/);
    let totalUnits = 0;

    words.forEach((word, wIdx) => {
      for (let cIdx = 0; cIdx < word.length; cIdx++) {
        const ch = word[cIdx];
        const seq = AMERICAN_MORSE[ch];
        if (!seq) continue;
        const startUnit = totalUnits;
        for (let i = 0; i < seq.length; i++) {
          const val = seq[i];
          const isMark = val > 0;
          const units = Math.abs(val);
          tokens.push({
            kind: isMark ? "MARK" : "GAP",
            units: units,
            startUnit: totalUnits,
            endUnit: totalUnits + units,
            char: ch
          });
          totalUnits += units;
        }
        const charEnd = totalUnits;
        tokens.push({
          kind: "CHAR_SPAN",
          char: ch,
          startUnit: startUnit,
          endUnit: charEnd
        });
        if (cIdx < word.length - 1) {
          tokens.push({
            kind: "GAP",
            units: INTER_LETTER_GAP,
            startUnit: totalUnits,
            endUnit: totalUnits + INTER_LETTER_GAP
          });
          totalUnits += INTER_LETTER_GAP;
        }
      }
      if (wIdx < words.length - 1) {
        tokens.push({
          kind: "GAP",
          units: INTER_WORD_GAP,
          startUnit: totalUnits,
          endUnit: totalUnits + INTER_WORD_GAP
        });
        totalUnits += INTER_WORD_GAP;
      }
    });

    return {
      events: tokens.filter((t) => t.kind === "MARK" || t.kind === "GAP"),
      charSpans: tokens.filter((t) => t.kind === "CHAR_SPAN"),
      totalUnits: totalUnits
    };
  }

  const SOUND_FILES = {
    sounder_down: "audio/sounder_down.wav",
    sounder_up: "audio/sounder_up.wav",
    key_click: "audio/key_click.wav",
    paper_turn: "audio/paper_turn.wav",
    route_lever: "audio/route_lever.wav"
  };

  class SoundEngine {
    constructor() {
      this.ctx = null;
      this.muted = false;
      this.buffers = {};
      this.htmlPools = {};
      this.poolCursor = {};
      this.loadingStarted = false;
      this.canFetch = global.location && global.location.protocol !== "file:";
    }

    ensureContext() {
      if (this.muted) return null;
      const AudioCtx = global.AudioContext || global.webkitAudioContext;
      if (AudioCtx) {
        if (!this.ctx) {
          this.ctx = new AudioCtx();
        }
        if (this.ctx.state === "suspended") {
          this.ctx.resume().catch(() => {});
        }
      }
      if (!this.loadingStarted) {
        this.loadingStarted = true;
        if (this.canFetch) {
          this.preloadAll();
        } else {
          this.initHtmlPools();
        }
      }
      return this.ctx;
    }

    initHtmlPools() {
      if (typeof global.Audio !== "function") return;
      Object.entries(SOUND_FILES).forEach(([name, url]) => {
        const pool = [];
        for (let i = 0; i < 3; i++) {
          const el = new global.Audio(url);
          el.preload = "auto";
          pool.push(el);
        }
        this.htmlPools[name] = pool;
        this.poolCursor[name] = 0;
      });
    }

    async preloadAll() {
      const entries = Object.entries(SOUND_FILES);
      for (let i = 0; i < entries.length; i++) {
        const [name, url] = entries[i];
        try {
          const res = await fetch(url);
          if (!res.ok) continue;
          const arr = await res.arrayBuffer();
          if (this.ctx) {
            this.buffers[name] = await this.ctx.decodeAudioData(arr);
          }
        } catch (_err) {
          // Graceful fallback to procedural Web Audio synthesis
        }
      }
    }

    setMuted(muted) {
      this.muted = Boolean(muted);
    }

    play(name, gainVal = 0.55) {
      if (this.muted) return;
      const ctx = this.ensureContext();

      const buf = this.buffers[name];
      if (buf && ctx) {
        const src = ctx.createBufferSource();
        const gain = ctx.createGain();
        src.buffer = buf;
        gain.gain.value = gainVal;
        src.connect(gain);
        gain.connect(ctx.destination);
        src.start(0);
        return;
      }

      const pool = this.htmlPools[name];
      if (pool && pool.length) {
        const idx = this.poolCursor[name] || 0;
        const el = pool[idx];
        this.poolCursor[name] = (idx + 1) % pool.length;
        try {
          el.volume = Math.min(1, Math.max(0, gainVal));
          el.currentTime = 0;
          const p = el.play();
          if (p && typeof p.catch === "function") {
            p.catch(() => {
              if (ctx) this.playSynth(ctx, name, gainVal);
            });
          }
          return;
        } catch (_err) {
          // Fall back to procedural synthesis below
        }
      }

      if (ctx) this.playSynth(ctx, name, gainVal);
    }

    playSynth(ctx, name, gainVal) {
      const now = ctx.currentTime;
      if (name === "sounder_down" || name === "sounder_up" || name === "key_click") {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        const isDown = name === "sounder_down";
        const isKey = name === "key_click";
        osc.type = "triangle";
        osc.frequency.setValueAtTime(isDown ? 620 : isKey ? 1480 : 940, now);
        osc.frequency.exponentialRampToValueAtTime(isDown ? 185 : 320, now + 0.032);
        gain.gain.setValueAtTime(gainVal * (isKey ? 0.25 : 0.45), now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + (isDown ? 0.042 : 0.028));
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(now);
        osc.stop(now + 0.05);
        return;
      }

      if (name === "paper_turn" || name === "route_lever") {
        const dur = name === "paper_turn" ? 0.08 : 0.065;
        const size = Math.floor(ctx.sampleRate * dur);
        const buffer = ctx.createBuffer(1, size, ctx.sampleRate);
        const data = buffer.getChannelData(0);
        for (let i = 0; i < size; i++) {
          data[i] = (Math.random() * 2 - 1) * (1 - i / size);
        }
        const src = ctx.createBufferSource();
        src.buffer = buffer;
        const filter = ctx.createBiquadFilter();
        filter.type = "bandpass";
        filter.frequency.value = name === "paper_turn" ? 2100 : 480;
        filter.Q.value = name === "paper_turn" ? 1.4 : 2.6;
        const gain = ctx.createGain();
        gain.gain.value = gainVal * 0.35;
        src.connect(filter);
        filter.connect(gain);
        gain.connect(ctx.destination);
        src.start(now);
      }
    }
  }

  function renderMainTape(canvas, schedule, options) {
    if (!canvas) return;
    const opts = options || {};
    const dpr = global.devicePixelRatio || 1;
    const cssWidth = Math.max(canvas.clientWidth || 720, 260);
    const cssHeight = 82;
    canvas.width = Math.floor(cssWidth * dpr);
    canvas.height = Math.floor(cssHeight * dpr);

    const ctx = canvas.getContext("2d");
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, cssWidth, cssHeight);

    // Paper strip background inside dark metal rollers
    const padX = 24;
    const stripY = 12;
    const stripH = 44;
    const stripW = cssWidth - padX * 2;

    ctx.fillStyle = "#ebe0c6";
    ctx.fillRect(padX, stripY, stripW, stripH);

    // Subtle paper edge shadow
    ctx.strokeStyle = "rgba(58, 43, 27, 0.38)";
    ctx.lineWidth = 1;
    ctx.strokeRect(padX + 0.5, stripY + 0.5, stripW - 1, stripH - 1);

    // Faint telegraph roller guide line
    ctx.strokeStyle = "rgba(140, 48, 38, 0.25)";
    ctx.beginPath();
    ctx.moveTo(padX, stripY + stripH * 0.5);
    ctx.lineTo(padX + stripW, stripY + stripH * 0.5);
    ctx.stroke();

    // Brass roller clips at ends
    ctx.fillStyle = "#8a6835";
    ctx.fillRect(padX - 6, stripY - 3, 6, stripH + 6);
    ctx.fillRect(padX + stripW, stripY - 3, 6, stripH + 6);

    const unitPx = (stripW - 44) / Math.max(schedule.totalUnits, 1);
    const startX = padX + 22;
    const progressUnit = typeof opts.progressUnit === "number" ? opts.progressUnit : schedule.totalUnits;
    const showCompare = Boolean(opts.compared);

    // Embossed ink marks
    schedule.events.forEach((ev) => {
      if (ev.kind !== "MARK") return;
      if (ev.startUnit > progressUnit) return;
      const clampedEnd = Math.min(ev.endUnit, progressUnit);
      const x = startX + ev.startUnit * unitPx;
      const w = Math.max(2, (clampedEnd - ev.startUnit) * unitPx);
      ctx.fillStyle = "#1f1913";
      ctx.fillRect(x, stripY + 15, w, 14);
      ctx.fillStyle = "rgba(255, 240, 210, 0.14)";
      ctx.fillRect(x, stripY + 15, w, 2);
    });

    // Live playhead needle
    if (opts.playing && progressUnit < schedule.totalUnits) {
      const headX = startX + progressUnit * unitPx;
      ctx.strokeStyle = "#b04032";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(headX, stripY - 2);
      ctx.lineTo(headX, stripY + stripH + 2);
      ctx.stroke();
    }

    // Decoded alignment calipers underneath paper strip when comparing with tape
    if (showCompare) {
      ctx.font = '600 11px "IBM Plex Mono", "Courier New", monospace';
      ctx.textAlign = "center";
      schedule.charSpans.forEach((span) => {
        const x1 = startX + span.startUnit * unitPx;
        const x2 = startX + span.endUnit * unitPx;
        const midX = (x1 + x2) * 0.5;
        ctx.strokeStyle = "rgba(235, 208, 150, 0.65)";
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(x1, stripY + stripH + 4);
        ctx.lineTo(x1, stripY + stripH + 8);
        ctx.lineTo(x2, stripY + stripH + 8);
        ctx.lineTo(x2, stripY + stripH + 4);
        ctx.stroke();

        ctx.fillStyle = "#ebd096";
        ctx.fillText(span.char, midX, stripY + stripH + 21);
      });
    }
  }

  function renderPracticeTape(canvas, segments) {
    if (!canvas) return;
    const dpr = global.devicePixelRatio || 1;
    const cssWidth = Math.max(canvas.clientWidth || 500, 280);
    const cssHeight = 46;
    canvas.width = Math.floor(cssWidth * dpr);
    canvas.height = Math.floor(cssHeight * dpr);

    const ctx = canvas.getContext("2d");
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, cssWidth, cssHeight);

    ctx.fillStyle = "#ebe0c6";
    ctx.fillRect(0, 8, cssWidth, 30);
    ctx.strokeStyle = "rgba(140, 48, 38, 0.22)";
    ctx.beginPath();
    ctx.moveTo(0, 23);
    ctx.lineTo(cssWidth, 23);
    ctx.stroke();

    if (!segments.length) return;
    const pxPerMs = 0.08;
    const maxVisibleWidth = cssWidth - 28;
    let totalW = 0;
    segments.forEach((seg) => {
      totalW += Math.max(3, seg.ms * pxPerMs);
    });
    let cursorX = totalW > maxVisibleWidth ? cssWidth - 14 - totalW : 14;
    segments.forEach((seg) => {
      const w = Math.max(3, seg.ms * pxPerMs);
      if (seg.mark && cursorX + w > 0) {
        ctx.fillStyle = "#1c1611";
        ctx.fillRect(cursorX, 17, w, 12);
      }
      cursorX += w;
    });
  }

  class WireController {
    constructor(opts) {
      this.sound = new SoundEngine();
      this.schedule = encodeMessage("MJ WATER");
      this.tapeCanvas = opts.tapeCanvas;
      this.practiceCanvas = opts.practiceCanvas;
      this.armatureEl = opts.armatureEl;
      this.dotEl = opts.dotEl;
      this.onStateChange = opts.onStateChange || function () {};

      this.isPlaying = false;
      this.isCompared = false;
      this.rafId = 0;
      this.timers = [];
      this.playStartTs = 0;

      // Live key state
      this.practiceSegments = [];
      this.keyDownTs = 0;
      this.lastReleaseTs = 0;
      this.keyActive = false;

      this.seedMotifPreview();
      this.redrawMain();
    }

    seedMotifPreview() {
      // Seed clean initial · — · motif on the practice strip so it reads immediately
      this.practiceSegments = [
        { mark: true, ms: 90 },
        { mark: false, ms: 95 },
        { mark: true, ms: 270 },
        { mark: false, ms: 95 },
        { mark: true, ms: 90 }
      ];
      renderPracticeTape(this.practiceCanvas, this.practiceSegments);
    }

    redrawMain(progressUnit) {
      renderMainTape(this.tapeCanvas, this.schedule, {
        playing: this.isPlaying,
        compared: this.isCompared,
        progressUnit: typeof progressUnit === "number" ? progressUnit : this.schedule.totalUnits
      });
    }

    setCompared(val) {
      this.isCompared = Boolean(val);
      this.sound.play("paper_turn", 0.45);
      this.redrawMain(this.isPlaying ? this.currentProgressUnit() : this.schedule.totalUnits);
    }

    currentProgressUnit() {
      if (!this.isPlaying) return this.schedule.totalUnits;
      const elapsedMs = performance.now() - this.playStartTs;
      return Math.min(this.schedule.totalUnits, elapsedMs / UNIT_MS);
    }

    setArmature(down) {
      if (this.armatureEl) this.armatureEl.classList.toggle("is-down", down);
      if (this.dotEl) this.dotEl.classList.toggle("is-marking", down);
    }

    stop() {
      this.timers.forEach((t) => clearTimeout(t));
      this.timers = [];
      if (this.rafId) {
        cancelAnimationFrame(this.rafId);
        this.rafId = 0;
      }
      this.isPlaying = false;
      this.setArmature(false);
      this.redrawMain(this.schedule.totalUnits);
      this.onStateChange(false);
    }

    playSignal() {
      if (this.isPlaying) {
        this.stop();
        return;
      }
      this.sound.ensureContext();
      this.isPlaying = true;
      this.playStartTs = performance.now();
      this.onStateChange(true);

      this.schedule.events.forEach((ev) => {
        if (ev.kind !== "MARK") return;
        const tDown = setTimeout(() => {
          if (!this.isPlaying) return;
          this.setArmature(true);
          this.sound.play("sounder_down", 0.65);
        }, ev.startUnit * UNIT_MS);

        const tUp = setTimeout(() => {
          if (!this.isPlaying) return;
          this.setArmature(false);
          this.sound.play("sounder_up", 0.52);
        }, ev.endUnit * UNIT_MS);

        this.timers.push(tDown, tUp);
      });

      const tDone = setTimeout(() => {
        this.stop();
      }, this.schedule.totalUnits * UNIT_MS + 180);
      this.timers.push(tDone);

      const tick = () => {
        if (!this.isPlaying) return;
        this.redrawMain(this.currentProgressUnit());
        this.rafId = requestAnimationFrame(tick);
      };
      this.rafId = requestAnimationFrame(tick);
    }

    keyDown(fromUser) {
      if (this.keyActive) return;
      if (fromUser) this.sound.ensureContext();
      this.keyActive = true;
      const now = performance.now();
      if (this.lastReleaseTs > 0) {
        const gapMs = Math.min(900, Math.max(40, now - this.lastReleaseTs));
        this.practiceSegments.push({ mark: false, ms: gapMs });
      }
      this.keyDownTs = now;
      this.setArmature(true);
      this.sound.play("sounder_down", 0.6);
    }

    keyUp() {
      if (!this.keyActive) return;
      this.keyActive = false;
      const now = performance.now();
      const markMs = Math.min(720, Math.max(55, now - this.keyDownTs));
      this.lastReleaseTs = now;
      this.practiceSegments.push({ mark: true, ms: markMs });
      if (this.practiceSegments.length > 64) {
        this.practiceSegments = this.practiceSegments.slice(-64);
      }
      this.setArmature(false);
      this.sound.play("sounder_up", 0.48);
      renderPracticeTape(this.practiceCanvas, this.practiceSegments);
    }

    clearPractice() {
      this.practiceSegments = [];
      this.lastReleaseTs = 0;
      renderPracticeTape(this.practiceCanvas, this.practiceSegments);
      this.sound.play("paper_turn", 0.4);
    }

    tapMotif() {
      this.sound.ensureContext();
      this.stop();
      this.practiceSegments = [];
      this.lastReleaseTs = 0;
      const pattern = [
        { mark: true, ms: 90 },
        { mark: false, ms: 110 },
        { mark: true, ms: 270 },
        { mark: false, ms: 110 },
        { mark: true, ms: 90 }
      ];
      let offset = 0;
      pattern.forEach((step) => {
        const t1 = setTimeout(() => {
          if (step.mark) {
            this.setArmature(true);
            this.sound.play("sounder_down", 0.62);
          } else {
            this.setArmature(false);
            this.sound.play("sounder_up", 0.5);
          }
          this.practiceSegments.push(step);
          renderPracticeTape(this.practiceCanvas, this.practiceSegments);
        }, offset);
        this.timers.push(t1);
        offset += step.ms;
      });
      const tEnd = setTimeout(() => {
        this.setArmature(false);
        this.sound.play("sounder_up", 0.5);
      }, offset);
      this.timers.push(tEnd);
    }
  }

  global.FORM19Morse = {
    WireController: WireController,
    encodeMessage: encodeMessage,
    renderMainTape: renderMainTape,
    renderPracticeTape: renderPracticeTape
  };
})(window);
