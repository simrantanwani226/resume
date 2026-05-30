#!/usr/bin/env bash
# Build resume.pdf from resume.md + style.css
#
# Pipeline: pandoc renders resume.md to an HTML *fragment* (no -s), which we wrap
# ourselves with style.css inlined as the ONLY stylesheet, then weasyprint -> PDF.
# We avoid `pandoc -s` on purpose: its standalone template injects a default
# `@media print { body { font-size: 12pt } }` rule that overrides style.css under
# weasyprint, breaking the intended sizing/one-page layout.
set -euo pipefail
cd "$(dirname "$0")"

WEASYPRINT="${WEASYPRINT:-$HOME/.local/bin/weasyprint}"  # pipx install, not on PATH

{
  echo '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Simran Tanwani</title><style>'
  cat style.css
  echo '</style></head><body>'
  pandoc resume.md
  echo '</body></html>'
} > resume.html

"$WEASYPRINT" resume.html resume.pdf 2>&1 | grep -vi 'max-width\|@media\|ignored' || true
echo "Built resume.pdf ($(pdfinfo resume.pdf | awk '/Pages/{print $2}') page(s))"
