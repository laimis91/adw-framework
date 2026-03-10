<#
.SYNOPSIS
    Launches AI agents for each sub-task brief.
.DESCRIPTION
    Supports Claude Code (claude) and Codex CLI (codex).

    Parallel mode: each agent runs in its own git worktree (separate working
    directory, same repo). Worktrees are created by Decompose.ps1 or on the fly.

    Sequential mode: agents share the main repo, checking out branches one at a time.
.EXAMPLE
    .\scripts\Run-Agents.ps1 -BriefsDir briefs -Repo .
    .\scripts\Run-Agents.ps1 -BriefsDir briefs -Repo . -SkipFirst -Parallel
    .\scripts\Run-Agents.ps1 -BriefsDir briefs -Repo . -Agent codex -Parallel -Cleanup
    .\scripts\Run-Agents.ps1 -BriefsDir briefs -Repo . -DryRun
.NOTES
    Prerequisites: git, and one of: claude, codex
#>

[CmdletBinding()]
param(
    [string]$BriefsDir = "briefs",
    [string]$Repo = ".",
    [ValidateSet("claude", "codex")][string]$Agent = "claude",
    [switch]$Parallel,
    [switch]$SkipFirst,
    [string]$WorktreesDir = ".worktrees",
    [switch]$Cleanup,
    [string]$LogDir = "",
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# ── Helpers ───────────────────────────────────────────────────────────────────

function Write-Fail  { param([string]$Msg) Write-Host "X $Msg" -ForegroundColor Red; throw $Msg }
function Write-Info  { param([string]$Msg) Write-Host "i $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "+ $Msg" -ForegroundColor Green }
function Write-Dry   { param([string]$Msg) Write-Host "~ [dry-run] $Msg" -ForegroundColor Yellow }
function Write-Warn  { param([string]$Msg) Write-Host "! $Msg" -ForegroundColor Yellow }

# ── Validate ──────────────────────────────────────────────────────────────────

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Fail "git is required." }

if (-not (Test-Path $BriefsDir -PathType Container)) { Write-Fail "Briefs directory not found: $BriefsDir" }
if (-not (Test-Path $Repo -PathType Container))      { Write-Fail "Repository not found: $Repo" }

$Repo = (Resolve-Path $Repo).Path

if (-not $DryRun -and -not (Get-Command $Agent -ErrorAction SilentlyContinue)) {
    Write-Fail "$Agent CLI not found. Install claude: https://docs.anthropic.com/en/docs/claude-code"
}

# Set up log directory
if (-not $LogDir) { $LogDir = Join-Path $BriefsDir "logs" }
if (-not $DryRun) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

# ── Collect brief files ──────────────────────────────────────────────────────

$briefFiles = @(Get-ChildItem (Join-Path $BriefsDir "sub-task-*.md") | Sort-Object Name)

if ($briefFiles.Count -eq 0) {
    Write-Fail "No sub-task brief files found in $BriefsDir\ (expected sub-task-*.md)"
}

Write-Info "Found $($briefFiles.Count) brief files in $BriefsDir\"

$startIndex = 0
if ($SkipFirst) {
    $startIndex = 1
    Write-Info "Skipping sub-task #1 (contracts -- -SkipFirst)"
}

# ── Extract fields from brief ────────────────────────────────────────────────

function Get-BranchFromBrief {
    param([string]$BriefPath)
    $match = Select-String -Path $BriefPath -Pattern 'Git branch:\s*(\S+)' | Select-Object -First 1
    if ($match) { return $match.Matches[0].Groups[1].Value }
    return ""
}

function Get-WorktreeFromBrief {
    param([string]$BriefPath)
    $match = Select-String -Path $BriefPath -Pattern 'Worktree:\s*(\S+)' | Select-Object -First 1
    if ($match) { return $match.Matches[0].Groups[1].Value }
    return ""
}

# ── Ensure worktree exists (parallel mode) ────────────────────────────────────

$script:createdWorktrees = @()

function Ensure-Worktree {
    param([string]$Branch, [string]$WorktreePath)

    if (Test-Path $WorktreePath -PathType Container) {
        return $true
    }

    if ($DryRun) {
        Write-Dry "git worktree add $WorktreePath $Branch"
        return $true
    }

    $parentDir = Split-Path $WorktreePath -Parent
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    git -C $Repo worktree add $WorktreePath $Branch --quiet 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Created worktree: $WorktreePath -> $Branch"
        $script:createdWorktrees += $WorktreePath
        return $true
    } else {
        Write-Warn "Could not create worktree for $Branch -- branch may not exist."
        return $false
    }
}

# ── Resolve working directory per agent ───────────────────────────────────────

function Resolve-AgentCwd {
    param([string]$BriefPath)

    $branch = Get-BranchFromBrief $BriefPath

    if ($Parallel) {
        # Check for worktree path in brief (set by Decompose.ps1)
        $wtHint = Get-WorktreeFromBrief $BriefPath
        if ($wtHint -and (Test-Path $wtHint -PathType Container)) {
            return $wtHint
        }

        # Derive from branch name
        if ($branch) {
            $wtName = Split-Path $branch -Leaf
            $wtPath = Join-Path $WorktreesDir $wtName

            $created = Ensure-Worktree -Branch $branch -WorktreePath $wtPath
            if ($created -and (Test-Path $wtPath -PathType Container -ErrorAction SilentlyContinue)) {
                return $wtPath
            }
        }

        Write-Warn "No worktree available for $(Split-Path $BriefPath -Leaf), falling back to main repo."
        return $Repo
    } else {
        # Sequential: checkout branch in main repo
        if ($branch) {
            if ($DryRun) {
                Write-Dry "cd $Repo; git checkout $branch"
            } else {
                Push-Location $Repo
                try { git checkout $branch --quiet 2>$null }
                catch { Write-Warn "Could not checkout branch $branch -- it may not exist yet." }
                Pop-Location
            }
        }
        return $Repo
    }
}

# ── Run a single agent ────────────────────────────────────────────────────────

function Invoke-Agent {
    param([string]$BriefPath, [int]$Index, [string]$AgentCwd)

    $briefName = [System.IO.Path]::GetFileNameWithoutExtension($BriefPath)
    $logFile = Join-Path $LogDir "$briefName.log"

    Write-Host ""
    Write-Host ("-" * 55)
    Write-Host "  Agent $Index`: $briefName" -ForegroundColor Magenta
    Write-Host "   Working dir: $AgentCwd"
    Write-Host "   Log: $logFile"
    Write-Host ("-" * 55)

    $briefContent = Get-Content $BriefPath -Raw

    if ($DryRun) {
        Write-Dry "$Agent -p `"<brief content>`" --cwd $AgentCwd > $logFile 2>&1"
        return $true
    }

    try {
        switch ($Agent) {
            "claude" { & claude -p $briefContent --cwd $AgentCwd *> $logFile }
            "codex"  { & codex exec $briefContent --cwd $AgentCwd *> $logFile }
        }
        Write-Ok "Agent $Index ($briefName) completed successfully."
        return $true
    } catch {
        Write-Warn "Agent $Index ($briefName) failed. Check log: $logFile"
        return $false
    }
}

# ── Launch agents ─────────────────────────────────────────────────────────────

$total = $briefFiles.Count - $startIndex
$modeStr = if ($Parallel) { "parallel (separate worktrees)" } else { "sequential (shared repo)" }
Write-Info "Launching $total agent(s) ($Agent, $modeStr)"

$failed = @()

if ($Parallel) {
    # Launch as PowerShell jobs, each with its own worktree
    $jobs = @()
    for ($i = $startIndex; $i -lt $briefFiles.Count; $i++) {
        $brief = $briefFiles[$i].FullName
        $index = $i + 1
        $agentCwd = Resolve-AgentCwd -BriefPath $brief
        $logFile = Join-Path $LogDir "$([System.IO.Path]::GetFileNameWithoutExtension($brief)).log"

        if ($DryRun) {
            Write-Dry "Start-Job: $Agent -p <brief> --cwd $agentCwd > $logFile"
        } else {
            $job = Start-Job -ScriptBlock {
                param($AgentCmd, $BriefContent, $Cwd, $LogPath)
                try {
                    & $AgentCmd -p $BriefContent --cwd $Cwd *> $LogPath
                    return $true
                } catch {
                    return $false
                }
            } -ArgumentList $Agent, (Get-Content $brief -Raw), $agentCwd, $logFile
            $jobs += @{ Job = $job; Brief = $brief; Index = $index; Cwd = $agentCwd }
        }
    }

    if (-not $DryRun -and $jobs.Count -gt 0) {
        Write-Info "Waiting for $($jobs.Count) parallel agents..."
        foreach ($j in $jobs) {
            $result = Receive-Job -Job $j.Job -Wait
            Remove-Job -Job $j.Job
            if ($result -ne $true) {
                $failed += $j.Brief
            }
        }
    }
} else {
    # Sequential
    for ($i = $startIndex; $i -lt $briefFiles.Count; $i++) {
        $brief = $briefFiles[$i].FullName
        $agentCwd = Resolve-AgentCwd -BriefPath $brief
        $success = Invoke-Agent -BriefPath $brief -Index ($i + 1) -AgentCwd $agentCwd
        if (-not $success) { $failed += $brief }
    }
}

# ── Worktree cleanup ─────────────────────────────────────────────────────────

if ($Parallel -and $Cleanup -and -not $DryRun) {
    Write-Host ""
    Write-Info "Cleaning up worktrees..."
    if (Test-Path $WorktreesDir -PathType Container) {
        Get-ChildItem $WorktreesDir -Directory | ForEach-Object {
            git -C $Repo worktree remove $_.FullName --force 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Removed worktree: $($_.FullName)"
            } else {
                Write-Warn "Could not remove worktree: $($_.Name) (may have uncommitted changes)"
            }
        }
        Remove-Item $WorktreesDir -ErrorAction SilentlyContinue
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host ("-" * 60)
Write-Host "  Agent run complete" -ForegroundColor White
Write-Host ("-" * 60)
Write-Host ""
Write-Host "Agents run: $total"
Write-Host "Failed: $($failed.Count)"
Write-Host "Logs: $LogDir\"
Write-Host ""

if ($failed.Count -gt 0) {
    Write-Warn "Some agents failed. Review logs before proceeding to integration."
    foreach ($f in $failed) { Write-Host "  X $f" -ForegroundColor Red }
    Write-Host ""
}

Write-Host "Next steps:"
Write-Host "  1. Review agent logs in $LogDir\"
Write-Host "  2. Verify each sub-task branch has commits: git log --oneline feature/<task>/<n>"
Write-Host "  3. Run integration check: .\scripts\Check-Integration.ps1 -IntegrationBranch feature/<task>"

if ($Parallel -and -not $Cleanup) {
    Write-Host ""
    Write-Host "  4. Clean up worktrees when done:"
    Write-Host "     git worktree list"
    Write-Host "     git worktree prune"
    Write-Host "     Remove-Item $WorktreesDir -Recurse"
    Write-Host "     Or re-run with -Cleanup to auto-remove."
}
