# FORA — Default Design System
# Version: 1.0.0
#
# This file is read by generate.js and passed to the codegen prompt.
# It tells the code generator exactly how to style the output HTML.
#
# HOW TO CUSTOMISE
# ─────────────────────────────────────────────────────────────────
# This is your personal design system. Edit any value in this file.
# The code generator reads it on every run — changes apply immediately.
# See default.example.md for a heavily annotated walkthrough of each section.
#
# If the brief specifies design_system: "company", this file is ignored
# and the company's public DS is fetched instead. This file is always
# the fallback if the company DS fetch fails.
# ─────────────────────────────────────────────────────────────────

---

## DESIGN INTENT

This is a neutral, typographic design system. It is intentionally simple.
The page should feel like a well-considered document — not a portfolio showpiece.
Whitespace and type hierarchy do all the work. No decorative elements. No gradients.
No shadows. Structure is the design.

The goal: a hiring manager opens the page and reads it. Nothing gets in the way.

---

## COLOR TOKENS

Use these exact values as CSS custom properties on :root.

```
--color-bg:       #FFFFFF   /* Page background */
--color-surface:  #F7F7F5   /* Subtle off-white. Cards, code blocks, table headers */
--color-border:   #E5E5E3   /* All borders and dividers */
--color-ink:      #1A1A18   /* Primary text. Headings, body, labels */
--color-mid:      #4A4A47   /* Secondary text. Descriptions, sub-headings */
--color-muted:    #8A8A85   /* Tertiary text. Captions, metadata, placeholders */
--color-accent:   #1A1A18   /* Same as ink — accent is typographic, not chromatic */
--color-accent-soft: #F0EFE9 /* Warm off-white. Highlighted callouts, act headers */
```

Color philosophy: the palette is near-monochrome. Warmth comes from the paper-white
surface tone (#F7F7F5 and #F0EFE9 lean slightly warm, not cool). There is no blue,
no brand color, no decorative accent. This keeps the page visually neutral so it
works alongside any company's brand without clashing.

---

## TYPOGRAPHY

### Typefaces

Load both from Google Fonts. Add this to the <head>:

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
```

**Inter** — used for all body text, headings, navigation, and UI elements.
Clean, legible, designed for screens. Weight 300 for body, 400 for UI, 500–600 for headings.

**JetBrains Mono** — used for labels, metadata, badges, eyebrows, and any small
uppercase text. Never used for body paragraphs. Weight 400–500 only.

### Type scale

```
--font-sans: 'Inter', system-ui, -apple-system, sans-serif
--font-mono: 'JetBrains Mono', 'Fira Code', monospace

--text-xs:   11px  / line-height: 1.5  / font: mono    — labels, badges, eyebrows
--text-sm:   13px  / line-height: 1.7  / font: sans    — captions, metadata, fine print
--text-base: 15px  / line-height: 1.75 / font: sans    — body copy, descriptions
--text-md:   18px  / line-height: 1.5  / font: sans    — lead paragraphs, intro text
--text-lg:   24px  / line-height: 1.3  / font: sans    — section headings (h3)
--text-xl:   32px  / line-height: 1.2  / font: sans    — page headings (h2)
--text-2xl:  48px  / line-height: 1.05 / font: sans    — hero title (h1)
```

### Type rules

- Headings: font-weight 600. Letter-spacing -0.02em on large sizes (xl, 2xl).
- Body: font-weight 300 for long prose. 400 for shorter descriptions and UI text.
- Mono labels: always uppercase, letter-spacing 0.12em, font-weight 400 or 500.
- Never bold a body paragraph. Use a new sentence structure instead.
- Line length: cap body text at 620px max-width. Longer lines hurt readability.
- No underlines except on interactive hover states.

---

## SPACING SCALE

Use an 8px base unit. All spacing values are multiples of 8.

```
--space-1:   8px
--space-2:   16px
--space-3:   24px
--space-4:   32px
--space-5:   48px
--space-6:   64px
--space-7:   96px
--space-8:   128px
```

Section padding: 96px top and bottom (--space-7) on desktop. 48px on mobile.
Content max-width: 720px centered. Navigation max-width: 1080px.
Page horizontal padding: 40px on desktop, 24px on mobile.

---

## BORDERS AND RADIUS

No shadows anywhere. Depth is created through borders and background color contrast.

```
--border:        1px solid var(--color-border)
--border-strong: 1.5px solid var(--color-ink)
--radius-sm:     3px   — badges, chips, small elements
--radius-md:     6px   — cards, inputs
--radius-lg:     12px  — large cards, image containers
```

Use --border for most UI elements.
Use --border-strong for elements that need emphasis — selected state, act headers.
Never use box-shadow as a design element. If something needs to stand out, use
a background color change or a stronger border.

---

## LAYOUT

The page is a single column. No multi-column layouts on the main content area.
Supporting elements (signal cards, metadata grids) can use 2 or 3 columns.

```
Page max-width:    1080px (centered, for nav and full-bleed sections)
Content max-width:  720px (centered, for all body text and acts)
```

### Grid for signal cards and metadata (2 columns)

Use CSS grid with gap of 1px (creates border-like dividers between cells):
```css
display: grid;
grid-template-columns: 1fr 1fr;
gap: 1px;
background: var(--color-border); /* fills the 1px gaps */
border: var(--border);
```
Each cell: background var(--color-bg), padding 20px 24px.

### Grid for 3-column elements

Same pattern but grid-template-columns: 1fr 1fr 1fr.
On mobile (below 640px): collapse to 1 column.

---

## COMPONENTS

### Navigation

Fixed to top. White background. 1px border-bottom.
Left: designer's name in Inter 500, 14px, color ink.
Center or right: "For [Company]" badge in mono xs uppercase, surface background, border.
Far right: portfolio link, text-sm, color muted, no underline.
Height: 56px. Padding: 0 40px.

### Eyebrow / section label

Mono, xs (11px), uppercase, letter-spacing 0.12em, color muted.
Displayed above section headings. Never bold.
Example: "01 — WHO I AM"

### Section heading (h2)

Inter 600, xl (32px), letter-spacing -0.02em, color ink.
Margin-bottom: 8px after the eyebrow, 24px before body text.

### Body paragraph

Inter 300, base (15px), line-height 1.75, color mid, max-width 620px.
Paragraph spacing: 16px between paragraphs.

### Positioning line (Act 1 hero statement)

The single most important sentence on the page. Style it distinctly.
Inter 500, md (18px), line-height 1.6, color ink, max-width 560px.
Preceded by a 2px left border in color ink, padding-left 20px.
This is a blockquote-style element — not a heading, not body copy.

### Philosophy note

The philosophy quote from profile.json. Appears below the positioning line.
Inter 300 italic, base (15px), color mid, max-width 560px.
No quotation marks. No border. Just the italic weight to distinguish it.

### Work card (Act 2)

White background, border, radius-md (6px). No shadow.
Header row: surface background, border-bottom, padding 16px 20px.
  — Company + title in Inter 500 sm (13px), color ink
  — Role type badge in mono xs, surface, border, radius-sm
Body: padding 20px. Inter 300 base (15px), color mid.
Decision label: mono xs uppercase, color muted, margin-bottom 4px.
Decision text: Inter 400 sm (13px), color ink.
Outcome text: Inter 300 sm (13px), color mid.
Spacing between decision and outcome: 12px.

### Day commitment card (Act 3)

Three cards in a row (desktop) or stacked (mobile).
Each card: border on all sides, no radius on the outer container edges
(use a joined border pattern — cards share borders rather than having gaps).
Header: surface background, border-bottom, padding 12px 20px.
  — "Day 15", "Day 30", "Day 90" in mono xs uppercase, color muted
  — Commitment title in Inter 500 sm (13px), color ink
Body: padding 16px 20px. Inter 300 sm (13px), color mid, line-height 1.65.
Credibility anchor (optional small text at bottom): mono xs, color muted.

### Signal card

Compact. Used for skills, working style signals, tools.
Border, surface background, padding 16px 20px, radius-sm.
Label: mono xs uppercase, color muted, margin-bottom 6px.
Value: Inter 400 base (15px), color ink.
Optional sub-text: Inter 300 sm (13px), color mid.

### CTA section

The final section before footer. Dark background.
Background: var(--color-ink). Text: #FFFFFF.
Heading: Inter 600, xl (32px), letter-spacing -0.02em.
Sub-text: Inter 300, base (15px), opacity 0.7.
Button: white background, ink text, no border-radius, padding 12px 28px,
Inter 500, sm (13px), uppercase, letter-spacing 0.06em.
On hover: background var(--color-surface), color var(--color-ink).

### "What is this?" section

Surface background, border-top and border-bottom, padding 40px.
Label: mono xs uppercase, color muted, margin-bottom 8px.
Body: Inter 300, sm (13px), color mid, max-width 560px, line-height 1.75.
GitHub link: Inter 400, sm, color ink, underline on hover.

### Footer

Border-top. Padding 32px 40px. Display flex, space-between.
Left: designer's name, mono xs, color muted.
Right: portfolio, LinkedIn, email links — mono xs, color muted, no underline.
On hover: color ink.

---

## RESPONSIVE BREAKPOINTS

```
Desktop:  > 960px  — full layout as described above
Tablet:   640–960px — reduce padding, keep two-column grids
Mobile:   < 640px  — single column, 24px horizontal padding,
                      reduce heading sizes (2xl → xl, xl → lg)
```

On mobile:
- Navigation: name left, "For [Company]" badge right. Portfolio link hidden.
- All multi-column grids collapse to single column.
- Section padding: 48px top and bottom.
- Work cards and day cards stack vertically.

---

## WHAT NOT TO DO

These are hard rules. Do not override them regardless of what the brief says.

- No gradients on any element.
- No box-shadow on any element. Use border instead.
- No decorative background patterns, textures, or images.
- No full-width hero images or cover photos.
- No more than two typefaces (Inter and JetBrains Mono).
- No font sizes smaller than 11px.
- No color outside the palette above unless the brief specifies design_system: "company".
- No centered body text. Left-align all paragraphs.
- No animations except subtle opacity transitions on interactive elements (0.1s).
- No horizontal scrolling on any viewport.

---

## CODEGEN INSTRUCTION SUMMARY

When generating HTML from this system:

1. Load Inter and JetBrains Mono from Google Fonts.
2. Set all CSS custom properties on :root.
3. Use Inter 300 for body, 500–600 for headings, mono for all labels and eyebrows.
4. All spacing uses the 8px scale — no arbitrary pixel values.
5. Borders instead of shadows everywhere.
6. Single column content at 720px max-width, centered.
7. Signal card grids use the 1px gap / border background pattern.
8. CTA section is the only dark-background element.
9. Every section has an eyebrow label in mono xs uppercase.
10. The positioning line in Act 1 uses the left-border blockquote style.
11. The page must be fully responsive at the three breakpoints above.
12. Output a single self-contained HTML file. Inline all CSS as a <style> block.
    Do not use external CSS files. Do not use CSS frameworks.
