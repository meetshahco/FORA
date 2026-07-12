#!/usr/bin/env bash
# FORA — run.sh
# Per-application script. Run this for every new job you apply to.
# Guides you through brainstorm → generate → deploy in one flow.
# Option is selected per-run — no lock-in.
#
# Usage:
#   ./run.sh                              — interactive, prompts for JD URL
#   ./run.sh https://company.com/jobs/x  — pass JD URL directly
#   ./run.sh --brief briefs/[slug].json  — skip brainstorm, use existing brief
#   ./run.sh status                       — show pipeline state and recent activity

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
fail() { echo -e "${RED}✗${RESET} $1"; exit 1; }
warn() { echo -e "${YELLOW}⚠${RESET}  $1"; }
info() { echo -e "${BOLD}→${RESET} $1"; }
dim()  { echo -e "${DIM}$1${RESET}"; }
step() { echo -e "\n${BOLD}${CYAN}[$1]${RESET} ${BOLD}$2${RESET}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Ctrl+C exits cleanly ─────────────────────────────────────────────────────
trap 'echo ""; echo "  Exited. Resume with: ./run.sh --brief [path]"; exit 0' INT

JD_URL=""
BRIEF_PATH=""
SKIP_BRAINSTORM=false

# ── Parse args ────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--brief" && -n "${2:-}" ]]; then
  BRIEF_PATH="$2"
  SKIP_BRAINSTORM=true
elif [[ "${1:-}" == http* ]]; then
  JD_URL="$1"
elif [[ "${1:-}" == "status" ]]; then

  # ── STATUS ──────────────────────────────────────────────────────────────────
  echo ""
  echo -e "${BOLD}FORA — Status${RESET}"
  echo "──────────────────────────────────────────────────────"
  echo ""

  # Profile
  if [[ -f "profile/profile.json" ]]; then
    name=$(node -e "try{const p=require('./profile/profile.json');console.log(p.name||p.designer_name||'found')}catch(e){console.log('found')}" 2>/dev/null || echo "found")
    modified=$(date -r "profile/profile.json" "+%Y-%m-%d" 2>/dev/null || echo "unknown")
    ok "profile.json       $name · $modified"
  else
    echo -e "${RED}✗${RESET} profile.json       not found — run ./setup.sh"
  fi

  # Design system
  if [[ -f "design-system/default.md" ]]; then
    ok "design-system      default.md present"
  else
    warn "design-system      default.md missing — run ./setup.sh to restore"
  fi

  # API keys + model + deploy config
  ANTHROPIC_KEY=""
  GEMINI_KEY=""
  OPENAI_KEY=""
  VERCEL_TOKEN=""
  VERCEL_PROJECT_STATUS=""
  DEPLOY_DOMAIN_STATUS=""
  AI_MODEL_ENV=""
  AI_PROVIDER_ENV=""
  if [[ -f ".env" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
      k="${line%%=*}"; v="${line#*=}"
      case "$k" in
        ANTHROPIC_API_KEY)   ANTHROPIC_KEY="$v" ;;
        GEMINI_API_KEY)      GEMINI_KEY="$v" ;;
        OPENAI_API_KEY)      OPENAI_KEY="$v" ;;
        VERCEL_TOKEN)        VERCEL_TOKEN="$v" ;;
        VERCEL_PROJECT_NAME) VERCEL_PROJECT_STATUS="$v" ;;
        DEPLOY_DOMAIN)       DEPLOY_DOMAIN_STATUS="$v" ;;
        AI_MODEL)            AI_MODEL_ENV="$v" ;;
        AI_PROVIDER)         AI_PROVIDER_ENV="$v" ;;
      esac
    done < ".env"
  fi

  # Determine active provider + default model
  ACTIVE_PROVIDER=""
  DEFAULT_MODEL=""
  if [[ -n "$AI_PROVIDER_ENV" ]]; then
    ACTIVE_PROVIDER="$AI_PROVIDER_ENV"
  elif [[ -n "$ANTHROPIC_KEY" ]]; then
    ACTIVE_PROVIDER="anthropic"
  elif [[ -n "$GEMINI_KEY" ]]; then
    ACTIVE_PROVIDER="gemini"
  elif [[ -n "$OPENAI_KEY" ]]; then
    ACTIVE_PROVIDER="openai"
  fi
  case "$ACTIVE_PROVIDER" in
    anthropic) DEFAULT_MODEL="claude-opus-4-5" ;;
    gemini)    DEFAULT_MODEL="gemini-2.0-flash" ;;
    openai)    DEFAULT_MODEL="gpt-4o" ;;
  esac
  ACTIVE_MODEL="${AI_MODEL_ENV:-$DEFAULT_MODEL}"

  # Build deploy URL preview
  DEPLOY_URL_PREVIEW=""
  if [[ -n "$VERCEL_TOKEN" ]]; then
    if [[ -n "$DEPLOY_DOMAIN_STATUS" ]]; then
      DEPLOY_URL_PREVIEW="https://${DEPLOY_DOMAIN_STATUS}/[company]"
    elif [[ -n "$VERCEL_PROJECT_STATUS" ]]; then
      DEPLOY_URL_PREVIEW="https://${VERCEL_PROJECT_STATUS}.vercel.app/[company]"
    fi
  fi

  echo ""
  if [[ -n "$ANTHROPIC_KEY" ]]; then
    [[ "$ACTIVE_PROVIDER" == "anthropic" ]] \
      && ok "Anthropic          active · model: ${ACTIVE_MODEL}" \
      || ok "Anthropic key      set ${DIM}(not active — AI_PROVIDER=${AI_PROVIDER_ENV})${RESET}"
  else
    echo -e "${DIM}  Anthropic          not set${RESET}"
  fi
  if [[ -n "$GEMINI_KEY" ]]; then
    [[ "$ACTIVE_PROVIDER" == "gemini" ]] \
      && ok "Gemini             active · model: ${ACTIVE_MODEL}" \
      || ok "Gemini key         set ${DIM}(not active — AI_PROVIDER=${AI_PROVIDER_ENV})${RESET}"
  else
    echo -e "${DIM}  Gemini             not set${RESET}"
  fi
  if [[ -n "$OPENAI_KEY" ]]; then
    [[ "$ACTIVE_PROVIDER" == "openai" ]] \
      && ok "OpenAI             active · model: ${ACTIVE_MODEL}" \
      || ok "OpenAI key         set ${DIM}(not active — AI_PROVIDER=${AI_PROVIDER_ENV})${RESET}"
  else
    echo -e "${DIM}  OpenAI             not set${RESET}"
  fi
  if [[ -n "$VERCEL_TOKEN" ]]; then
    ok "Vercel             set · ${DEPLOY_URL_PREVIEW}"
  else
    echo -e "${DIM}  Vercel             not set${RESET}"
  fi
  echo ""
  if [[ -n "$ACTIVE_PROVIDER" ]]; then
    dim "  To update keys or model: ./setup.sh"
  fi

  # Available options
  echo ""
  HAS_A=false; HAS_V=false
  { [[ -n "$ANTHROPIC_KEY" ]] || [[ -n "$GEMINI_KEY" ]] || [[ -n "$OPENAI_KEY" ]]; } && HAS_A=true
  [[ -n "$VERCEL_TOKEN"  ]] && HAS_V=true
  echo -e "  Available options:"
  echo -e "  1 ${GREEN}✓${RESET}  Manual codegen + Manual deploy"
  [[ "$HAS_V" == true ]] \
    && echo -e "  2 ${GREEN}✓${RESET}  Manual codegen + Auto deploy  ${DIM}→ ${DEPLOY_URL_PREVIEW}${RESET}" \
    || echo -e "  2 ${DIM}✗  Manual codegen + Auto deploy  (needs Vercel token — run ./setup.sh)${RESET}"
  [[ "$HAS_A" == true ]] \
    && echo -e "  3 ${GREEN}✓${RESET}  Auto codegen via AI API + Manual deploy" \
    || echo -e "  3 ${DIM}✗  Auto codegen + Manual deploy  (needs AI key — run ./setup.sh)${RESET}"
  [[ "$HAS_A" == true && "$HAS_V" == true ]] \
    && echo -e "  4 ${GREEN}✓${RESET}  Auto codegen via AI API + Auto deploy  ${DIM}→ ${DEPLOY_URL_PREVIEW}${RESET}" \
    || echo -e "  4 ${DIM}✗  Auto codegen + Auto deploy    (needs AI key + Vercel token — run ./setup.sh)${RESET}"

  # Recent briefs
  echo ""
  echo -e "  ${BOLD}Recent briefs:${RESET}"
  briefs=$(ls -t briefs/*.json 2>/dev/null | grep -v "example-brief" | head -5 || true)
  if [[ -z "$briefs" ]]; then
    dim "    none yet"
  else
    while IFS= read -r f; do
      modified=$(date -r "$f" "+%Y-%m-%d" 2>/dev/null || echo "")
      echo -e "    $(basename "$f")  ${DIM}$modified${RESET}"
    done <<< "$briefs"
  fi

  # Recent pages
  echo ""
  echo -e "  ${BOLD}Recent pages:${RESET}"
  pages=$(find output -name "index.html" 2>/dev/null | xargs ls -t 2>/dev/null | head -5 || true)
  if [[ -z "$pages" ]]; then
    dim "    none yet"
  else
    while IFS= read -r f; do
      modified=$(date -r "$f" "+%Y-%m-%d" 2>/dev/null || echo "")
      slug=$(basename "$(dirname "$f")")
      echo -e "    output/$slug/index.html  ${DIM}$modified${RESET}"
    done <<< "$pages"
  fi

  echo ""
  echo "──────────────────────────────────────────────────────"
  echo -e "  ${BOLD}./run.sh${RESET}                        start a new application"
  echo -e "  ${BOLD}./run.sh --brief briefs/[x].json${RESET}  skip brainstorm, regenerate page"
  echo -e "  ${BOLD}./brainstorm.sh --recover [company]${RESET} save brief from clipboard (if JSON is copied but wasn't saved)"
  echo ""
  exit 0
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
GEMINI_KEY=""
OPENAI_KEY=""
VERCEL_TOKEN=""
VERCEL_PROJECT="fora-pages"
DEPLOY_DOMAIN_RUN=""

if [[ -f ".env" ]]; then
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
      DEPLOY_DOMAIN)       DEPLOY_DOMAIN_RUN="$v" ;;
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
    echo -e "  Job description URL:"
    echo -e "  ${DIM}Or press R to recover a brief you already have copied from AI chat${RESET}"
    echo -e "  ${DIM}(Ctrl+C to exit)${RESET}"
    read -r JD_URL
  fi

  echo ""

  # Recovery shortcut — user typed "r" or "R" at the URL prompt
  if [[ "$(echo "$JD_URL" | tr '[:upper:]' '[:lower:]')" == "r" ]]; then
    echo -e "  What company is this brief for? (used as the filename)"
    echo -e "  ${DIM}e.g. remote, linear, nola${RESET}"
    read -r recover_slug
    recover_slug=$(echo "$recover_slug" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')
    FORA_CALLED_FROM_RUN=true bash brainstorm.sh --recover "$recover_slug"
    BRIEF_PATH=$(ls -t briefs/*.json 2>/dev/null | head -1 || true)
    [[ -z "$BRIEF_PATH" ]] && fail "No brief found. Try again."
    SLUG=$(basename "$BRIEF_PATH" .json)
    ok "Brief ready: $BRIEF_PATH"
  elif [[ -n "$JD_URL" ]]; then
    FORA_CALLED_FROM_RUN=true bash brainstorm.sh "$JD_URL"
    # Find the most recently modified brief
    BRIEF_PATH=$(ls -t briefs/*.json 2>/dev/null | head -1 || true)
    [[ -z "$BRIEF_PATH" ]] && fail "No brief found in briefs/. Something went wrong in brainstorm."
    SLUG=$(basename "$BRIEF_PATH" .json)
    ok "Brief ready: $BRIEF_PATH"
  else
    fail "No URL provided. Run: ./run.sh https://company.com/jobs/role"
  fi
fi

echo ""
echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"
echo -e "  Brainstorm complete. Now let's generate your page."
echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"

# ════════════════════════════════════════════════════════════════════════════
# STEP 2 — MODE SELECTION
# ════════════════════════════════════════════════════════════════════════════
step "2/3" "Generate"
echo ""

# Build available options based on detected keys
HAS_AI=false
HAS_VERCEL=false
{ [[ -n "$ANTHROPIC_KEY" ]] || [[ -n "$GEMINI_KEY" ]] || [[ -n "$OPENAI_KEY" ]]; } && HAS_AI=true
[[ -n "$VERCEL_TOKEN"  ]] && HAS_VERCEL=true

echo "  How do you want to generate and deploy this page?"
echo ""
echo -e "  ${BOLD}1)${RESET} Manual codegen via AI chat + Manual deploy via any static host"
echo -e "  ${BOLD}2)${RESET} Manual codegen via AI chat + Auto deploy via Vercel            $([ "$HAS_VERCEL" == false ] && echo "${DIM}(needs Vercel token)${RESET}" || echo "${GREEN}✓${RESET}")"
echo -e "  ${BOLD}3)${RESET} Auto codegen via AI API   + Manual deploy via any static host  $([ "$HAS_AI" == false ] && echo "${DIM}(needs Anthropic, Gemini, or OpenAI key)${RESET}" || echo "${GREEN}✓${RESET}")"
echo -e "  ${BOLD}4)${RESET} Auto codegen via AI API   + Auto deploy via Vercel             $([ "$HAS_AI" == false ] || [ "$HAS_VERCEL" == false ] && echo "${DIM}(needs AI key + Vercel token)${RESET}" || echo "${GREEN}✓${RESET}")"
echo ""

# Show which keys are active
if [[ "$HAS_AI" == true || "$HAS_VERCEL" == true ]]; then
  KEYS_MSG="  Keys detected:"
  [[ -n "$ANTHROPIC_KEY" ]] && KEYS_MSG+=" Anthropic ✓"
  [[ -n "$GEMINI_KEY"    ]] && KEYS_MSG+=" Gemini ✓"
  [[ -n "$OPENAI_KEY"    ]] && KEYS_MSG+=" OpenAI ✓"
  [[ "$HAS_VERCEL" == true ]] && KEYS_MSG+=" Vercel ✓"
  dim "$KEYS_MSG"
else
  dim "  No keys detected — option 1 is free and needs nothing"
fi
echo ""

echo -e "  ${DIM}(Ctrl+C to exit)${RESET}"
read -r MODE_CHOICE

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
    if [[ "$HAS_AI" == false ]]; then
      echo ""
      warn "Option 3 needs an AI API key. Add one of these to your .env and run again."
      echo "  ANTHROPIC_API_KEY — https://console.anthropic.com/settings/keys"
      echo "  GEMINI_API_KEY    — https://aistudio.google.com/app/apikey"
      echo "  OPENAI_API_KEY    — https://platform.openai.com/api-keys"
      exit 1
    fi
    MODE="2a"
    ;;
  4)
    if [[ "$HAS_AI" == false || "$HAS_VERCEL" == false ]]; then
      echo ""
      warn "Option 4 needs both an AI key and a Vercel token. Add missing keys to your .env and run again."
      [[ "$HAS_AI" == false ]] && echo "  Missing AI key — add one of: ANTHROPIC_API_KEY, GEMINI_API_KEY, OPENAI_API_KEY"
      [[ "$HAS_VERCEL" == false ]]    && echo "  Missing: VERCEL_TOKEN — https://vercel.com/account/tokens"
      exit 1
    fi
    MODE="3"
    ;;
  *)
    MODE="1"
    ;;
esac

# Derive output slug from brief _meta (same logic as generate.js)
# Falls back to brief filename if _meta is missing
BRIEF_SLUG=$(node -e "
  try {
    const b = require('./$BRIEF_PATH');
    const c = (b._meta?.company || '').toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'');
    const r = (b._meta?.role    || '').toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'');
    console.log(c && r ? c+'-'+r : c || r || '');
  } catch(e) { console.log(''); }
" 2>/dev/null || echo "")
[[ -z "$BRIEF_SLUG" ]] && BRIEF_SLUG="$SLUG"
OUTPUT_FILE="output/$BRIEF_SLUG/index.html"

# Build deploy URL preview for pre-deploy gate
if [[ -n "$DEPLOY_DOMAIN_RUN" ]]; then
  DEPLOY_URL_PREVIEW="https://${DEPLOY_DOMAIN_RUN}/${BRIEF_SLUG}"
else
  DEPLOY_URL_PREVIEW="https://${VERCEL_PROJECT}.vercel.app/${BRIEF_SLUG}"
fi

# ── Helper: validate output file ─────────────────────────────────────────────
validate_output() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo ""
    fail "Output file not found: $file"
    echo ""
    echo "  This usually means generation was interrupted or failed silently."
    echo "  Re-run to try again:"
    echo ""
    case "$MODE" in
      3|2a) echo "  node generate.js --run $BRIEF_PATH" ;;
      2b|1) echo "  ./run.sh --brief $BRIEF_PATH" ;;
    esac
    echo ""
    exit 1
  fi

  local size_kb
  size_kb=$(du -k "$file" 2>/dev/null | cut -f1)
  if [[ "${size_kb:-0}" -lt 5 ]]; then
    echo ""
    warn "Output file is only ${size_kb}KB — likely an empty or broken page."
    echo ""
    echo -e "  ${DIM}This usually means all AI sections failed (wrong model, bad key, rate limit).${RESET}"
    echo -e "  ${DIM}Check your .env — then retry:${RESET}"
    echo ""
    case "$MODE" in
      3|2a) echo "  node generate.js --run $BRIEF_PATH" ;;
      2b|1) echo "  ./run.sh --brief $BRIEF_PATH" ;;
    esac
    echo ""
    exit 1
  fi
}

# ── Generate ──────────────────────────────────────────────────────────────────
echo ""

# Fix 5 — Resume from existing output
if [[ -f "$OUTPUT_FILE" ]]; then
  EXISTING_KB=$(du -k "$OUTPUT_FILE" 2>/dev/null | cut -f1)
  if [[ "${EXISTING_KB:-0}" -ge 5 ]]; then
    echo ""
    warn "A page already exists for this brief (${EXISTING_KB}KB):"
    dim "  $OUTPUT_FILE"
    echo ""
    echo "  What do you want to do?"
    echo "  1) Use existing page — skip to preview and deploy"
    echo "  2) Regenerate — overwrite with a fresh generation"
    echo ""
    echo -e "  ${DIM}(Ctrl+C to exit)${RESET}"
    read -r RESUME_CHOICE
    if [[ "$RESUME_CHOICE" == "1" ]]; then
      ok "Using existing page → $OUTPUT_FILE"
      SKIP_GENERATE=true
    else
      dim "  Regenerating..."
      SKIP_GENERATE=false
    fi
  fi
fi

SKIP_GENERATE="${SKIP_GENERATE:-false}"

if [[ "$SKIP_GENERATE" == false ]]; then
  case "$MODE" in
    3|2a)
      info "Generating page via AI API..."
      echo ""
      set +e
      node generate.js --run "$BRIEF_PATH"
      GEN_EXIT=$?
      set -e

      if [[ "$GEN_EXIT" -eq 1 ]]; then
        # Total failure — generate.js already printed the reason
        echo ""
        echo -e "  ${DIM}Fix the issue above, then retry: ./run.sh --brief $BRIEF_PATH${RESET}"
        echo ""
        exit 1
      elif [[ "$GEN_EXIT" -eq 2 ]]; then
        # Partial failure — sections were generated but some failed
        echo ""
        warn "Some sections failed. The page has been written with placeholders."
        echo ""
        echo "  Options:"
        echo "  1) Continue — preview the partial page and decide from there"
        echo "  2) Retry    — re-run generation now (./run.sh --brief will restart)"
        echo "  3) Abort"
        echo ""
        echo -e "  ${DIM}(Ctrl+C to exit)${RESET}"
        read -r PARTIAL_CHOICE
        case "$PARTIAL_CHOICE" in
          2)
            echo ""
            dim "  Re-running generation..."
            set +e
            node generate.js --run "$BRIEF_PATH"
            GEN_EXIT=$?
            set -e
            [[ "$GEN_EXIT" -eq 1 ]] && { echo ""; echo -e "  ${DIM}Fix the issue above, then retry: ./run.sh --brief $BRIEF_PATH${RESET}"; echo ""; exit 1; }
            ;;
          3)
            echo "  Aborted. Resume with: ./run.sh --brief $BRIEF_PATH"
            exit 0
            ;;
          *)
            dim "  Continuing with partial page..."
            ;;
        esac
      fi
      echo ""
      ok "Page generated → $OUTPUT_FILE"
      ;;

    2b|1)
      echo ""
      bash codegen.sh "$BRIEF_PATH"
      ;;
  esac
fi

# Fix 2 — output validation (catches empty shells for all modes)
validate_output "$OUTPUT_FILE"
ok "Page ready → $OUTPUT_FILE"

# ── Preview ───────────────────────────────────────────────────────────────────
echo ""
ABS_PATH="$(cd "$(dirname "$OUTPUT_FILE")" && pwd)/$(basename "$OUTPUT_FILE")"
echo -e "  ${BOLD}Preview your page before deploying:${RESET}"
echo -e "  ${DIM}open \"$ABS_PATH\"${RESET}"
echo -e "  ${DIM}or: file://$ABS_PATH${RESET}"
echo ""
echo -e "  Looks good? (Y/n)"
echo -e "  ${DIM}(Ctrl+C to exit)${RESET}"
read -r LOOKS_GOOD

if [[ "$LOOKS_GOOD" =~ ^[Nn]$ ]]; then
  echo ""
  echo "  No problem. Your page is saved — edit your brief and re-run:"
  echo ""
  case "$MODE" in
    3|2a) echo "  node generate.js --run $BRIEF_PATH" ;;
    2b|1) echo "  ./codegen.sh $BRIEF_PATH" ;;
  esac
  echo ""
  echo "  Or restart the full flow: ./run.sh --brief $BRIEF_PATH"
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
    # Fix 4 — pre-deploy gate
    echo -e "  ${BOLD}This will publish your page live.${RESET}"
    DEPLOY_URL_DISPLAY="${DEPLOY_URL_PREVIEW:-https://${VERCEL_PROJECT}.vercel.app/${BRIEF_SLUG}}"
    echo -e "  URL: ${DIM}${DEPLOY_URL_DISPLAY}${RESET}"
    echo ""
    echo -e "  Ready to go live? (y/N)"
    echo -e "  ${DIM}(Ctrl+C to exit)${RESET}"
    read -r DEPLOY_CONFIRM
    if [[ ! "$DEPLOY_CONFIRM" =~ ^[Yy]$ ]]; then
      echo ""
      echo "  Not deployed. Your page is saved locally:"
      echo "  $OUTPUT_FILE"
      echo ""
      echo "  Deploy whenever you're ready: node generate.js --deploy $BRIEF_PATH"
      echo ""
      exit 0
    fi
    echo ""
    info "Deploying via Vercel..."
    echo ""
    node generate.js --publish "$BRIEF_PATH" || { echo ""; fail "Deploy failed. Check VERCEL_TOKEN in .env and try: node generate.js --deploy $BRIEF_PATH"; }
    ;;

  2b)
    # Fix 4 — pre-deploy gate
    echo -e "  ${BOLD}This will publish your page live.${RESET}"
    DEPLOY_URL_DISPLAY="${DEPLOY_URL_PREVIEW:-https://${VERCEL_PROJECT}.vercel.app/${BRIEF_SLUG}}"
    echo -e "  URL: ${DIM}${DEPLOY_URL_DISPLAY}${RESET}"
    echo ""
    echo -e "  Ready to go live? (y/N)"
    echo -e "  ${DIM}(Ctrl+C to exit)${RESET}"
    read -r DEPLOY_CONFIRM
    if [[ ! "$DEPLOY_CONFIRM" =~ ^[Yy]$ ]]; then
      echo ""
      echo "  Not deployed. Your page is saved locally:"
      echo "  $OUTPUT_FILE"
      echo ""
      echo "  Deploy whenever you're ready: node generate.js --deploy $BRIEF_PATH"
      echo ""
      exit 0
    fi
    echo ""
    info "Deploying via Vercel..."
    echo ""
    node generate.js --deploy "$BRIEF_PATH" || { echo ""; fail "Deploy failed. Check VERCEL_TOKEN in .env and try: node generate.js --deploy $BRIEF_PATH"; }
    ;;

  2a|1)
    echo "  Deploy to any static host:"
    echo ""
    echo -e "  ${BOLD}Netlify drop${RESET} (free, no account needed)"
    echo "  → https://app.netlify.com/drop"
    echo "  → Drag your output/$BRIEF_SLUG/ folder in"
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
echo -e "${GREEN}${BOLD}Done.${RESET}"
echo ""
echo -e "  ${BOLD}Preview your page:${RESET}"
ABS_OUTPUT="$(cd "$(dirname "$OUTPUT_FILE")" 2>/dev/null && pwd)/$(basename "$OUTPUT_FILE")"
echo -e "  open \"$ABS_OUTPUT\""
echo ""
echo -e "  ${DIM}Next application:     ./run.sh${RESET}"
echo -e "  ${DIM}Re-run this one:      ./run.sh --brief $BRIEF_PATH${RESET}"
echo -e "  ${DIM}Health check:         ./setup.sh --check${RESET}"
echo ""
