#!/usr/bin/env bash
# Build Simran_Tanwani_Resume.pdf + .docx from a resume.md + style.css.
#
# Usage:
#   ./build.sh                          # builds the master resume.md at repo root
#   ./build.sh applications/<job-dir>   # builds that folder's tailored resume.md
#
# Pipeline: pandoc renders resume.md to an HTML *fragment* (no -s), wrapped with
# style.css inlined as the ONLY stylesheet, then weasyprint -> PDF; pandoc -> DOCX.
# We avoid `pandoc -s` on purpose: its standalone template injects a default
# `@media print { body { font-size: 12pt } }` rule that overrides style.css under
# weasyprint and breaks the one-page layout.
set -euo pipefail
cd "$(dirname "$0")"

WEASYPRINT="${WEASYPRINT:-$HOME/.local/bin/weasyprint}"   # pipx install, not on PATH

DIR="${1:-.}"                          # target folder; default = repo root (master)
SRC="$DIR/resume.md"
OUT="$DIR/Simran_Tanwani_Resume"       # produces <OUT>.pdf and <OUT>.docx
TMP="$DIR/.build.html"

[ -f "$SRC" ] || { echo "error: no resume.md in '$DIR'"; exit 1; }

{
  echo '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Simran Tanwani</title><style>'
  cat style.css
  echo '</style></head><body>'
  pandoc "$SRC"
  echo '</body></html>'
} > "$TMP"

"$WEASYPRINT" "$TMP" "$OUT.pdf" 2>&1 | grep -vi 'max-width\|@media\|ignored' || true
pandoc "$SRC" -o "$OUT.docx"
rm -f "$TMP"

echo "Built $OUT.pdf + $OUT.docx ($(pdfinfo "$OUT.pdf" | awk '/Pages/{print $2}') page)"
