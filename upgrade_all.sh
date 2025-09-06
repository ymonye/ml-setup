#!/usr/bin/env bash
set -euo pipefail

# Run upgrade scripts found in the current working directory
scripts=(
  "upgrade_claude.sh"
  "upgrade_codex.sh"
  "upgrade_crush.sh"
  "upgrade_cursor.sh"
  "upgrade_gemini.sh"
  "upgrade_opencode.sh"
  "upgrade_qwen.sh"
)

for script in "${scripts[@]}"; do
  if [[ -x "./$script" ]]; then
    echo "==> Running ./$script"
    "./$script"
  elif [[ -f "./$script" ]]; then
    echo "==> Running ./$script with bash"
    bash "./$script"
  else
    echo "Skipping $script (not found in current directory)" >&2
  fi
done
