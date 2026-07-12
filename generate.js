#!/usr/bin/env node
/**
 * FORA — generate.js
 * Version: 1.1.0
 *
 * Three modes:
 *   node generate.js --run     briefs/[slug].json   → assembles HTML to output/  (needs Anthropic, Gemini, or OpenAI key)
 *   node generate.js --publish briefs/[slug].json   → assembles + deploys to Vercel  (needs AI key + Vercel)
 *   node generate.js --deploy  briefs/[slug].json   → deploys existing output/ to Vercel  (needs Vercel only — Option 2)
 *
 * Supported AI providers (auto-detected from .env, or set AI_PROVIDER explicitly):
 *   ANTHROPIC_API_KEY  → claude-opus-4-5 (default model)
 *   GEMINI_API_KEY     → gemini-2.0-flash (default model)
 *   OPENAI_API_KEY     → gpt-4o (default model)
 *   AI_MODEL           → override default model for whichever provider is active
 *   AI_PROVIDER        → force a specific provider (anthropic | gemini | openai)
 *
 * Internal modules (in order of execution):
 *   1. Planner        — reads brief + template, builds execution plan in memory
 *   2. KnowledgeLoader — loads profile.json
 *   3. DSLoader       — loads DS tokens (own default.md or company DS fetch)
 *   4. Codegen        — calls Anthropic API per section, fills slots
 *   5. Assembler      — stitches sections into a full HTML page
 *   6. Publisher      — deploys to Vercel (--publish only)
 */

'use strict';

const fs   = require('fs');
const path = require('path');
const https = require('https');

// ── Load .env manually (no dotenv dependency) ────────────────────────────────
function loadEnv() {
  const envPath = path.join(__dirname, '.env');
  if (!fs.existsSync(envPath)) return;
  const lines = fs.readFileSync(envPath, 'utf8').split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx < 0) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const val = trimmed.slice(eqIdx + 1).trim().replace(/^['"]|['"]$/g, '');
    if (!process.env[key]) process.env[key] = val;
  }
}
loadEnv();

// ── CLI helpers ──────────────────────────────────────────────────────────────
const BOLD   = '\x1b[1m';
const GREEN  = '\x1b[0;32m';
const YELLOW = '\x1b[0;33m';
const RED    = '\x1b[0;31m';
const DIM    = '\x1b[2m';
const RESET  = '\x1b[0m';

const ok   = (msg) => console.log(`${GREEN}✓${RESET} ${msg}`);
const info = (msg) => console.log(`${BOLD}→${RESET} ${msg}`);
const warn = (msg) => console.log(`${YELLOW}⚠${RESET}  ${msg}`);
const fail = (msg) => { console.error(`${RED}✗${RESET} ${msg}`); process.exit(1); };
const dim  = (msg) => console.log(`${DIM}${msg}${RESET}`);

// ── Simple HTTPS fetch ───────────────────────────────────────────────────────
function fetchUrl(url, options = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, {
      method: options.method || 'GET',
      headers: options.headers || {},
    }, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => resolve({ status: res.statusCode, body, headers: res.headers }));
    });
    req.on('error', reject);
    if (options.body) req.write(options.body);
    req.end();
  });
}

// ── Provider detection ───────────────────────────────────────────────────────
// Priority: explicit AI_PROVIDER env var → first key found → error
function detectProvider() {
  const explicit = (process.env.AI_PROVIDER || '').toLowerCase();
  if (explicit) {
    const valid = ['anthropic', 'gemini', 'openai'];
    if (!valid.includes(explicit)) fail(`Unknown AI_PROVIDER "${explicit}". Use: anthropic, gemini, openai`);
    return explicit;
  }
  if (process.env.ANTHROPIC_API_KEY) return 'anthropic';
  if (process.env.GEMINI_API_KEY)    return 'gemini';
  if (process.env.OPENAI_API_KEY)    return 'openai';
  fail(`No AI API key found. Add one of these to your .env:
  ANTHROPIC_API_KEY  — https://console.anthropic.com/settings/keys
  GEMINI_API_KEY     — https://aistudio.google.com/app/apikey
  OPENAI_API_KEY     — https://platform.openai.com/api-keys`);
}

// ── Unified AI caller ────────────────────────────────────────────────────────
async function callAI(systemPrompt, userMessage) {
  const provider = detectProvider();
  switch (provider) {
    case 'anthropic': return callAnthropic(systemPrompt, userMessage);
    case 'gemini':    return callGemini(systemPrompt, userMessage);
    case 'openai':    return callOpenAI(systemPrompt, userMessage);
  }
}

// ── Anthropic ────────────────────────────────────────────────────────────────
async function callAnthropic(systemPrompt, userMessage) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) fail('ANTHROPIC_API_KEY is not set. Add it to your .env file.');

  const model = process.env.AI_MODEL || 'claude-opus-4-5';

  const payload = JSON.stringify({
    model,
    max_tokens: 4096,
    system: systemPrompt,
    messages: [{ role: 'user', content: userMessage }],
  });

  const res = await fetchUrl('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: payload,
  });

  if (res.status !== 200) {
    let errMsg = `Anthropic API error ${res.status}`;
    try { const p = JSON.parse(res.body); if (p.error?.message) errMsg += `: ${p.error.message}`; } catch {}
    throw new Error(errMsg);
  }

  const parsed = JSON.parse(res.body);
  return parsed.content?.[0]?.text ?? '';
}

// ── Gemini ───────────────────────────────────────────────────────────────────
async function callGemini(systemPrompt, userMessage) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) fail('GEMINI_API_KEY is not set. Add it to your .env file.');

  const model = process.env.AI_MODEL || 'gemini-2.0-flash';

  const payload = JSON.stringify({
    system_instruction: { parts: [{ text: systemPrompt }] },
    contents: [{ role: 'user', parts: [{ text: userMessage }] }],
    generationConfig: { maxOutputTokens: 4096 },
  });

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const res = await fetchUrl(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: payload,
  });

  if (res.status !== 200) {
    let errMsg = `Gemini API error ${res.status}`;
    try { const p = JSON.parse(res.body); if (p.error?.message) errMsg += `: ${p.error.message}`; } catch {}
    throw new Error(errMsg);
  }

  const parsed = JSON.parse(res.body);
  return parsed.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
}

// ── OpenAI ───────────────────────────────────────────────────────────────────
async function callOpenAI(systemPrompt, userMessage) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) fail('OPENAI_API_KEY is not set. Add it to your .env file.');

  const model = process.env.AI_MODEL || 'gpt-4o';

  const payload = JSON.stringify({
    model,
    max_tokens: 4096,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user',   content: userMessage  },
    ],
  });

  const res = await fetchUrl('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization:  `Bearer ${apiKey}`,
      'content-type': 'application/json',
    },
    body: payload,
  });

  if (res.status !== 200) {
    let errMsg = `OpenAI API error ${res.status}`;
    try { const p = JSON.parse(res.body); if (p.error?.message) errMsg += `: ${p.error.message}`; } catch {}
    throw new Error(errMsg);
  }

  const parsed = JSON.parse(res.body);
  return parsed.choices?.[0]?.message?.content ?? '';
}

// ════════════════════════════════════════════════════════════════════════════
// MODULE 1 — PLANNER
// Reads brief + template JSON. Returns execution plan (in memory only).
// ════════════════════════════════════════════════════════════════════════════
function planner(brief, templateJson) {
  const plan = {
    slug:          `${brief._meta.company}-${brief._meta.role}`
                     .toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''),
    template_id:   brief._meta.template_id,
    section_order: templateJson.section_order,
    section_config: templateJson.section_config || {},
    slot_map:      templateJson.slot_map || {},
    sections:      [],
  };

  for (const sectionId of plan.section_order) {
    // Skip standalone: false sections — they're injected inline
    const cfg = plan.section_config[sectionId] || {};
    if (cfg.standalone === false) continue;

    plan.sections.push({
      id:     sectionId,
      config: cfg,
    });
  }

  return plan;
}

// ════════════════════════════════════════════════════════════════════════════
// MODULE 2 — KNOWLEDGE LOADER
// Loads profile.json. Merges relevant fields into the section brief slice.
// ════════════════════════════════════════════════════════════════════════════
function knowledgeLoader() {
  const profilePath = path.join(__dirname, 'profile', 'profile.json');
  if (!fs.existsSync(profilePath)) {
    fail(`profile.json not found at profile/profile.json

Run profile-builder-prompt.md first to create your profile:
  1. Open a new AI chat
  2. Paste prompts/profile-builder-prompt.md
  3. Share your career materials
  4. Save the output to profile/profile.json`);
  }

  try {
    return JSON.parse(fs.readFileSync(profilePath, 'utf8'));
  } catch (e) {
    fail(`Could not parse profile.json: ${e.message}`);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MODULE 3 — DS LOADER
// Loads design system tokens.
// "own"     → reads design-system/default.md, extracts CSS token block
// "company" → fetches company DS (future V1 feature), falls back to own
// Returns: string of CSS custom property declarations
// ════════════════════════════════════════════════════════════════════════════
function dsLoader(brief) {
  const dsType   = brief._meta.design_system || 'own';
  const dsPath   = path.join(__dirname, 'design-system', 'default.md');

  if (dsType === 'company' && brief._meta.company_ds_url) {
    // V1 feature: fetch and parse company DS tokens
    // For now: warn and fall back to own DS
    warn(`Company DS fetch is a V1 feature. Falling back to your default DS.`);
    warn(`Company DS URL was: ${brief._meta.company_ds_url}`);
    warn(`To use company tokens: extract them manually and add to design-system/default.md.`);
  }

  if (!fs.existsSync(dsPath)) {
    warn(`design-system/default.md not found. Page will use _base.html defaults.`);
    return '';
  }

  const content = fs.readFileSync(dsPath, 'utf8');

  // Extract the CSS tokens block from default.md.
  // Looks for the FIRST fenced ```css block — keep all your token declarations
  // in a single ```css block in default.md. Multiple blocks: only the first is read.
  const tokenMatch = content.match(/```css[^\n]*\n([\s\S]*?)```/);
  if (tokenMatch) return tokenMatch[1].trim();

  // Fallback: look for first :root { ... } block directly.
  // Same rule applies — keep all custom properties in a single :root block.
  const rootMatch = content.match(/:root\s*\{([\s\S]*?)\}/);
  if (rootMatch) return `:root {\n${rootMatch[1]}\n}`;

  warn(`Could not extract CSS tokens from design-system/default.md. Using base defaults.`);
  return '';
}

// ════════════════════════════════════════════════════════════════════════════
// MEDIA RESOLVER
// Resolves a media object from a brief work entry into something codegen can use.
// MVP strategy: base64-encode local files so the page is self-contained.
// Future Option B: copy files to output/[slug]/assets/ and return a relative URL.
// To switch strategies later, only this function needs to change.
// ════════════════════════════════════════════════════════════════════════════
function resolveMedia(media) {
  if (!media || media.type === null) return null;

  // Remote embeds (loom, youtube, figma) — nothing to resolve, URL is already in the brief
  if (['loom', 'youtube', 'figma'].includes(media.type)) {
    return media;
  }

  // Local image — resolve to base64 data URI
  if (media.type === 'image' && media.file) {
    const filePath = path.resolve(__dirname, media.file);
    if (!fs.existsSync(filePath)) {
      warn(`Media file not found: ${media.file} — skipping.`);
      return null;
    }

    const ext      = path.extname(media.file).toLowerCase().replace('.', '');
    const mimeMap  = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', gif: 'image/gif' };
    const mimeType = mimeMap[ext];
    if (!mimeType) {
      warn(`Unsupported image format: ${ext} — skipping. Use jpeg, png, or gif.`);
      return null;
    }

    const fileSizeKB = fs.statSync(filePath).size / 1024;
    if (fileSizeKB > 2048) {
      warn(`Media file ${media.file} is ${Math.round(fileSizeKB)}KB — over 2MB. Consider using a Loom link instead.`);
    }

    const base64 = fs.readFileSync(filePath).toString('base64');
    return {
      ...media,
      file: `data:${mimeType};base64,${base64}`,  // codegen uses media.file as the img src
    };
  }

  return null;
}

// ════════════════════════════════════════════════════════════════════════════
// MODULE 4 — CODEGEN
// Calls AI per section. Returns filled HTML string.
// ════════════════════════════════════════════════════════════════════════════
async function codegen(sectionId, sectionConfig, brief, profile, dsTokens, plan) {
  // Load the section template
  const templatePath = path.join(__dirname, 'templates', 'sections', `${sectionId}.html`);
  if (!fs.existsSync(templatePath)) {
    warn(`No template found for section "${sectionId}" — skipping.`);
    return `<!-- section ${sectionId} skipped: no template found -->`;
  }
  const sectionSpec = fs.readFileSync(templatePath, 'utf8');

  // Load the codegen prompt
  const codegenPromptPath = path.join(__dirname, 'prompts', 'codegen-prompt.md');
  if (!fs.existsSync(codegenPromptPath)) {
    fail(`codegen-prompt.md not found at prompts/codegen-prompt.md`);
  }
  const codegenPromptTemplate = fs.readFileSync(codegenPromptPath, 'utf8');

  // Build section brief slice — only what's relevant to this section
  const sectionBrief = buildSectionBrief(sectionId, brief, profile, plan);

  // Build template config slice
  const templateConfig = JSON.stringify({
    slot_map:       plan.slot_map,
    section_config: sectionConfig,
  }, null, 2);

  // Assemble the full prompt by replacing placeholders
  const fullPrompt = codegenPromptTemplate
    .replace('{{SECTION_SPEC}}',    sectionSpec)
    .replace('{{DS_TOKENS}}',       dsTokens || '(none — use _base.html defaults)')
    .replace('{{SECTION_BRIEF}}',   JSON.stringify(sectionBrief, null, 2))
    .replace('{{TEMPLATE_CONFIG}}', templateConfig);

  const html = await callAI(
    'You are the FORA code generator. Output only the filled HTML section. No markdown fences. No commentary.',
    fullPrompt
  );

  return html.trim();
}

// Builds the relevant brief slice for a given section
function buildSectionBrief(sectionId, brief, profile, plan) {
  const base = {
    _meta:          brief._meta,
    static_wrapper: brief.static_wrapper,
    tone_notes:     brief.tone_notes,
    slot_map:       plan.slot_map,
  };

  switch (sectionId) {
    case 'nav':
      return {
        ...base,
        designer_name:    profile.identity?.name,
        company_name:     brief._meta.company,
        nav_badge:        brief.static_wrapper?.nav_badge,
        portfolio_url:    brief.static_wrapper?.nav_portfolio_url,
      };

    case 'act1_hero':
      return {
        ...base,
        act1:             brief.act1_who_i_am,
        signals:          profile.signals,
        include_signals_inline: plan.section_config?.act1_hero?.include_signals_inline ?? true,
        signals_position:       plan.section_config?.act1_hero?.signals_position ?? 'below_philosophy',
      };

    case 'act2_work': {
      // Resolve media for each work entry before passing to codegen
      const works = (brief.act2_what_ive_done?.works || []).map(work => ({
        ...work,
        media: resolveMedia(work.media),
      }));
      return {
        ...base,
        act2: { ...brief.act2_what_ive_done, works },
        max_works: plan.section_config?.act2_work?.max_works ?? 3,
      };
    }

    case 'act3_bring':
      return {
        ...base,
        act3:             brief.act3_what_ill_bring,
        show_credibility_anchors: plan.section_config?.act3_bring?.show_credibility_anchors ?? false,
      };

    case 'signal_cards':
      return {
        ...base,
        signals:          profile.signals,
        opportunity_model: brief.opportunity_model,
      };

    case 'direct_cta':
      return {
        ...base,
        designer_name:  profile.identity?.name,
        email:          profile.identity?.email,
        cta_url:        '#',   // updated post-publish
        cold_message:   brief.cold_message,
      };

    case 'footer':
      return {
        ...base,
        designer_name:  profile.identity?.name,
        portfolio_url:  profile.identity?.portfolio_url,
        linkedin_url:   profile.identity?.linkedin_url,
        email:          profile.identity?.email,
      };

    default:
      return base;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MODULE 5 — ASSEMBLER
// Stitches section HTML into a full page. Injects _base.html and DS tokens.
// ════════════════════════════════════════════════════════════════════════════
function assembler(sectionOutputs, dsTokens, brief, profile) {
  const basePath = path.join(__dirname, 'templates', 'sections', '_base.html');
  let baseHtml = fs.existsSync(basePath) ? fs.readFileSync(basePath, 'utf8') : '';

  // Inject DS token overrides into {{ds_tokens}} slot
  if (dsTokens) {
    const tokenBlock = `<style>\n:root {\n${dsTokens}\n}\n</style>`;
    baseHtml = baseHtml.replace('<!-- {{ds_tokens}} -->', tokenBlock);
  } else {
    baseHtml = baseHtml.replace('<!-- {{ds_tokens}} -->', '');
  }

  const companyName   = brief._meta.company;
  const designerName  = profile.identity?.name || 'Designer';
  const role          = brief._meta.role;

  const pageTitle = `${designerName} — For ${companyName}`;
  const metaDesc  = `${designerName}'s application for ${role} at ${companyName}, generated by FORA.`;

  const body = sectionOutputs.join('\n\n');

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="robots" content="noindex, nofollow">
  <title>${pageTitle}</title>
  <meta name="description" content="${metaDesc}">
  ${baseHtml}
</head>
<body>
${body}
</body>
</html>`;
}

// ════════════════════════════════════════════════════════════════════════════
// MODULE 6 — PUBLISHER
// Deploys to Vercel. Returns the live URL.
// ════════════════════════════════════════════════════════════════════════════
async function publisher(slug, htmlContent) {
  const token       = process.env.VERCEL_TOKEN;
  const projectName = process.env.VERCEL_PROJECT_NAME || 'fora-pages';
  const domain      = process.env.DEPLOY_DOMAIN;

  if (!token) fail('VERCEL_TOKEN is not set. Add it to your .env file.');

  info('Deploying to Vercel...');

  // Create a deployment via Vercel API
  const files = [
    {
      file:     `${slug}/index.html`,
      data:     Buffer.from(htmlContent).toString('base64'),
      encoding: 'base64',
    },
  ];

  const deployPayload = JSON.stringify({
    name:   projectName,
    files,
    target: 'production',
    projectSettings: {
      framework: null,
      outputDirectory: '.',
    },
  });

  const res = await fetchUrl('https://api.vercel.com/v13/deployments', {
    method: 'POST',
    headers: {
      Authorization:  `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: deployPayload,
  });

  if (res.status !== 200 && res.status !== 201) {
    let errMsg = `Vercel API error ${res.status}`;
    try {
      const parsed = JSON.parse(res.body);
      if (parsed.error?.message) errMsg += `: ${parsed.error.message}`;
    } catch {}
    throw new Error(errMsg);
  }

  const deployment = JSON.parse(res.body);
  const deployUrl  = deployment.url ? `https://${deployment.url}/${slug}` : null;
  const customUrl  = domain ? `https://${domain}/${slug}` : null;

  return customUrl || deployUrl || `https://${projectName}.vercel.app/${slug}`;
}

// ════════════════════════════════════════════════════════════════════════════
// MAIN
// ════════════════════════════════════════════════════════════════════════════
async function main() {
  const args   = process.argv.slice(2);
  const mode   = args[0];
  const briefArg = args[1];

  if (!mode || !briefArg || !['--run', '--publish', '--deploy'].includes(mode)) {
    console.log(`
${BOLD}FORA — generate.js${RESET}

Usage:
  node generate.js --run     briefs/[slug].json   # assemble page locally       (needs AI key)
  node generate.js --publish briefs/[slug].json   # assemble + deploy to Vercel (needs AI key + Vercel)
  node generate.js --deploy  briefs/[slug].json   # deploy existing output/     (needs Vercel only)

  --deploy is for Option 2: you generated the HTML manually in an AI chat,
  saved it to output/[slug]/index.html, and now want to deploy without an AI key.

Supported AI providers (set one key in .env, FORA auto-detects):
  ANTHROPIC_API_KEY  → https://console.anthropic.com/settings/keys
  GEMINI_API_KEY     → https://aistudio.google.com/app/apikey
  OPENAI_API_KEY     → https://platform.openai.com/api-keys

Override model:     AI_MODEL=gemini-2.0-pro  (or any model name for your provider)
Force provider:     AI_PROVIDER=gemini        (if you have multiple keys set)
`);
    process.exit(0);
  }

  const publish = mode === '--publish';
  const deployOnly = mode === '--deploy';

  console.log('');
  console.log(`${BOLD}FORA — ${publish ? 'Generate + Publish' : 'Generate'}${RESET}`);
  console.log('──────────────────────────────────────────');

  // ── Load brief ──────────────────────────────────────────────────────────
  const briefPath = path.resolve(briefArg);
  if (!fs.existsSync(briefPath)) fail(`Brief not found: ${briefArg}`);

  let brief;
  try {
    brief = JSON.parse(fs.readFileSync(briefPath, 'utf8'));
  } catch (e) {
    fail(`Could not parse brief: ${e.message}`);
  }
  ok(`Brief loaded: ${brief._meta.company} — ${brief._meta.role}`);

  // ── Load template ────────────────────────────────────────────────────────
  const templateId   = brief._meta.template_id || 'three-act';
  const templatePath = path.join(__dirname, 'templates', `${templateId}.json`);
  if (!fs.existsSync(templatePath)) fail(`Template not found: templates/${templateId}.json`);

  const templateJson = JSON.parse(fs.readFileSync(templatePath, 'utf8'));
  ok(`Template: ${templateId}`);

  // ── Module 1: Planner ────────────────────────────────────────────────────
  const plan = planner(brief, templateJson);
  dim(`  Sections: ${plan.sections.map(s => s.id).join(' → ')}`);

  // ── --deploy shortcut: skip codegen, deploy existing HTML ────────────────
  if (deployOnly) {
    const outputFile = path.join(__dirname, 'output', plan.slug, 'index.html');
    if (!fs.existsSync(outputFile)) {
      fail(`No generated page found at output/${plan.slug}/index.html

Generate the HTML first — either:
  Option 1 (manual): paste prompts/codegen-prompt.md + your brief into any AI chat,
                     assemble the sections, save to output/${plan.slug}/index.html
  Option 3 (auto):   node generate.js --run ${briefArg}`);
    }

    // Pre-deploy validation — catch empty shells before they go live
    const fileSizeKB = Math.round(fs.statSync(outputFile).size / 1024);
    if (fileSizeKB < 5) {
      fail(`output/${plan.slug}/index.html is only ${fileSizeKB}KB — likely an empty or broken page.
Regenerate before deploying:
  node generate.js --run ${briefArg}`);
    }

    const htmlContent = fs.readFileSync(outputFile, 'utf8');
    ok(`Page loaded from output/${plan.slug}/index.html (${fileSizeKB}KB)`);

    try {
      const liveUrl = await publisher(plan.slug, htmlContent);
      ok(`Deployed → ${liveUrl}`);

      // Log to applications.json
      const appsPath = path.join(__dirname, 'applications', 'applications.json');
      let apps = [];
      if (fs.existsSync(appsPath)) {
        try { apps = JSON.parse(fs.readFileSync(appsPath, 'utf8')); } catch {}
      }
      apps.push({
        company:      brief._meta.company,
        role:         brief._meta.role,
        slug:         plan.slug,
        url:          liveUrl,
        published_at: new Date().toISOString(),
        confidence:   brief._meta.confidence_score || null,
        template:     brief._meta.template_id,
        mode:         '2b-manual-codegen',
        prompt_versions: {
          brainstorm: brief._meta.schema_version || null,
          codegen:    'manual',
        },
      });
      fs.mkdirSync(path.dirname(appsPath), { recursive: true });
      fs.writeFileSync(appsPath, JSON.stringify(apps, null, 2), 'utf8');
      ok(`Logged → applications/applications.json (${apps.length} total)`);

      console.log('');
      console.log(`${BOLD}Live URL:${RESET}`);
      console.log(`  ${GREEN}${liveUrl}${RESET}`);
      console.log('');
      console.log('Copy this into your cold message and send it.');
    } catch (e) {
      fail(`Deploy failed: ${e.message}`);
    }

    console.log('');
    return;
  }

  // ── Module 2: Knowledge Loader ───────────────────────────────────────────
  const profile = knowledgeLoader();
  ok(`Profile loaded: ${profile.identity?.name}`);

  // ── Module 3: DS Loader ──────────────────────────────────────────────────
  const dsTokens = dsLoader(brief);
  ok(`Design system: ${brief._meta.design_system === 'company' ? brief._meta.company + ' DS' : 'default'}`);

  // ── Module 4: Codegen ────────────────────────────────────────────────────
  const sectionOutputs = [];
  const failedSections = [];
  const succeededSections = [];

  for (const section of plan.sections) {
    info(`Generating: ${section.id}`);
    try {
      const html = await codegen(
        section.id,
        section.config,
        brief,
        profile,
        dsTokens,
        plan
      );
      sectionOutputs.push(html);
      succeededSections.push(section.id);
      ok(`  ${section.id} done`);
    } catch (e) {
      warn(`  ${section.id} failed: ${e.message}`);
      failedSections.push({ id: section.id, error: e.message });
      sectionOutputs.push(`<!-- ${section.id}: generation failed — ${e.message} -->`);
    }
  }

  // Determine generation outcome
  const totalSections   = plan.sections.length;
  const allFailed       = failedSections.length === totalSections;
  const partialFailure  = failedSections.length > 0 && !allFailed;

  if (allFailed) {
    console.error('');
    console.error(`${RED}✗${RESET} All ${totalSections} sections failed. Page not written.`);
    console.error('');
    console.error('  Common causes:');
    console.error('  • Wrong AI model — check AI_MODEL in .env matches your account');
    console.error('  • Invalid or expired API key');
    console.error('  • API rate limit or quota exceeded');
    console.error('');
    console.error(`  First error: ${failedSections[0].error}`);
    console.error('');
    console.error('  Fix your .env, then retry:');
    console.error(`  ${BOLD}node generate.js --run ${briefArg}${RESET}`);
    process.exit(1);
  }

  if (partialFailure) {
    console.error('');
    warn(`Partial failure — ${failedSections.length} of ${totalSections} sections failed:`);
    for (const f of failedSections) {
      console.error(`  ${RED}✗${RESET} ${f.id}: ${f.error}`);
    }
    console.error('');
    warn('Page will be assembled with placeholder comments for failed sections.');
    warn('Retry with: node generate.js --run ' + briefArg);
    console.error('');
  }

  // ── Module 5: Assembler ──────────────────────────────────────────────────
  info('Assembling page...');
  const fullHtml = assembler(sectionOutputs, dsTokens, brief, profile);

  // Write to output/
  const outputDir  = path.join(__dirname, 'output', plan.slug);
  const outputFile = path.join(outputDir, 'index.html');
  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(outputFile, fullHtml, 'utf8');

  const fileSizeKB = Math.round(fs.statSync(outputFile).size / 1024);
  ok(`Page assembled → output/${plan.slug}/index.html (${fileSizeKB}KB)`);

  // Exit 2 for partial failure — run.sh uses this to show recovery options
  if (partialFailure) process.exitCode = 2;

  // ── Module 6: Publisher ──────────────────────────────────────────────────
  if (publish) {
    try {
      const liveUrl = await publisher(plan.slug, fullHtml);
      ok(`Deployed → ${liveUrl}`);

      // ── Log to applications/applications.json ──────────────────────────
      const appsPath = path.join(__dirname, 'applications', 'applications.json');
      let apps = [];
      if (fs.existsSync(appsPath)) {
        try { apps = JSON.parse(fs.readFileSync(appsPath, 'utf8')); } catch {}
      }
      apps.push({
        company:      brief._meta.company,
        role:         brief._meta.role,
        slug:         plan.slug,
        url:          liveUrl,
        published_at: new Date().toISOString(),
        confidence:   brief._meta.confidence_score || null,
        template:     brief._meta.template_id,
        mode:         '3-auto',
        prompt_versions: {
          brainstorm: brief._meta.schema_version || null,
          codegen:    'codegen-v1',
        },
      });
      fs.mkdirSync(path.dirname(appsPath), { recursive: true });
      fs.writeFileSync(appsPath, JSON.stringify(apps, null, 2), 'utf8');
      ok(`Logged → applications/applications.json (${apps.length} total)`);

      console.log('');
      console.log(`${BOLD}Live URL:${RESET}`);
      console.log(`  ${GREEN}${liveUrl}${RESET}`);
      console.log('');
      console.log('Copy this into your cold message and send it.');
    } catch (e) {
      fail(`Deploy failed: ${e.message}`);
    }
  } else {
    console.log('');
    const absPath = path.resolve(outputFile);
    console.log(`${BOLD}Preview:${RESET}`);
    console.log(`  file://${absPath}`);
    console.log(`  (paste into any browser, or: open output/${plan.slug}/index.html on mac)`);
    console.log('');
    console.log(`When ready to go live:`);
    console.log(`  ${BOLD}node generate.js --publish ${briefArg}${RESET}`);
  }

  console.log('');
}

main().catch((e) => {
  fail(`Unexpected error: ${e.message}`);
});
