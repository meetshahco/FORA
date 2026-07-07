#!/usr/bin/env bash
# FORA — run.sh
# Per-application script. Run this for every new job you apply to.
# Guides you through brainstorm → generate → deploy in one flow.
# Mode is selected per-run — no lock-in.
#
# Usage:
#   ./run.sh                              — interactive, prompts for JD URL
#   ./run.sh https://company.com/jobs/x  — pass JD URL directly
#   ./run.sh --brief briefs/[slug].json  — skip brainstorm, use existing brief

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
fail() { echo -e "${RED}✗${RESET} $1"; exit 1; }
warn() { echo -e "${YELLOW}⚠${RESET}  $1"; }
info() { echo -e "${BOLD}→${RESET} $1"; }
dim()  { echo -e "${DIM}$1${RESET}"; }
step() { echo -e "\n${BOLD}${CYAN}[$1]${RESET} ${BOLD}$2${RESET}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

JD_URL=""
BRIEF_PATH=""
SKIP_BRAINSTORM=false

# ── Parse args ────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--brief" && -n "${2:-}" ]]; then
  BRIEF_PATH="$2"
  SKIP_BRAINSTORM=true
elif [[ "${1:-}" == http* ]]; then
  JD_URL="$1"
fi

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}FORA — New Application${RESET}"
echo "──────────────────────────────────────────────────────"

# ── Pre-flight checks ─────────────────────────────────────────────────────────
if [[ ! -f "profile/profile.json" ]]; then
  fail "profile/profile.json not found. Run ./setup.sh first."
fi

if [[ ! -f "design-system/default.md" ]]; then
  fail "design-system/default.md not found. Run ./setup.sh to restore."
fi

# ── Load .env (detect available keys) ────────────────────────────────────────
ANTHROPIC_KEY=""
VERCEL_TOKEN=""
VERCEL_PROJECT="fora-pages"

if [[ -f ".env" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    k="${line%%=*}"; v="${line#*=}"
    v="${v%\"*}"; v="${v#\"}"
    case "$k" in
      ANTHROPIC_API_KEY)   ANTHROPIC_KEY="$v" ;;
      VERCEL_TOKEN)        VERCEL_TOKEN="$v" ;;
      VERCEL_PROJECT_NAME) VERCEL_PROJECT="$v" ;;
    esac
  done < ".env"
fi

# ════════════════════════════════════════════════════════════════════════════
# STEP 1 — BRAINSTORM
# ════════════════════════════════════════════════════════════════════════════

if $SKIP_BRAINSTORM; then
  [[ -f "$BRIEF_PATH" ]] || fail "Brief not found: $BRIEF_PATH"
  ok "Using existing brief: $BRIEF_PATH"
  SLUG=$(basename "$BRIEF_PATH" .json)
else
  step "1/3" "Brainstorm"

  if [[ -z "$JD_URL" ]]; then
    echo ""
    read -rp "  Job description URL: " JD_URL
  fi

  echo ""
  if [[ -n "$JD_URL" ]]; then
    bash brainstorm.sh "$JD_URL"
  else
    fail "No URL provided. Run: ./run.sh https://company.com/jobs/role"
  fi

  # brainstorm.sh saves the brief and prints the slug — derive from briefs/
  # Find the most recently modified brief
  BRIEF_PATH=$(ls -t briefs/*.json 2>/dev/null | head -1 || true)
  [[ -z "$BRIEF_PATH" ]] && fail "No brief found in briefs/. Something went wrong in brainstorm."
  SLUG=$(basename "$BRIEF_PATH" .json)
  ok "Brief ready: $BRIEF_PATH"
fi

# ════════════════════════════════════════════════════════════════════════════
# STEP 2 — MODE SELECTION
# ════════════════════════════════════════════════════════════════════════════
step "2/3" "Generate"
echo ""

# Build available options based on detected keys
HAS_ANTHROPIC=false
HAS_VERCEL=false
[[ -n "$ANTHROPIC_KEY" ]] && HAS_ANTHROPIC=true
[[ -n "$VERCEL_TOKEN"  ]] && HAS_VERCEL=true

echo "  How do you want to generate and deploy this page?"
echo ""
echo -e "  ${BOLD}1)${RESET} Manual codegen via AI chat   + Manual deploy via any static host"
echo -e "  ${BOLD}2)${RESET} Manual codegen via AI chat   + Auto deploy via Vercel            $([ "$HAS_VERCEL" == false ] && echo "${DIM}(needs Vercel token)${RESET}" || echo "${GREEN}✓${RESET}")"
echo -e "  ${BOLD}3)${RESET} Auto codegen via Anthropic API + Manual deploy via any static host $([ "$HAS_ANTHROPIC" == false ] && echo "${DIM}(needs Anthropic key)${RESET}" || echo "${GREEN}✓${RESET}")"
echo -e "  ${BOLD}4)${RESET} Auto codegen via Anthropic API + Auto deploy via Vercel            $([ "$HAS_ANTHROPIC" == false ] || [ "$HAS_VERCEL" == false ] && echo "${DIM}(needs both keys)${RESET}" || echo "${GREEN}✓${RESET}")"
echo ""

# Show which keys are active
if [[ "$HAS_ANTHROPIC" == true || "$HAS_VERCEL" == true ]]; then
  KEYS_MSG="  Keys detected:"
  [[ "$HAS_ANTHROPIC" == true ]] && KEYS_MSG+=" Anthropic ✓"
  [[ "$HAS_VERCEL" == true ]]    && KEYS_MSG+=" Vercel ✓"
  dim "$KEYS_MSG"
else
  dim "  No keys detected — option 1 is free and needs nothing"
fi
echo ""

read -rp "  Enter 1, 2, 3, or 4: " MODE_CHOICE

# Validate choice against available keys
case "$MODE_CHOICE" in
  2)
    if [[ "$HAS_VERCEL" == false ]]; then
      echo ""
      warn "Option 2 needs a Vercel token. Add VERCEL_TOKEN to your .env and run again."
      echo "  Get a token at: https://vercel.com/account/tokens"
      exit 1
    fi
    MODE="2b"
    ;;
  3)
    if [[ "$HAS_ANTHROPIC" == false ]]; then
      echo ""
      warn "Option 3 needs an Anthropic API key. Add ANTHROPIC_API_KEY to your .env and run again."
      echo "  Get a key at: https://console.anthropic.com/settings/keys"
      exit 1
    fi
    MODE="2a"
    ;;
  4)
    if [[ "$HAS_ANTHROPIC" == false || "$HAS_VERCEL" == false ]]; then
      echo ""
      warn "Option 4 needs both keys. Add missing keys to your .env and run again."
      [[ "$HAS_ANTHROPIC" == false ]] && echo "  Missing: ANTHROPIC_API_KEY — https://console.anthropic.com/settings/keys"
      [[ "$HAS_VERCEL" == false ]]    && echo "  Missing: VERCEL_TOKEN — https://vercel.com/account/tokens"
      exit 1
    fi
    MODE="3"
    ;;
  *)
    MODE="1"
    ;;
esac

OUTPUT_FILE="output/$SLUG/index.html"

# ── Generate ──────────────────────────────────────────────────────────────────
echo ""

case "$MODE" in
  3|2a)
    info "Generating page via Anthropic API..."
    echo ""
    if node generate.js --run "$BRIEF_PATH"; then
      echo ""
      ok "Page generated → $OUTPUT_FILE"
    else
      fail "generate.js failed. Check ANTHROPIC_API_KEY in .env and try again."
    fi
    ;;

  2b|1)
    echo ""
    bash codegen.sh "$BRIEF_PATH"

    if [[ ! -f "$OUTPUT_FILE" ]]; then
      fail "Page not saved at $OUTPUT_FILE. Run ./run.sh --brief $BRIEF_PATH to try again."
    fi
    ok "Page ready → $OUTPUT_FILE"
    ;;
esac

# ── Preview ───────────────────────────────────────────────────────────────────
echo ""
ABS_PATH="$(cd "$(dirname "$OUTPUT_FILE")" && pwd)/$(basename "$OUTPUT_FILE")"
echo -e "  ${BOLD}Preview your page before deploying:${RESET}"
echo -e "  ${DIM}file://$ABS_PATH${RESET}"
echo ""
read -rp "  Happy with it? (y/n): " LOOKS_GOOD

if [[ "$LOOKS_GOOD" =~ ^[Nn]$ ]]; then
  echo ""
  echo "  No problem — edit your brief and re-run:"
  echo ""
  case "$MODE" in
    3|2a) echo "  node generate.js --run $BRIEF_PATH" ;;
    2b|1) echo "  ./codegen.sh $BRIEF_PATH" ;;
  esac
  echo ""
  echo "  Or re-run the full flow: ./run.sh --brief $BRIEF_PATH"
  echo ""
  exit 0
fi

# ════════════════════════════════════════════════════════════════════════════
# STEP 3 — DEPLOY
# ════════════════════════════════════════════════════════════════════════════
step "3/3" "Deploy"
echo ""

case "$MODE" in
  3)
    info "Deploying via Vercel..."
    echo ""
    node generate.js --publish "$BRIEF_PATH" || fail "Deploy failed. Check VERCEL_TOKEN in .env."
    ;;

  2b)
    info "Deploying via Vercel..."
    echo ""
    node generate.js --deploy "$BRIEF_PATH" || fail "Deploy failed. Check VERCEL_TOKEN in .env."
    ;;

  2a|1)
    echo "  Deploy to any static host:"
    echo ""
    echo -e "  ${BOLD}Netlify drop${RESET} (free, no account needed)"
    echo "  → https://app.netlify.com/drop"
    echo "  → Drag your output/$SLUG/ folder in"
    echo ""
    echo -e "  ${BOLD}GitHub Pages, Cloudflare Pages, or any static host${RESET}"
    echo "  → The output is a single self-contained index.html"
    echo ""
    dim "  Want automated deploy next time? Add a Vercel token and pick option 2 or 4 on the next run."
    echo ""
    ;;
esac

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "──────────────────────────────────────────────────────"
echo -e "${GREEN}${BOLD}Application ready.${RESET}"
echo ""
echo "  Next application:  ./run.sh [JD URL]"
echo "  Re-run this one:   ./run.sh --brief $BRIEF_PATH"
echo "  Health check:      ./setup.sh --check"
echo ""
