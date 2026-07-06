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
| `profile/profile-template.json` | ✓ Built |
| `profile/imports/` | ✓ Built |
| `prompts/brainstorm-prompt.md` | ✓ Built (v2.1.0) |
| `prompts/codegen-prompt.md` | ✓ Built |
| `prompts/profile-builder-prompt.md` | ✓ Built |
| `prompts/ds-builder-prompt.md` | ✓ Built |
| `briefs/example-brief.json` | ✓ Built |
| `design-system/default.md` | ✓ Built |
| `templates/sections/*.html` | ✓ Built (8 files) |
| `templates/*.json` | ✓ Built (3 templates) |
| `generate.js` | ✓ Built |
| `brainstorm.sh` | ✓ Built |
| `.env.example` | ✓ Built |
| `README.md` | ✓ Built |
| `SETUP.md` | ✓ Built |
| `package.json` | ✓ Built |
| First real application end-to-end | ← next milestone |

---

## MVP — Prove the pipeline works

**Goal:** one designer, one JD, one deployed page, one cold message.
**Success metric:** live URL from JD URL in under 15 minutes, unassisted.

### What's built

**`design-system/default.md`**
Full token set — color, typography, spacing, borders, components, responsive rules,
codegen instruction summary. Committed to the public repo (not sensitive data).
Configurable via `prompts/ds-builder-prompt.md` — accepts portfolio URL, DS link,
Figma tokens, CSS file, or plain description. Optional step, never a blocker.

**`templates/sections/` — 8 files**

Static (pre-built, never touched by codegen):
- `nav.html` — top navigation bar with name + "For [Company]" badge
- `footer.html` — minimal footer with portfolio, LinkedIn, email

Slot-based (codegen fills `{{slot}}` placeholders):
- `act1_hero.html` — positioning statement, philosophy note, signals
- `act2_work.html` — 2–3 proof-of-work entries with media support
- `act3_bring.html` — 15/30/90 day commitments
- `signal_cards.html` — skills, working style, tools
- `direct_cta.html` — call to action with contact link

**`templates/*.json` — 3 template definitions**
- `three-act.json` — default: hero → work → bring → signals → cta
- `work-first.json` — leads with proof of work, hero second
- `single-statement.json` — minimal: one strong statement + one case study + cta

**`generate.js`** — the pipeline, two modes

`--run briefs/[slug].json`
```
read brief → load default.md (or fetch company DS) → call Anthropic API per section
→ assemble full HTML → write output/[slug]/index.html
```

`--publish briefs/[slug].json`
```
--run + deploy to Vercel → return live URL
```

Media support: base64-encodes local images (jpeg/png/gif), embeds Loom/YouTube/Figma
via iframe. resolveMedia() is Option A — swap to CDN upload (Option B) without touching
anything else.

**`brainstorm.sh`**
Fetches JD via curl, assembles prompt + profile.json + JD text, copies to clipboard.
Cross-platform (pbcopy / xclip / xsel). One command → paste into any AI chat.

**`prompts/brainstorm-prompt.md` (v2.1.0)**
Phase 1: JD analysis + Opportunity Model (auto-runs).
Phase 2: narrative brainstorm — Act 1 emphasis, Act 2 works, Act 3 commitments, DS direction, template.
Phase 2B: iteration without regenerating the full proposal.
Phase 2C: media collection per work entry — URL or local filename, caption written and confirmed.
Phase 3: locks content_brief.json + outputs assets checklist.

**`prompts/profile-builder-prompt.md`**
4-phase AI-assisted profile builder. Accepts resume, LinkedIn export, case study notes,
anything. Drafts full profile.json, walks designer through review section by section.
One-time setup, update incrementally as work grows.

**`prompts/ds-builder-prompt.md`**
Optional. Configures design-system/default.md to match designer's personal brand.
Accepts portfolio URL, DS/Storybook link, Figma tokens, CSS file, or plain description.
Outputs complete configured default.md with "what changed" summary.

### MVP milestone checklist

- [x] `default.md` written with full token set and codegen instructions
- [x] All 8 section HTML files built
- [x] All 3 template JSONs built
- [x] `codegen-prompt.md` written with media rendering rules
- [x] `generate.js` built — `--run` and `--publish` modes
- [x] `brainstorm.sh` built and tested
- [x] `profile-builder-prompt.md` written
- [x] `ds-builder-prompt.md` written
- [x] `README.md` and `SETUP.md` written
- [ ] First real `profile.json` built from actual career materials
- [ ] First real brainstorm run against a live JD
- [ ] `generate.js --run` produces a valid HTML page locally
- [ ] `generate.js --publish` produces a live URL
- [ ] README updated with screenshot of real output
- [ ] End-to-end run from JD URL to live page documented

---

## V1 — Any designer can run this

**Goal:** a designer who has never used FORA can clone, onboard, and deploy in one afternoon unassisted.
**Success metric:** first person outside the builder deploys successfully without asking for help.

### What V1 adds (MVP carries forward unchanged)

**`applications/applications.json`** schema + tracking
Local log of every brief run and every page deployed. Grows with every application.
Seed the schema now, read it in V1. Commit the structure (personal data gitignored).

**`generate.js` updates**
- PostHog snippet injected into every deployed page
- Output versioning — each save creates `v1.html`, `v2.html`, etc.
- `design-system/user.css` loaded as override layer after codegen

**`brainstorm.sh` → interactive CLI**
Currently: assembles prompt + copies to clipboard.
V1: interactive session — media files dragged in during the chat get auto-saved to `assets/`,
brief gets auto-saved to `briefs/`. The "dream flow" — no manual file management.

**`CLAUDE.md`** — repo context file for AI tools (Cursor, Copilot, etc.)

**`CONTRIBUTING.md`** — for the open-source community

**Tagline update**
"Turn a job description into a personalised application landing page" → something closer to
what FORA actually is: a career intelligence tool for designers who apply intentionally.

**`README.md`** — add screenshot / live example
The single biggest friction point for open-source traction. Add after first real deployment.

### V1 milestone checklist

- [ ] First external user deploys successfully unassisted
- [ ] `applications.json` schema committed, tracking wired into `--publish`
- [ ] PostHog injected and tracking page views per application
- [ ] Output versioning working
- [ ] `brainstorm.sh` upgraded to interactive CLI with auto file management
- [ ] `CLAUDE.md` written
- [ ] `CONTRIBUTING.md` written
- [ ] README screenshot added from real deployment
- [ ] Tagline updated
- [ ] `brainstorm.ps1` for Windows (or documented as community contribution)
- [ ] Repo polished and ready for public promotion
- [ ] Content launch: post, thread, or blog linking to repo

---

## What comes after V1

V2 introduces the agent layer: crawler, confidence scorer, company intelligence, analytics agent,
and the orchestrator that connects them. None of this is needed to prove the product works.
V2 is earned after V1 has real users producing real applications.

---

## Build order (completed for MVP, V1 next)

```
default.md              ✓
    ↓
section HTML files      ✓ (8 files)
    ↓
template JSONs          ✓ (3 files)
    ↓
codegen-prompt.md       ✓
    ↓
generate.js             ✓
    ↓
first real application  ← here now
    ↓
README screenshot       ← after first deploy
    ↓
V1 features             ← after first external user
```
