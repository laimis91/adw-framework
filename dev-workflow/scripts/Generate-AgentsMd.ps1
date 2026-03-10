<#
.SYNOPSIS
    Auto-generates project context files for AI coding agents.
.DESCRIPTION
    Inspects the repository to capture architecture, conventions, build commands,
    dependency rules, and file structure. Outputs CLAUDE.md, AGENTS.md, or both.
.EXAMPLE
    .\scripts\Generate-AgentsMd.ps1                          # CLAUDE.md (default)
    .\scripts\Generate-AgentsMd.ps1 -Format agents           # AGENTS.md only
    .\scripts\Generate-AgentsMd.ps1 -Format both             # both files
    .\scripts\Generate-AgentsMd.ps1 -Format claude -Output custom.md
    .\scripts\Generate-AgentsMd.ps1 -DryRun
.NOTES
    Prerequisites: git
#>

[CmdletBinding()]
param(
    [ValidateSet("claude", "agents", "both")][string]$Format = "claude",
    [string]$Output = "",
    [string]$Repo = ".",
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Write-Info { param([string]$Msg) Write-Host "i $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "+ $Msg" -ForegroundColor Green }

if ($Output -and $Format -eq "both") {
    Write-Host "X -Output cannot be used with -Format both (two files are generated)." -ForegroundColor Red
    exit 1
}

Set-Location $Repo

git rev-parse --is-inside-work-tree 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "X Not a git repository: $Repo" -ForegroundColor Red
    exit 1
}

$projectRoot = git rev-parse --show-toplevel
Set-Location $projectRoot

# ── Detect project type ──────────────────────────────────────────────────────

function Find-ProjectTypes {
    $types = [System.Collections.ArrayList]::new()

    $hasSln = (Get-ChildItem *.sln -ErrorAction SilentlyContinue).Count -gt 0
    $hasCsproj = (Get-ChildItem -Recurse -Depth 3 -Filter "*.csproj" -ErrorAction SilentlyContinue).Count -gt 0
    if ($hasSln -or $hasCsproj) {
        [void]$types.Add("dotnet")
        $csprojContent = Get-ChildItem -Recurse -Depth 3 -Filter "*.csproj" -ErrorAction SilentlyContinue |
            ForEach-Object { Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue } | Out-String
        if ($csprojContent -match "Blazor")              { [void]$types.Add("blazor") }
        if ($csprojContent -match "Microsoft\.Maui")     { [void]$types.Add("maui") }
        if ($csprojContent -match "Microsoft\.AspNetCore") { [void]$types.Add("aspnet") }
    }

    if (Test-Path "package.json") {
        [void]$types.Add("node")
        if ((Test-Path "next.config.js") -or (Test-Path "next.config.mjs") -or (Test-Path "next.config.ts")) {
            [void]$types.Add("nextjs")
        }
        $pkg = Get-Content "package.json" -Raw -ErrorAction SilentlyContinue
        if ($pkg -match '"react"') { [void]$types.Add("react") }
    }

    if ((Test-Path "Assets" -PathType Container) -and (Test-Path "ProjectSettings/ProjectVersion.txt")) {
        [void]$types.Add("unity")
    }

    if (Test-Path "platformio.ini") { [void]$types.Add("esp32") }

    if ((Test-Path "pyproject.toml") -or (Test-Path "setup.py") -or (Test-Path "requirements.txt")) {
        [void]$types.Add("python")
        $pyContent = ""
        if (Test-Path "pyproject.toml") { $pyContent += Get-Content "pyproject.toml" -Raw -ErrorAction SilentlyContinue }
        if (Test-Path "requirements.txt") { $pyContent += Get-Content "requirements.txt" -Raw -ErrorAction SilentlyContinue }
        if ($pyContent -match "fastapi") { [void]$types.Add("fastapi") }
    }

    if (Test-Path "Cargo.toml") { [void]$types.Add("rust") }
    if (Test-Path "go.mod") { [void]$types.Add("go") }
    if ((Test-Path "index.html") -and -not (Test-Path "package.json")) { [void]$types.Add("static") }

    if ($types.Count -eq 0) { [void]$types.Add("unknown") }
    return $types -join " "
}

# ── Detect architecture ──────────────────────────────────────────────────────

function Find-Architecture {
    param([string]$Types)
    $arch = "Not determined"

    $hasDomain = (Test-Path "src/Domain" -PathType Container) -or (Test-Path "src/Core" -PathType Container) -or (Test-Path "Domain" -PathType Container)
    $hasApp = (Test-Path "src/Application" -PathType Container) -or (Test-Path "Application" -PathType Container)
    if ($hasDomain -and $hasApp) { $arch = "Clean Architecture (Onion)" }

    $hasViewModels = (Get-ChildItem -Recurse -Depth 4 -Filter "*ViewModel*" -ErrorAction SilentlyContinue).Count -gt 0
    if ($hasViewModels) {
        if ($arch -match "Clean") { $arch = "$arch + MVVM" } else { $arch = "MVVM" }
    }

    if ($Types -match "unity") {
        $hasAsmdef = (Get-ChildItem -Recurse -Filter "*.asmdef" -ErrorAction SilentlyContinue).Count -gt 0
        if ($hasAsmdef) { $arch = "Clean Architecture with asmdef layering" }
        else { $arch = "Unity (standard)" }
    }

    if ($Types -match "esp32") {
        if ((Test-Path "lib" -PathType Container) -or (Test-Path "src/hal" -PathType Container) -or (Test-Path "src/services" -PathType Container)) {
            $arch = "Layered (HAL -> Services -> App -> main)"
        }
    }

    return $arch
}

# ── Detect build/test commands ────────────────────────────────────────────────

function Find-BuildCmd {
    param([string]$Types)
    if ($Types -match "dotnet") {
        $sln = Get-ChildItem *.sln -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($sln) { return "dotnet build $($sln.Name)" } else { return "dotnet build" }
    }
    if ($Types -match "node")   { return "npm run build" }
    if ($Types -match "esp32")  { return "pio run" }
    if ($Types -match "python") { return "# No build step (interpreted)" }
    if ($Types -match "rust")   { return "cargo build" }
    if ($Types -match "go")     { return "go build ./..." }
    return "# TODO: add build command"
}

function Find-TestCmd {
    param([string]$Types)
    if ($Types -match "dotnet") { return "dotnet test" }
    if ($Types -match "node")   { return "npm test" }
    if ($Types -match "esp32")  { return "pio test" }
    if ($Types -match "python") {
        if ((Test-Path "pyproject.toml") -and (Select-String -Path "pyproject.toml" -Pattern "pytest" -Quiet -ErrorAction SilentlyContinue)) {
            return "pytest"
        }
        return "python -m pytest"
    }
    if ($Types -match "rust") { return "cargo test" }
    if ($Types -match "go")   { return "go test ./..." }
    return "# TODO: add test command"
}

# ── Generate file structure ───────────────────────────────────────────────────

function Get-FileStructure {
    $excludes = @('.git', 'node_modules', 'bin', 'obj', '.vs', '.idea', 'Library', 'Temp', 'Logs', '.pio', 'dist', 'build', '__pycache__', '.venv', 'target', '.worktrees')
    Get-ChildItem -Directory -Depth 2 -ErrorAction SilentlyContinue |
        Where-Object {
            $dir = $_
            -not ($excludes | Where-Object { $dir.FullName -match [regex]::Escape($_) })
        } |
        Sort-Object FullName |
        Select-Object -First 40 |
        ForEach-Object {
            $rel = $_.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
            "  $rel"
        }
}

# ── Detect dependency rules ──────────────────────────────────────────────────

function Find-DependencyRules {
    param([string]$Types, [string]$Arch)
    $rules = ""

    if ($Arch -match "Clean") {
        $rules = @"
- Domain layer has no external dependencies (no framework, no infrastructure references)
- Application layer depends only on Domain
- Infrastructure implements Application interfaces
- UI/Presentation depends on Application, never directly on Infrastructure
- Dependency injection wires Infrastructure to Application interfaces at composition root
"@
    }

    if ($Types -match "unity" -and $Arch -match "asmdef") {
        $rules += "`n- Assembly definitions (asmdef) enforce layer boundaries at compile time"
        $rules += "`n- Game logic assemblies must not reference Unity Editor assemblies"
        $rules += "`n- Shared contracts in a dedicated assembly referenced by all layers"
    }

    if (-not $rules) { $rules = "- No specific dependency rules detected -- define as project matures" }
    return $rules
}

# ── Detect conventions ────────────────────────────────────────────────────────

function Find-Conventions {
    $conventions = ""

    if (Get-ChildItem -Recurse -Depth 4 -Filter "I*.cs" -ErrorAction SilentlyContinue | Select-Object -First 1) {
        $conventions += "`n- Interface naming: prefix with I (e.g., IOrderService)"
    }
    if (Get-ChildItem -Recurse -Depth 4 -Filter "*Tests.cs" -ErrorAction SilentlyContinue | Select-Object -First 1) {
        $conventions += "`n- Test class naming: {ClassName}Tests"
    }
    $testFiles = Get-ChildItem -Recurse -Depth 4 -Include "*.test.ts","*.test.js","*.spec.ts","*.spec.js" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($testFiles) { $conventions += "`n- Test file naming: {name}.test.{ext} or {name}.spec.{ext}" }

    $lastCommits = git log --oneline -10 2>$null
    if ($lastCommits -match '^\w+ (feat|fix|chore|docs|refactor|test|style|perf)') {
        $conventions += "`n- Commit messages: Conventional Commits (feat:, fix:, chore:, etc.)"
    }

    $hasAppSettings = (Test-Path "appsettings.json") -or
        (Get-ChildItem -Recurse -Depth 3 -Filter "appsettings.json" -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($hasAppSettings) { $conventions += "`n- Configuration: appsettings.json with environment overrides" }

    if ((Test-Path ".env.example") -or (Test-Path ".env.sample")) { $conventions += "`n- Environment variables: documented in .env.example" }
    if (Test-Path ".editorconfig") { $conventions += "`n- Code style: enforced via .editorconfig" }
    if ((Test-Path ".prettierrc") -or (Test-Path ".prettierrc.json")) { $conventions += "`n- Code formatting: Prettier" }
    if ((Test-Path ".eslintrc.json") -or (Test-Path ".eslintrc.js") -or (Test-Path "eslint.config.js")) { $conventions += "`n- Linting: ESLint" }

    if (-not $conventions) { $conventions = "`n- No specific conventions detected -- define as project matures" }
    return $conventions
}

# ── Build the document body ───────────────────────────────────────────────────

Write-Info "Inspecting project..."

$projectTypes = Find-ProjectTypes
$architecture = Find-Architecture $projectTypes
$buildCmd = Find-BuildCmd $projectTypes
$testCmd = Find-TestCmd $projectTypes
$depRules = Find-DependencyRules $projectTypes $architecture
$conventions = Find-Conventions
$fileStructure = (Get-FileStructure) -join "`n"
$projectName = Split-Path $projectRoot -Leaf
$generatedDate = Get-Date -Format "yyyy-MM-dd"

$readmeDesc = "TODO: Add project description"
if (Test-Path "README.md") {
    $line = Get-Content "README.md" | Where-Object { $_ -notmatch '^(#|\s*$)' } | Select-Object -First 1
    if ($line) { $readmeDesc = $line }
}

# ── Detect dev-workflow skill ─────────────────────────────────────────────────

$workflowSection = ""
if (Test-Path "dev-workflow/SKILL.md") {
    $workflowSection = @"

## Development Workflow

This project uses the AI-Assisted Development Workflow.
Follow it for all code changes: Triage -> Discover -> Plan -> [Design] -> Build & Test -> Document.

See ``dev-workflow/SKILL.md`` for full phases, rules, and approval gates.

Key rules:
- Never guess -- ask before assuming
- Plan before coding -- get approval before implementation
- One step at a time -- build + test after each plan step
- Flag deviations -- stop if reality doesn't match the plan
"@
    Write-Info "Detected dev-workflow skill -- adding workflow section."
}

# ── Generate content for a given format ───────────────────────────────────────

function Build-Content {
    param([string]$Fmt)

    switch ($Fmt) {
        "claude" {
            $title = "CLAUDE.md"
            $subtitle = "Project context for Claude Code. Auto-generated -- edit to refine."
        }
        "agents" {
            $title = "AGENTS.md"
            $subtitle = "Project context for AI coding agents. Auto-generated -- edit to refine."
        }
    }

    return @"
# $title

> $subtitle

## Project

- **Name:** $projectName
- **Description:** $readmeDesc
- **Type:** $projectTypes
- **Generated:** $generatedDate

## Architecture

**Pattern:** $architecture

### Dependency rules

$depRules

## Build & Test

``````bash
# Build
$buildCmd

# Test
$testCmd
``````

## File Structure

``````
$fileStructure
``````

## Key Conventions
$conventions

## AI Agent Instructions

When working on this project:

1. **Read this file first** before making any changes
2. **Respect layer boundaries** -- see dependency rules above
3. **Run build + test** after every change: ``$buildCmd && $testCmd``
4. **Follow existing patterns** -- check nearby files before creating new ones
5. **No hardcoded secrets** -- use configuration / environment variables
6. **Ask before adding dependencies** -- justify new packages
$workflowSection

## Notes

<!-- Add project-specific notes, gotchas, and tribal knowledge here -->
<!-- Examples:
- The legacy OrderService uses a different pattern -- don't copy it
- Auth tokens expire every 30 min in dev, 24h in prod
- The /api/v1/ endpoints are frozen -- all new work goes in /api/v2/
-->
"@
}

# ── Write a single file ──────────────────────────────────────────────────────

function Write-AgentFile {
    param([string]$Fmt, [string]$OutputPath)
    $content = Build-Content $Fmt

    if ($DryRun) {
        Write-Output $content
        Write-Info "Dry run ($OutputPath) -- nothing written."
    } else {
        Set-Content -Path $OutputPath -Value $content -Encoding UTF8
        Write-Ok "Generated: $OutputPath"
    }
}

# ── Output ────────────────────────────────────────────────────────────────────

switch ($Format) {
    "claude" {
        if (-not $Output) { $Output = "CLAUDE.md" }
        Write-AgentFile "claude" $Output
    }
    "agents" {
        if (-not $Output) { $Output = "AGENTS.md" }
        Write-AgentFile "agents" $Output
    }
    "both" {
        Write-AgentFile "claude" "CLAUDE.md"
        Write-AgentFile "agents" "AGENTS.md"
    }
}

Write-Info "Review and edit the file(s) to add project-specific knowledge."
