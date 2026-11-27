#!/usr/bin/env bash
# Lint and format check. Run from the project root: ./scripts/check.sh
set -euo pipefail
selene src
stylua --check src
echo "Checks passed"
