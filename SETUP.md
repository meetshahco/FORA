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

FORA works in four modes. You don't need an API key to get a real output.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  1  Manual codegen via AI chat + Manual deploy via any static host          │
│     Free — no keys needed                                                   │
│     Best for: first run, no keys yet                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  2  Manual codegen via AI chat + Auto deploy via Vercel          ★          │
│     Needs: Vercel token only                                                │
│     Best for: permanent URL with zero AI API cost                           │
├─────────────────────────────────────────────────────────────────────────────┤
│  3  Auto codegen via AI API + Manual deploy via any static host             │
│     Needs: Anthropic, Gemini, or OpenAI key                                 │
│     Best for: fast generation, deploy wherever you prefer                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  4  Auto codegen via AI API + Auto deploy via Vercel                        │
│     Needs: any AI key + Vercel token                                        │
│     Best for: fully automated — URL ready to send the same day              │
└─────────────────────────────────────────────────────────────────────────────┘

★ Option 2 is the most practical starting point — permanent URL, zero AI API cost.
  AI provider and Vercel are fully independent. You only need what your option requires.
```

**Supported AI providers for options 3 + 4:**
- Anthropic Claude — [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)
- Google Gemini — [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey)
- OpenAI — [platform.openai.com/api-keys](https://platform.openai.com/api-keys)

Add any one key to `.env` — FORA auto-detects the provider. If you have multiple keys set, it prioritises Anthropic → Gemini → OpenAI, or you can force a specific provider with `AI_PROVIDER=gemini` in `.env`.

You choose your option **per application** when you run `./run.sh` — not once during setup. If you have no keys, option 1 is always available. As you add keys, more options unlock automatically.

---

## What you'll build

By the end of this guide:

```
✓ A private career knowledge base (profile.json)
✓ A brainstorm run against a real job description
✓ A personalised application landing page
✓ A live URL you can send in a cold message (options 2 + 4 only)

Result: https://meet-shah.vercel.app/company-role   (your name, your URL)
```

---

## Time breakdown

| Step | What you're doing | Required? | Time |
|------|-------------------|-----------|-----:|
| 1 | Fork + clone the repo | Yes | 2 min |
| 2 | Build your profile | Yes | ~15 min |
| 3 | Set up your design system | Optional | 5 min |
| 4 | Configure API keys | Options 3 + 4 need an AI key. Options 2 + 4 need Vercel. | 5 min |
| 5 | Run your first application | Yes | ~15 min |

Step 2 is the only real work — but the AI does the heavy lifting. You paste your resume (or LinkedIn export, or any career notes) and it drafts your full `profile.json`. You review and correct. Most designers are done in 15 minutes. The profile is the foundation everything else builds on — do it once, reuse it forever.

**What one application run looks like (Step 5 in detail):**

| Phase | What happens | Where | Time |
|-------|-------------|-------|-----:|
| Brainstorm | FORA fetches the JD, assembles your profile + prompt, copies to clipboard | Terminal → AI chat | ~10 min |
| Brief | AI analyses the role, proposes all three acts, you refine and approve | AI chat | ~5 min |
| Save | You copy the final JSON, press Enter — brief saved automatically | Terminal | ~1 min |
| Generate | Paste codegen prompt into AI chat (or auto via API) — full HTML produced | AI chat or API | ~3 min |
| Deploy | Page live on Vercel (auto) or drag to Netlify (manual) | Terminal or browser | ~1 min |

Total per application once set up: **~15–20 min**

If anything goes wrong during generation, FORA pauses and gives you recovery options — it never fails silently. Add a few minutes for any retry.

---

## Before you start

**Required for all modes:**
- Node.js 18+ installed ([nodejs.org](https://nodejs.org))
- Your resume, LinkedIn export, or any career materials (for Step 2)
- An AI chat open — Claude.ai, ChatGPT, Gemini, or any model you prefer

**OS note:** These instructions are written for macOS. If you're on Linux, replace `pbcopy` with `xclip -selection clipboard` and `pbpaste` with `xclip -selection clipboard -o`. On Windows, WSL is recommended.

**Options 3 + 4 only — automated codegen (pick one):**
- Anthropic Claude key — [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)
- Google Gemini key — [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey)
- OpenAI key — [platform.openai.com/api-keys](https://platform.openai.com/api-keys)

**Options 2 + 4 only — automated deploy:**
- A Vercel account — [vercel.com](https://vercel.com) (free tier works)
- A Vercel token — [vercel.com/account/tokens](https://vercel.com/account/tokens)

AI provider and Vercel are independent. You only need what your option requires.

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

`setup.sh` is a re-runnable health check. It verifies your environment, walks you through key setup, and tells you exactly what's missing. Run it anytime — first setup, after changing keys, or on a new machine.

**You should now have:**
```
✓ FORA/ folder on your machine
✓ Node version confirmed
✓ .env written with your keys (if applicable)
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
In your browser, open any AI chat. Paste `prompts/ds-builder-prompt.md`.

Then share any combination of:
- Your portfolio URL
- A link to your public design system or Storybook
- A DS file (Figma tokens JSON, CSS variables, anything)
- A plain description of your visual style

The assistant extracts your visual language, asks a few focused questions, and outputs a complete configured `design-system/default.md`. Save it and you're done.

Or open `design-system/default.md` directly in any text editor — it's a plain markdown file with annotated tokens.

**You should now have:**
```
✓ design-system/default.md  (already in the repo — edit or leave as-is)
```

---

## Step 4 — Configure API keys
*~5 min — skip entirely if using option 1*

| Option | Needs this step? |
|--------|-----------------|
| Option 1 — fully manual | No — skip this step |
| Option 2 — manual codegen, auto deploy | Yes — Vercel token only |
| Option 3 — auto codegen, manual deploy | Yes — one AI key (Anthropic, Gemini, or OpenAI) |
| Option 4 — fully automated | Yes — one AI key + Vercel token |

**In your terminal:**
```bash
cp .env.example .env
```

Open `.env` in any text editor (TextEdit, VS Code, Notepad — anything) and fill in only what your option needs.

For auto codegen (options 3 + 4) — add **one** AI key:
```
# Pick one — FORA auto-detects which provider to use
ANTHROPIC_API_KEY=your_key_here
GEMINI_API_KEY=your_key_here
OPENAI_API_KEY=your_key_here
```

For auto deploy (options 2 + 4) — add your Vercel token and set your project name:
```
VERCEL_TOKEN=your_vercel_token
VERCEL_PROJECT_NAME=meet-shah    # use your name — this becomes your URL
```

Your deploy URL will be `https://[project-name].vercel.app/[company]`. Use your name so it looks like yours, not a shared tool. If you have a custom domain (e.g. `apply.yourname.com`), add it too:
```
DEPLOY_DOMAIN=apply.yourname.com
```

Tip: run `./setup.sh` instead of editing `.env` manually — it suggests your project name automatically from your profile.json and walks you through the rest conversationally.

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

## Step 5 — Run your first application
*~15 min*

From here on, every application starts with one command:
```bash
./run.sh
```

It will ask for the job description URL, then guide you through brainstorm → generate → deploy in one flow. You don't need to remember any arguments — just run it and follow the prompts.

Here's what happens under the hood:

```
  Terminal              AI chat (browser tab)          Terminal
  ────────              ─────────────────────          ────────
  run.sh asks
  for JD URL      ───→  brainstorm paste
  + profile.json        ↓
  + JD text             brainstorm conversation
                        ↓
                        final content_brief.json  ───→ saved automatically
                                                       briefs/[company].json
```

**In your terminal:**
```bash
./run.sh
```

The script asks for the JD URL, fetches it, assembles your profile + the brainstorm prompt, and copies everything to your clipboard. It then waits for you.

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

If you're running `./run.sh`, this step happens automatically after the brainstorm — it prompts you to pick an option and handles the rest.

If you're re-generating a page without re-doing the brainstorm:
```bash
./run.sh --brief briefs/[company].json
```

This skips the brainstorm and goes straight to generate → deploy.

---

**What happens based on your option:**

Options 3 + 4 (auto codegen): the script calls your configured AI provider's API and writes `output/[company]/index.html` automatically. Works with Anthropic, Gemini, or OpenAI — whichever key you have in `.env`.

Options 1 + 2 (manual codegen): the script copies the full codegen prompt + brief to your clipboard. Paste into your AI chat, copy the HTML output, come back to the terminal and press Enter. The script saves it automatically.

> **Need to exit at any point?** Press `Ctrl+C` — every prompt shows this hint.

---

**If a page already exists for this brief**, FORA will detect it and ask:
```
A page already exists for this brief (42KB)
1) Use existing page — skip to preview and deploy
2) Regenerate — overwrite with a fresh generation
```
Choose 1 to go straight to preview without re-running codegen. Useful if you just want to re-deploy after tweaking a brief manually.

**If generation partially fails** (some sections succeed, some don't), FORA writes the page with placeholder comments for the failed sections and gives you three choices: continue with the partial page, retry generation, or abort. You'll see exactly which sections failed and why.

---

**You should now have:**
```
✓ output/[company]/index.html
```

---

## Step 7 — Deploy
*~2 min*

If you used `./run.sh`, deploy is handled at the end of the flow automatically based on your option choice. If you're running manually:

**Auto deploy via Vercel (options 2 + 4):**

Before deploying, FORA will show you the exact URL and ask for confirmation:
```
This will publish your page live.
URL: https://meet-shah.vercel.app/nola

Ready to go live? (y/N)
```

The default is N — so if you accidentally press Enter, nothing goes live. Type `y` to proceed.

If you're deploying manually (outside of `./run.sh`):
```bash
node generate.js --deploy briefs/[company].json
```

Returns a live URL: `https://[your-project-name].vercel.app/[company]` (or your custom domain if you set one).

Your Vercel project must exist before the first deploy — create it once at [vercel.com/new](https://vercel.com/new) (empty project, no framework, no git connection needed). The project name must match `VERCEL_PROJECT_NAME` in your `.env`.

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

Open any AI chat, paste `prompts/profile-builder-prompt.md`, then paste your current `profile.json` and describe what changed ("I just shipped X at Y company — here are the details"). The AI merges the update. Save the output back to `profile/profile.json`.

Or open `profile/profile.json` directly in any text editor — the schema has inline instructions on every field.

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

Open `.env` in any text editor and add your key. Supported providers:
```
ANTHROPIC_API_KEY=   — https://console.anthropic.com/settings/keys
GEMINI_API_KEY=      — https://aistudio.google.com/app/apikey
OPENAI_API_KEY=      — https://platform.openai.com/api-keys
```

Then verify:
```bash
./setup.sh --check
```

The next time you run `./run.sh`, the new option will show as available automatically. If you have multiple keys and want to control which one is used, add `AI_PROVIDER=gemini` (or `anthropic` / `openai`) to `.env`.

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

Skips the brainstorm, goes straight to option selection → generate → deploy.

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

**Stay up to date.** FORA is actively improving — bug fixes, better prompts, new features. Your fork doesn't update automatically. To pull the latest changes:

1. Go to your fork on GitHub (`github.com/yourhandle/FORA`)
2. Click **Sync fork** → **Update branch**
3. In your terminal:
```bash
git pull origin main
```

Your personal files (`profile.json`, `briefs/`, `output/`, `.env`) are gitignored and never touched by updates.

---

## Troubleshooting

**Scripts say permission denied**
```bash
./setup.sh
```
Running setup.sh automatically fixes permissions on all scripts.

**All sections fail with a 404 or model error**

You'll see something like:
```
✗ All 6 sections failed. Page not written.
  First error: Gemini API error 404: This model is no longer available...
```
This means the model in your `.env` is wrong or deprecated. Open `.env` and check `AI_MODEL`. For Gemini, use `gemini-2.0-flash`. Delete the `AI_MODEL=` line entirely to fall back to the provider default. Then retry:
```bash
./run.sh --brief briefs/[company].json
```

**Some sections fail, some succeed**

You'll see a partial failure warning with a choice to continue, retry, or abort. If you continue, the page is written with placeholder HTML comments for the failed sections — open it in a browser and you'll see which sections are missing. Retry is usually the right call unless you want to fix the brief first.

**Page generated but looks empty or wrong**

FORA checks file size after generation — if it's under 5KB it blocks and tells you. If it passes the size check but looks off, open it in a browser and inspect for placeholder comments (`<!-- section X: generation failed -->`). Those sections need to be regenerated.

**generate.js fails with an API key error**

Check your key in `.env` — make sure there are no extra spaces, quotes, or line breaks. Run `./run.sh status` to confirm which key FORA is detecting and which model is active.

**Vercel deploy fails**

Open `.env` and check `VERCEL_TOKEN` and `VERCEL_PROJECT_NAME`. The project name must match exactly what's in your Vercel dashboard. Your Vercel project must exist before the first deploy — create it at [vercel.com/new](https://vercel.com/new).

**The page looks unstyled**

Check that `design-system/default.md` exists. It ships with the repo — if it's missing, restore it:
```bash
git checkout design-system/default.md
```

**brainstorm.sh fetched an empty or broken JD**

Some job boards block automated fetches. Copy the JD text manually, open your AI chat, and paste `prompts/brainstorm-prompt.md` + your `profile.json` + the JD text directly.
