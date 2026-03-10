<#
.SYNOPSIS
    Automates the mechanical parts of mega task decomposition.
.DESCRIPTION
    Takes a JSON decomposition file (produced by the AI during Plan phase),
    creates git branches, worktrees for parallel work, and brief files.
.EXAMPLE
    .\scripts\Decompose.ps1 -Task "add-notifications" -Input decomposition.json
    .\scripts\Decompose.ps1 -Task "add-notifications" -Input decomposition.json -DryRun
    .\scripts\Decompose.ps1 -Task "add-notifications" -Input decomposition.json -BriefsDir briefs
.NOTES
    Prerequisites: git
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Task,
    [Parameter(Mandatory)][string]$Input,
    [string]$BriefsDir = "briefs",
    [string]$BaseBranch = "main",
    [string]$WorktreesDir = ".worktrees",
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# ── Helpers ───────────────────────────────────────────────────────────────────

function Write-Fail  { param([string]$Msg) Write-Host "X $Msg" -ForegroundColor Red; throw $Msg }
function Write-Info  { param([string]$Msg) Write-Host "i $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "+ $Msg" -ForegroundColor Green }
function Write-Dry   { param([string]$Msg) Write-Host "~ [dry-run] $Msg" -ForegroundColor Yellow }

# ── Validate ──────────────────────────────────────────────────────────────────

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Fail "git is required but not installed." }

if (-not (Test-Path $Input)) { Write-Fail "Input file not found: $Input" }

$decomposition = Get-Content $Input -Raw | ConvertFrom-Json
if (-not $decomposition.sub_tasks -or $decomposition.sub_tasks.Count -eq 0) {
    Write-Fail "Invalid JSON: must have a non-empty 'sub_tasks' array."
}

git diff --quiet HEAD 2>$null
if ($LASTEXITCODE -ne 0) { Write-Fail "Working tree has uncommitted changes. Commit or stash first." }

# ── Read decomposition ────────────────────────────────────────────────────────

$description = if ($decomposition.description) { $decomposition.description } else { "No description" }
$subTasks = @($decomposition.sub_tasks)
$subTaskCount = $subTasks.Count

Write-Info "Task: $Task"
Write-Info "Description: $description"
Write-Info "Sub-tasks: $subTaskCount"
Write-Host ""

# ── Step 1: Create integration branch ────────────────────────────────────────

$integrationBranch = "feature/$Task"

if ($DryRun) {
    Write-Dry "git checkout $BaseBranch"
    Write-Dry "git checkout -b $integrationBranch"
} else {
    git checkout $BaseBranch --quiet 2>$null
    git show-ref --verify --quiet "refs/heads/$integrationBranch" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Info "Integration branch '$integrationBranch' already exists, checking out."
        git checkout $integrationBranch --quiet
    } else {
        git checkout -b $integrationBranch --quiet
        Write-Ok "Created integration branch: $integrationBranch"
    }
}

# ── Step 2: Create sub-task branches ─────────────────────────────────────────

Write-Host ""
Write-Info "Creating sub-task branches..."

for ($i = 0; $i -lt $subTaskCount; $i++) {
    $name = $subTasks[$i].name
    $branch = "feature/$Task/$name"

    if ($DryRun) {
        Write-Dry "git branch $branch (from $integrationBranch)"
    } else {
        git show-ref --verify --quiet "refs/heads/$branch" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Branch '$branch' already exists, skipping."
        } else {
            git branch $branch $integrationBranch
            Write-Ok "Created branch: $branch"
        }
    }
}

# ── Step 2b: Create worktrees for parallel work ──────────────────────────────

Write-Host ""
Write-Info "Creating worktrees in $WorktreesDir\ for parallel agents..."

if (-not $DryRun) {
    New-Item -ItemType Directory -Path $WorktreesDir -Force | Out-Null
}

for ($i = 0; $i -lt $subTaskCount; $i++) {
    $name = $subTasks[$i].name
    $branch = "feature/$Task/$name"
    $worktreePath = Join-Path $WorktreesDir $name

    if ($DryRun) {
        Write-Dry "git worktree add $worktreePath $branch"
    } else {
        if (Test-Path $worktreePath -PathType Container) {
            Write-Info "Worktree '$worktreePath' already exists, skipping."
        } else {
            git worktree add $worktreePath $branch --quiet 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Created worktree: $worktreePath -> $branch"
            } else {
                Write-Host "! Could not create worktree for $branch" -ForegroundColor Yellow
            }
        }
    }
}

# ── Step 3: Generate brief files ─────────────────────────────────────────────

Write-Host ""
Write-Info "Generating brief files in $BriefsDir\..."

if (-not $DryRun) {
    New-Item -ItemType Directory -Path $BriefsDir -Force | Out-Null
}

for ($i = 0; $i -lt $subTaskCount; $i++) {
    $st = $subTasks[$i]
    $name = $st.name
    $desc = $st.description
    $size = if ($st.size) { $st.size } else { "medium" }
    $layer = if ($st.layer) { $st.layer } else { "TBD" }
    $hasUi = if ($null -ne $st.has_ui) { $st.has_ui } else { $false }
    $branch = "feature/$Task/$name"
    $worktreePath = Join-Path $WorktreesDir $name
    $num = $i + 1

    # Build scope list
    $scope = if ($st.scope -and @($st.scope).Count -gt 0) {
        (@($st.scope) | ForEach-Object { "- $_" }) -join "`n"
    } else { "- TBD" }

    # Build depends_on
    $depends = if ($st.depends_on -and @($st.depends_on).Count -gt 0) {
        @($st.depends_on) -join ", "
    } else { "none" }

    # Build acceptance criteria
    $criteria = if ($st.acceptance_criteria -and @($st.acceptance_criteria).Count -gt 0) {
        (@($st.acceptance_criteria) | ForEach-Object { "- [ ] $_" }) -join "`n"
    } else { "- [ ] TBD" }

    # Other sub-tasks
    $others = ($subTasks | Where-Object { $_.name -ne $name } | ForEach-Object { $_.name }) -join ", "
    if (-not $others) { $others = "none" }

    # Workflow
    $workflow = if ($hasUi -eq $true) { "Run: Plan -> Design -> Build & Test." } else { "Run: Plan -> Build & Test." }

    # Order note
    if ($i -eq 0) {
        $orderNote = "!! BUILD FIRST -- other sub-tasks depend on this."
    } elseif ($depends -ne "none") {
        $orderNote = "Depends on: $depends (must be merged into integration branch first)."
    } else {
        $orderNote = "Can run in parallel after contracts are merged."
    }

    $briefFile = Join-Path $BriefsDir "sub-task-$num-$name.md"

    $briefContent = @"
## Sub-Task Brief: $name

### Context
Project: $Task
Parent task: $description
This is sub-task $num of $subTaskCount. Other sub-tasks are handling: $others.
$orderNote

### Goal
$desc

### Scope
- Files/modules to touch:
$scope
- Layer: $layer

### Shared contracts (already defined)
<!-- Paste interfaces, DTOs, schemas from sub-task #1 (contracts) here after it's complete. -->
<!-- Include actual code signatures, not just names. -->

### Constraints
- Must not modify: files owned by other sub-tasks
- Dependencies: $depends
- Architecture: follow project conventions (see AGENTS.md or playbook)
- Git branch: $branch
- Worktree: $worktreePath

### Acceptance criteria
$criteria
- [ ] Build passes: ``dotnet build`` (or project-appropriate command)
- [ ] Tests pass: ``dotnet test`` (or project-appropriate command)

### What to do
$workflow
Follow project conventions.
Add code comments where intent isn't obvious.
Do NOT update README, CHANGELOG, or architecture docs --
that happens in the final Document phase after integration.
"@

    if ($DryRun) {
        $lineCount = ($briefContent -split "`n").Count
        Write-Dry "Would write: $briefFile ($lineCount lines)"
    } else {
        Set-Content -Path $briefFile -Value $briefContent -Encoding UTF8
        Write-Ok "Generated: $briefFile"
    }
}

# ── Step 4: Print summary + next steps ───────────────────────────────────────

Write-Host ""
Write-Host ("-" * 60)
Write-Host "  Decomposition complete" -ForegroundColor White
Write-Host ("-" * 60)
Write-Host ""
Write-Host "Integration branch: $integrationBranch"
Write-Host ""
Write-Host "Sub-tasks:"
for ($i = 0; $i -lt $subTaskCount; $i++) {
    $name = $subTasks[$i].name
    $size = if ($subTasks[$i].size) { $subTasks[$i].size } else { "medium" }
    Write-Host "  feature/$Task/$name  ($size)"
    Write-Host "    -> worktree: $WorktreesDir\$name\"
}
Write-Host ""
Write-Host "Brief files: $BriefsDir\"
Get-ChildItem (Join-Path $BriefsDir "sub-task-*.md") -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $($_.Name)" }
Write-Host ""
Write-Host ("-" * 60)
Write-Host "  Next steps" -ForegroundColor White
Write-Host ("-" * 60)
Write-Host ""
$firstTask = $subTasks[0].name
Write-Host "1. Build contracts first:"
Write-Host "   cd $WorktreesDir\$firstTask"
Write-Host "   # Complete sub-task #1, then merge into $integrationBranch"
Write-Host ""
Write-Host "2. Run remaining sub-tasks (parallel):"
Write-Host "   .\scripts\Run-Agents.ps1 -BriefsDir $BriefsDir -SkipFirst -Parallel -WorktreesDir $WorktreesDir"
Write-Host ""
Write-Host "   Or manually per sub-task (each agent gets its own worktree):"
for ($i = 1; $i -lt $subTaskCount; $i++) {
    $name = $subTasks[$i].name
    $num = $i + 1
    Write-Host "   claude -p `$(Get-Content $BriefsDir\sub-task-$num-$name.md -Raw) --cwd $WorktreesDir\$name"
}
Write-Host ""
Write-Host "3. After all sub-tasks complete:"
Write-Host "   .\scripts\Check-Integration.ps1 -IntegrationBranch $integrationBranch"
Write-Host ""
Write-Host "4. Clean up worktrees when done:"
Write-Host "   git worktree list"
for ($i = 0; $i -lt $subTaskCount; $i++) {
    $name = $subTasks[$i].name
    Write-Host "   git worktree remove $WorktreesDir\$name"
}
Write-Host "   Remove-Item $WorktreesDir -ErrorAction SilentlyContinue"
