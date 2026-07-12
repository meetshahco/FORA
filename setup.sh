#!/usr/bin/env bash
# FORA — setup.sh
# Version: 1.0.0
#
# Re-runnable health check and setup script.
# Run this anytime — first setup, after changing API keys, on a new machine, or when something feels wrong.
# It checks current state, tells you what's missing, and exits cleanly with a next step.
#
# Usage:
#   ./setup.sh          — full health check + setup
#   ./setup.sh --check  — health check only, no prompts

set -e

# Redirect stdin from terminal device — prevents clipboard content ever reaching stdin
exec < /dev/tty

# ── Colours ──────────────────────────────────────────────────────────────────
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
DIM='\033[2m'
CYAN='\033[0;36m'
RESET='\033[0m'

ok()   { echo -e "${GREEN}✓${RESET} $1"; }
fail() { echo -e "${RED}✗${RESET} $1"; }
warn() { echo -e "${YELLOW}⚠${RESET}  $1"; }
info() { echo -e "${BOLD}→${RESET} $1"; }
dim()  { echo -e "${DIM}$1${RESET}"; }
step() { echo -e "\n${BOLD}${CYAN}[$1]${RESET} ${BOLD}$2${RESET}"; }

CHECK_ONLY=false
[[ "$1" == "--check" ]] && CHECK_ONLY=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

EXIT_CODE=0

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}FORA — Setup & Health Check${RESET}"
echo "──────────────────────────────────────────────────────"
dim "Re-run this anytime: after changing keys, on a new machine, or when something feels wrong."
echo ""

# ── Ensure all scripts are executable ────────────────────────────────────────
for script in brainstorm.sh codegen.sh run.sh setup.sh; do
  [[ -f "$script" ]] && chmod +x "$script"
done

# ════════════════════════════════════════════════════════════════════════════
# CHECK 1 — Node.js
# ════════════════════════════════════════════════════════════════════════════
step "1/5" "Node.js"

if command -v node &>/dev/null; then
  NODE_VERSION=$(node --version)
  NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v//' | cut -d. -f1)
  if [[ "$NODE_MAJOR" -ge 18 ]]; then
    ok "Node $NODE_VERSION"
  else
    fail "Node $NODE_VERSION is too old. FORA needs Node 18+."
    echo ""
    echo "  Install the latest Node at: https://nodejs.org"
    echo ""
    exit 1
  fi
else
  fail "Node.js not found."
  echo ""
  echo "  Install Node 18+ at: https://nodejs.org"
  echo "  Then run ./setup.sh again."
  echo ""
  exit 1
fi

# ════════════════════════════════════════════════════════════════════════════
# CHECK 2 — Dependencies
# ════════════════════════════════════════════════════════════════════════════
step "2/5" "Dependencies"

if [[ -d "node_modules" ]]; then
  ok "node_modules present"
else
  if $CHECK_ONLY; then
    fail "node_modules not found — run: npm install"
    EXIT_CODE=1
  else
    info "Running npm install..."
    npm install
    ok "npm install complete"
  fi
fi

# ════════════════════════════════════════════════════════════════════════════
# CHECK 3 — Profile
# ════════════════════════════════════════════════════════════════════════════
step "3/5" "Profile"

if [[ -f "profile/profile.json" ]]; then
  # Quick validation — check it's valid JSON with an identity field
  if node -e "const p=require('./profile/profile.json'); if(!p.identity?.name) throw new Error()" 2>/dev/null; then
    NAME=$(node -e "console.log(require('./profile/profile.json').identity.name)" 2>/dev/null)
    ok "profile.json found — $NAME"
  else
    warn "profile.json exists but looks incomplete or invalid."
    dim "  Check that identity.name is filled in and the file is valid JSON."
    EXIT_CODE=1
  fi
else
  fail "profile/profile.json not found."
  echo ""
  echo "  Your profile is your private career knowledge base."
  echo "  It lives only on your machine and is never committed to git."
  echo ""
  echo "  To create it:"
  echo "  1. Open a new AI chat — Claude.ai, ChatGPT, or any model you prefer"
  echo "  2. Paste the contents of: prompts/profile-builder-prompt.md"
  echo "  3. Share your resume, LinkedIn export, or any career materials"
  echo "  4. Save the AI's output to: profile/profile.json"
  echo ""
  echo "  This takes ~15 minutes — the AI does the heavy lifting from your resume paste."
  echo "  Run ./setup.sh again when it's done."
  echo ""
  exit 1
fi

# ════════════════════════════════════════════════════════════════════════════
# CHECK 4 — Design System
# ════════════════════════════════════════════════════════════════════════════
step "4/5" "Design system"

if [[ -f "design-system/default.md" ]]; then
  # Check the TOKEN BLOCK css fence exists
  if grep -q '```css' design-system/default.md; then
    ok "design-system/default.md — token block present"
  else
    warn "design-system/default.md exists but no \`\`\`css token block found."
    dim "  generate.js reads the first \`\`\`css block. Check the TOKEN BLOCK section."
    EXIT_CODE=1
  fi
else
  fail "design-system/default.md not found."
  echo ""
  echo "  This file ships with the repo. If it's missing, restore it from git:"
  echo "  git checkout design-system/default.md"
  echo ""
  EXIT_CODE=1
fi

# ════════════════════════════════════════════════════════════════════════════
# CHECK 5 — API keys
# ════════════════════════════════════════════════════════════════════════════
step "5/5" "API keys"

ENV_FILE=".env"
ANTHROPIC_KEY=""
GEMINI_KEY=""
OPENAI_KEY=""
VERCEL_TOKEN=""
VERCEL_PROJECT=""
DEPLOY_DOMAIN=""
AI_MODEL_SET=""

# Load existing .env
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    k="${line%%=*}"; v="${line#*=}"
    v="${v%\"*}"; v="${v#\"}"
    case "$k" in
      ANTHROPIC_API_KEY)   ANTHROPIC_KEY="$v" ;;
      GEMINI_API_KEY)      GEMINI_KEY="$v" ;;
      OPENAI_API_KEY)      OPENAI_KEY="$v" ;;
      VERCEL_TOKEN)        VERCEL_TOKEN="$v" ;;
      VERCEL_PROJECT_NAME) VERCEL_PROJECT="$v" ;;
      DEPLOY_DOMAIN)       DEPLOY_DOMAIN="$v" ;;
      AI_MODEL)            AI_MODEL_SET="$v" ;;
    esac
  done < "$ENV_FILE"
fi

# Derive suggested project name from profile.json (slugified designer name)
SUGGESTED_PROJECT=""
if [[ -f "profile/profile.json" ]]; then
  PROFILE_NAME=$(node -e "try{const p=require('./profile/profile.json');console.log(p.identity?.name||'')}catch(e){}" 2>/dev/null || echo "")
  if [[ -n "$PROFILE_NAME" ]]; then
    SUGGESTED_PROJECT=$(echo "$PROFILE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
  fi
fi
[[ -z "$SUGGESTED_PROJECT" ]] && SUGGESTED_PROJECT="fora-pages"

# Summarise current state
HAS_AI=false
HAS_VERCEL=false
AI_PROVIDER_NAME=""
{ [[ -n "$ANTHROPIC_KEY" ]] || [[ -n "$GEMINI_KEY" ]] || [[ -n "$OPENAI_KEY" ]]; } && HAS_AI=true
[[ -n "$VERCEL_TOKEN" ]] && HAS_VERCEL=true
[[ -n "$ANTHROPIC_KEY" ]] && AI_PROVIDER_NAME="Anthropic"
[[ -n "$GEMINI_KEY"    ]] && AI_PROVIDER_NAME="Gemini"
[[ -n "$OPENAI_KEY"    ]] && AI_PROVIDER_NAME="OpenAI"

if [[ "$HAS_AI" == true ]]; then
  ok "AI key set (${AI_PROVIDER_NAME}) — auto codegen available"
else
  dim "  No AI key — manual codegen only (paste into AI chat)"
fi

if [[ "$HAS_VERCEL" == true ]]; then
  # Show what the deploy URL actually looks like
  CURRENT_PROJECT="${VERCEL_PROJECT:-$SUGGESTED_PROJECT}"
  if [[ -n "$DEPLOY_DOMAIN" ]]; then
    ok "Vercel token set — deploy URL: https://${DEPLOY_DOMAIN}/[company]"
  else
    ok "Vercel token set — deploy URL: https://${CURRENT_PROJECT}.vercel.app/[company]"
  fi
else
  dim "  No Vercel token — manual deploy only (Netlify drop or any static host)"
fi

# ── Conversational key setup (skip if --check) ──────────────────────────────
if ! $CHECK_ONLY; then

  # Only prompt if no keys exist OR user is on a re-run and things changed
  NEEDS_SETUP=false
  [[ ! -f "$ENV_FILE" ]] && NEEDS_SETUP=true

  if [[ "$NEEDS_SETUP" == false ]]; then
    echo ""
    echo -e "  ${DIM}Update or add API keys? (y/N)${RESET}"
    read -r DO_SETUP
    [[ "$DO_SETUP" =~ ^[Yy]$ ]] && NEEDS_SETUP=true
  fi

  if [[ "$NEEDS_SETUP" == true ]]; then
    echo ""
    echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"
    echo -e "${BOLD}Key setup${RESET}"
    echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"

    # ── Question 1: AI key ─────────────────────────────────────────────────
    echo ""
    if [[ "$HAS_AI" == true ]]; then
      echo -e "  AI key already set ${DIM}(${AI_PROVIDER_NAME})${RESET} — replace it or skip to keep it."
    else
      echo "  Do you have an AI API key? (used for auto codegen — options 3 + 4)"
      echo -e "  ${DIM}If not, you can always generate in AI chat for free — skip for now.${RESET}"
    fi
    echo ""
    echo "  1) Anthropic Claude  — console.anthropic.com/settings/keys"
    echo "  2) Google Gemini     — aistudio.google.com/app/apikey"
    echo "  3) OpenAI            — platform.openai.com/api-keys"
    [[ "$HAS_AI" == true ]] && echo "  4) Keep existing key" || echo "  4) Skip — no AI key"
    echo ""
    echo -e "  ${DIM}(Ctrl+C to exit)${RESET}"
    read -r AI_CHOICE

    NEW_ANTHROPIC=""
    NEW_GEMINI=""
    NEW_OPENAI=""
    NEW_MODEL=""

    case "$AI_CHOICE" in
      1)
        echo ""
        echo -e "  Paste your Anthropic key:"
        read -r NEW_ANTHROPIC
        if [[ -n "$NEW_ANTHROPIC" ]]; then
          ok "Anthropic key received"
          NEW_GEMINI=""; NEW_OPENAI=""
          GEMINI_KEY=""; OPENAI_KEY=""
          echo ""
          echo -e "  Which model? Press Enter for the default."
          echo -e "  ${DIM}1) claude-opus-4-5     (default — best quality)${RESET}"
          echo -e "  ${DIM}2) claude-sonnet-4-5   (faster, still strong)${RESET}"
          echo -e "  ${DIM}3) Custom — type a model name${RESET}"
          read -r MODEL_CHOICE
          case "$MODEL_CHOICE" in
            1|"") NEW_MODEL="claude-opus-4-5" ;;
            2)    NEW_MODEL="claude-sonnet-4-5" ;;
            3)    echo -e "  Model name:"; read -r NEW_MODEL ;;
            *)    NEW_MODEL="$MODEL_CHOICE" ;;
          esac
          ok "Model: ${NEW_MODEL}"
        fi
        ;;
      2)
        echo ""
        echo -e "  Paste your Gemini key:"
        read -r NEW_GEMINI
        if [[ -n "$NEW_GEMINI" ]]; then
          ok "Gemini key received"
          NEW_ANTHROPIC=""; NEW_OPENAI=""
          ANTHROPIC_KEY=""; OPENAI_KEY=""
          echo ""
          echo -e "  Which model? Press Enter for the default."
          echo -e "  ${DIM}1) gemini-2.0-flash    (recommended — fast, widely available)${RESET}"
          echo -e "  ${DIM}2) gemini-2.5-pro      (slower, highest quality)${RESET}"
          echo -e "  ${DIM}3) gemini-2.5-flash    (fast + strong — check availability for your account)${RESET}"
          echo -e "  ${DIM}4) Custom — type a model name${RESET}"
          read -r MODEL_CHOICE
          case "$MODEL_CHOICE" in
            1|"") NEW_MODEL="gemini-2.0-flash" ;;
            2)    NEW_MODEL="gemini-2.5-pro" ;;
            3)    NEW_MODEL="gemini-2.5-flash" ;;
            4)    echo -e "  Model name:"; read -r NEW_MODEL ;;
            *)    NEW_MODEL="$MODEL_CHOICE" ;;
          esac
          ok "Model: ${NEW_MODEL}"
        fi
        ;;
      3)
        echo ""
        echo -e "  Paste your OpenAI key:"
        read -r NEW_OPENAI
        if [[ -n "$NEW_OPENAI" ]]; then
          ok "OpenAI key received"
          NEW_ANTHROPIC=""; NEW_GEMINI=""
          ANTHROPIC_KEY=""; GEMINI_KEY=""
          echo ""
          echo -e "  Which model? Press Enter for the default."
          echo -e "  ${DIM}1) gpt-4o              (default — best quality)${RESET}"
          echo -e "  ${DIM}2) gpt-4o-mini          (faster, lower cost)${RESET}"
          echo -e "  ${DIM}3) Custom — type a model name${RESET}"
          read -r MODEL_CHOICE
          case "$MODEL_CHOICE" in
            1|"") NEW_MODEL="gpt-4o" ;;
            2)    NEW_MODEL="gpt-4o-mini" ;;
            3)    echo -e "  Model name:"; read -r NEW_MODEL ;;
            *)    NEW_MODEL="$MODEL_CHOICE" ;;
          esac
          ok "Model: ${NEW_MODEL}"
        fi
        ;;
      4|*)
        if [[ "$HAS_AI" == true ]]; then
          ok "Keeping existing ${AI_PROVIDER_NAME} key"
        else
          dim "  Skipping AI key — options 1 and 2 will always be available."
        fi
        ;;
    esac

    # ── Question 2: Vercel ─────────────────────────────────────────────────
    echo ""
    if [[ "$HAS_VERCEL" == true ]]; then
      CURRENT_PROJECT="${VERCEL_PROJECT:-$SUGGESTED_PROJECT}"
      if [[ -n "$DEPLOY_DOMAIN" ]]; then
        echo -e "  Vercel already set — deploy URL: ${DIM}https://${DEPLOY_DOMAIN}/[company]${RESET}"
      else
        echo -e "  Vercel already set — deploy URL: ${DIM}https://${CURRENT_PROJECT}.vercel.app/[company]${RESET}"
      fi
    else
      echo "  Do you have a Vercel token? (used for auto deploy — options 2 + 4)"
      echo -e "  ${DIM}Gets you a permanent live URL with one command. Free tier works.${RESET}"
      echo -e "  ${DIM}Get one at: vercel.com/account/tokens${RESET}"
    fi
    echo ""
    echo "  1) Paste a new token"
    if [[ "$HAS_VERCEL" == true ]]; then
      echo "  2) Update project name / custom domain  ${DIM}(keep existing token)${RESET}"
      echo "  3) Keep everything as-is"
    else
      echo "  2) Skip — I'll deploy manually"
    fi
    echo ""
    echo -e "  ${DIM}(Ctrl+C to exit)${RESET}"
    read -r VERCEL_CHOICE

    NEW_VERCEL=""
    NEW_PROJECT="${VERCEL_PROJECT:-$SUGGESTED_PROJECT}"
    NEW_DOMAIN="${DEPLOY_DOMAIN}"

    # Helper: ask project name + domain questions
    ask_project_and_domain() {
      echo ""
      echo -e "  What should your Vercel project be called?"
      echo -e "  ${DIM}This becomes your URL: [project-name].vercel.app/[company]${RESET}"
      echo -e "  ${DIM}Press Enter to use: ${NEW_PROJECT}${RESET}"
      read -r INPUT_PROJECT
      [[ -n "$INPUT_PROJECT" ]] && NEW_PROJECT="$INPUT_PROJECT"
      ok "Project: ${NEW_PROJECT} → https://${NEW_PROJECT}.vercel.app/[company]"

      echo ""
      echo -e "  Custom domain? (e.g. apply.yourname.com)"
      echo -e "  ${DIM}If yes, pages deploy to https://[domain]/[company] instead.${RESET}"
      if [[ -n "$NEW_DOMAIN" ]]; then
        echo -e "  ${DIM}Current: ${NEW_DOMAIN} — press Enter to keep, or type a new one${RESET}"
      else
        echo -e "  ${DIM}Leave blank to skip — you can add this later.${RESET}"
      fi
      read -r INPUT_DOMAIN
      if [[ -n "$INPUT_DOMAIN" ]]; then
        NEW_DOMAIN="$INPUT_DOMAIN"
        ok "Custom domain: https://${NEW_DOMAIN}/[company]"
        dim "  Remember to add this domain in Vercel dashboard → your project → Settings → Domains"
      elif [[ -n "$NEW_DOMAIN" ]]; then
        ok "Keeping domain: https://${NEW_DOMAIN}/[company]"
      fi
    }

    case "$VERCEL_CHOICE" in
      1)
        echo ""
        echo -e "  Paste your Vercel token:"
        read -r NEW_VERCEL
        if [[ -n "$NEW_VERCEL" ]]; then
          ok "Vercel token received"
          ask_project_and_domain
        fi
        ;;
      2)
        if [[ "$HAS_VERCEL" == true ]]; then
          # Keep token, update project name + domain only
          ask_project_and_domain
        else
          dim "  Skipping Vercel — you can drag your output/ folder to netlify.com/drop."
        fi
        ;;
      3|*)
        if [[ "$HAS_VERCEL" == true ]]; then
          ok "Keeping existing Vercel config"
        else
          dim "  Skipping Vercel — you can drag your output/ folder to netlify.com/drop."
        fi
        ;;
    esac

    # ── Write .env ─────────────────────────────────────────────────────────
    FINAL_ANTHROPIC="${NEW_ANTHROPIC:-$ANTHROPIC_KEY}"
    FINAL_GEMINI="${NEW_GEMINI:-$GEMINI_KEY}"
    FINAL_OPENAI="${NEW_OPENAI:-$OPENAI_KEY}"
    FINAL_VERCEL="${NEW_VERCEL:-$VERCEL_TOKEN}"
    FINAL_PROJECT="${NEW_PROJECT:-$SUGGESTED_PROJECT}"
    FINAL_DOMAIN="${NEW_DOMAIN:-$DEPLOY_DOMAIN}"
    FINAL_MODEL="${NEW_MODEL:-$AI_MODEL_SET}"

    {
      echo "# FORA — Environment Variables"
      echo "# Generated by setup.sh — re-run setup.sh to update keys, model, or domain"
      echo ""
      echo "# AI provider — add ONE key (FORA auto-detects which to use)"
      echo "# Options 3 + 4 only — not required for options 1 or 2"
      echo "ANTHROPIC_API_KEY=${FINAL_ANTHROPIC}"
      echo "GEMINI_API_KEY=${FINAL_GEMINI}"
      echo "OPENAI_API_KEY=${FINAL_OPENAI}"
      echo ""
      echo "# Model to use for codegen — set during setup, change anytime by re-running setup.sh"
      echo "AI_MODEL=${FINAL_MODEL}"
      echo ""
      echo "# Optional — force a specific provider if you have multiple keys"
      echo "AI_PROVIDER="
      echo ""
      echo "# Vercel — options 2 + 4 only"
      echo "VERCEL_TOKEN=${FINAL_VERCEL}"
      echo "# Your personal project name — your deploy URL is: https://[name].vercel.app/[company]"
      echo "VERCEL_PROJECT_NAME=${FINAL_PROJECT}"
      echo "# Optional custom domain — e.g. apply.yourname.com → https://apply.yourname.com/[company]"
      echo "DEPLOY_DOMAIN=${FINAL_DOMAIN}"
      echo ""
      echo "# PostHog — optional, V1 feature"
      echo "POSTHOG_API_KEY="
    } > "$ENV_FILE"

    echo ""
    ok ".env saved"

    # Re-read final state for summary
    ANTHROPIC_KEY="$FINAL_ANTHROPIC"
    GEMINI_KEY="$FINAL_GEMINI"
    OPENAI_KEY="$FINAL_OPENAI"
    VERCEL_TOKEN="$FINAL_VERCEL"
    VERCEL_PROJECT="$FINAL_PROJECT"
    DEPLOY_DOMAIN="$FINAL_DOMAIN"
    HAS_AI=false
    HAS_VERCEL=false
    AI_PROVIDER_NAME=""
    { [[ -n "$ANTHROPIC_KEY" ]] || [[ -n "$GEMINI_KEY" ]] || [[ -n "$OPENAI_KEY" ]]; } && HAS_AI=true
    [[ -n "$VERCEL_TOKEN" ]] && HAS_VERCEL=true
    [[ -n "$ANTHROPIC_KEY" ]] && AI_PROVIDER_NAME="Anthropic"
    [[ -n "$GEMINI_KEY"    ]] && AI_PROVIDER_NAME="Gemini"
    [[ -n "$OPENAI_KEY"    ]] && AI_PROVIDER_NAME="OpenAI"
  fi
fi

# ════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "──────────────────────────────────────────────────────"

if [[ "$EXIT_CODE" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}FORA is ready.${RESET}"
  echo ""

  # Show which options are unlocked
  echo -e "  ${BOLD}Available options:${RESET}"
  echo -e "  1 ${GREEN}✓${RESET}  Manual codegen + Manual deploy  ${DIM}(always free)${RESET}"
  if [[ "$HAS_VERCEL" == true ]]; then
    if [[ -n "$DEPLOY_DOMAIN" ]]; then
      DEPLOY_URL_PREVIEW="https://${DEPLOY_DOMAIN}/[company]"
    else
      DEPLOY_URL_PREVIEW="https://${VERCEL_PROJECT}.vercel.app/[company]"
    fi
    echo -e "  2 ${GREEN}✓${RESET}  Manual codegen + Auto deploy  ${DIM}→ ${DEPLOY_URL_PREVIEW}${RESET}"
  else
    echo -e "  2 ${DIM}✗  Manual codegen + Auto deploy  (add Vercel token — vercel.com/account/tokens)${RESET}"
  fi
  [[ "$HAS_AI" == true ]] \
    && echo -e "  3 ${GREEN}✓${RESET}  Auto codegen via ${AI_PROVIDER_NAME} + Manual deploy" \
    || echo -e "  3 ${DIM}✗  Auto codegen + Manual deploy  (add an AI key)${RESET}"
  if [[ "$HAS_AI" == true && "$HAS_VERCEL" == true ]]; then
    echo -e "  4 ${GREEN}✓${RESET}  Auto codegen via ${AI_PROVIDER_NAME} + Auto deploy  ${DIM}→ ${DEPLOY_URL_PREVIEW}${RESET}"
  else
    echo -e "  4 ${DIM}✗  Auto codegen + Auto deploy    (add AI key + Vercel token)${RESET}"
  fi

  echo ""
  echo -e "  ${BOLD}Start your first application:${RESET}"
  echo -e "  ${BOLD}./run.sh${RESET}"
  echo ""
  dim "  Re-run ./setup.sh anytime to update keys, model, or domain."
else
  echo -e "${YELLOW}${BOLD}Setup incomplete.${RESET} Fix the issues above and run ./setup.sh again."
fi

echo ""
