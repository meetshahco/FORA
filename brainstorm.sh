#!/usr/bin/env bash
# FORA — brainstorm.sh
# Fetches a JD, assembles the brainstorm prompt + your profile.json,
# copies everything to clipboard, then guides you through saving the brief.
#
# Usage:
#   ./brainstorm.sh https://company.com/jobs/senior-designer
#   ./brainstorm.sh                  # will ask you for the URL interactively

set -euo pipefail

# Redirect stdin from terminal device — prevents clipboard content ever reaching stdin
exec < /dev/tty

# ── Colours for output ──────────────────────────────────────────────────────
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
DIM="\033[2m"
RESET="\033[0m"

ok()   { echo -e "${GREEN}✓${RESET} $1"; }
info() { echo -e "${BOLD}→${RESET} $1"; }
warn() { echo -e "${YELLOW}⚠${RESET}  $1"; }
fail() { echo -e "${RED}✗${RESET} $1"; exit 1; }

# ── Paths ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="$SCRIPT_DIR/prompts/brainstorm-prompt.md"
PROFILE_FILE="$SCRIPT_DIR/profile/profile.json"
BRIEFS_DIR="$SCRIPT_DIR/briefs"

# ── Ctrl+C exits cleanly ─────────────────────────────────────────────────────
trap 'echo ""; echo "  Exited."; echo "  Resume:   ./run.sh"; echo "  Recover:  ./brainstorm.sh --recover [company]  (if you have the JSON copied)"; exit 0' INT

# ── Check dependencies ───────────────────────────────────────────────────────
check_deps() {
  local missing=()
  command -v curl &>/dev/null || missing+=("curl")
  if ! command -v pbcopy &>/dev/null && \
     ! command -v xclip &>/dev/null && \
     ! command -v xsel  &>/dev/null; then
    missing+=("pbcopy / xclip / xsel (clipboard tool)")
  fi
  if [[ ${#missing[@]} -gt 0 ]]; then
    fail "Missing dependencies: ${missing[*]}"
  fi
}

# ── Flush any buffered stdin (prevents clipboard paste bleeding into shell) ──
flush_stdin() {
  while read -r -t 0 _; do read -r _; done 2>/dev/null || true
}

# ── Copy to clipboard (cross-platform) ──────────────────────────────────────
copy_to_clipboard() {
  local content="$1"
  if command -v pbcopy &>/dev/null; then
    echo "$content" | pbcopy
  elif command -v xclip &>/dev/null; then
    echo "$content" | xclip -selection clipboard
  elif command -v xsel &>/dev/null; then
    echo "$content" | xsel --clipboard --input
  fi
}

# ── Paste from clipboard (cross-platform) ───────────────────────────────────
paste_from_clipboard() {
  if command -v pbpaste &>/dev/null; then
    pbpaste
  elif command -v xclip &>/dev/null; then
    xclip -selection clipboard -o
  elif command -v xsel &>/dev/null; then
    xsel --clipboard --output
  fi
}

# ── Derive slug from URL ─────────────────────────────────────────────────────
# Extracts the domain name only (e.g. "remote", "notion", "linear")
# Avoids job ID numbers and path noise like /openings/7762220003
derive_slug() {
  local url="$1"
  # Strip protocol explicitly for macOS sed compatibility
  url="${url#http://}"
  url="${url#https://}"
  url="${url#www.}"
  # Extract domain only (first segment before first /)
  local domain="${url%%/*}"
  # Extract company name (second-to-last dot segment, e.g. "remote" from "remote.com")
  local slug
  slug=$(echo "$domain" | awk -F'.' '{if(NF>=2) print $(NF-1); else print $1}')
  # Sanitise
  slug=$(echo "$slug" | sed 's/[^a-zA-Z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//' | tr '[:upper:]' '[:lower:]')
  echo "$slug"
}

# ── Fetch JD text from URL ───────────────────────────────────────────────────
fetch_jd() {
  local url="$1"
  local raw

  info "Fetching job description from $url"

  raw=$(curl -sL --max-time 15 \
    -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
    "$url" 2>/dev/null) || fail "Could not fetch URL. Check your connection or paste the JD manually."

  local text
  text=$(echo "$raw" \
    | sed 's/<[^>]*>//g' \
    | sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&nbsp;/ /g; s/&#39;/'"'"'/g; s/&quot;/"/g' \
    | sed '/^[[:space:]]*$/d' \
    | tr -s ' ' \
    | head -n 300)

  if [[ -z "$text" ]]; then
    warn "Could not fetch the JD automatically — some job boards block this."
    echo ""
    echo "  Copy the job description text manually from the page,"
    echo "  then paste it into your AI chat alongside the brainstorm prompt."
    echo ""
    echo "  The prompt is already on your clipboard — just add the JD text manually."
    echo ""
    exit 0
  fi

  echo "$text"
}

# ── Save brief interactively ─────────────────────────────────────────────────
save_brief() {
  local slug="$1"
  local brief_path="$BRIEFS_DIR/${slug}.json"

  mkdir -p "$BRIEFS_DIR"

  # Check if brief already exists and ask what to do
  if [[ -f "$brief_path" ]]; then
    echo ""
    warn "A brief for this company already exists: briefs/${slug}.json"
    echo ""
    echo "  What would you like to do?"
    echo "  1) Overwrite it with a new brief"
    echo "  2) Save as a new version (briefs/${slug}-v2.json)"
    echo "  3) Keep the existing brief and exit"
    echo ""
    flush_stdin; read -r choice < /dev/tty
    case "$choice" in
      1)
        info "Will overwrite briefs/${slug}.json"
        ;;
      2)
        # Find next available version number
        local v=2
        while [[ -f "$BRIEFS_DIR/${slug}-v${v}.json" ]]; do
          ((v++))
        done
        slug="${slug}-v${v}"
        brief_path="$BRIEFS_DIR/${slug}.json"
        info "Will save as briefs/${slug}.json"
        ;;
      3)
        echo ""
        ok "Keeping existing brief. To use it:"
        echo ""
        echo -e "  ${BOLD}./run.sh --brief briefs/${slug}.json${RESET}"
        echo ""
        exit 0
        ;;
      *)
        fail "Invalid choice. Run brainstorm.sh again."
        ;;
    esac
  fi

  echo ""
  echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"
  echo -e "${BOLD}Step 2 of 2 — Save the brief${RESET}"
  echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"
  echo ""
  echo "  When the AI gives you the final content_brief.json:"
  echo ""
  echo -e "  ${BOLD}1. Copy the JSON block${RESET} from the AI chat  (⌘C)"
  echo -e "  ${BOLD}2. Paste it here${RESET}  (⌘V)"
  echo -e "  ${BOLD}3. Press Ctrl+D${RESET} on a new empty line to save"
  echo ""
  echo -e "  ${DIM}(Ctrl+C to exit without saving)${RESET}"
  echo ""

  # Read content directly from paste — natural Cmd+V flow
  local content
  content=$(cat /dev/tty 2>/dev/null || true)

  if [[ -z "$content" ]]; then
    fail "No content received. Paste the JSON and press Ctrl+D to save."
  fi

  # Validate JSON
  local valid=true
  echo "$content" | node -e "
    process.stdin.resume();
    process.stdin.setEncoding('utf8');
    let d='';
    process.stdin.on('data',c=>d+=c);
    process.stdin.on('end',()=>{
      try{JSON.parse(d);process.exit(0)}
      catch(e){process.exit(1)}
    });
  " 2>/dev/null || valid=false

  if [[ "$valid" == false ]]; then
    echo ""
    warn "The content doesn't look like valid JSON."
    echo "  Make sure you copied only the JSON block (starting with { and ending with })"
    echo ""
    echo -e "  Paste the JSON block again, then press ${BOLD}Ctrl+D${RESET}:"
    echo ""
    content=$(cat /dev/tty 2>/dev/null || true)
    echo "$content" | node -e "
      process.stdin.resume();
      process.stdin.setEncoding('utf8');
      let d='';
      process.stdin.on('data',c=>d+=c);
      process.stdin.on('end',()=>{try{JSON.parse(d);process.exit(0)}catch(e){process.exit(1)}});
    " 2>/dev/null || fail "Still not valid JSON. Check the AI output and try again."
  fi

  # Save the file
  printf '%s' "$content" > "$brief_path"

  # Clear any terminal noise from clipboard paste, then print clean result
  echo ""
  echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"
  ok "Brief saved → briefs/${slug}.json"
  ok "Valid JSON confirmed"
  echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"
  echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}FORA — Brainstorm${RESET}"
  echo "──────────────────────────────"

  check_deps

  # ── Recovery mode: skip brainstorm, just save the brief from clipboard ───────
  # Usage: ./brainstorm.sh --recover [slug]
  # For when you already have the JSON in your clipboard but the brief wasn't saved.
  if [[ "${1:-}" == "--recover" ]]; then
    local slug="${2:-}"
    if [[ -z "$slug" ]]; then
      echo ""
      echo "  What company is this brief for? (used as the filename)"
      echo -e "  ${DIM}e.g. remote, linear, nola${RESET}"
      flush_stdin; read -r slug < /dev/tty
      slug=$(echo "$slug" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')
    fi
    echo ""
    echo -e "${BOLD}Recovery mode — saving brief from clipboard${RESET}"
    echo ""
    echo "  Paste the JSON here (⌘V), then press Ctrl+D on a new empty line:"
    echo -e "  ${DIM}(Ctrl+C to exit)${RESET}"
    save_brief "$slug"
    exit 0
  fi

  # Get URL
  local jd_url="${1:-}"
  if [[ -z "$jd_url" ]]; then
    echo ""
    read -r jd_url < /dev/tty
    echo ""
  fi

  [[ -z "$jd_url" ]] && fail "No URL provided."

  # Derive slug from URL
  local slug
  slug=$(derive_slug "$jd_url")

  # Check required files
  [[ -f "$PROMPT_FILE" ]] || fail "brainstorm-prompt.md not found at $PROMPT_FILE"
  [[ -f "$PROFILE_FILE" ]] || fail "profile.json not found at $PROFILE_FILE

  Build your profile first:
    1. Open a new AI chat (Claude.ai, ChatGPT, etc.)
    2. Run: cat prompts/profile-builder-prompt.md | pbcopy
       then paste into your AI chat
    3. Share your resume or career materials
    4. Copy the JSON output and run: pbpaste > profile/profile.json
    5. Verify: ./setup.sh --check"

  # Fetch JD
  local jd_text
  jd_text=$(fetch_jd "$jd_url")
  ok "Job description fetched ($(echo "$jd_text" | wc -l | tr -d ' ') lines)"

  # Read files
  local prompt profile
  prompt=$(cat "$PROMPT_FILE")
  profile=$(cat "$PROFILE_FILE")

  # Assemble the full paste
  local assembled
  assembled="$(cat <<ASSEMBLED
$prompt

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## DESIGNER PROFILE (profile.json)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

\`\`\`json
$profile
\`\`\`

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## JOB DESCRIPTION
## Source: $jd_url
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$jd_text
ASSEMBLED
)"

  # Copy to clipboard
  copy_to_clipboard "$assembled"

  local char_count=${#assembled}
  local line_count
  line_count=$(echo "$assembled" | wc -l | tr -d ' ')

  echo ""
  ok "Prompt assembled and copied to clipboard ($line_count lines)"
  echo ""
  echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"
  echo -e "${BOLD}Step 1 of 2 — Run the brainstorm${RESET}"
  echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"
  echo ""
  echo "  1. Open your AI chat (Claude.ai, ChatGPT, or any model)"
  echo "  2. Paste  ⌘V  — the full prompt + your profile + JD is ready"
  echo "  3. The agent runs the brainstorm automatically"
  echo "  4. Review and refine the content until you're happy"
  echo "  5. Ask the agent: \"give me the final content_brief.json\""
  echo "  6. Copy the JSON block it outputs"
  echo ""

  # Save the brief
  save_brief "$slug"

  # Only offer to continue if running standalone (not called from run.sh)
  if [[ "${FORA_CALLED_FROM_RUN:-}" != "true" ]]; then
    echo -e "  Ready to generate your page."
    echo -e "  Press Enter to continue to generate + deploy..."
    echo -e "  ${DIM}(Ctrl+C to stop here — resume later with: ./run.sh --brief briefs/${slug}.json)${RESET}"
    echo ""
    flush_stdin; read -r < /dev/tty
    echo ""
    exec "$SCRIPT_DIR/run.sh" --brief "$SCRIPT_DIR/briefs/${slug}.json"
  fi
}

main "$@"
