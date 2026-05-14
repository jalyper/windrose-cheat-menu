# Publish a GitHub Release for the current tag with the matching dist zip
# attached. Run from the repo root or anywhere — the script resolves paths
# from its own location.
#
# One-time setup (only needed once per machine):
#   winget install --id GitHub.cli   # or: scoop install gh
#   gh auth login                    # browser device-code flow
#
# Usage:
#   .\scripts\publish-release.ps1
#   .\scripts\publish-release.ps1 -Version 0.2.0
#   .\scripts\publish-release.ps1 -Version 0.2.0 -Draft
#
# What it does:
#   1. Confirms gh is installed and authenticated
#   2. Builds dist\WindroseCheatMenu-<version>.zip if missing
#   3. Reads the matching changelog section from CHANGELOG.md
#   4. Creates / updates the GitHub Release for tag v<version>
#   5. Attaches the zip

[CmdletBinding()]
param(
    [string]$Version = "0.1.0",
    [switch]$Draft,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ---- Resolve repo root -------------------------------------------------
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {

    $tag      = "v$Version"
    $modDir   = Join-Path $repoRoot "WindroseCheatMenu"
    $distDir  = Join-Path $repoRoot "dist"
    $zipName  = "WindroseCheatMenu-$Version.zip"
    $zipPath  = Join-Path $distDir $zipName

    Write-Host "==> Repo: $repoRoot"
    Write-Host "==> Tag : $tag"
    Write-Host "==> Zip : $zipPath"

    # ---- Sanity: gh installed + authenticated --------------------------
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        throw "gh CLI not found on PATH. Install via 'winget install --id GitHub.cli'."
    }
    & gh auth status -h github.com 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "gh is not authenticated for github.com. Run 'gh auth login' first."
    }

    # ---- Build zip if missing or -Force --------------------------------
    if ($Force -or -not (Test-Path $zipPath)) {
        if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }
        if (Test-Path $zipPath) { Remove-Item $zipPath }
        Write-Host "==> Building $zipName"
        Compress-Archive -Path $modDir -DestinationPath $zipPath -Force
    } else {
        Write-Host "==> Using existing $zipName ($(Get-Item $zipPath | ForEach-Object { '{0:N0} bytes' -f $_.Length }))"
    }

    # ---- Pull the matching section out of CHANGELOG.md -----------------
    $changelogPath = Join-Path $repoRoot "CHANGELOG.md"
    $notes = "Release of $tag. See CHANGELOG.md for details."
    if (Test-Path $changelogPath) {
        $changelog = Get-Content $changelogPath -Raw
        $pattern = "(?ms)^## \[$([regex]::Escape($Version))\].*?(?=^## \[|\z)"
        $match = [regex]::Match($changelog, $pattern)
        if ($match.Success) {
            $notes = $match.Value.Trim()
        }
    }

    # ---- Verify the tag exists locally + on remote ---------------------
    $localTag = & git tag -l $tag
    if (-not $localTag) {
        throw "Local tag '$tag' does not exist. Create it first: git tag -a $tag -m '$tag release' && git push origin $tag"
    }
    & git ls-remote --tags origin $tag 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not verify tag on remote; attempting to push it."
        & git push origin $tag
    }

    # ---- Create or update the release ----------------------------------
    # Note: PowerShell 5.1 wraps stderr from native commands in ErrorRecords
    # when redirected with `2>$null`, which would fail this script even though
    # `gh release view` exits 0 when the release exists. Use exit code only
    # and discard stderr via a temp file.
    $stderrFile = [System.IO.Path]::GetTempFileName()
    try {
        $existing = & gh release view $tag --json url 2>$stderrFile
        $existsExit = $LASTEXITCODE
    } finally {
        Remove-Item $stderrFile -ErrorAction SilentlyContinue
    }

    if ($existsExit -eq 0 -and $existing) {
        Write-Host "==> Release $tag already exists; uploading asset (clobber)"
        & gh release upload $tag $zipPath --clobber
    } else {
        Write-Host "==> Creating release $tag"
        $argsList = @(
            "release", "create", $tag, $zipPath,
            "--title", "$tag",
            "--notes", $notes
        )
        if ($Draft) { $argsList += "--draft" }
        & gh @argsList
    }

    Write-Host ""
    Write-Host "==> Release URL:"
    & gh release view $tag --json url --jq '.url'

} finally {
    Pop-Location
}
