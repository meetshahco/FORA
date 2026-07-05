# FORA — Setup Guide

Everything you need to go from zero to your first live application page, in one afternoon.

---

## What you'll build

By the end of this guide:

```
✓ A private career knowledge base (profile.json)
✓ A brainstorm run against a real job description
✓ A personalised application landing page
✓ A live URL you can send in a cold message (optional)

Result: https://fora-pages.vercel.app/company-role
```

---

## Time breakdown

| Step | What you're doing | Time |
|------|-------------------|-----:|
| 1 | Clone the repo | 2 min |
| 2 | Build your profile | ~45 min |
| 3 | Set up your design system | 5 min |
| 4 | Configure environment (optional) | 5 min |
| 5 | Run your first brainstorm | ~15 min |
| 6 | Generate your page | 2 min |
| 7 | Publish (optional) | 2 min |

Most of the time is Step 2 — building your profile. That's intentional. The profile is the foundation everything else builds on. Do it once, reuse it forever.

Throughout this guide, steps are labelled by where you're working:
`[Terminal]` `[Browser]` `[Editor]`

---

## Before you start

You'll need:
- Node.js 18+ installed
- Your resume, LinkedIn export, or any career materials (for Step 2)
- An AI chat open — Claude.ai, ChatGPT, Gemini, Cursor, or any model you prefer

For automated codegen and deploy (optional):
- An Anthropic API key — [console.anthropic.com](https://console.anthropic.com/settings/keys)
- A Vercel account — [vercel.com](https://vercel.com) (free tier works)

---

## Step 1 — Clone the repo
*~2 min*

`[Terminal]`
```bash
git clone https://github.com/meetshahco/FORA.git
cd FORA
npm install
```

**You should now have:**
```
✓ FORA/ cloned locally
✓ node_modules/ installed
```

---

## Step 2 — Build your profile
*~45 min — the most important step*

Your profile is your private career knowledge base. It lives only on your machine and is the source of truth for every application you generate. Build it once, update it as your work grows.

`[Browser]` Open any AI chat — Claude.ai, ChatGPT, Gemini, Cursor, whatever you use.

`[Editor]` Open `prompts/profile-builder-prompt.md` and copy the full contents.

`[Browser]` Paste it into your AI chat, then share your raw materials — your resume, LinkedIn export, case study notes, anything that documents your work. The more you share, the richer the profile. The assistant will ask a few focused questions, draft a complete `profile.json`, and walk you through reviewing it section by section.

`[Editor]` When you're happy with the output, create the file and paste the JSON in:

```
profile/profile.json
```

`[Terminal]` Verify it exists:
```bash
cat profile/profile.json
```

**You should now have:**
```
✓ profile/profile.json
```

This file is gitignored — it will never be committed or pushed.

---

## Step 3 — Set up your design system
*~5 min*

Your design system is the visual baseline for every page you generate. The default is clean, neutral, and typographic — designed to look intentional without being templated.

`[Editor]` Open `design-system/default.md` and adjust colours, fonts, or spacing to match your personal brand. Or leave it untouched — the defaults work well out of the box.

**You should now have:**
```
✓ design-system/default.md  (already in the repo — just edit it)
```

---

## Step 4 — Configure environment variables
*~5 min — skip if using Mode 1 (manual, zero cost)*

FORA works without any API keys in fully manual mode. Configure this step only if you want automated codegen (`--run`) or automated deploy (`--publish`).

`[Terminal]`
```bash
cp .env.example .env
```

`[Editor]` Open `.env` and fill in what you need:

```
# For generate.js --run (automated codegen)
ANTHROPIC_API_KEY=your_key_here

# For generate.js --publish (automated deploy to Vercel)
VERCEL_TOKEN=your_vercel_token
VERCEL_PROJECT_NAME=fora-pages
```

To get your Vercel token: `[Browser]` vercel.com/account/tokens → Create Token.

If you're skipping automated deploy, you can use Netlify drop, GitHub Pages, or any static host — `generate.js --run` produces a plain HTML file that works anywhere.

**You should now have (if applicable):**
```
✓ .env with your keys
```

---

## Step 5 — Run your first brainstorm
*~15 min*

Find a job description you want to apply to. Copy the URL.

`[Terminal]`
```bash
./brainstorm.sh https://company.com/jobs/senior-designer
```

This fetches the JD, assembles the brainstorm prompt with your `profile.json`, and copies everything to your clipboard.

`[Browser]` Open any AI chat and paste. The FORA brainstorm agent will:
1. Analyse the JD and score the match against your profile
2. Propose content for all three acts — who you are, what you've done, what you'll bring
3. Ask if you have any visuals to attach (screenshots, Loom links, Figma URLs)
4. Ask for your input or refinements
5. Lock a `content_brief.json` and give you an assets checklist

`[Editor]` Save the brief the agent outputs:
```
briefs/acme-senior-designer.json
```

`[Terminal]` If the agent listed any local files in the assets checklist, drop them in:
```bash
# e.g. cp ~/Desktop/kwikpay-dashboard.png assets/
```

**You should now have:**
```
✓ briefs/
    acme-senior-designer.json
✓ assets/
    [any local files you attached]
```

Brief files are gitignored — they won't be committed.

---

## Step 6 — Generate your page
*~2 min*

**If you have an Anthropic API key (Mode 2+3):**

`[Terminal]`
```bash
node generate.js --run briefs/acme-senior-designer.json
```

This calls the API per section, assembles your page, and writes it locally.

**If you're going fully manual (Mode 1):**

`[Browser]` Open any AI chat. Paste `prompts/codegen-prompt.md`, then paste the contents of your brief. Ask the assistant to generate each section one at a time.

`[Editor]` Assemble the HTML into `output/acme-senior-designer/index.html`.

`[Terminal]` Preview your page:
```bash
open output/acme-senior-designer/index.html
```

**You should now have:**
```
✓ output/
    acme-senior-designer/
        index.html
```

If something looks off, edit the brief and re-run. The brief is the source of truth.

---

## Step 7 — Publish
*~2 min — optional*

**Vercel (automated):**

`[Terminal]`
```bash
node generate.js --publish briefs/acme-senior-designer.json
```

Returns a live URL: `https://fora-pages.vercel.app/acme-senior-designer`

Your Vercel project must exist before the first deploy — `[Browser]` create it once at vercel.com/new (empty project, no framework, no git connection needed).

**Netlify drop (manual, free):**

`[Browser]` Go to [app.netlify.com/drop](https://app.netlify.com/drop), drag your `output/acme-senior-designer/` folder in. Done.

**GitHub Pages, Cloudflare Pages, or any static host:**

The output is a single `index.html` with no external dependencies. It works on any static host.

**You should now have:**
```
✓ A live URL to send
```

---

## What's next

**Apply again.** `[Terminal]` Run `brainstorm.sh` with a new JD. Your profile stays — each application takes 15–20 minutes once you're set up.

**Update your profile.** When you ship new work, `[Editor]` open `profile/profile.json` and update the relevant entry. Or `[Browser]` re-run `profile-builder-prompt.md` with your current profile + what changed — the assistant handles the merge.

**Customise your design system.** `[Editor]` Edit `design-system/default.md` to adjust colours, typography, or spacing. Changes apply to every page you generate from that point.

**Track your applications.** Application history tracking is coming in V1 — a local `applications/applications.json` that logs every brief you've run, every page you've deployed, and every response. The system gets richer with every application.

---

## Troubleshooting

**`brainstorm.sh` says permission denied**

`[Terminal]`
```bash
chmod +x brainstorm.sh
```

**generate.js fails with API error**

`[Editor]` Check your `ANTHROPIC_API_KEY` in `.env`. Make sure there are no extra spaces or quotes.

**Vercel deploy fails**

`[Editor]` Check `VERCEL_TOKEN` and `VERCEL_PROJECT_NAME` in `.env`. Your Vercel project must exist before the first deploy.

**The page looks unstyled**

Check that `design-system/default.md` exists. It ships with the repo — if it's missing, re-clone or restore it from git.

**brainstorm.sh fetched an empty or broken JD**

Some job boards block automated fetches. `[Browser]` Copy the JD text manually, open your AI chat, and paste `prompts/brainstorm-prompt.md` + your `profile.json` + the JD text directly.
