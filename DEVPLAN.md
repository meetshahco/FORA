# FORA — Development Plan

> A career operating system that captures your experience as structured knowledge,
> collaborates with you to choose the strongest narrative for each opportunity,
> and generates personalised application assets — while learning from every outcome.

---

## Guiding principle

Build the simplest thing that proves the workflow works. Ship it to yourself first.
Every persisted artifact, every scored dimension, every agent — earned only after the
simple version has produced real applications and real outcomes.

The 15-minute test: a designer who has never heard of FORA should be able to clone
the repo, fill their profile, run the brainstorm, and have a live URL — in one afternoon.

---

## Current status

| Artifact | Status |
|---|---|
| `profile.json` | Built |
| `brainstorm-prompt.md` | Built |
| `example-brief.json` | Built |
| `default.md` | To build (MVP blocker) |
| `templates/sections/*.html` | To build |
| `templates/*.json` | To build |
| `codegen-prompt.md` | To build |
| `generate.js` | To build |

---

## MVP — Prove the pipeline works

**Goal:** one designer, one JD, one deployed page, one cold message.
**Success metric:** live URL from JD URL in under 15 minutes, unassisted.

### What to build

**1. `design-system/default.md`** ← build this first, it blocks everything else

Your visual system written as LLM-consumable codegen instructions:
- Color tokens (backgrounds, foregrounds, accents)
- Typography (font families, sizes, weights, line heights)
- Spacing scale
- Border radius / component patterns
- Tone rules (what the generated copy should feel like)
- Component patterns (how cards, CTAs, grids should look)

Format: prose instructions + example CSS variables. Not a Figma handoff — written for an LLM to generate matching HTML from.

---

**2. `templates/sections/` — 8 files**

Static (never touched by LLM):
- `nav.html` — top navigation bar with name + links
- `footer.html` — minimal footer
- `whats_this.html` — one-paragraph explanation of FORA on every page

Slot-based (codegen fills the `{{slot}}` placeholders):
- `act1_hero.html` — opening positioning statement + headline
- `act2_work.html` — 2–3 proof-of-work case studies
- `act3_bring.html` — 15/30/90 day commitments for this specific role
- `signal_cards.html` — 3–4 signal cards (skills, indicators, context)
- `direct_cta.html` — one clear call-to-action with contact link

---

**3. `templates/*.json` — 3 template definitions**

Each file defines section order and which brief fields map to which slots.

- `three-act.json` — default: hero → work → bring → signals → cta
- `work-first.json` — leads with proof of work, hero second
- `single-statement.json` — minimal: one strong statement + one case study + cta

---

**4. `prompts/codegen-prompt.md`**

System prompt for the codegen call. Receives:
- `execution_plan` (in-memory, not persisted)
- DS tokens from `default.md`
- Section spec (slot definitions)

Outputs clean, self-contained HTML block per dynamic section.
Called once per dynamic section by `generate.js`.

---

**5. `generate.js`** — the only script, two modes

**`--run briefs/[slug].json`**
```
read brief
→ load default.md (or fetch company DS if brief.design_system === "company")
→ build execution plan in memory
→ call codegen for each dynamic section
→ assemble full HTML (static + dynamic sections)
→ write output/[slug]/current.html
→ deploy to Vercel preview
→ start file watcher (redeploy on save)
```

**`--publish`**
```
promote current.html to live Vercel URL
→ append record to applications/applications.json
→ generate cold message (one LLM call)
→ print live URL + cold message
→ stop watcher
```

What to deliberately NOT build in MVP:
- `run.json` (state persistence — rerun if it fails)
- `execution_plan.json` (keep it in memory)
- confidence scorer (you know which roles to apply to)
- opportunity model as a separate artifact (brainstorm does this inline)
- story performance tracking (seed the fields, don't read them yet)

---

**6. `.env.example` + rough `README.md`**

README covers: clone → fill profile → run brainstorm → run generate → get URL.
Ten steps max. Polish in V1.

---

### MVP file tree (what gets committed)

```
FORA/
├── .env.example
├── .gitignore
├── generate.js
├── brainstorm.sh
├── DEVPLAN.md
├── README.md (rough)
│
├── profile/
│   ├── profile.json           ← yours, already built
│   ├── profile-template.json  ← blank + instructions (V1)
│   └── imports/               ← drop resume, LinkedIn, decks here
│
├── prompts/
│   ├── brainstorm-prompt.md   ← already built
│   └── codegen-prompt.md      ← build in MVP
│
├── design-system/
│   └── default.md             ← build first — MVP blocker
│
├── templates/
│   ├── sections/
│   │   ├── nav.html
│   │   ├── footer.html
│   │   ├── whats_this.html
│   │   ├── act1_hero.html
│   │   ├── act2_work.html
│   │   ├── act3_bring.html
│   │   ├── signal_cards.html
│   │   └── direct_cta.html
│   ├── three-act.json
│   ├── work-first.json
│   └── single-statement.json
│
├── briefs/
│   └── example-brief.json     ← already built
│
└── applications/
    └── applications.json      ← auto-written, grows with every deploy
```

---

### MVP milestone checklist

- [ ] `default.md` written and tested with a manual codegen call
- [ ] All 8 section HTML files built
- [ ] All 3 template JSONs built
- [ ] `codegen-prompt.md` written
- [ ] `generate.js --run` produces a valid HTML page locally
- [ ] `generate.js --run` deploys to Vercel preview
- [ ] File watcher redeploys on save
- [ ] `generate.js --publish` produces a live URL
- [ ] `generate.js --publish` logs to `applications.json`
- [ ] Cold message printed in terminal
- [ ] End-to-end run from JD URL to live page in under 15 minutes

---

## V1 — Any designer can run this

**Goal:** a designer who has never used FORA can clone, onboard, and deploy in one afternoon unassisted.
**Success metric:** first person outside the builder deploys successfully without asking for help.

### What V1 adds (MVP carries forward unchanged)

**`prompts/profile-builder-prompt.md`**
Drop resume + LinkedIn export + case study decks into `profile/imports/`.
Run this prompt in any AI. `profile.json` generated in ~20 minutes.
Reduces onboarding from 2 hours (manual) to 20 minutes.

**`profile/profile-template.json`**
Blank `profile.json` with field-by-field inline instructions.
For designers who prefer manual entry over the import prompt.

**`templates/work-first.json`** (if not shipped in MVP)
Third template option — leads with proof of work rather than positioning.

**`design-system/user.css`** (documented, gitignored)
Designer-specific CSS override layer. Loaded on top of the generated DS tokens.
Never committed — personal to each FORA installation.

**`generate.js` updates**
- PostHog snippet injected into every deployed page
- `output/` versioning — each save creates `v1.html`, `v2.html`, etc.
- `user.css` loaded as DS override layer after codegen

**`README.md`** — full version
Setup in under 10 steps. Two commands. Written for a designer, not a developer.
Covers: setup, profile building (manual + import), brainstorm, generate, publish, tweak.

**`templates/README.md`**
Documents how to build a custom template. Non-developers should be able to follow it.

**`brainstorm.sh` / `brainstorm.ps1`** (if not in MVP)
Shell script that fetches the JD, assembles the full prompt + profile.json + JD text,
and copies it to clipboard. One command → ready to paste into any AI chat.

---

### V1 milestone checklist

- [ ] `profile-builder-prompt.md` tested — produces valid `profile.json` from real import files
- [ ] `profile-template.json` complete with inline instructions for every field
- [ ] PostHog injected and tracking page views per application
- [ ] Output versioning working (`v1.html`, `v2.html`, ...)
- [ ] `user.css` override documented and gitignored
- [ ] `README.md` tested — someone unfamiliar with FORA reads it and deploys without help
- [ ] `templates/README.md` written
- [ ] `brainstorm.sh` tested on Mac + Linux
- [ ] `brainstorm.ps1` tested on Windows (or documented as community contribution)
- [ ] Repo polished and ready for public GitHub push
- [ ] Content launch: post, thread, or blog linking to repo

---

## What comes after V1

V2 introduces the agent layer: crawler, confidence scorer, company intelligence, analytics agent,
and the orchestrator that connects them. None of this is needed to prove the product works.
V2 is earned after V1 has real users producing real applications.

Full V2 and V3 spec: see `applyOS_v5_responsive.html` (architecture reference).

---

## Build order

```
default.md              ← start here
    ↓
section HTML files      ← 8 files, build static first
    ↓
template JSONs          ← 3 files, 30 minutes
    ↓
codegen-prompt.md       ← write once, test with a manual API call
    ↓
generate.js             ← wire it all together
    ↓
first real application  ← run the pipeline end to end
    ↓
README.md               ← write after you've done it once yourself
```
