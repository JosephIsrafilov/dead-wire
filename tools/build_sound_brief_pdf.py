"""Generate a sleek 6-page mobile-friendly PDF audio brief for DEAD WIRE.

Uses pure Python stdlib for rich-text tokenization and PDF 1.4 assembly,
and native Windows .NET System.Drawing (GDI+) via PowerShell/C# for crisp
1080x1920 anti-aliased Cyrillic rendering (135x240 mm phone portrait pages).
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[1]
OUTPUT_PDF = ROOT / "docs" / "audio" / "DEAD_WIRE_Sound_Brief_Mobile.pdf"

TOKEN_RE = re.compile(r"(\*\*.*?\*\*|_.*?_|`.*?`|\[\[.*?\]\])")


def tokenize(text: str) -> list[list[dict[str, str]]]:
    """Split text by explicit newlines and inline markup into typed tokens."""
    paragraphs: list[list[dict[str, str]]] = []
    for raw_para in text.split("\n"):
        tokens: list[dict[str, str]] = []
        pos = 0
        for m in TOKEN_RE.finditer(raw_para):
            if m.start() > pos:
                tokens.append({"style": "normal", "text": raw_para[pos : m.start()]})
            tok = m.group(0)
            if tok.startswith("**"):
                tokens.append({"style": "bold", "text": tok[2:-2]})
            elif tok.startswith("_"):
                tokens.append({"style": "italic", "text": tok[1:-1]})
            elif tok.startswith("`"):
                tokens.append({"style": "mono", "text": tok[1:-1]})
            elif tok.startswith("[["):
                tokens.append({"style": "brass", "text": tok[2:-2]})
            pos = m.end()
        if pos < len(raw_para):
            tokens.append({"style": "normal", "text": raw_para[pos:]})

        # Split non-mono chunks into words + whitespace so GDI+ wraps cleanly.
        word_tokens: list[dict[str, str]] = []
        for item in tokens:
            if item["style"] == "mono":
                word_tokens.append(item)
                continue
            for part in re.split(r"(\s+)", item["text"]):
                if part:
                    word_tokens.append({"style": item["style"], "text": part})
        paragraphs.append(word_tokens)
    return paragraphs


def build_spec() -> dict[str, Any]:
    return {
        "pages": [
            {
                "num": 1,
                "kind": "cover",
                "eyebrow": "КОЛОРАДО  ·  АПРЕЛЬ 1890  ·  AUDIO BRIEF",
                "title": "DEAD WIRE",
                "subtitle": "Короткое ТЗ для композитора и саунд-дизайнера",
                "spoiler": {
                    "title": "СПОЙЛЕР-СТОП! СНАЧАЛА СЫГРАЙ",
                    "paragraphs": [
                        tokenize(
                            "Пожалуйста, сначала один раз пройди присланный билд **Ночи 1 в наушниках**, и только потом листай дальше — внутри раскрыты фишки сюжета."
                        )
                    ],
                },
                "about": {
                    "title": "О чём игра",
                    "paragraphs": [
                        tokenize(
                            "Психологический хоррор-вестерн от 1-го лица о ночном телеграфисте в горном городке Блэк-Крик."
                        ),
                        tokenize(
                            "**Главный крючок:** _ты слышишь по морзянке одно, твоя рука пишет на бланке другое, а бумажная лента никогда не врёт._"
                        ),
                    ],
                },
                "quote": "«Живая тишина + аналоговая механика 1890 г. + редкий церковный хор сильнее любого пафосного оркестра.»",
                "contrast": [
                    {
                        "title": "Ночь (Станция)",
                        "paragraphs": [
                            tokenize(
                                "Теснота, сухой латунный клопфер, скрип пера, печка, ветер в стекле и тревога в паузах."
                            )
                        ],
                    },
                    {
                        "title": "День (Салун)",
                        "paragraphs": [
                            tokenize(
                                "Солнце Запада, расстроенное салунное пианино, звон стаканов, карты, азарт и живые люди."
                            )
                        ],
                    },
                ],
            },
            {
                "num": 2,
                "kind": "cards",
                "header_left": "РЕФЕРЕНСЫ И АТМОСФЕРА",
                "header_right": "ВДОХНОВЕНИЕ",
                "heading": "Чем мы вдохновлялись",
                "lead": tokenize("Шесть точных ориентиров — берём настроение, воздух и живую драму:"),
                "cards": [
                    {
                        "title": "1. Silent Hill 2",
                        "pill": "Akira Yamaoka",
                        "compact": True,
                        "paragraphs": [
                            tokenize(
                                "Холодный индустриальный воздух, редкие металлические резонансы и тревога внутри тишины — страшнее всего в паузах."
                            )
                        ],
                    },
                    {
                        "title": "2. Mouthwashing",
                        "pill": "Психологический гнёт",
                        "compact": True,
                        "paragraphs": [
                            tokenize(
                                "Давящий гул живой машины, клаустрофобия рабочего места и тихое, липкое чувство вины."
                            )
                        ],
                    },
                    {
                        "title": "3. NieR Replicant / Automata",
                        "pill": "Keiichi Okabe",
                        "compact": True,
                        "paragraphs": [
                            tokenize(
                                "Один узнаваемый мотив в разных обличьях, призрачный вокал / хор и скрытая звуковая разгадка ближе к финалу."
                            )
                        ],
                    },
                    {
                        "title": "4. Final Fantasy (VI / VII / X)",
                        "pill": "Драма и катарсис",
                        "compact": True,
                        "paragraphs": [
                            tokenize(
                                "Сильный эмоциональный лейтмотив, сакральные хоровые акценты и хрупкое, честное сольное пианино в титрах."
                            )
                        ],
                    },
                    {
                        "title": "5. Red Dead Redemption 2",
                        "pill": "Woody Jackson",
                        "compact": True,
                        "paragraphs": [
                            tokenize(
                                "Тёплый пыльный Запад 1890-х: расстроенное салунное _tack piano_, редкая горная гитара на рассвете, дерево и стекло."
                            )
                        ],
                    },
                    {
                        "title": "6. No, I'm Not a Human",
                        "pill": "Зловещий порог",
                        "compact": True,
                        "paragraphs": [
                            tokenize(
                                "Ноль дешёвых «бу!»-скримеров; пугает ледяная ясность и ощущение, что за окном стоит кто-то почти человеческий."
                            )
                        ],
                    },
                ],
            },
            {
                "num": 3,
                "kind": "features",
                "header_left": "ДРАМАТУРГИЯ ЗВУКА",
                "header_right": "ГЛАВНЫЕ ФИШКИ",
                "heading": "Три главные фишки",
                "timeline_card": {
                    "title": "1. «Музыкальная рифма»",
                    "pill": "4–6 НОТ",
                    "intro": tokenize(
                        "Придумай **ОДНУ** цепкую короткую мелодию и проведи её через 5 превращений недели:"
                    ),
                    "items": [
                        tokenize("[[Меню:]] одинокое старое пианино + лёгкая тень хора и гул провода."),
                        tokenize("[[Рассвет / перекур:]] скупые аккорды гитары на крыльце с кучей воздуха."),
                        tokenize("[[Салун (Дни 1–3):]] бодрый 1890s _Cakewalk_ на _tack piano_ + чистая шкатулка _Symphonion_."),
                        tokenize("[[Салун (Дни 5–6, «гниение»):]] медленный минорный вальс + **один фальшивящий зубец** у шкатулки."),
                        tokenize("[[Титры:]] далёкий Поезд № 17, чистое сольное пианино и тёплый хор."),
                    ],
                },
                "choir_card": {
                    "title": "2. Церковный хор и фисгармония",
                    "pill": "АКЦЕНТ",
                    "paragraphs": [
                        tokenize(
                            "Не громкий блокбастер, а **призрачный камерный церковный хор + старая фисгармония** (_pump organ_) строго в 4 точках:"
                        ),
                        tokenize(
                            "· еле слышная тень в **Меню**  · тихий реквием в **Ночь 6**\n· утренний колокол и далёкий гимн **Воскресенья** перед судом  · пронзительное вступление в **Титрах**."
                        ),
                    ],
                },
                "pipe_card": {
                    "title": "3. Секретный ритм · — ·",
                    "pill": "NieR Route B",
                    "paragraphs": [
                        tokenize(
                            "В тихих паузах Ночей 1–5 на грани слышимости (`-30 dB`, глухой low-pass `< 900 Hz`) изредка стучит далёкое железо: **коротко — длинно — коротко** (`· — ·`)."
                        ),
                        tokenize(
                            "Ровно так же герой от нервов стучит пальцем по столу. В Ночь 6 игрок узнаёт правду: заземление станции прикручено к водопроводной трубе — **так снизу стучали запертые шахтёры в 1885-м.**"
                        ),
                    ],
                },
            },
            {
                "num": 4,
                "kind": "cards",
                "header_left": "ДОРОЖНАЯ КАРТА",
                "header_right": "3 ЭТАПА",
                "heading": "План работы по этапам",
                "cards": [
                    {
                        "title": "Этап 1 · Старт (Ночь 1 и мотив)",
                        "pill": "СЕЙЧАС",
                        "compact": True,
                        "bullets": [
                            tokenize("**Главный мотив (4–6 нот):** Меню (пианино + тень хора) и Рассвет / тихий перекур (акустика)."),
                            tokenize("**Телеграф:** живой латунный клопфер (вниз/вверх, 3–4 вариации), ключ, мягкий скрип пера, часовой ход ленты."),
                            tokenize("**Ночь и тело:** фоны комнаты / ветра / печки / провода, глухой стук `· — ·`, палец по столу и хруст судороги кисти."),
                            tokenize("**Курение 1890:** чирк серной спички с шипением, затяжка, выдох, тушение окурка."),
                            tokenize("**Пролог Поезда № 17 (45–60 с):** рельсы, тормоза, пар, далёкий гудок в горах."),
                        ],
                    },
                    {
                        "title": "Этап 2 · Город, Салун и Персонажи",
                        "compact": True,
                        "bullets": [
                            tokenize("**Музыка салуна:** бодрый _Cakewalk_ (Дни 1–3) → минорный вальс (Дни 5–6) + шкатулка _Symphonion_ (чистая и со сломанным зубцом)."),
                            tokenize("**Салун и азарт:** хлопок распашных дверей, виски, стакан о дуб, автомат _The Silver Spur_ (рычаг, барабаны, латунный _DING-DING!_), карты _Faro_, кости в кожаном стакане (_Liar's Dice_)."),
                            tokenize("**«Фишки» 12 персонажей вместо озвучки:** звон серебряного доллара картёжника, стук перевёрнутого стакана бармена, ключи хозяйки, шёлк по пенсне, ладонь по стеклу фонаря, хлопок перчаток."),
                        ],
                    },
                    {
                        "title": "Этап 3 · Поздние ночи, Хор и Финал",
                        "compact": True,
                        "bullets": [
                            tokenize("Индустриальный дрон Ночей 3–6, грозовая наводка на проводе и старое хриплое реле наставника Коула."),
                            tokenize("**Воскресенье и Суд:** утренний колокол и далёкий хор → напряжение → срез в вакуумную тишину → финал на ключе → **Титры (пианино + хор)**."),
                        ],
                    },
                ],
            },
            {
                "num": 5,
                "kind": "cards",
                "header_left": "ПОЛЕЗНЫЙ АРСЕНАЛ",
                "header_right": "ПЛАГИНЫ И БАЗЫ",
                "heading": "Плагины, хоры и базы SFX",
                "cards": [
                    {
                        "title": "Бесплатный топ (0$ — ставь и пиши)",
                        "pill": "FREE",
                        "compact": True,
                        "bullets": [
                            tokenize("**Spitfire LABS Choir:** записан в AIR Studios с _Eric Whitacre Singers_ — готовый призрачный церковный воздух и живые гласные."),
                            tokenize("**Decent Sampler + Pianobook.co.uk:** сотни бесплатных библиотек — живые хоры из реальных церквей, `Tack Piano`, `Harmonium / Pump Organ`, `Music Box`."),
                            tokenize("**Orchestral Tools SINEfactory:** бесплатные студийные вокальные и оркестровые патчи."),
                            tokenize("**Хоррор-обработка:** **Valhalla Supermassive** (реверб на хор и дроны) · **ChowTapeModel** (аналоговая плёнка) · **PaulXStretch** (любой скрип → дрон) · **iZotope Vinyl** (сломанная шкатулка) · **TDR Nova** (динамический EQ, идеально чистит `1.2–4 kHz` под телеграф)."),
                        ],
                    },
                    {
                        "title": "Если есть Kontakt (Pro-хоры)",
                        "pill": "PRO",
                        "compact": True,
                        "bullets": [
                            tokenize("**Spitfire Eric Whitacre Choir:** шёпот, дыхание и тонкие сакральные кластеры."),
                            tokenize("**Strezov Sampling** (_Wotan / Freyja / Choir Omnia_): живая, мощная церковно-ритуальная подача без «пластика»."),
                            tokenize("**Soundiron Requiem Light / Sick** · **Fluffy Audio Haunted Choir** · **Silence+Other Sounds (Hellen)** — призрачные шёпоты и холодные хоровые тени."),
                        ],
                    },
                    {
                        "title": "Легальные базы живого фоли (CC0 / RF)",
                        "compact": True,
                        "bullets": [
                            tokenize("**Sonniss GDC Audio Bundles:** 100+ ГБ студийных WAV бесплатно для коммерческих игр (поезда, металл, двери, ветер, дерево)."),
                            tokenize("**Freesound.org (фильтр CC0):** быстрый добор редких скрипов, спичек и толстого стекла 1890-х."),
                        ],
                    },
                ],
            },
            {
                "num": 6,
                "kind": "rules",
                "header_left": "ТЕХНИЧКА БЕЗ ДУХОТЫ",
                "header_right": "ПРАВИЛА МИКСА",
                "heading": "4 золотых правила и сдача",
                "rules": [
                    {
                        "num": 1,
                        "title": "Священный телеграф (1.2 – 4.0 kHz)",
                        "paragraphs": [
                            tokenize(
                                "Щелчок клопфера — главный инструмент игрока. Он живёт в **1.2–4 кГц**: в ночных фонах, дронах и хоровых падах мягко прибирай эту полосу (например, через _TDR Nova_), чтобы ветер не съел морзянку."
                            )
                        ],
                    },
                    {
                        "num": 2,
                        "title": "Никаких скримеров поверх кода",
                        "paragraphs": [
                            tokenize(
                                "Во время приёма важных сообщений — ноль громких «бу!»-ударов. Пугает ледяная ясность, а не перегруз."
                            )
                        ],
                    },
                    {
                        "num": 3,
                        "title": "Звук не подсказывает ответ",
                        "paragraphs": [
                            tokenize(
                                "Штамп, рычаг, бумага и ключ — честная физика. Никаких «дзынь, правильно!» или «ошибка!» — игрок сам сверяет ленту и бланк."
                            )
                        ],
                    },
                    {
                        "num": 4,
                        "title": "Удобный формат сдачи",
                        "paragraphs": [
                            tokenize(
                                "· **SFX и 3D-точки** (клопфер, печка, шкатулка, тики): `WAV 48 kHz / 16-bit`, **Mono**.\n· **Комната и музыка:** `WAV` или `OGG` (**Stereo**), бесшовные лупы без щелчков, пики не выше `-1 dB`."
                            )
                        ],
                    },
                ],
                "closing": "Кидай демки, хоровые эскизы и сэмплы хоть по 20 секунд — сразу отслушаем, проверим в живом билде под телеграф и соберём вместе!",
            },
        ]
    }


# Strictly ASCII-only PowerShell + C# GDI+ renderer so PowerShell 5.1 never mangles UTF-8 scripts.
PS1_RENDERER = r"""
param(
    [Parameter(Mandatory=$true)][string]$SpecPath,
    [Parameter(Mandatory=$true)][string]$OutDir
)

$ErrorActionPreference = 'Stop'
Add-Type -ReferencedAssemblies 'System.Drawing','System.Web.Extensions' -TypeDefinition @'
using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;

public class BriefRenderer
{
    const int W = 1080;
    const int H = 1920;
    const int MARGIN_X = 72;
    const int TOP_Y = 74;
    const int FOOTER_Y = H - 76;
    const int CONTENT_W = W - MARGIN_X * 2;

    static Color Hex(string h)
    {
        return ColorTranslator.FromHtml(h);
    }

    static GraphicsPath RoundedRect(float x, float y, float w, float h, float r)
    {
        float d = r * 2f;
        var path = new GraphicsPath();
        path.AddArc(x, y, d, d, 180, 90);
        path.AddArc(x + w - d, y, d, d, 270, 90);
        path.AddArc(x + w - d, y + h - d, d, d, 0, 90);
        path.AddArc(x, y + h - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }

    static Font F_H1 = new Font("Georgia", 84f, FontStyle.Bold, GraphicsUnit.Pixel);
    static Font F_SUB = new Font("Georgia", 31f, FontStyle.Regular, GraphicsUnit.Pixel);
    static Font F_H2 = new Font("Georgia", 46f, FontStyle.Bold, GraphicsUnit.Pixel);
    static Font F_H3 = new Font("Georgia", 29f, FontStyle.Bold, GraphicsUnit.Pixel);
    static Font F_EYEBROW = new Font("Segoe UI", 19f, FontStyle.Bold, GraphicsUnit.Pixel);
    static Font F_TOPRULE = new Font("Segoe UI", 18f, FontStyle.Bold, GraphicsUnit.Pixel);
    static Font F_BODY = new Font("Segoe UI", 25f, FontStyle.Regular, GraphicsUnit.Pixel);
    static Font F_BODY_B = new Font("Segoe UI", 25f, FontStyle.Bold, GraphicsUnit.Pixel);
    static Font F_BODY_I = new Font("Segoe UI", 25f, FontStyle.Italic, GraphicsUnit.Pixel);
    static Font F_SMALL = new Font("Segoe UI", 23f, FontStyle.Regular, GraphicsUnit.Pixel);
    static Font F_SMALL_B = new Font("Segoe UI", 23f, FontStyle.Bold, GraphicsUnit.Pixel);
    static Font F_SMALL_I = new Font("Segoe UI", 23f, FontStyle.Italic, GraphicsUnit.Pixel);
    static Font F_MONO = new Font("Consolas", 21f, FontStyle.Regular, GraphicsUnit.Pixel);
    static Font F_QUOTE = new Font("Georgia", 28f, FontStyle.Regular, GraphicsUnit.Pixel);
    static Font F_PILL = new Font("Segoe UI", 19f, FontStyle.Bold, GraphicsUnit.Pixel);
    static Font F_FOOTER = new Font("Segoe UI", 19f, FontStyle.Regular, GraphicsUnit.Pixel);
    static Font F_NUM = new Font("Segoe UI", 22f, FontStyle.Bold, GraphicsUnit.Pixel);

    static StringFormat MakeSF()
    {
        var sf = new StringFormat(StringFormat.GenericTypographic);
        sf.FormatFlags |= StringFormatFlags.MeasureTrailingSpaces | StringFormatFlags.NoWrap;
        return sf;
    }

    static Font TokenFont(string style, bool compact)
    {
        if (style == "mono") return F_MONO;
        if (compact)
        {
            if (style == "bold" || style == "brass") return F_SMALL_B;
            if (style == "italic") return F_SMALL_I;
            return F_SMALL;
        }
        if (style == "bold" || style == "brass") return F_BODY_B;
        if (style == "italic") return F_BODY_I;
        return F_BODY;
    }

    static float MeasureTextWidth(Graphics g, string text, Font f, StringFormat sf)
    {
        if (string.IsNullOrEmpty(text)) return 0f;
        return g.MeasureString(text, f, 4000, sf).Width;
    }

    class Tok
    {
        public string style;
        public string text;
    }

    static List<List<Tok>> WrapParagraphs(Graphics g, object[] rawParas, float maxWidth, bool compact, StringFormat sf)
    {
        var allLines = new List<List<Tok>>();
        foreach (object[] rawPara in rawParas)
        {
            var curLine = new List<Tok>();
            float curW = 0f;
            foreach (Dictionary<string, object> d in rawPara)
            {
                string style = (string)d["style"];
                string text = (string)d["text"];
                bool isSpace = string.IsNullOrWhiteSpace(text);
                if (isSpace && curLine.Count == 0) continue;

                Font f = TokenFont(style, compact);
                float w = MeasureTextWidth(g, text, f, sf);
                float extra = (style == "mono") ? 16f : 0f;
                float needed = w + extra;

                if (curLine.Count > 0 && curW + needed > maxWidth)
                {
                    while (curLine.Count > 0 && string.IsNullOrWhiteSpace(curLine[curLine.Count - 1].text))
                        curLine.RemoveAt(curLine.Count - 1);
                    allLines.Add(curLine);
                    curLine = new List<Tok>();
                    curW = 0f;
                    if (isSpace) continue;
                }

                curLine.Add(new Tok { style = style, text = text });
                curW += needed;
            }
            if (curLine.Count > 0)
            {
                while (curLine.Count > 0 && string.IsNullOrWhiteSpace(curLine[curLine.Count - 1].text))
                    curLine.RemoveAt(curLine.Count - 1);
                if (curLine.Count > 0) allLines.Add(curLine);
            }
        }
        return allLines;
    }

    static List<string> WrapPlainWords(Graphics g, string text, Font f, float maxWidth, StringFormat sf)
    {
        var lines = new List<string>();
        var words = text.Split(' ');
        string cur = "";
        foreach (var word in words)
        {
            string test = (cur.Length == 0) ? word : (cur + " " + word);
            if (cur.Length > 0 && MeasureTextWidth(g, test, f, sf) > maxWidth)
            {
                lines.Add(cur);
                cur = word;
            }
            else
            {
                cur = test;
            }
        }
        if (cur.Length > 0) lines.Add(cur);
        return lines;
    }

    static int LineStep(bool compact) { return compact ? 33 : 36; }

    static float DrawLines(Graphics g, List<List<Tok>> lines, float x, float y, bool compact, Color baseColor, StringFormat sf)
    {
        int step = LineStep(compact);
        float cy = y;
        using (var ivory = new SolidBrush(Hex("#F2E9D8")))
        using (var brass = new SolidBrush(Hex("#F0C37C")))
        using (var body = new SolidBrush(baseColor))
        using (var monoBg = new SolidBrush(Hex("#282018")))
        using (var monoPen = new Pen(Hex("#4E3C28"), 1.5f))
        {
            foreach (var line in lines)
            {
                float cx = x;
                foreach (var tok in line)
                {
                    Font f = TokenFont(tok.style, compact);
                    float tw = MeasureTextWidth(g, tok.text, f, sf);
                    if (tok.style == "mono")
                    {
                        float px = 8f;
                        using (var p = RoundedRect(cx, cy + 1f, tw + px * 2f, step - 4f, 6f))
                        {
                            g.FillPath(monoBg, p);
                            g.DrawPath(monoPen, p);
                        }
                        g.DrawString(tok.text, f, brass, cx + px, cy + 3f, sf);
                        cx += tw + px * 2f;
                    }
                    else
                    {
                        Brush b = (tok.style == "bold") ? ivory : ((tok.style == "brass") ? brass : body);
                        g.DrawString(tok.text, f, b, cx, cy, sf);
                        cx += tw;
                    }
                }
                cy += step;
            }
        }
        return cy;
    }

    static Bitmap MakeCanvas(out Graphics g)
    {
        var bmp = new Bitmap(W, H, PixelFormat.Format24bppRgb);
        g = Graphics.FromImage(bmp);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        g.Clear(Hex("#12100E"));

        using (var gp = new GraphicsPath())
        {
            gp.AddEllipse(-120, -260, 1480, 1480);
            using (var pgb = new PathGradientBrush(gp))
            {
                pgb.CenterPoint = new PointF(920f, 180f);
                pgb.CenterColor = Color.FromArgb(46, 130, 88, 42);
                pgb.SurroundColors = new Color[] { Color.FromArgb(0, 18, 16, 14) };
                g.FillRectangle(pgb, 0, 0, W, H);
            }
        }
        return bmp;
    }

    static float DrawChrome(Graphics g, int pageNum, int total, string leftLbl, string rightLbl, StringFormat sf)
    {
        float y = TOP_Y;
        if (!string.IsNullOrEmpty(leftLbl))
        {
            using (var pen = new Pen(Hex("#3C3024"), 2f))
                g.DrawLine(pen, MARGIN_X, y, W - MARGIN_X, y);
            y += 16f;
            using (var br = new SolidBrush(Hex("#D59E54")))
            {
                g.DrawString(leftLbl, F_TOPRULE, br, MARGIN_X, y, sf);
                float rw = MeasureTextWidth(g, rightLbl, F_TOPRULE, sf);
                g.DrawString(rightLbl, F_TOPRULE, br, W - MARGIN_X - rw, y, sf);
            }
            y += 42f;
        }
        using (var pen = new Pen(Hex("#2D241C"), 2f))
            g.DrawLine(pen, MARGIN_X, FOOTER_Y - 16, W - MARGIN_X, FOOTER_Y - 16);
        using (var br = new SolidBrush(Hex("#8D7F6B")))
        {
            g.DrawString("DEAD WIRE  \u00b7  AUDIO BRIEF", F_FOOTER, br, MARGIN_X, FOOTER_Y, sf);
            string pg = string.Format("{0:00} / {1:00}", pageNum, total);
            float pw = MeasureTextWidth(g, pg, F_FOOTER, sf);
            g.DrawString(pg, F_FOOTER, br, W - MARGIN_X - pw, FOOTER_Y, sf);
        }
        return y;
    }

    static void DrawPill(Graphics g, float rightX, float y, string text, StringFormat sf)
    {
        float tw = MeasureTextWidth(g, text, F_PILL, sf);
        float pw = tw + 24f;
        float ph = 32f;
        float px = rightX - pw;
        using (var p = RoundedRect(px, y, pw, ph, 7f))
        using (var bg = new SolidBrush(Hex("#2B2116")))
        using (var pen = new Pen(Hex("#5B442C"), 1.5f))
        using (var br = new SolidBrush(Hex("#F0C37C")))
        {
            g.FillPath(bg, p);
            g.DrawPath(pen, p);
            g.DrawString(text, F_PILL, br, px + 12f, y + 4f, sf);
        }
    }

    static float DrawCard(
        Graphics g,
        float x,
        float y,
        float w,
        string title,
        string pill,
        object[] rawParas,
        object[] rawBullets,
        bool compact,
        string bgHex,
        string borderHex,
        string titleHex,
        string stripeHex,
        float padX,
        float padY,
        StringFormat sf)
    {
        float innerW = w - padX * 2f;
        float totalH = padY;
        if (!string.IsNullOrEmpty(title)) totalH += 42f;

        var paras = new List<List<List<Tok>>>();
        int paraGap = 11;
        int bulletGap = 10;
        int step = LineStep(compact);

        if (rawParas != null)
        {
            foreach (object[] rp in rawParas)
            {
                var wl = WrapParagraphs(g, rp, innerW, compact, sf);
                paras.Add(wl);
                totalH += wl.Count * step + paraGap;
            }
        }

        var bullets = new List<List<List<Tok>>>();
        float bIndent = 26f;
        if (rawBullets != null)
        {
            foreach (object[] rb in rawBullets)
            {
                var wl = WrapParagraphs(g, rb, innerW - bIndent, compact, sf);
                bullets.Add(wl);
                totalH += wl.Count * step + bulletGap;
            }
        }

        if (paras.Count > 0 && bullets.Count == 0) totalH -= paraGap;
        else if (bullets.Count > 0) totalH -= bulletGap;
        totalH += padY;

        using (var path = RoundedRect(x, y, w, totalH, 16f))
        using (var bg = new SolidBrush(Hex(bgHex)))
        using (var pen = new Pen(Hex(borderHex), 2f))
        {
            g.FillPath(bg, path);
            g.DrawPath(pen, path);
        }

        if (!string.IsNullOrEmpty(stripeHex))
        {
            using (var sp = RoundedRect(x, y + 2f, 9f, totalH - 4f, 4f))
            using (var sb = new SolidBrush(Hex(stripeHex)))
                g.FillPath(sb, sp);
        }

        float cy = y + padY;
        if (!string.IsNullOrEmpty(title))
        {
            using (var tb = new SolidBrush(Hex(titleHex)))
                g.DrawString(title, F_H3, tb, x + padX, cy, sf);
            if (!string.IsNullOrEmpty(pill))
                DrawPill(g, x + w - padX, cy + 2f, pill, sf);
            cy += 42f;
        }

        Color bodyCol = Hex("#E2D6C2");
        for (int i = 0; i < paras.Count; i++)
        {
            cy = DrawLines(g, paras[i], x + padX, cy, compact, bodyCol, sf);
            if (i < paras.Count - 1 || bullets.Count > 0) cy += paraGap;
        }

        using (var dotBr = new SolidBrush(Hex("#D59E54")))
        {
            for (int i = 0; i < bullets.Count; i++)
            {
                g.FillEllipse(dotBr, x + padX + 4f, cy + 12f, 8f, 8f);
                cy = DrawLines(g, bullets[i], x + padX + bIndent, cy, compact, bodyCol, sf);
                if (i < bullets.Count - 1) cy += bulletGap;
            }
        }

        return y + totalH;
    }

    static float DrawQuoteBox(Graphics g, float x, float y, float w, string quote, StringFormat sf)
    {
        var lines = WrapPlainWords(g, quote, F_QUOTE, w - 62f, sf);
        float h = 26f + lines.Count * 39f + 22f;
        using (var p = RoundedRect(x, y, w, h, 14f))
        using (var bg = new SolidBrush(Hex("#241C14")))
        using (var pen = new Pen(Hex("#6E502E"), 2f))
            { g.FillPath(bg, p); g.DrawPath(pen, p); }
        using (var sp = RoundedRect(x, y + 2f, 9f, h - 4f, 4f))
        using (var sb = new SolidBrush(Hex("#D59E54")))
            g.FillPath(sb, sp);
        float cy = y + 24f;
        using (var qb = new SolidBrush(Hex("#F7ECD8")))
        {
            foreach (var l in lines)
            {
                g.DrawString(l, F_QUOTE, qb, x + 32f, cy, sf);
                cy += 39f;
            }
        }
        return y + h;
    }

    static void SaveFrame(Bitmap bmp, string outDir, int num)
    {
        string jpgPath = Path.Combine(outDir, string.Format("page_{0:00}.jpg", num));
        string pngPath = Path.Combine(outDir, string.Format("page_{0:00}.png", num));

        ImageCodecInfo jpgCodec = null;
        foreach (var c in ImageCodecInfo.GetImageEncoders())
            if (c.FormatID == ImageFormat.Jpeg.Guid) { jpgCodec = c; break; }

        using (var eps = new EncoderParameters(1))
        {
            eps.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, 94L);
            bmp.Save(jpgPath, jpgCodec, eps);
        }
        bmp.Save(pngPath, ImageFormat.Png);
    }

    public static void RenderAll(string specPath, string outDir)
    {
        string json = File.ReadAllText(specPath, Encoding.UTF8);
        var ser = new JavaScriptSerializer();
        ser.MaxJsonLength = 10 * 1024 * 1024;
        var root = (Dictionary<string, object>)ser.DeserializeObject(json);
        var pages = (object[])root["pages"];
        int total = pages.Length;
        var sf = MakeSF();

        foreach (Dictionary<string, object> p in pages)
        {
            int num = Convert.ToInt32(p["num"]);
            string kind = (string)p["kind"];
            Graphics g;
            using (var bmp = MakeCanvas(out g))
            using (g)
            {
                string hl = p.ContainsKey("header_left") ? (string)p["header_left"] : null;
                string hr = p.ContainsKey("header_right") ? (string)p["header_right"] : null;
                float y = DrawChrome(g, num, total, hl, hr, sf);

                if (kind == "cover")
                {
                    string eyebrow = (string)p["eyebrow"];
                    float ew = MeasureTextWidth(g, eyebrow, F_EYEBROW, sf);
                    using (var ep = RoundedRect(MARGIN_X, y, ew + 34f, 40f, 8f))
                    using (var ebg = new SolidBrush(Hex("#241C14")))
                    using (var epen = new Pen(Hex("#5B442C"), 2f))
                    using (var eb = new SolidBrush(Hex("#F0C37C")))
                    {
                        g.FillPath(ebg, ep); g.DrawPath(epen, ep);
                        g.DrawString(eyebrow, F_EYEBROW, eb, MARGIN_X + 17f, y + 7f, sf);
                    }
                    y += 66f;

                    using (var h1b = new SolidBrush(Hex("#F7F0E2")))
                        g.DrawString((string)p["title"], F_H1, h1b, MARGIN_X, y, sf);
                    y += 100f;
                    using (var subb = new SolidBrush(Hex("#D59E54")))
                        g.DrawString((string)p["subtitle"], F_SUB, subb, MARGIN_X, y, sf);
                    y += 60f;

                    var sp = (Dictionary<string, object>)p["spoiler"];
                    y = DrawCard(g, MARGIN_X, y, CONTENT_W, (string)sp["title"], null,
                        (object[])sp["paragraphs"], null, false,
                        "#2A1311", "#A63426", "#FF8E7C", "#D94B38", 28f, 22f, sf);
                    y += 24f;

                    var ab = (Dictionary<string, object>)p["about"];
                    y = DrawCard(g, MARGIN_X, y, CONTENT_W, (string)ab["title"], null,
                        (object[])ab["paragraphs"], null, false,
                        "#1B1714", "#3A2F24", "#F2E9D8", null, 28f, 22f, sf);
                    y += 24f;

                    y = DrawQuoteBox(g, MARGIN_X, y, CONTENT_W, (string)p["quote"], sf);
                    y += 24f;

                    var contrast = (object[])p["contrast"];
                    float gap = 22f;
                    float colW = (CONTENT_W - gap) / 2f;
                    var c0 = (Dictionary<string, object>)contrast[0];
                    var c1 = (Dictionary<string, object>)contrast[1];
                    float yl = DrawCard(g, MARGIN_X, y, colW, (string)c0["title"], null,
                        (object[])c0["paragraphs"], null, true,
                        "#1B1714", "#3A2F24", "#F0C37C", null, 22f, 20f, sf);
                    float yr = DrawCard(g, MARGIN_X + colW + gap, y, colW, (string)c1["title"], null,
                        (object[])c1["paragraphs"], null, true,
                        "#1B1714", "#3A2F24", "#F0C37C", null, 22f, 20f, sf);
                    y = Math.Max(yl, yr);
                }
                else if (kind == "cards")
                {
                    using (var h2b = new SolidBrush(Hex("#F2E9D8")))
                        g.DrawString((string)p["heading"], F_H2, h2b, MARGIN_X, y, sf);
                    y += 60f;
                    if (p.ContainsKey("lead"))
                    {
                        var leadLines = WrapParagraphs(g, (object[])p["lead"], CONTENT_W, true, sf);
                        y = DrawLines(g, leadLines, MARGIN_X, y, true, Hex("#B3A48F"), sf);
                        y += 20f;
                    }
                    else
                    {
                        y += 6f;
                    }
                    var cards = (object[])p["cards"];
                    foreach (Dictionary<string, object> c in cards)
                    {
                        bool cmp = c.ContainsKey("compact") && Convert.ToBoolean(c["compact"]);
                        string pill = c.ContainsKey("pill") ? (string)c["pill"] : null;
                        object[] ps = c.ContainsKey("paragraphs") ? (object[])c["paragraphs"] : null;
                        object[] bs = c.ContainsKey("bullets") ? (object[])c["bullets"] : null;
                        y = DrawCard(g, MARGIN_X, y, CONTENT_W, (string)c["title"], pill, ps, bs,
                            cmp, "#1B1714", "#3A2F24", "#F2E9D8", null, 24f, 19f, sf);
                        y += 20f;
                    }
                }
                else if (kind == "features")
                {
                    using (var h2b = new SolidBrush(Hex("#F2E9D8")))
                        g.DrawString((string)p["heading"], F_H2, h2b, MARGIN_X, y, sf);
                    y += 66f;

                    var tl = (Dictionary<string, object>)p["timeline_card"];
                    var introLines = WrapParagraphs(g, (object[])tl["intro"], CONTENT_W - 56f, true, sf);
                    var items = (object[])tl["items"];
                    var wrappedItems = new List<List<List<Tok>>>();
                    float tlStep = LineStep(true);
                    float tlH = 22f + 42f + introLines.Count * tlStep + 14f;
                    foreach (object[] it in items)
                    {
                        var wl = WrapParagraphs(g, it, CONTENT_W - 94f, true, sf);
                        wrappedItems.Add(wl);
                        tlH += wl.Count * tlStep + 12f;
                    }
                    tlH += 10f;

                    using (var tp = RoundedRect(MARGIN_X, y, CONTENT_W, tlH, 16f))
                    using (var tbg = new SolidBrush(Hex("#1B1714")))
                    using (var tpen = new Pen(Hex("#3A2F24"), 2f))
                        { g.FillPath(tbg, tp); g.DrawPath(tpen, tp); }

                    float cy = y + 22f;
                    using (var hb = new SolidBrush(Hex("#F2E9D8")))
                        g.DrawString((string)tl["title"], F_H3, hb, MARGIN_X + 28f, cy, sf);
                    DrawPill(g, MARGIN_X + CONTENT_W - 28f, cy + 2f, (string)tl["pill"], sf);
                    cy += 42f;
                    cy = DrawLines(g, introLines, MARGIN_X + 28f, cy, true, Hex("#E2D6C2"), sf);
                    cy += 14f;

                    float lx = MARGIN_X + 40f;
                    var nodeYs = new List<float>();
                    foreach (var wl in wrappedItems)
                    {
                        nodeYs.Add(cy + 14f);
                        cy = DrawLines(g, wl, MARGIN_X + 64f, cy, true, Hex("#E2D6C2"), sf);
                        cy += 12f;
                    }
                    if (nodeYs.Count >= 2)
                    {
                        using (var lpen = new Pen(Hex("#6A4F32"), 3f))
                            g.DrawLine(lpen, lx, nodeYs[0], lx, nodeYs[nodeYs.Count - 1]);
                    }
                    using (var dbr = new SolidBrush(Hex("#D59E54")))
                    using (var dpen = new Pen(Hex("#12100E"), 2f))
                    {
                        foreach (float ny in nodeYs)
                        {
                            g.FillEllipse(dbr, lx - 6f, ny - 6f, 12f, 12f);
                            g.DrawEllipse(dpen, lx - 6f, ny - 6f, 12f, 12f);
                        }
                    }
                    y += tlH + 22f;

                    var cc = (Dictionary<string, object>)p["choir_card"];
                    y = DrawCard(g, MARGIN_X, y, CONTENT_W, (string)cc["title"], (string)cc["pill"],
                        (object[])cc["paragraphs"], null, true,
                        "#1B1714", "#3A2F24", "#F2E9D8", null, 28f, 20f, sf);
                    y += 22f;

                    var pc = (Dictionary<string, object>)p["pipe_card"];
                    y = DrawCard(g, MARGIN_X, y, CONTENT_W, (string)pc["title"], (string)pc["pill"],
                        (object[])pc["paragraphs"], null, true,
                        "#1F1812", "#634628", "#F2E9D8", null, 28f, 20f, sf);
                }
                else if (kind == "rules")
                {
                    using (var h2b = new SolidBrush(Hex("#F2E9D8")))
                        g.DrawString((string)p["heading"], F_H2, h2b, MARGIN_X, y, sf);
                    y += 66f;

                    var rules = (object[])p["rules"];
                    foreach (Dictionary<string, object> r in rules)
                    {
                        var rParas = (object[])r["paragraphs"];
                        var wl = WrapParagraphs(g, (object[])rParas[0], CONTENT_W - 52f, true, sf);
                        float ch = 22f + 46f + wl.Count * LineStep(true) + 22f;
                        using (var rp = RoundedRect(MARGIN_X, y, CONTENT_W, ch, 16f))
                        using (var rbg = new SolidBrush(Hex("#1B1714")))
                        using (var rpen = new Pen(Hex("#3A2F24"), 2f))
                            { g.FillPath(rbg, rp); g.DrawPath(rpen, rp); }

                        float cx = MARGIN_X + 26f;
                        float rcy = y + 22f;
                        using (var cbg = new SolidBrush(Hex("#2E2216")))
                        using (var cpen = new Pen(Hex("#D59E54"), 2f))
                        using (var cbr = new SolidBrush(Hex("#F0C37C")))
                        using (var h3b = new SolidBrush(Hex("#F2E9D8")))
                        {
                            g.FillEllipse(cbg, cx, rcy, 38f, 38f);
                            g.DrawEllipse(cpen, cx, rcy, 38f, 38f);
                            string ns = Convert.ToString(r["num"]);
                            float nw = MeasureTextWidth(g, ns, F_NUM, sf);
                            g.DrawString(ns, F_NUM, cbr, cx + (38f - nw) / 2f, rcy + 4f, sf);
                            g.DrawString((string)r["title"], F_H3, h3b, cx + 52f, rcy + 2f, sf);
                        }
                        rcy += 48f;
                        DrawLines(g, wl, cx, rcy, true, Hex("#E2D6C2"), sf);
                        y += ch + 22f;
                    }

                    y = DrawQuoteBox(g, MARGIN_X, y, CONTENT_W, (string)p["closing"], sf);
                }

                if (y > FOOTER_Y - 24)
                    throw new Exception(string.Format("Vertical overflow on page {0}: {1} > {2}", num, y, FOOTER_Y - 24));

                SaveFrame(bmp, outDir, num);
            }
        }
    }
}
'@

[BriefRenderer]::RenderAll($SpecPath, $OutDir)
"""


def write_jpeg_pdf(jpeg_paths: list[pathlib.Path], out_pdf: pathlib.Path) -> None:
    """Assemble JPEG pages (1080x1920 @ 203.2 DPI = 382.68 x 680.31 pt) into PDF 1.4."""
    page_w_pt = 382.68
    page_h_pt = 680.31
    img_w = 1080
    img_h = 1920

    objects: list[bytes] = []

    def add_obj(body: bytes) -> int:
        objects.append(body)
        return len(objects)

    # 1: Catalog (placeholder updated once Pages id is known)
    add_obj(b"")
    # 2: Pages (placeholder)
    add_obj(b"")

    page_ids: list[int] = []
    for idx, jpath in enumerate(jpeg_paths):
        jpg_bytes = jpath.read_bytes()
        img_name = f"/Im{idx + 1}"
        img_dict = (
            f"<< /Type /XObject /Subtype /Image /Width {img_w} /Height {img_h} "
            f"/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode "
            f"/Length {len(jpg_bytes)} >>\nstream\n"
        ).encode("ascii") + jpg_bytes + b"\nendstream"
        img_id = add_obj(img_dict)

        content_str = f"q\n{page_w_pt:.2f} 0 0 {page_h_pt:.2f} 0 0 cm\n{img_name} Do\nQ\n".encode("ascii")
        content_obj = (
            f"<< /Length {len(content_str)} >>\nstream\n".encode("ascii")
            + content_str
            + b"endstream"
        )
        content_id = add_obj(content_obj)

        page_obj = (
            f"<< /Type /Page /Parent 2 0 R "
            f"/MediaBox [0 0 {page_w_pt:.2f} {page_h_pt:.2f}] "
            f"/Resources << /XObject << {img_name} {img_id} 0 R >> >> "
            f"/Contents {content_id} 0 R >>"
        ).encode("ascii")
        page_ids.append(add_obj(page_obj))

    kids = " ".join(f"{pid} 0 R" for pid in page_ids)
    objects[0] = b"<< /Type /Catalog /Pages 2 0 R >>"
    objects[1] = f"<< /Type /Pages /Kids [{kids}] /Count {len(page_ids)} >>".encode("ascii")

    buf = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets: list[int] = [0]
    for obj_num, body in enumerate(objects, start=1):
        offsets.append(len(buf))
        buf.extend(f"{obj_num} 0 obj\n".encode("ascii"))
        buf.extend(body)
        buf.extend(b"\nendobj\n")

    xref_pos = len(buf)
    buf.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    buf.extend(b"0000000000 65535 f \n")
    for off in offsets[1:]:
        buf.extend(f"{off:010d} 00000 n \n".encode("ascii"))

    buf.extend(
        (
            f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
            f"startxref\n{xref_pos}\n%%EOF\n"
        ).encode("ascii")
    )

    out_pdf.parent.mkdir(parents=True, exist_ok=True)
    out_pdf.write_bytes(bytes(buf))


def build_pdf(preview_dir: pathlib.Path | None = None) -> None:
    spec = build_spec()
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = pathlib.Path(tmp)
        spec_path = tmp_path / "spec.json"
        ps1_path = tmp_path / "render.ps1"
        render_dir = tmp_path / "frames"
        render_dir.mkdir(parents=True, exist_ok=True)

        spec_path.write_text(json.dumps(spec, ensure_ascii=False), encoding="utf-8")
        ps1_path.write_text(PS1_RENDERER, encoding="ascii")

        cmd = [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ps1_path),
            str(spec_path),
            str(render_dir),
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if res.returncode != 0:
            raise RuntimeError(
                f"Renderer failed (code={res.returncode}):\n{res.stdout}\n{res.stderr}"
            )

        jpgs = sorted(render_dir.glob("page_*.jpg"))
        pngs = sorted(render_dir.glob("page_*.png"))
        if len(jpgs) != len(spec["pages"]):
            raise RuntimeError(f"Expected {len(spec['pages'])} frames, got {len(jpgs)}")

        write_jpeg_pdf(jpgs, OUTPUT_PDF)

        if preview_dir is not None:
            preview_dir.mkdir(parents=True, exist_ok=True)
            for p in pngs:
                shutil.copy2(p, preview_dir / p.name)

    size_kb = OUTPUT_PDF.stat().st_size // 1024
    print(f"Generated {OUTPUT_PDF} ({len(spec['pages'])} pages, {size_kb} KB)")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build DEAD WIRE mobile PDF sound brief.")
    parser.add_argument(
        "--preview-dir",
        type=pathlib.Path,
        default=None,
        help="Optional directory to write page_01..06.png previews.",
    )
    args = parser.parse_args()
    build_pdf(args.preview_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
