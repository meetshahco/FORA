#!/usr/bin/env bash
# FORA — codegen.sh
# Assembles the codegen prompt + your brief, copies to clipboard.
# Waits for you to paste into AI chat, generate the HTML, then saves it automatically.
#
# Usage:
#   ./codegen.sh briefs/[company].json

set -euo pipefail

# ── Colours ─────────────────────────────────────────────────────────────────
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

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="$SCRIPT_DIR/prompts/codegen-prompt.md"

# ── Copy to clipboard ────────────────────────────────────────────────────────
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

# ── Paste from clipboard ─────────────────────────────────────────────────────
paste_from_clipboard() {
  if command -v pbpaste &>/dev/null; then
    pbpaste
  elif command -v xclip &>/dev/null; then
    xclip -selection clipboard -o
  elif command -v xsel &>/dev/null; then
    xsel --clipboard --output
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}FORA — Codegen${RESET}"
  echo "──────────────────────────────"

  # Get brief path
  local brief_path="${1:-}"
  if [[ -z "$brief_path" ]]; then
    echo ""
    echo "  Available briefs:"
    ls "$SCRIPT_DIR/briefs/"*.json 2>/dev/null | xargs -I{} basename {} .json | sed 's/^/    /' || echo "    (none yet)"
    echo ""
    read -rp "  Brief filename (e.g. remote): " brief_name
    brief_name="${brief_name#briefs/}"
    brief_name="${brief_name%.json}"
    brief_path="$SCRIPT_DIR/briefs/${brief_name}.json"
  fi

  # Resolve to absolute path
  [[ "$brief_path" != /* ]] && brief_path="$SCRIPT_DIR/$brief_path"
  [[ "$brief_path" != *.json ]] && brief_path="${brief_path}.json"

  [[ -f "$PROMPT_FILE" ]] || fail "codegen-prompt.md not found at $PROMPT_FILE"
  [[ -f "$brief_path"  ]] || fail "Brief not found at $brief_path — run brainstorm.sh first"

  # Derive slug from brief filename
  local slug
  slug=$(basename "$brief_path" .json)

  local output_dir="$SCRIPT_DIR/output/${slug}"
  local output_file="$output_dir/index.html"

  # Check if output already exists
  if [[ -f "$output_file" ]]; then
    echo ""
    warn "A generated page already exists for this brief."
    echo ""
    echo "  1) Regenerate (overwrite existing)"
    echo "  2) Keep existing and exit"
    echo ""
    read -rp "  Enter 1 or 2: " choice
    case "$choice" in
      2)
        echo ""
        ok "Keeping existing page."
        echo ""
        echo -e "  Preview:  ${BOLD}open output/${slug}/index.html${RESET}"
        echo ""
        exit 0
        ;;
    esac
  fi

  # Read files
  local prompt brief
  prompt=$(cat "$PROMPT_FILE")
  brief=$(cat "$brief_path")

  # Assemble
  local assembled
  assembled="$(cat <<ASSEMBLED
$prompt

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## CONTENT BRIEF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

\`\`\`json
$brief
\`\`\`
ASSEMBLED
)"

  copy_to_clipboard "$assembled"

  local line_count
  line_count=$(echo "$assembled" | wc -l | tr -d ' ')

  ok "Prompt + brief copied to clipboard ($line_count lines)"
  echo ""
  echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"
  echo -e "${BOLD}Step 1 of 2 — Generate the HTML${RESET}"
  echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"
  echo ""
  echo "  1. Open your AI chat (Claude.ai, ChatGPT, or any model)"
  echo "  2. Paste  ⌘V  — the full codegen prompt + brief is ready"
  echo "  3. The assistant generates the complete page HTML"
  echo "  4. Copy the full HTML output (starting with <!DOCTYPE html>)"
  echo ""

  # Wait for user
  read -rp "  Press Enter when you have the HTML copied... "

  # Flush terminal buffer
  while read -r -t 0.1 _discard; do : ; done 2>/dev/null || true

  # Read from clipboard
  local content
  content=$(paste_from_clipboard 2>/dev/null || true)

  if [[ -z "$content" ]]; then
    echo ""
    echo "  Clipboard appears empty. Paste the HTML directly below,"
    echo -e "  then press ${BOLD}Ctrl+D${RESET} on a new empty line when done:"
    echo ""
    content=$(cat 2>/dev/null || true)
  fi

  [[ -z "$content" ]] && fail "No content received. Copy the HTML and run codegen.sh again."

  # Basic HTML check
  if ! echo "$content" | grep -qi "<!DOCTYPE\|<html"; then
    echo ""
    warn "This doesn't look like a full HTML page."
    echo "  Make sure you copied the complete output starting with <!DOCTYPE html>"
    echo ""
    read -rp "  Copy the full HTML and press Enter to try again (or Ctrl+C to exit): "
    while read -r -t 0.1 _discard; do : ; done 2>/dev/null || true
    content=$(paste_from_clipboard 2>/dev/null || true)
  fi

  # Save
  mkdir -p "$output_dir"
  printf '%s' "$content" > "$output_file"

  echo ""
  echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"
  ok "Page saved → output/${slug}/index.html"
  echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"
  echo ""
  echo -e "  Preview:  ${BOLD}open output/${slug}/index.html${RESET}"
  echo ""
  echo -e "${BOLD}Next step — deploy:${RESET}"
  echo ""

  # Mode-aware next step
  local env_file="$SCRIPT_DIR/.env"
  local has_vercel=false
  [[ -f "$env_file" ]] && grep -q "^VERCEL_TOKEN=.\+" "$env_file" 2>/dev/null && has_vercel=true

  if [[ "$has_vercel" == true ]]; then
    echo -e "  ${BOLD}node generate.js --deploy briefs/${slug}.json${RESET}"
    echo -e "  ${DIM}(Mode 2B — deploys to Vercel, returns live URL)${RESET}"
  else
    echo "  Drag your output/${slug}/ folder to https://app.netlify.com/drop"
    echo -e "  ${DIM}(Mode 1 — free, no account needed)${RESET}"
  fi
  echo ""
}

main "$@"
