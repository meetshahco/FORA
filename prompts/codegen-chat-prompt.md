# FORA — Codegen Chat Prompt
# This prompt is assembled by codegen.sh and copied to your clipboard.
# Paste it into any AI chat to generate the complete application page HTML.
# ──────────────────────────────────────────────────────────────────────────

You are generating a personalised application landing page for a designer using the FORA pipeline.

You will receive everything you need in this message:
1. A content brief (the copy, structure, and data for this application)
2. HTML section templates (the exact markup to fill in)
3. CSS design system tokens (the visual language)
4. A base HTML shell (fonts, reset, utilities)

Your output is a **single, complete, self-contained HTML file** — ready to open in a browser with no further editing.

---

## OUTPUT RULES

1. Output only the complete HTML file. Start with `<!DOCTYPE html>` and end with `</html>`. No explanation, no markdown fences around the whole file, no commentary before or after.
2. Fill every `{{slot_name}}` placeholder in the templates with real content from the brief. No unfilled placeholders in the output.
3. If a slot value is null, empty, or missing — omit the element entirely. No empty tags, no placeholder text like "TBD" or "[role]".
4. Do not add sections, elements, or decorative flourishes not in the templates. The templates are final.
5. Do not invent copy. Every word must trace to the brief.
6. Respect tone_notes from the brief exactly.
7. Do not soften outcomes — if the brief says "doubled activation rate", write that exactly.
8. Use ONLY the class names defined in the section templates and `_base.html`. Do not invent new class names.
   Wrong: `class="fora-title"`, `class="fora-header"`, `class="fora-day-column"`, `class="fora-positioning-line"`
   Right: `class="fora-act1__heading"`, `class="fora-eyebrow"`, `class="fora-day-card"`, `class="fora-act1__positioning"`
   If a class name is not in the template or base styles, do not use it.
9. Each section is rendered exactly once. Do not repeat or duplicate any section.
10. Do not add any `<style>` blocks beyond what the templates already include. All styling comes from `_base.html` and the section templates.
11. If a slot value is null, an empty string, or explicitly false:
    omit the element that would have contained it entirely.
    Do not render empty tags, empty links, or placeholder text.
12. If a required brief field is missing or undefined:
    leave that slot visually absent but do not fabricate content.
    For text slots: render an empty string. For link slots: omit the element entirely.
    Never generate placeholder text like "Coming soon", "TBD", or "[role]".
13. Do not add decorative elements, dividers, icons, illustrations,
    or visual flourishes not specified in the section template or brief.
    The design system is intentionally minimal. Restraint is the correct output.

---

## PAGE STRUCTURE

This order is fixed. Do not reorder, skip, or duplicate any section.

```
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{page_title}}</title>
  <!-- base HTML injected here (fonts, reset, DS tokens) -->
</head>
<body>
  <!-- 1. nav -->
  <!-- 2. act1_hero -->
  <!-- 3. act2_work -->
  <!-- 4. act3_bring -->
  <!-- 5. direct_cta -->
  <!-- 6. footer -->
</body>
</html>
```

Every section must appear exactly once, in this exact order. If a section has no content, render it with a minimal fallback — do not skip it or move it.

---

## SECTION-SPECIFIC RULES

**nav:** The badge renders as `<span class="fora-nav__badge">`. Always include an img tag inside the badge span — fill `src` with the value of `_meta.company_logo_url` from the brief (e.g. `https://logo.clearbit.com/nola.money`) and `alt` with `_meta.company`. Always add `onerror="this.style.display='none'"` so broken images disappear silently. Do not skip this img even if you are unsure the URL works — the onerror handles it. If `static_wrapper.portfolio_url` is null, omit the portfolio link.

**act1_hero:** `philosophy_note` renders as `<p class="fora-act1__philosophy">` — italic, no quotation marks. Signals render as `.fora-signal-card` items inside `.fora-act1__signals` grid. Each signal card: `<div class="fora-signal-card"><span class="fora-signal-card__label">…</span><p class="fora-signal-card__value">…</p></div>`.

**act2_work:** Render one element per work in `works[]`, in order, using `section_format`:
- `featured_project` → `.fora-work-card` — header with `.fora-work-card__company` + `.fora-work-card__badge`, body with `.fora-work-card__framing`, then `.fora-work-card__label` + `.fora-work-card__decision`, then `.fora-work-card__label` + `.fora-work-card__outcome`
- `timeline_entry` → `.fora-work-card` with timeline styling (same structure, lighter treatment)
- `signal_card` → `.fora-signal-card` inside a `.fora-signals__grid`

**act3_bring:** Three columns (day_15, day_30, day_90) inside `.fora-act3__grid`. Each column is a `.fora-day-card` with `.fora-day-card__header` (containing `.fora-day-card__label` + `.fora-day-card__title`) and `.fora-day-card__body`. `credibility_anchor` fields are context only — never render them on the page.

**direct_cta:** Dark section — background `var(--color-ink)`, all text white. CTA button: white text, mono font, no fill (transparent background), 1px white border. On hover: rgba(255,255,255,0.1) background. Cold message renders as italic quote in a subdued block.

**footer:** Omit any link where the URL is null.

---
