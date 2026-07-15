# FORA — Roadmap

FORA is an open-source agentic pipeline that turns a job description into a personalised application landing page. This document tracks what has been built, what is in progress, and what comes next.

---

## Guiding principles

**Pipeline over product.** The core value is a reliable, repeatable workflow. Every feature is justified by whether it makes that workflow faster, more accurate, or more accessible to a new user.

**The 15-minute test.** A designer who has never used FORA should be able to clone the repo, fill their profile, run the brainstorm, and have a live URL — in one afternoon, unassisted.

**Earn each layer.** No V2 features (agents, scoring, analytics) until the V1 workflow has produced real applications for real users and the data shows what actually needs improving.

**Architecture is locked.** The key decisions below were established in design and correctly implemented. They should not be revisited without strong evidence.

---

## Architecture decisions — do not change

| Decision | Rationale |
|---|---|
| Tool-agnostic brainstorm | `brainstorm.sh` copies to clipboard — designer pastes into any AI chat. No Claude dependency, no API key required for this step. |
| No external npm dependencies | Core pipeline uses only Node.js built-ins. `npm install` is not required to run the pipeline. |
| DS decision at brief level | `brief._meta.design_system` is `own` or `company`. Own loads `default.md`. Company fetches the public DS URL at runtime, extracts tokens, discards — never saved to disk. Falls back to `default.md` on any failure. |
| Section brief slicing | `buildSectionBrief()` sends only the relevant brief slice per codegen call, not the full profile and brief. Keeps context lean, costs down. |
| Media as base64 | Local images resolved to base64 data URIs — pages are self-contained single files. No asset folder management, no relative path issues on deploy. |
| Mode selection per application | Designer picks mode in `run.sh` each time, not once during setup. Keys in `.env` determine which modes are available. |
| Profile is always private | `profile.json`, `briefs/`, `output/`, `.env` all gitignored. Only the pipeline code is public. |

---

## V0 — Pipeline ✓ Complete

**Goal:** a working end-to-end pipeline. JD URL → brainstorm → brief → generated HTML → deployed live URL.

**Status:** shipped. Pipeline runs. All six modules complete. Three templates. Multi-provider AI support.

### What was built

| Artifact | Status |
|---|---|
| `generate.js` — six-module pipeline | ✓ |
| `--run`, `--deploy`, `--publish` CLI modes | ✓ |
| Multi-provider AI: Anthropic, Gemini, OpenAI | ✓ |
| `brainstorm.sh` — JD fetch, prompt assembly, clipboard | ✓ |
| `run.sh` — guided end-to-end workflow | ✓ |
| `setup.sh` — health check, dependency check, `.env` writer | ✓ |
| `brainstorm-prompt.md` v2.1 — three phases, DS direction, template picker | ✓ |
| `codegen-prompt.md` — section rules, media rendering, copy guardrails | ✓ |
| `profile-builder-prompt.md` — four-phase AI-assisted profile builder | ✓ |
| `ds-builder-prompt.md` — optional DS configuration from portfolio/Figma/CSS | ✓ |
| `design-system/default.md` — full token set, codegen instructions | ✓ |
| `templates/sections/_base.html` — reset, global CSS, all component styles | ✓ |
| Section templates: `nav`, `act1_hero`, `act2_work`, `act3_bring`, `direct_cta`, `footer`, `signal_cards` | ✓ |
| Template JSONs: `three-act`, `work-first`, `single-statement` | ✓ |
| `applications/applications.json` — local log of all deployed pages | ✓ |
| `examples/alex-rivera/` — fictional example, all three templates | ✓ |
| `README.md`, `SETUP.md`, `CHANGELOG.md`, `CONTRIBUTING.md` | ✓ |
| `templates/README.md` — template schema docs, custom template guide | ✓ |
| `briefs/README.md` — brief field reference | ✓ |
| `SECURITY.md` — API key handling, gitignore guidance | ✓ |
| `LICENSE` — MIT | ✓ |
| `about/index.html` — FORA explainer page, deployed alongside every application | ✓ |

### Key fixes shipped post-launch

- DS token cascade order — tokens now inject after base styles and correctly override defaults
- Work card BEM structure — codegen prompts now include literal HTML skeleton, not descriptions
- Terminal end-of-run output — local preview first, then live URL, then cold message verbatim
- Vercel URL — `VERCEL_URL` env var eliminates guessing from async `deployment.aliases`
- Duplicate section safety net — generate.js strips duplicate sections from codegen output
- Job board slug detection — LinkedIn, Greenhouse, Lever, Workable, and 8 others use `job-<id>` as filename
- Copy guardrails — no em-dashes, no AI language, sentence variation enforced in all prompts
- Template picker moved before AI chat — brief is generated with correct structure from the start
- Example output routing — briefs in `examples/*/` write to `examples/*/output/`, not root `output/`

---

## V1 — Any designer can run this

**Goal:** a designer who has never used FORA can clone, onboard, and deploy in one afternoon unassisted.

**Success metric:** first person outside the original builder deploys successfully without asking for help.

### What V1 adds

**README screenshot / live example link**
The single highest-leverage improvement available. A screenshot or live URL between the title and Quick Start turns the repo from a pipeline description into a product with visible proof. Add after the first real deployment is public.

**`CLAUDE.md` — repo context file**
Machine-readable repo context for AI coding tools (Cursor, Copilot, Claude Code). Describes the module map, key files, and what not to touch. Makes AI-assisted contributions more accurate.

**PostHog analytics**
Snippet injected into every deployed page. Tracks `page_view` per application — slug, company, template. Opt-in via `POSTHOG_API_KEY` in `.env`. Enables the outcome tracking in V2.

**Output versioning**
Each `--run` on the same brief produces `v1.html`, `v2.html` etc. instead of overwriting. Enables A/B comparison and rollback.

**`brainstorm.sh` — brief auto-save improvements**
Currently: saves brief from clipboard, launches `run.sh`. Target: auto-detect when JSON appears in clipboard, reduce manual copy step, improve recovery flow when brief save fails mid-session.

**Windows support**
`brainstorm.sh` is bash-only. Either `brainstorm.ps1` (PowerShell) or a Node.js equivalent. Documented as a community contribution target.

**Content launch**
Post, thread, or short writeup linking to the repo. Brings in first external users, generates first external feedback.

### V1 checklist

- [ ] README screenshot added from a real deployed page
- [ ] `CLAUDE.md` written
- [ ] PostHog snippet injected in assembler, opt-in via `.env`
- [ ] Output versioning in `generate.js`
- [ ] `brainstorm.sh` auto-save improvements
- [ ] First external user deploys successfully unassisted
- [ ] `brainstorm.ps1` or Node.js equivalent for Windows (community)
- [ ] Content launch

---

## V2 — Intelligence layer

**Goal:** FORA gets smarter with every application. Outcomes feed back into decisions.

**Prerequisite:** V1 has real users producing real applications. The data exists to know what to improve.

### What V2 adds

**Opportunity crawler**
Given a company name or URL, fetches public signals: recent funding, product launches, team changes, open roles. Surfaces them in the brainstorm as context. Designer decides what to use.

**Confidence scorer**
Structured profile-to-JD match score across five dimensions (domain, seniority, stack, role type, cultural fit). Produces a 0–100 score with gap flags. Already partially designed in `brainstorm-prompt.md` — this wires it into the pipeline formally.

**Analytics agent**
Reads `applications.json` + PostHog data. Surfaces: which templates convert, which work entries get time-on-page, response rate by company stage. Runs on request, not automatically.

**Company DS fetcher (robust)**
Currently stubbed — falls back to `default.md` on any failure. V2 makes it reliable: crawls company Storybook, extracts CSS custom properties, validates the token set before applying.

**Outcome tracking**
`applications.json` already has `outcome`, `interview`, `response_received` fields. V2 adds a lightweight CLI command to update them: `node generate.js --outcome briefs/slug.json`. Feeds the analytics agent.

**MCP integration**
`generate.js` as a registered MCP tool — callable from Claude Desktop, Cursor, or any MCP client. Designer runs the full pipeline from their AI chat without switching to terminal.

---

## V3 — Platform

**Goal:** FORA works for teams, agencies, and non-designer use cases.

**Prerequisite:** V2 is stable and the core workflow is proven across multiple users and roles.

### What V3 explores

- Multi-profile support — one install, multiple designers
- Team mode — shared `applications.json`, shared templates, per-designer profiles
- Non-designer role support — engineer, PM, researcher profile schemas
- API mode — `generate.js` as a REST API, callable from external tools
- Hosted option — fora.so as a web interface, no terminal required

---

## Module map — current architecture

```
generate.js
  ├── Module 1: Planner        — reads brief + template JSON, builds execution plan
  ├── Module 2: KnowledgeLoader — loads profile.json
  ├── Module 3: DSLoader        — loads DS tokens from default.md or company DS URL
  ├── Module 4: Codegen         — calls AI API per section, fills HTML slots
  ├── Module 5: Assembler       — stitches sections, injects DS tokens
  └── Module 6: Publisher       — deploys to Vercel, logs to applications.json

brainstorm.sh
  └── JD fetch → template picker → prompt assembly → clipboard → brief save → run.sh

run.sh
  └── mode selection → brainstorm.sh or generate.js depending on mode

setup.sh
  └── health check → .env writer → dependency check
```

---

## Execution modes

| Mode | Codegen | Deploy | Keys needed |
|---|---|---|---|
| 1 | Manual — any AI chat | Manual — any static host | None |
| 2 ★ | Manual — any AI chat | Auto — Vercel | Vercel token |
| 3 | Auto — AI API | Manual — any static host | AI key |
| 4 | Auto — AI API | Auto — Vercel | AI key + Vercel token |

★ Mode 2 is the recommended starting point — permanent URL, zero AI API cost, full control over the generated HTML.
