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
# Extracts a filename-safe slug from the job URL.
# For job-board URLs (linkedin, greenhouse, lever, workday, indeed, ashby, breezy,
# bamboohr, smartrecruiters, recruitee, jobvite) we use "job-<id>" so the file
# isn't misleadingly named after the board. For company-hosted URLs we use the
# domain (e.g. "notion", "linear"). The actual company name in _meta.company is
# set by the AI from JD content — this slug is only used as a temp filename.
JOB_BOARD_DOMAINS="linkedin|greenhouse|lever|workday|indeed|ashby|breezy|bamboohr|smartrecruiters|recruitee|jobvite|myworkdayjobs"

derive_slug() {
  local url="$1"
  # Strip protocol
  url="${url#http://}"
  url="${url#https://}"
  url="${url#www.}"
  # Extract domain only (first segment before first /)
  local domain="${url%%/*}"
  local domain_lower
  domain_lower=$(echo "$domain" | tr '[:upper:]' '[:lower:]')

  # Check if this is a job board URL
  if echo "$domain_lower" | grep -qE "($JOB_BOARD_DOMAINS)"; then
    # Extract a numeric job ID from the URL path (last run of digits, min 5 chars)
    local job_id
    job_id=$(echo "$url" | grep -oE '[0-9]{5,}' | tail -1)
    if [[ -n "$job_id" ]]; then
      echo "job-${job_id}"
    else
      # No ID found — use board name + timestamp
      local board
      board=$(echo "$domain_lower" | awk -F'.' '{if(NF>=2) print $(NF-1); else print $1}')
      echo "${board}-$(date +%s)"
    fi
    return
  fi

  # Company-hosted URL — extract domain name as before
  local slug
  slug=$(echo "$domain" | awk -F'.' '{if(NF>=2) print $(NF-1); else print $1}')
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
    warn "A brief file already exists: briefs/${slug}.json"
    echo ""
    echo "  What would you like to do?"
    echo "  1) Overwrite it with a new brief"
    echo "  2) Save as a new version (briefs/${slug}-v2.json)"
    echo "  3) Keep the existing brief and exit"
    echo ""
    read -r choice
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
  echo -e "  ${BOLD}1. Copy the JSON block${RESET} in your AI chat  (⌘C)"
  echo -e "  ${BOLD}2. Switch back here and press Enter${RESET} — FORA reads your clipboard"
  echo ""
  echo -e "  ${DIM}(Ctrl+C to exit)${RESET}"

  read -r _

  local content
  content=$(pbpaste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || xsel --clipboard --output 2>/dev/null || true)

  if [[ -z "$content" ]]; then
    fail "Clipboard appears empty. Copy the JSON in your AI chat and try again."
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
    warn "Clipboard doesn't look like valid JSON."
    echo "  Make sure you copied only the JSON block (starting with { and ending with })"
    echo "  not the surrounding text."
    echo ""
    echo -e "  Copy just the JSON, then press Enter:"
    echo -e "  ${DIM}(Ctrl+C to exit)${RESET}"
    read -r _
    content=$(pbpaste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || xsel --clipboard --output 2>/dev/null || true)
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

# ── Template picker ──────────────────────────────────────────────────────────
pick_template() {
  local brief_path="$1"

  echo ""
  echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"
  echo -e "${BOLD}Choose a page template${RESET}"
  echo -e "${BOLD}──────────────────────────────────────────────────${RESET}"
  echo ""
  echo -e "  ${BOLD}1) three-act${RESET}  ${DIM}(default)${RESET}"
  echo -e "     Who I Am → Work → First 90 Days → CTA"
  echo -e "     ${DIM}Best for: most roles. Identity leads, work follows.${RESET}"
  echo ""
  echo -e "  ${BOLD}2) work-first${RESET}"
  echo -e "     Work → Who I Am → First 90 Days → CTA"
  echo -e "     ${DIM}Best for: craft-focused roles, engineering cultures, strong case studies.${RESET}"
  echo ""
  echo -e "  ${BOLD}3) single-statement${RESET}"
  echo -e "     One positioning line → One case study → First 90 Days → CTA"
  echo -e "     ${DIM}Best for: minimal brands, leadership roles, when one story outweighs a list.${RESET}"
  echo ""

  # Offer to open previews if examples exist
  local examples_dir="$SCRIPT_DIR/examples"
  if [[ -f "$examples_dir/alex-rivera/output/index.html" ]] || \
     [[ -f "$examples_dir/alex-rivera-work-first/output/index.html" ]]; then
    echo -e "  ${DIM}Want to preview the templates in your browser first? (y/n)${RESET}"
    read -r preview_choice
    if [[ "$preview_choice" == "y" || "$preview_choice" == "Y" ]]; then
      [[ -f "$examples_dir/alex-rivera/output/index.html" ]] && \
        open "$examples_dir/alex-rivera/output/index.html"
      [[ -f "$examples_dir/alex-rivera-work-first/output/index.html" ]] && \
        open "$examples_dir/alex-rivera-work-first/output/index.html"
      [[ -f "$examples_dir/alex-rivera-single-statement/output/index.html" ]] && \
        open "$examples_dir/alex-rivera-single-statement/output/index.html"
      echo ""
      echo -e "  ${DIM}(Opened in browser — come back here to pick)${RESET}"
      echo ""
    fi
  fi

  echo -e "  Enter 1, 2, or 3 — or press Enter for default (three-act):"
  read -r template_choice

  local template_id
  case "${template_choice:-1}" in
    1|"") template_id="three-act" ;;
    2)    template_id="work-first" ;;
    3)    template_id="single-statement" ;;
    *)
      warn "Invalid choice — using three-act."
      template_id="three-act"
      ;;
  esac

  # Write template_id into the saved brief
  local updated
  updated=$(node -e "
    const fs = require('fs');
    const b = JSON.parse(fs.readFileSync('$brief_path', 'utf8'));
    b._meta.template_id = '$template_id';
    process.stdout.write(JSON.stringify(b, null, 2));
  ")

  if [[ -n "$updated" ]]; then
    printf '%s' "$updated" > "$brief_path"
    ok "Template set → ${template_id}"
  else
    warn "Could not update template_id in brief — defaulting to three-act at runtime."
  fi

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
      read -r slug
      slug=$(echo "$slug" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')
    fi
    echo ""
    echo -e "${BOLD}Recovery mode — saving brief from clipboard${RESET}"
    echo ""
    echo "  Copy the JSON in your AI chat (⌘C), then press Enter here — FORA reads your clipboard."
    echo -e "  ${DIM}(Ctrl+C to exit)${RESET}"
    save_brief "$slug"
    exit 0
  fi

  # Get URL
  local jd_url="${1:-}"
  if [[ -z "$jd_url" ]]; then
    echo ""
    read -r jd_url
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

  # ── Template picker ──────────────────────────────────────────────────────────
  local brief_path="$BRIEFS_DIR/${slug}.json"
  pick_template "$brief_path"

  # Only offer to continue if running standalone (not called from run.sh)
  if [[ "${FORA_CALLED_FROM_RUN:-}" != "true" ]]; then
    echo -e "  Ready to generate your page."
    echo -e "  Press Enter to continue to generate + deploy..."
    echo -e "  ${DIM}(Ctrl+C to stop here — resume later with: ./run.sh --brief briefs/${slug}.json)${RESET}"
    echo ""
    read -r _
    echo ""
    exec "$SCRIPT_DIR/run.sh" --brief "$SCRIPT_DIR/briefs/${slug}.json"
  fi
}

main "$@"
