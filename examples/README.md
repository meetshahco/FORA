# FORA — Examples

This folder shows FORA end-to-end with a fictional designer.
No setup required. No API key. No profile needed.

Use this to:
- See what a real `profile.json` looks like filled in
- See what a `content_brief.json` looks like after a brainstorm
- Open the pre-generated page and see the output before running anything yourself
- Understand the pipeline before committing to your own profile

---

## The example

**Designer:** Alex Rivera — 6 years experience, product and systems design background
**Role applied to:** Head of Design at Meridian (fictional Series B fintech)
**Mode used:** Mode 2B — manual codegen, auto deploy

---

## Files

```
examples/
└── alex-rivera/
    ├── profile.json          ← Alex's complete career knowledge base
    ├── brief.json            ← content_brief.json from the brainstorm
    └── output/
        └── index.html        ← the generated page (open in browser)
```

---

## Try it

**Just see the output:**

Open `examples/alex-rivera/output/index.html` in your browser.
That's the page FORA would generate for a real application.

**Run it yourself:**

```bash
# Copy Alex's profile as a starting point
cp examples/alex-rivera/profile.json profile/profile.json

# Generate the page from the example brief
node generate.js --run examples/alex-rivera/brief.json

# Open the output
open output/meridian-head-of-design/index.html
```

This lets you verify your setup works before building your own profile.

---

## What this is not

Alex Rivera is fictional. The work, companies, and outcomes are invented to showcase
what well-structured profile data produces. Do not use any of this content in a real application.
