# FORA — Setup Guide

Everything you need to go from zero to your first live application page, in one afternoon.

---

## How this works

Before you start, here's the mental model. Three pieces, no magic connections between them.

```
┌─────────────────────────────────────────────────────────────────┐
│                        THE THREE PIECES                         │
├─────────────────┬──────────────────────┬────────────────────────┤
│   GitHub        │   Your machine       │   AI chat              │
│   (the repo)    │   (your files)       │   (your thinking tool) │
├─────────────────┼──────────────────────┼────────────────────────┤
│ Holds the       │ profile.json    ←private, never committed      │
│ open-source     │ briefs/*.json   ←private, never committed      │
│ pipeline code   │ output/*.html   ←generated pages               │
│                 │ assets/         ←your media files              │
│ You fork it     │                      │                         │
│ once, clone     │ Terminal runs the    │ You paste prompts in.   │
│ to your mac.    │ scripts here.        │ Copy outputs back.      │
│ That's it.      │                      │ No connection needed.   │
└─────────────────┴──────────────────────┴────────────────────────┘
```

**The AI chat is just a tab in your browser.** There's no plugin, no GitHub connection, no API required to use it. You copy a prompt file, paste it into Claude.ai or ChatGPT, share your career materials, and the AI helps you build `profile.json`. When it's done, you copy the output and save it as a file on your machine. That's the whole loop.

**Terminal is the glue.** `brainstorm.sh` assembles your prompt and copies it to clipboard — one command, then paste into your AI chat. `generate.js` reads your local files, calls the AI, and writes an HTML file. Everything runs locally on your machine.

**Your private data never touches GitHub.** The repo contains the pipeline — prompts, templates, scripts. Your profile, your briefs, your output pages: all gitignored, all local.

---

## Modes — pick yours before starting

FORA works in three modes. You don't need an API key to get a real output.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  1  Manual codegen via AI chat + Manual deploy via any static host          │
│     Free — no API keys needed                                               │
│     Best for: first run, no keys yet                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  2  Manual codegen via AI chat + Auto deploy via Vercel          ★          │
│     Needs: Vercel token only                                                │
│     Best for: permanent URL with zero Anthropic cost                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  3  Auto codegen via Anthropic API + Manual deploy via any static host      │
│     Needs: Anthropic API key only                                           │
│     Best for: fast generation, deploy wherever you prefer                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  4  Auto codegen via Anthropic API + Auto deploy via Vercel                 │
│     Needs: Anthropic + Vercel                                               │
│     Best for: fully automated — URL ready to send the same day              │
└─────────────────────────────────────────────────────────────────────────────┘

★ Option 2 is the most practical starting point — permanent URL, zero API cost.
  Anthropic and Vercel are fully independent. You only need what your option requires.
```

You choose your option **per application** when you run `./run.sh` — not once during setup. If you have no keys, option 1 is always available. As you add keys, more options unlock automatically.

---

## What you'll build

By the end of this guide:

```
✓ A private career knowledge base (profile.json)
✓ A brainstorm run against a real job description
✓ A personalised application landing page
✓ A live URL you can send in a cold message (Mode 3 only)

Result: https://fora-pages.vercel.app/company-role
```

---

## Time breakdown

| Step | What you're doing | Required? | Time |
|------|-------------------|-----------|-----:|
| 1 | Fork + clone the repo | Yes | 2 min |
| 2 | Build your profile | Yes | ~15 min |
| 3 | Set up your design system | Optional | 5 min |
| 4 | Configure API keys | Mode 2A + 3 need Anthropic. Mode 2B + 3 need Vercel. | 5 min |
| 5 | Run your first application | Yes | ~15 min |

Step 2 is the only real work — but the AI does the heavy lifting. You paste your resume (or LinkedIn export, or any career notes) and it drafts your full `profile.json`. You review and correct. Most designers are done in 15 minutes. The profile is the foundation everything else builds on — do it once, reuse it forever.

Throughout this guide, steps are labelled by where you're working:
`[Terminal]` `[Browser]` `[Editor]`

---

## Before you start

**Required for all modes:**
- Node.js 18+ installed ([nodejs.org](https://nodejs.org))
- Your resume, LinkedIn export, or any career materials (for Step 2)
- An AI chat open — Claude.ai, ChatGPT, Gemini, or any model you prefer

**OS note:** These instructions are written for macOS. If you're on Linux, replace `pbcopy` with `xclip -selection clipboard` and `pbpaste` with `xclip -selection clipboard -o`. On Windows, WSL is recommended.

**Mode 2A + 3 only — automated codegen:**
- An Anthropic API key — [console.anthropic.com](https://console.anthropic.com/settings/keys)

**Mode 2B + 3 only — automated deploy:**
- A Vercel account — [vercel.com](https://vercel.com) (free tier works)
- A Vercel token — [vercel.com/account/tokens](https://vercel.com/account/tokens)

Anthropic and Vercel are independent. You only need what your mode requires.

---

## Step 1 — Fork and clone the repo
*~2 min*

**In your browser** — go to [github.com/meetshahco/FORA](https://github.com/meetshahco/FORA) and click **Fork** (top right). This creates your own copy at `github.com/yourhandle/FORA`. You only need to do this once.

**In your terminal** — clone your fork. Replace `yourhandle` with your GitHub username:
```bash
git clone https://github.com/yourhandle/FORA.git
```

Then run these fixed commands exactly as written:
```bash
cd FORA
chmod +x setup.sh brainstorm.sh codegen.sh run.sh
./setup.sh
```

> **Important:** every command in this guide runs from inside the `FORA/` folder. If you open a new terminal tab at any point, run `cd path/to/FORA` to get back before continuing.

`setup.sh` is a re-runnable health check. It verifies your environment, walks you through mode selection and API keys, and tells you exactly what's missing. Run it anytime — first setup, after changing keys, or on a new machine.

**You should now have:**
```
✓ FORA/ folder on your machine
✓ Node version confirmed
✓ Mode selected and .env written (if using Mode 2B/3)
```

---

## Step 2 — Build your profile
*~15 min — the AI does the heavy lifting*

Your profile is your private career knowledge base. It lives only on your machine and is the source of truth for every application you generate. Build it once, update it as your work grows.

**In your terminal** — copy the profile builder prompt to your clipboard:
```bash
cat prompts/profile-builder-prompt.md | pbcopy
```

**In your browser** — open any AI chat (Claude.ai, ChatGPT, Gemini, or any model you prefer). Paste with ⌘V, then in the same message paste your raw career materials — your resume text, a LinkedIn export, or any notes you have. The AI drafts a complete `profile.json` and walks you through reviewing it section by section. Correct anything that's wrong or missing.

The more you share, the richer the profile. A resume paste is enough to get started.

When the AI gives you the final JSON, copy it. Then **back in your terminal**, save it:
```bash
pbpaste > profile/profile.json
```

Verify it was saved correctly:
```bash
./setup.sh --check
```

You should see `✓ profile.json found — [your name]`. If it shows an error, the JSON may be malformed — go back to the AI chat and ask it to output the JSON again cleanly, then re-run the save command.

**You should now have:**
```
✓ profile/profile.json
```

This file is gitignored — it will never be committed or pushed.

**Updating your profile later** — when you ship new work or want to add more context, run the same command again:
```bash
cat prompts/profile-builder-prompt.md | pbcopy
```
Paste into your AI chat with your current `profile.json` + what changed ("I just shipped X at Y — here are the details"). The AI merges the update. Then save it back:
```bash
pbpaste > profile/profile.json
```

**Want to see FORA's output before building your profile?**
Open `examples/alex-rivera/output/index.html` in your browser — a pre-generated page showing what FORA produces, no setup needed.

---

## Step 3 — Set up your design system
*~5 min*

Your design system is the visual baseline for every page you generate. The default is clean, neutral, and typographic — designed to look intentional without being templated.

**Option A — Use the defaults (recommended for your first run)**
Skip this step entirely. The defaults work well out of the box. Come back to this once you've generated your first page and know what you want to change.

**Option B — Configure it to match your personal brand**
`[Browser]` Open any AI chat. Paste `prompts/ds-builder-prompt.md`.

Then share any combination of:
- Your portfolio URL
- A link to your public design system or Storybook
- A DS file (Figma tokens JSON, CSS variables, anything)
- A plain description of your visual style

The assistant extracts your visual language, asks a few focused questions, and outputs a complete configured `design-system/default.md`. Save it and you're done.

`[Editor]` Or skip the AI and edit `design-system/default.md` directly — it's a plain markdown file with annotated tokens.

**You should now have:**
```
✓ design-system/default.md  (already in the repo — edit or leave as-is)
```

---

## Step 4 — Configure API keys
*~5 min — skip entirely if using Mode 1 or Mode 2B*

| Mode | Needs this step? |
|------|-----------------|
| Mode 1 — fully manual | No — skip this step |
| Mode 2A — auto codegen | Yes — Anthropic key only |
| Mode 2B — auto deploy ★ | Yes — Vercel token only |
| Mode 3 — fully automated | Yes — both keys |

**In your terminal:**
```bash
cp .env.example .env
```

Open `.env` in any text editor (TextEdit, VS Code, Notepad — anything) and fill in only the keys your mode needs:

```
# Mode 2A + 3 only — automated page generation
ANTHROPIC_API_KEY=your_key_here

# Mode 2B + 3 only — automated deploy to Vercel
VERCEL_TOKEN=your_vercel_token
VERCEL_PROJECT_NAME=fora-pages
```

To get your Vercel token: go to [vercel.com/account/tokens](https://vercel.com/account/tokens) → Create Token.

Run the health check to confirm your keys are wired correctly:
```bash
./setup.sh --check
```

**You should now have (if applicable):**
```
✓ .env with your keys
```

---

## Step 5 — Run your first brainstorm
*~15 min*

Here's what happens in this step:

```
  Terminal              AI chat (browser tab)          Terminal
  ────────              ─────────────────────          ────────
  brainstorm.sh
  + profile.json  ───→  paste once
  + JD text             ↓
                        brainstorm conversation
                        ↓
                        final content_brief.json  ───→ saved automatically
                                                       briefs/[company-role].json
```

**In your terminal** — paste in the URL of the job description you want to apply for:
```bash
./brainstorm.sh https://company.com/jobs/senior-designer
```

The script fetches the JD, assembles your profile + the brainstorm prompt, and copies everything to your clipboard. It then waits for you.

**In your browser** — open any AI chat and paste with ⌘V. The brainstorm agent will:
1. Analyse the JD and score it against your profile
2. Propose content for all three acts — who you are, what you've done, what you'll bring
3. Ask if you have any visuals to include (screenshots, Loom links, Figma URLs)
4. Ask for your input or refinements until you're happy
5. Output the final `content_brief.json`

When the agent gives you the final JSON, **copy just the JSON block** (starting with `{` and ending with `}`).

**Back in your terminal** — press Enter when prompted. The script reads from your clipboard and saves the brief automatically:
```
✓ Brief saved → briefs/[company].json
✓ Valid JSON confirmed
```

No filename to decide. No file to create manually. The name is derived from the company domain in the URL you provided.

> **Need to exit at any point?** Press `Ctrl+C` — the script exits cleanly and tells you the exact command to resume.

If the agent also gives you an assets checklist (local files like screenshots), copy them into the assets folder:
```bash
cp ~/Desktop/your-screenshot.png assets/
```

**You should now have:**
```
✓ briefs/[company-role].json
✓ assets/ (any local files listed in the assets checklist)
```

Brief files are gitignored — they won't be committed.

---

## Step 6 — Generate your page
*~2 min (Mode 2A + 3) or ~15 min (Mode 1 + 2B)*

**Mode 2A + 3 — Automated codegen (Anthropic API key required):**

In your terminal — replace `[company]` with the brief filename brainstorm.sh gave you:
```bash
node generate.js --run briefs/[company].json
```

This calls the API, assembles your page, and writes it to `output/[company]/index.html` automatically.

---

**Mode 1 + 2B — Manual codegen (no Anthropic key needed):**

In your terminal:
```bash
./codegen.sh briefs/[company].json
```

This copies the codegen prompt + your brief to your clipboard in one go. Then:

1. Open your AI chat and paste ⌘V
2. The assistant generates the full page HTML
3. Copy the HTML output
4. Come back to the terminal and press Enter

The script saves the HTML automatically — no file naming, no folder creation.

> **Need to exit?** Press `Ctrl+C` — the script exits cleanly with the command to resume.

---

**You should now have:**
```
✓ output/[company]/index.html
```

If something looks off, run `./codegen.sh briefs/[company].json` again — it'll ask if you want to regenerate.

---

## Step 7 — Deploy
*~2 min*

If you used `./run.sh`, deploy is handled at the end of the flow automatically based on your option choice. If you're running manually:

**Auto deploy via Vercel (options 2 + 4):**

In your terminal — replace `[company]` with your brief filename:
```bash
node generate.js --deploy briefs/[company].json
```

Returns a live URL: `https://fora-pages.vercel.app/[company]`

Your Vercel project must exist before the first deploy — create it once at [vercel.com/new](https://vercel.com/new) (empty project, no framework, no git connection needed).

---

**Manual deploy via any static host (options 1 + 3):**

Drag your `output/[company]/` folder to [app.netlify.com/drop](https://app.netlify.com/drop) — free, no account needed.

Or use GitHub Pages, Cloudflare Pages, S3, or any static host. The output is a single self-contained `index.html` that works anywhere.

**You should now have:**
```
✓ A live URL to send
```

---

## Maintaining FORA

**Update your profile** — when you ship new work, get promoted, or change roles:

`[Browser]` Open a new AI chat. Paste `prompts/profile-builder-prompt.md`, then paste your current `profile.json` and describe what changed ("I just shipped X at Y company — here are the details"). The AI merges the update. Save the output back to `profile/profile.json`.

Or `[Editor]` edit `profile/profile.json` directly — the schema has inline instructions on every field.

---

**Update your design system** — when you rebrand or want a different visual feel:

In your terminal:
```bash
cat prompts/ds-builder-prompt.md | pbcopy
```
Open any AI chat, paste, and share your portfolio URL, DS file, or describe your aesthetic. The AI outputs a configured `design-system/default.md`. Copy the output and save it:
```bash
pbpaste > design-system/default.md
```

Or open `design-system/default.md` directly in any text editor — all tokens are in the `TOKEN BLOCK` section at the top.

---

**Add or switch API keys** — if you want to unlock a new option:

Open `.env` in any text editor and add your key. Then verify:
```bash
./setup.sh --check
```

The next time you run `./run.sh`, the new option will show as available automatically.

---

**Health check** — if something stops working:
```bash
./setup.sh --check
```

Runs all checks silently and reports exactly what's missing.

---

**Re-run an existing application** — tweak the brief and regenerate:
```bash
./run.sh --brief briefs/[company].json
```

Skips the brainstorm, goes straight to mode selection → generate → deploy.

---

## What's next

**Apply again.** Run `./run.sh` with a new JD URL — brainstorm, generate, and deploy in one guided flow. Each application takes 15–20 minutes once you're set up.

**Update your profile.** When you ship new work, run:
```bash
cat prompts/profile-builder-prompt.md | pbcopy
```
Paste into AI chat with your current `profile.json` + what changed. Copy the updated JSON and save:
```bash
pbpaste > profile/profile.json
```

**Customise your design system.** Open `design-system/default.md` in any text editor and adjust colours, typography, or spacing. Changes apply to every page you generate from that point.

**Track your applications.** Application history tracking is coming in V1 — a local `applications/applications.json` that logs every brief you've run, every page you've deployed, and every response.

---

## Troubleshooting

**Scripts say permission denied**
```bash
./setup.sh
```
Running setup.sh automatically fixes permissions on all scripts.

**generate.js fails with API error**

Check your `ANTHROPIC_API_KEY` in `.env`. Make sure there are no extra spaces or quotes.

**Vercel deploy fails**

`[Editor]` Check `VERCEL_TOKEN` and `VERCEL_PROJECT_NAME` in `.env`. Your Vercel project must exist before the first deploy.

**The page looks unstyled**

Check that `design-system/default.md` exists. It ships with the repo — if it's missing, re-clone or restore it from git.

**brainstorm.sh fetched an empty or broken JD**

Some job boards block automated fetches. `[Browser]` Copy the JD text manually, open your AI chat, and paste `prompts/brainstorm-prompt.md` + your `profile.json` + the JD text directly.
