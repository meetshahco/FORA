#!/bin/bash
# test/regression.sh — Run after any prompt or code change to verify output quality.
# Works inside the repository (expects profile/profile.json and briefs/ to exist).

GOLDEN_BRIEFS=("sentinelone.json" "nola-founding-designer.json")
BRIEFS_DIR="briefs"
FAILS=0

# Parse arguments
MODE="--run"
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run|--dry)
      MODE="--dry-run"
      shift
      ;;
    *)
      # Treat other arguments as specific briefs to test
      SPECIFIC_BRIEFS+=("$1")
      shift
      ;;
  esac
done

if [ ${#SPECIFIC_BRIEFS[@]} -gt 0 ]; then
  BRIEFS=("${SPECIFIC_BRIEFS[@]}")
else
  BRIEFS=("${GOLDEN_BRIEFS[@]}")
fi

echo "Running regression tests in mode: $MODE"

for brief in "${BRIEFS[@]}"; do
  # Add extension if missing
  if [[ ! "$brief" =~ \.json$ ]]; then
    brief="${brief}.json"
  fi

  brief_path="$BRIEFS_DIR/$brief"
  if [ ! -f "$brief_path" ]; then
    echo "⚠ Warning: brief not found at $brief_path, skipping."
    continue
  fi

  # Extract precise slug from brief JSON using node to match generate.js planner logic
  slug=$(node -e "
    try {
      const b = require('./$brief_path');
      const company = b._meta?.company || 'company';
      const role = b._meta?.role || 'role';
      const slug = (b._meta?.slug_override || (company + '-' + role))
        .toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
      console.log(slug);
    } catch (e) {
      console.log('');
    }
  ")
  
  if [ -z "$slug" ]; then
    slug=$(basename "$brief" .json)
  fi

  echo "─── Testing: $brief ───"

  # Run the generator
  node generate.js "$MODE" "$brief_path"
  if [ $? -ne 0 ]; then
    echo "✗ FAIL: generation failed for $brief"
    FAILS=$((FAILS + 1))
    continue
  fi

  # Find output file
  # Look in output/[slug]/index.html
  # Wait, planner slug could be slightly different, let's find the matching index.html
  actual_file=$(find output -name "index.html" -path "*$slug*" | head -1)

  if [ -z "$actual_file" ] || [ ! -f "$actual_file" ]; then
    echo "✗ FAIL: no output file found for $brief"
    FAILS=$((FAILS + 1))
    continue
  fi

  issues=0

  # 1. Check for raw brief directives/framing instructions appearing on the page
  if grep -qiE "Lead with the|Use as a short|Frame as evidence|framing_angle" "$actual_file"; then
    echo "  ✗ Raw brief directives/instructions found in output"
    issues=$((issues + 1))
  fi

  # 2. Check for placeholder text (ignoring HTML comments)
  if grep -v -E "<!--|-->" "$actual_file" | grep -qiE "coming soon|TBD|\[role\]|\[company\]|\{\{"; then
    echo "  ✗ Placeholder text or unresolved slots found in output"
    issues=$((issues + 1))
  fi

  # 3. Check for AI commentary / conversational notes
  if grep -qiE "I chose|I decided|Using a minimal|Based on the brief" "$actual_file"; then
    echo "  ✗ AI commentary or design choice explanation found in output"
    issues=$((issues + 1))
  fi

  # 4. Check file size bounds (sanity check)
  file_size=$(wc -c < "$actual_file" | tr -d ' ')
  if [ "$file_size" -lt 5000 ]; then
    echo "  ✗ File size too small (${file_size}B) - output is likely truncated or empty"
    issues=$((issues + 1))
  fi

  if [ "$file_size" -gt 500000 ]; then
    echo "  ✗ File size too large (${file_size}B) - output contains excessive data"
    issues=$((issues + 1))
  fi

  # 5. Check for raw em-dashes (—) that should be banned (outside of markup/CSS/scaffolding)
  # Show as a warning instead of failure since user profile data may legitimately contain them.
  em_dashes=$(sed 's/<!--.*-->//g' "$actual_file" | grep -v -E "style|css|<link|<title" | grep -o "—" | wc -l | tr -d ' ')
  if [ "$em_dashes" -gt 0 ]; then
    echo "  ⚠ Warning: Found $em_dashes em-dashes (—) outside comments/styles."
  fi

  if [ "$issues" -eq 0 ]; then
    echo "  ✓ All checks passed for $brief (${file_size}B)"
  else
    echo "  ✗ $issues issue(s) found in $actual_file"
    FAILS=$((FAILS + 1))
  fi
done

echo ""
if [ "$FAILS" -eq 0 ]; then
  echo "═══ ALL TESTS PASSED ═══"
  exit 0
else
  echo "═══ $FAILS BRIEF(S) FAILED REGRESSION ═══"
  exit 1
fi
