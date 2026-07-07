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
# CHECK 5 — Mode + API keys
# ════════════════════════════════════════════════════════════════════════════
step "5/5" "Mode & API keys"

# Load .env if it exists
ENV_FILE=".env"
ANTHROPIC_KEY=""
VERCEL_TOKEN=""
VERCEL_PROJECT=""

if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    val="${val%\"}"
    val="${val#\"}"
    case "$key" in
      ANTHROPIC_API_KEY)   ANTHROPIC_KEY="$val" ;;
      VERCEL_TOKEN)        VERCEL_TOKEN="$val" ;;
      VERCEL_PROJECT_NAME) VERCEL_PROJECT="$val" ;;
    esac
  done < "$ENV_FILE"
fi

# Determine current mode from keys present
if [[ -n "$ANTHROPIC_KEY" && -n "$VERCEL_TOKEN" ]]; then
  CURRENT_MODE=3
elif [[ -n "$ANTHROPIC_KEY" && -z "$VERCEL_TOKEN" ]]; then
  CURRENT_MODE="2a"
elif [[ -z "$ANTHROPIC_KEY" && -n "$VERCEL_TOKEN" ]]; then
  CURRENT_MODE="2b"
else
  CURRENT_MODE=1
fi

# Print current mode status
case "$CURRENT_MODE" in
  1)
    ok "Mode 1 — Fully manual (no API keys configured)"
    dim "  Codegen: paste manually into AI chat"
    dim "  Deploy:  drag to Netlify drop or any static host"
    ;;
  2a)
    ok "Mode 2A — Automated codegen (Anthropic configured)"
    dim "  Codegen: node generate.js --run"
    dim "  Deploy:  drag to Netlify or add Vercel token for Mode 3"
    ;;
  2b)
    ok "Mode 2B — Manual codegen + auto deploy (Vercel configured) ★"
    dim "  Codegen: paste manually into AI chat"
    dim "  Deploy:  node generate.js --deploy"
    ;;
  3)
    ok "Mode 3 — Fully automated (Anthropic + Vercel configured)"
    dim "  Codegen: node generate.js --run"
    dim "  Deploy:  node generate.js --publish"
    ;;
esac

# Offer mode change if not check-only
if ! $CHECK_ONLY; then
  echo ""
  echo -e "  ${DIM}Want to switch mode or update your keys? (y/N)${RESET}"
  read -r SWITCH_MODE
  if [[ "$SWITCH_MODE" =~ ^[Yy]$ ]]; then
    echo ""
    echo "  Which mode do you want to use?"
    echo ""
    echo "  1) Fully manual          — free, no API keys"
    echo "     Codegen in AI chat. Deploy via Netlify drag-and-drop."
    echo ""
    echo "  2) Manual codegen + auto deploy  ★  — Vercel token only"
    echo "     Codegen in AI chat (zero cost). One command to get a live URL."
    echo ""
    echo "  3) Automated codegen + manual deploy  — Anthropic key only"
    echo "     generate.js handles HTML. Deploy manually."
    echo ""
    echo "  4) Fully automated  — Anthropic + Vercel"
    echo "     One command from brief to live URL."
    echo ""
    read -rp "  Mode (1/2/3/4): " MODE_CHOICE

    NEW_ANTHROPIC=""
    NEW_VERCEL=""
    NEW_PROJECT=""

    case "$MODE_CHOICE" in
      1)
        echo ""
        echo "  Mode 1: You'll paste codegen-prompt.md + your brief into any AI chat."
        echo "          Cost: \$0 per application."
        echo ""
        ok "Mode 1 selected. No API keys needed."
        # Clear keys if .env exists
        if [[ -f "$ENV_FILE" ]]; then
          sed -i.bak 's/^ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=/' "$ENV_FILE"
          sed -i.bak 's/^VERCEL_TOKEN=.*/VERCEL_TOKEN=/' "$ENV_FILE"
          rm -f "${ENV_FILE}.bak"
        fi
        ;;
      2)
        echo ""
        echo "  Mode 2B: You'll paste codegen-prompt.md + your brief into any AI chat."
        echo "           Vercel handles deploy automatically."
        echo "           Cost: \$0 per application."
        echo ""
        read -rp "  Paste your Vercel token: " NEW_VERCEL
        NEW_PROJECT="${VERCEL_PROJECT:-fora-pages}"
        read -rp "  Vercel project name [${NEW_PROJECT}]: " INPUT_PROJECT
        [[ -n "$INPUT_PROJECT" ]] && NEW_PROJECT="$INPUT_PROJECT"
        ;;
      3)
        echo ""
        echo "  Mode 2A: generate.js calls the Anthropic API to build your HTML automatically."
        echo "           Deploy the output manually (Netlify, GitHub Pages, etc.)"
        echo ""
        read -rp "  Paste your Anthropic API key: " NEW_ANTHROPIC
        ;;
      4)
        echo ""
        echo "  Mode 3: generate.js builds your HTML and deploys to Vercel in one command."
        echo ""
        read -rp "  Paste your Anthropic API key: " NEW_ANTHROPIC
        read -rp "  Paste your Vercel token: " NEW_VERCEL
        NEW_PROJECT="${VERCEL_PROJECT:-fora-pages}"
        read -rp "  Vercel project name [${NEW_PROJECT}]: " INPUT_PROJECT
        [[ -n "$INPUT_PROJECT" ]] && NEW_PROJECT="$INPUT_PROJECT"
        ;;
      *)
        warn "Unrecognised choice. Keeping current mode."
        ;;
    esac

    # Write .env
    if [[ -n "$NEW_ANTHROPIC" || -n "$NEW_VERCEL" || "$MODE_CHOICE" == "1" ]]; then
      cp .env.example "$ENV_FILE" 2>/dev/null || touch "$ENV_FILE"
      # Write cleanly from .env.example structure
      {
        echo "# FORA — Environment Variables"
        echo "# Generated by setup.sh — re-run setup.sh to change mode or update keys"
        echo ""
        echo "# Anthropic — Mode 2A + 3 only"
        echo "ANTHROPIC_API_KEY=${NEW_ANTHROPIC}"
        echo ""
        echo "# Model override (optional)"
        echo "AI_MODEL="
        echo ""
        echo "# Vercel — Mode 2B + 3 only"
        echo "VERCEL_TOKEN=${NEW_VERCEL}"
        echo "VERCEL_PROJECT_NAME=${NEW_PROJECT:-fora-pages}"
        echo "DEPLOY_DOMAIN="
        echo ""
        echo "# PostHog — optional, V1 feature"
        echo "POSTHOG_API_KEY="
      } > "$ENV_FILE"
      ok ".env written"
    fi
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

  # Print the right next-step based on current mode
  # Re-read .env to get final state
  FINAL_ANTHROPIC=""
  FINAL_VERCEL=""
  if [[ -f "$ENV_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
      k="${line%%=*}"; v="${line#*=}"
      [[ "$k" == "ANTHROPIC_API_KEY" ]] && FINAL_ANTHROPIC="$v"
      [[ "$k" == "VERCEL_TOKEN" ]]      && FINAL_VERCEL="$v"
    done < "$ENV_FILE"
  fi

  if [[ -n "$FINAL_ANTHROPIC" && -n "$FINAL_VERCEL" ]]; then
    echo "  Your workflow (Mode 3 — fully automated):"
    echo ""
    dim "  Per application:"
    echo "  1.  ./brainstorm.sh https://company.com/jobs/role"
    echo "      → paste into AI chat → save brief to briefs/[slug].json"
    echo "  2.  node generate.js --publish briefs/[slug].json"
    echo "      → live URL returned"
  elif [[ -n "$FINAL_ANTHROPIC" ]]; then
    echo "  Your workflow (Mode 2A — auto codegen):"
    echo ""
    dim "  Per application:"
    echo "  1.  ./brainstorm.sh https://company.com/jobs/role"
    echo "      → paste into AI chat → save brief to briefs/[slug].json"
    echo "  2.  node generate.js --run briefs/[slug].json"
    echo "      → open output/[slug]/index.html in browser"
    echo "  3.  Deploy manually (Netlify drop, GitHub Pages, etc.)"
  elif [[ -n "$FINAL_VERCEL" ]]; then
    echo "  Your workflow (Mode 2B — manual codegen, auto deploy) ★"
    echo ""
    dim "  Per application:"
    echo "  1.  ./brainstorm.sh https://company.com/jobs/role"
    echo "      → paste into AI chat → save brief to briefs/[slug].json"
    echo "  2.  Open AI chat → paste prompts/codegen-prompt.md + brief"
    echo "      → save HTML to output/[slug]/index.html"
    echo "  3.  node generate.js --deploy briefs/[slug].json"
    echo "      → live URL returned"
  else
    echo "  Your workflow (Mode 1 — fully manual):"
    echo ""
    dim "  Per application:"
    echo "  1.  ./brainstorm.sh https://company.com/jobs/role"
    echo "      → paste into AI chat → save brief to briefs/[slug].json"
    echo "  2.  Open AI chat → paste prompts/codegen-prompt.md + brief"
    echo "      → save HTML to output/[slug]/index.html"
    echo "  3.  Drag output/[slug]/ to https://app.netlify.com/drop"
    echo "      → live URL returned"
  fi

  echo ""
  dim "  Re-run ./setup.sh anytime to check your setup or switch mode."
else
  echo -e "${YELLOW}${BOLD}Setup incomplete.${RESET} Fix the issues above and run ./setup.sh again."
fi

echo ""
