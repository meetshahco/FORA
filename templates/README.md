# FORA Templates

A template controls which sections appear on the page, in what order, and how each section behaves. Three templates are included out of the box. You can build your own.

Set the template in your content brief: `_meta.template_id = "three-act"` — or leave it empty to default to `three-act`. You'll be prompted to choose during `brainstorm.sh`.

---

## Three Act `three-act`

The default. Leads with identity, follows with proof of work, closes with a commitment plan. Works for almost any role and seniority level.

```
┌─────────────────────────────┐
│  Nav                        │  sticky, company badge + portfolio link
├─────────────────────────────┤
│  01 — Who I Am              │  heading + positioning line + philosophy + signals grid
├─────────────────────────────┤
│  02 — What I've Done        │  up to 3 work entries (featured, signal, timeline)
├─────────────────────────────┤
│  03 — What I'll Bring       │  day 15 / day 30 / day 90 commitment grid
├─────────────────────────────┤
│  CTA                        │  dark section, email + button
├─────────────────────────────┤
│  Footer                     │  name + links
└─────────────────────────────┘
```

**Best for:** Senior IC, founding designer, player-coach. Any role where identity and narrative need to come before the work. General purpose default when you're unsure.

**Signals:** Inline inside Act 1, below the philosophy note (2-column grid).

**Works:** Up to 3. Mix of `featured_project`, `signal_card`, and `timeline_entry` formats.

**Example:** `examples/alex-rivera/output/index.html`

---

## Work First `work-first`

Leads with proof of work before identity. The work speaks first — who you are contextualises it. Sections 01 and 02 swap order.

```
┌─────────────────────────────┐
│  Nav                        │  sticky, company badge + portfolio link
├─────────────────────────────┤
│  01 — The Work              │  up to 3 work entries, opens strong with no preamble
├─────────────────────────────┤
│  02 — Who I Am              │  heading + positioning + philosophy + signals grid
├─────────────────────────────┤
│  03 — What I'll Bring       │  day 15 / day 30 / day 90 commitment grid
├─────────────────────────────┤
│  CTA                        │  dark section, email + button
├─────────────────────────────┤
│  Footer                     │  name + links
└─────────────────────────────┘
```

**Best for:** Senior IC roles. Research-heavy or craft-focused companies where showing is more credible than telling. Roles where the JD lists specific outputs expected. Engineering-culture companies.

**Signals:** Inline inside Act 2 (Who I Am), same as three-act but lower on page.

**Works:** Up to 3. Act 2 (the work section) opens without eyebrow preamble — the first work entry carries the opening weight.

**Example:** `examples/alex-rivera-work-first/output/index.html`

---

## Single Statement `single-statement`

Minimal. One strong positioning statement, one case study, one commitment plan, one CTA. Nothing extra. Restraint is the design.

```
┌─────────────────────────────┐
│  Nav                        │  sticky, company badge + portfolio link
├─────────────────────────────┤
│  (no eyebrow)               │  positioning line as the h1 heading — not your name
├─────────────────────────────┤
│  The work                   │  exactly one work entry, strongest match only
├─────────────────────────────┤
│  The first 90 days          │  day 15 / day 30 / day 90 (no heading)
├─────────────────────────────┤
│  CTA                        │  dark section, email + button
├─────────────────────────────┤
│  Footer                     │  name + links
└─────────────────────────────┘
```

**Best for:** Design-forward or taste-conscious companies where restraint signals taste. Leadership roles where one strong story outweighs a list. Situations where the brief has one standout case study and adding more would dilute it. Companies with very clean, minimal brand identities.

**Signals:** Excluded entirely. No signal grid.

**Works:** Exactly 1. The strongest match from your brief's `works[]` array. Framing angle carries more weight when there's only one story.

**Example:** `examples/alex-rivera-single-statement/output/index.html`

---

## Template schema

```json
{
  "_meta": {
    "id": "three-act",
    "name": "Three Act",
    "description": "...",
    "best_for": "..."
  },
  "section_order": ["nav", "act1_hero", "act2_work", "act3_bring", "direct_cta", "footer"],
  "section_config": {
    "act2_work": { "max_works": 3 },
    "act1_hero": { "include_signals_inline": true, "signals_position": "below_philosophy" },
    "act3_bring": { "show_credibility_anchors": false },
    "signal_cards": { "standalone": false }
  },
  "slot_map": {}
}
```

**`section_order`** — array of section IDs in render order. Each ID must match an HTML file in `templates/sections/`. Available: `nav`, `act1_hero`, `act2_work`, `act3_bring`, `direct_cta`, `footer`, `signal_cards`.

**`section_config`** — per-section behaviour. All fields optional.

| Section | Key | Type | Description |
|---|---|---|---|
| `act2_work` | `max_works` | number | Max work entries to render (default: 3) |
| `act1_hero` | `include_signals_inline` | boolean | Render signal grid inside Act 1 (default: true) |
| `act1_hero` | `signals_position` | string | `below_philosophy` or `below_positioning` |
| `act3_bring` | `show_credibility_anchors` | boolean | Always false — anchors are AI context only, never rendered |
| `signal_cards` | `standalone` | boolean | If false, section is skipped (signals already inline in act1) |

**`slot_map`** — maps slot names to brief field paths. Leave empty `{}` for defaults. Only needed when building custom templates with non-standard slot names.

---

## Building a custom template

1. Copy any existing template JSON from `templates/`
2. Rename it (e.g. `templates/my-template.json`)
3. Edit `section_order` to your preferred sequence
4. Set `template_id` in your brief to match the filename (without `.json`)
5. Run: `node generate.js --run briefs/your-brief.json`

The template is selected per-application via the brief — not globally.

---

## Adding a new section

1. Create `templates/sections/your-section.html` with `{{slot_name}}` placeholders
2. Document the slots in a comment block at the top of the file
3. Add all component CSS for the section to `templates/sections/_base.html` — not in the section file itself
4. Add the section ID to any template's `section_order`
5. Add a brief slice handler in `generate.js` → `buildSectionBrief()`
