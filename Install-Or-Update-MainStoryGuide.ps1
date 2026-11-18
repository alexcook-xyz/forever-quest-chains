# Install-Or-Update-MainStoryGuide.ps1
# Fresh-install / update helper for the MainStoryGuide addon (E0 / 0.3).
# Copies the MainStoryGuide/ addon folder from this repo into the
# World of Warcraft Interface/AddOns directory. Safe to run repeatedly
# (idempotent): every run re-copies the same files.
#
#
# Saved variables (MainStoryGuideDB / MainStoryGuideCharDB) live under
# WTF/Account/.../SavedVariables and are never touched by this script,
# so character progress survives reinstalls and updates.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\Install-Or-Update-MainStoryGuide.ps1
#   powershell -ExecutionPolicy Bypass -File .\Install-Or-Update-MainStoryGuide.ps1 -TargetDir "C:\Games\WoW\_retail_\Interface\AddOns"
[CmdletBinding()]
param(
  [string]$TargetDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$AddonName = "MainStoryGuide"
$TocName = "MainStoryGuide.toc"

# Resolve the repo root (this script lives at the repo root).
if ($PSScriptRoot) {
  $RepoRoot = $PSScriptRoot
} else {
  $RepoRoot = (Get-Location).Path
}
$AddonSource = Join-Path $RepoRoot $AddonName
$TocPath = Join-Path $AddonSource $TocName

if (-not (Test-Path -LiteralPath $TocPath -PathType Leaf)) {
  Write-Error "Installer: missing addon descriptor at '$TocPath'. Run from the repo root."
  exit 1
}

if ([string]::IsNullOrWhiteSpace($TargetDir)) {
  if ($env:ProgramFiles) {
    $TargetDir = Join-Path $env:ProgramFiles "World of Warcraft\_retail_\Interface\AddOns"
  } else {
    $TargetDir = Join-Path $RepoRoot "World of Warcraft\_retail_\Interface\AddOns"
  }
}
$AddonDest = Join-Path $TargetDir $AddonName

if (-not (Test-Path -LiteralPath $AddonDest -PathType Container)) {
  New-Item -ItemType Directory -Force -Path $AddonDest | Out-Null
}

# Copy the addon verbatim (overwrite). Never deletes the destination:
# stale extra files are left alone, and SavedVariables outside the
# addon folder are never touched.
$SourceFiles = Get-ChildItem -LiteralPath $AddonSource -Recurse -File
if (-not $SourceFiles) {
  Write-Error "Installer: no files found under '$AddonSource'."
  exit 1
}
foreach ($file in $SourceFiles) {
  $relative = $file.FullName.Substring($AddonSource.Length).TrimStart('\', '/')
  $destFile = Join-Path $AddonDest $relative
  $destDir = Split-Path -Parent $destFile
  if (-not (Test-Path -LiteralPath $destDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  }
  Copy-Item -LiteralPath $file.FullName -Destination $destFile -Force
}

# Verify the installed descriptor matches the repo source.
$DestToc = Join-Path $AddonDest $TocName
if (-not (Test-Path -LiteralPath $DestToc -PathType Leaf)) {
  Write-Error "Installer: verification failed - '$DestToc' was not created."
  exit 1
}
$sourceToc = Get-Content -LiteralPath $TocPath -Raw
if ($sourceToc -notmatch "SavedVariables:\s*MainStoryGuideDB") {
  Write-Error "Installer: '$TocPath' does not declare the MainStoryGuideDB SavedVariables identity."
  exit 1
}

Write-Output "MainStoryGuide installed to '$AddonDest'."
Write-Output "SavedVariables (MainStoryGuideDB / MainStoryGuideCharDB) were left untouched."
exit 0
