# Lint and format check. Run from the project root: .\scripts\check.ps1
$ErrorActionPreference = "Stop"
selene src
stylua --check src
Write-Host "Checks passed"
