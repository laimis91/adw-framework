<#
.SYNOPSIS
    Validates integration readiness after all sub-tasks complete.
.DESCRIPTION
    Checks that all sub-task branches exist, have commits, can merge without
    conflicts, and that build + tests pass after merge.
.EXAMPLE
    .\scripts\Check-Integration.ps1 -IntegrationBranch "feature/add-notifications"
    .\scripts\Check-Integration.ps1 -IntegrationBranch "feature/add-notifications" -BuildCmd "dotnet build" -TestCmd "dotnet test"
    .\scripts\Check-Integration.ps1 -IntegrationBranch "feature/add-notifications" -DryRun
.NOTES
    Prerequisites: git, and optionally the build/test toolchain for the project
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$IntegrationBranch,
    [string]$BuildCmd = "",
    [string]$TestCmd = "",
    [switch]$SkipBuild,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# ── Helpers ───────────────────────────────────────────────────────────────────

function Write-Fail  { param([string]$Msg) Write-Host "X $Msg" -ForegroundColor Red }
function Write-Info  { param([string]$Msg) Write-Host "i $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "+ $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "! $Msg" -ForegroundColor Yellow }
function Write-Check { param([string]$Msg) Write-Host "? $Msg" -ForegroundColor White }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Fail "git is required."; exit 1 }

# ── Auto-detect build/test commands ───────────────────────────────────────────

function Find-Commands {
    if (-not $script:BuildCmd) {
        if (Get-ChildItem *.sln -ErrorAction SilentlyContinue) { $script:BuildCmd = "dotnet build" }
        elseif (Test-Path "package.json")    { $script:BuildCmd = "npm run build" }
        elseif (Test-Path "platformio.ini")  { $script:BuildCmd = "pio run" }
        elseif (Test-Path "Makefile")        { $script:BuildCmd = "make" }
    }
    if (-not $script:TestCmd) {
        if (Get-ChildItem *.sln -ErrorAction SilentlyContinue) { $script:TestCmd = "dotnet test" }
        elseif (Test-Path "package.json")    { $script:TestCmd = "npm test" }
        elseif (Test-Path "platformio.ini")  { $script:TestCmd = "pio test" }
        elseif (Test-Path "Makefile")        { $script:TestCmd = "make test" }
    }
}

# ── State tracking ────────────────────────────────────────────────────────────

$pass = 0; $failCount = 0; $warnCount = 0
$results = [System.Collections.ArrayList]::new()

function Record-Pass { param([string]$Msg) $script:pass++; [void]$script:results.Add("+ $Msg"); Write-Ok $Msg }
function Record-Fail { param([string]$Msg) $script:failCount++; [void]$script:results.Add("X $Msg"); Write-Fail $Msg }
function Record-Warn { param([string]$Msg) $script:warnCount++; [void]$script:results.Add("! $Msg"); Write-Warn $Msg }

# ── Check 1: Integration branch exists ────────────────────────────────────────

Write-Check "Integration branch exists: $IntegrationBranch"

git show-ref --verify --quiet "refs/heads/$IntegrationBranch" 2>$null
if ($LASTEXITCODE -eq 0) {
    Record-Pass "Integration branch exists: $IntegrationBranch"
} else {
    Record-Fail "Integration branch not found: $IntegrationBranch"
    Write-Host ""
    Write-Fail "Cannot continue without integration branch."
    exit 1
}

# ── Discover sub-task branches ────────────────────────────────────────────────

$branchPrefix = "$IntegrationBranch/"
$subBranches = @(git for-each-ref --format='%(refname:short)' "refs/heads/$branchPrefix" 2>$null)

if ($subBranches.Count -eq 0) {
    Record-Fail "No sub-task branches found matching ${branchPrefix}*"
    Write-Host ""
    Write-Fail "Expected branches like ${branchPrefix}contracts, ${branchPrefix}sub-task-2, etc."
    exit 1
}

Write-Info "Found $($subBranches.Count) sub-task branch(es):"
foreach ($b in $subBranches) { Write-Host "  - $b" }
Write-Host ""

# ── Check 2: Each sub-task branch has commits ────────────────────────────────

Write-Check "Sub-task branches have commits beyond integration branch..."

foreach ($branch in $subBranches) {
    $commitCount = (git rev-list --count "$IntegrationBranch..$branch" 2>$null)
    if ($LASTEXITCODE -ne 0) { $commitCount = "0" }
    if ([int]$commitCount -gt 0) {
        Record-Pass "$branch`: $commitCount commit(s) ahead"
    } else {
        Record-Warn "$branch`: no commits ahead of integration branch (empty sub-task?)"
    }
}
Write-Host ""

# ── Check 3: No merge conflicts (dry-run merge) ──────────────────────────────

Write-Check "Merge conflict check (dry-run)..."

$originalBranch = git branch --show-current
$tempBranch = "__integration-check-$(Get-Date -Format 'yyyyMMddHHmmss')"

if ($DryRun) {
    Write-Info "[dry-run] Would create temp branch $tempBranch from $IntegrationBranch and test-merge each sub-task branch."
} else {
    git checkout $IntegrationBranch --quiet 2>$null
    git checkout -b $tempBranch --quiet 2>$null

    # Individual merge checks
    foreach ($branch in $subBranches) {
        git merge --no-commit --no-ff $branch --quiet 2>$null
        if ($LASTEXITCODE -eq 0) {
            Record-Pass "Merge $branch`: no conflicts"
            git merge --abort 2>$null
            if ($LASTEXITCODE -ne 0) { git reset --hard HEAD --quiet 2>$null }
        } else {
            Record-Fail "Merge $branch`: CONFLICTS DETECTED"
            git merge --abort 2>$null
            if ($LASTEXITCODE -ne 0) { git reset --hard HEAD --quiet 2>$null }
        }
    }

    # Full sequential merge test
    Write-Host ""
    Write-Check "Full merge test (all branches into integration)..."
    git reset --hard $IntegrationBranch --quiet 2>$null

    $allMergeOk = $true
    foreach ($branch in $subBranches) {
        git merge --no-commit --no-ff $branch --quiet 2>$null
        if ($LASTEXITCODE -ne 0) {
            $allMergeOk = $false
            Record-Fail "Sequential merge breaks at: $branch"
            git merge --abort 2>$null
            if ($LASTEXITCODE -ne 0) { git reset --hard HEAD --quiet 2>$null }
            break
        }
    }

    if ($allMergeOk) { Record-Pass "All branches merge cleanly together" }

    # Clean up
    git reset --hard HEAD --quiet 2>$null
    if ($originalBranch) { git checkout $originalBranch --quiet 2>$null }
    else { git checkout $IntegrationBranch --quiet 2>$null }
    git branch -D $tempBranch --quiet 2>$null
}
Write-Host ""

# ── Check 4 & 5: Build and test ──────────────────────────────────────────────

if ($SkipBuild) {
    Write-Info "Skipping build and test checks (-SkipBuild)."
} elseif ($DryRun) {
    Find-Commands
    Write-Info "[dry-run] Would run build: $(if ($BuildCmd) { $BuildCmd } else { '(not detected)' })"
    Write-Info "[dry-run] Would run tests: $(if ($TestCmd) { $TestCmd } else { '(not detected)' })"
} else {
    Find-Commands

    git checkout $IntegrationBranch --quiet 2>$null
    $tempBranch = "__integration-build-$(Get-Date -Format 'yyyyMMddHHmmss')"
    git checkout -b $tempBranch --quiet 2>$null

    $allMerged = $true
    foreach ($branch in $subBranches) {
        git merge --no-ff $branch --quiet -m "Integration check: merge $branch" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Record-Fail "Cannot merge all branches for build test."
            $allMerged = $false
            git merge --abort 2>$null
            break
        }
    }

    if ($allMerged) {
        # Build check
        if ($BuildCmd) {
            Write-Check "Build: $BuildCmd"
            Invoke-Expression $BuildCmd *>$null
            if ($LASTEXITCODE -eq 0) { Record-Pass "Build passes after merge" }
            else { Record-Fail "Build fails after merge: $BuildCmd" }
        } else {
            Record-Warn "No build command detected -- skipping build check."
        }

        # Test check
        if ($TestCmd) {
            Write-Check "Tests: $TestCmd"
            Invoke-Expression $TestCmd *>$null
            if ($LASTEXITCODE -eq 0) { Record-Pass "Tests pass after merge" }
            else { Record-Fail "Tests fail after merge: $TestCmd" }
        } else {
            Record-Warn "No test command detected -- skipping test check."
        }
    }

    # Clean up
    if ($originalBranch) { git checkout $originalBranch --quiet 2>$null }
    else { git checkout $IntegrationBranch --quiet 2>$null }
    git branch -D $tempBranch --quiet 2>$null
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host ("-" * 60)
Write-Host "  Integration Check Results" -ForegroundColor White
Write-Host ("-" * 60)
Write-Host ""
foreach ($r in $results) { Write-Host "  $r" }
Write-Host ""
Write-Host "  Passed: $pass | Failed: $failCount | Warnings: $warnCount"
Write-Host ""

if ($failCount -gt 0) {
    Write-Host "NOT READY for integration. Fix failures above first." -ForegroundColor Red
    exit 1
} elseif ($warnCount -gt 0) {
    Write-Host "READY with warnings. Review warnings before merging." -ForegroundColor Yellow
} else {
    Write-Host "READY for integration." -ForegroundColor Green
}

Write-Host ""
Write-Host "To merge:"
Write-Host "  git checkout $IntegrationBranch"
foreach ($branch in $subBranches) {
    Write-Host "  git merge --no-ff $branch"
}
