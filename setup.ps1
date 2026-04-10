# gstack setup — build browser binary + register skills with Claude Code / Codex
# PowerShell port for Windows
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Check bun ────────────────────────────────────────────────
if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Error @"
bun is required but not installed.
Install from: https://bun.sh/docs/installation
  PowerShell: irm bun.sh/install.ps1 | iex
"@
    exit 1
}

# ─── Paths ────────────────────────────────────────────────────
$INSTALL_GSTACK_DIR = $PSScriptRoot
$SOURCE_GSTACK_DIR  = (Resolve-Path $PSScriptRoot).Path
$INSTALL_SKILLS_DIR = Split-Path $INSTALL_GSTACK_DIR -Parent
$BROWSE_BIN         = Join-Path $SOURCE_GSTACK_DIR "browse\dist\browse.exe"
$CODEX_SKILLS       = Join-Path $HOME ".codex\skills"
$CODEX_GSTACK       = Join-Path $CODEX_SKILLS "gstack"
$FACTORY_SKILLS     = Join-Path $HOME ".factory\skills"
$FACTORY_GSTACK     = Join-Path $FACTORY_SKILLS "gstack"

# ─── Quiet mode helper ───────────────────────────────────────
$QUIET = $false
function Log-Message { param([string]$Message) if (-not $QUIET) { Write-Host $Message } }

# ─── Parse flags ──────────────────────────────────────────────
$TargetHost = "claude"
$LOCAL_INSTALL = $false
$SKILL_PREFIX = $true
$SKILL_PREFIX_FLAG = $false

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--host"       { $i++; $TargetHost = $args[$i] }
        "--local"      { $LOCAL_INSTALL = $true }
        "--prefix"     { $SKILL_PREFIX = $true;  $SKILL_PREFIX_FLAG = $true }
        "--no-prefix"  { $SKILL_PREFIX = $false; $SKILL_PREFIX_FLAG = $true }
        { $_ -in "-q","--quiet" } { $QUIET = $true }
        default {
            if ($args[$i] -match '^--host=(.+)$') { $TargetHost = $Matches[1] }
        }
    }
}

# Validate host
$validHosts = @("claude","codex","kiro","factory","auto")
if ($TargetHost -eq "openclaw") {
    Write-Host @"

OpenClaw integration uses a different model — OpenClaw spawns Claude Code
sessions natively via ACP. gstack provides methodology artifacts, not a
full skill installation.

To integrate gstack with OpenClaw:
  1. Tell your OpenClaw agent: 'install gstack for openclaw'
  2. Or generate artifacts: bun run gen:skill-docs --host openclaw
  3. See docs/OPENCLAW.md for the full architecture

"@
    exit 0
}
if ($TargetHost -notin $validHosts) {
    Write-Error "Unknown --host value: $TargetHost (expected claude, codex, kiro, factory, openclaw, or auto)"
    exit 1
}

# ─── Resolve skill prefix preference ─────────────────────────
$GSTACK_CONFIG = Join-Path $SOURCE_GSTACK_DIR "bin\gstack-config"
$env:GSTACK_SETUP_RUNNING = "1"

if (-not $SKILL_PREFIX_FLAG) {
    $savedPrefix = $null
    try { $savedPrefix = & bun run $GSTACK_CONFIG get skill_prefix 2>$null } catch {}
    if ($savedPrefix -eq "true") {
        $SKILL_PREFIX = $true
    } elseif ($savedPrefix -eq "false") {
        $SKILL_PREFIX = $false
    } else {
        # No saved preference — prompt interactively or default
        if ($QUIET) {
            $SKILL_PREFIX = $false
        } elseif ([Environment]::UserInteractive) {
            Write-Host ""
            Write-Host "Skill naming: how should gstack skills appear?"
            Write-Host ""
            Write-Host "  1) Short names: /qa, /ship, /review"
            Write-Host "     Recommended. Clean and fast to type."
            Write-Host ""
            Write-Host "  2) Namespaced: /gstack-qa, /gstack-ship, /gstack-review"
            Write-Host "     Use this if you run other skill packs alongside gstack to avoid conflicts."
            Write-Host ""
            $choice = Read-Host "Choice [1/2] (default: 1)"
            if ($choice -eq "2") { $SKILL_PREFIX = $true } else { $SKILL_PREFIX = $false }
        } else {
            $SKILL_PREFIX = $false
        }
        $prefixVal = if ($SKILL_PREFIX) { "true" } else { "false" }
        try { & bun run $GSTACK_CONFIG set skill_prefix $prefixVal 2>$null } catch {}
    }
} else {
    $prefixVal = if ($SKILL_PREFIX) { "true" } else { "false" }
    try { & bun run $GSTACK_CONFIG set skill_prefix $prefixVal 2>$null } catch {}
}

# --local (deprecated)
if ($LOCAL_INSTALL) {
    Write-Warning "--local is deprecated. Use global install + --team instead."
    if ($TargetHost -eq "codex") { Write-Error "--local is only supported for Claude Code (not Codex)."; exit 1 }
    $INSTALL_SKILLS_DIR = Join-Path (Get-Location).Path ".claude\skills"
    New-Item -ItemType Directory -Force -Path $INSTALL_SKILLS_DIR | Out-Null
    $TargetHost = "claude"
}

# Auto-detect hosts
$INSTALL_CLAUDE  = $false
$INSTALL_CODEX   = $false
$INSTALL_KIRO    = $false
$INSTALL_FACTORY = $false

if ($TargetHost -eq "auto") {
    if (Get-Command claude   -ErrorAction SilentlyContinue) { $INSTALL_CLAUDE  = $true }
    if (Get-Command codex    -ErrorAction SilentlyContinue) { $INSTALL_CODEX   = $true }
    if (Get-Command kiro-cli -ErrorAction SilentlyContinue) { $INSTALL_KIRO    = $true }
    if (Get-Command droid    -ErrorAction SilentlyContinue) { $INSTALL_FACTORY = $true }
    if (-not ($INSTALL_CLAUDE -or $INSTALL_CODEX -or $INSTALL_KIRO -or $INSTALL_FACTORY)) {
        $INSTALL_CLAUDE = $true
    }
} elseif ($TargetHost -eq "claude")  { $INSTALL_CLAUDE  = $true }
  elseif ($TargetHost -eq "codex")   { $INSTALL_CODEX   = $true }
  elseif ($TargetHost -eq "kiro")    { $INSTALL_KIRO    = $true }
  elseif ($TargetHost -eq "factory") { $INSTALL_FACTORY = $true }

# ─── Playwright browser check ────────────────────────────────
function Test-PlaywrightBrowser {
    Push-Location $SOURCE_GSTACK_DIR
    try {
        # On Windows, use Node.js (Bun has pipe issues — oven-sh/bun#4253)
        if (Get-Command node -ErrorAction SilentlyContinue) {
            node -e "const { chromium } = require('playwright'); (async () => { const b = await chromium.launch(); await b.close(); })()" 2>$null
            return $LASTEXITCODE -eq 0
        }
        return $false
    } catch { return $false }
    finally { Pop-Location }
}

# ─── 1. Build browse binary if needed ─────────────────────────
$NEEDS_BUILD = $false
if (-not (Test-Path $BROWSE_BIN)) {
    $NEEDS_BUILD = $true
} else {
    $browseBinTime = (Get-Item $BROWSE_BIN).LastWriteTime
    $srcFiles = Get-ChildItem -Path (Join-Path $SOURCE_GSTACK_DIR "browse\src") -Recurse -File -ErrorAction SilentlyContinue
    if ($srcFiles | Where-Object { $_.LastWriteTime -gt $browseBinTime }) { $NEEDS_BUILD = $true }
    $pkgJson = Join-Path $SOURCE_GSTACK_DIR "package.json"
    if ((Test-Path $pkgJson) -and (Get-Item $pkgJson).LastWriteTime -gt $browseBinTime) { $NEEDS_BUILD = $true }
    $bunLock = Join-Path $SOURCE_GSTACK_DIR "bun.lock"
    if ((Test-Path $bunLock) -and (Get-Item $bunLock).LastWriteTime -gt $browseBinTime) { $NEEDS_BUILD = $true }
}

if ($NEEDS_BUILD) {
    Log-Message "Building browse binary..."
    Push-Location $SOURCE_GSTACK_DIR
    try {
        bun install
        bun run build
    } finally { Pop-Location }

    # Safety net: write .version if build script didn't
    $versionFile = Join-Path $SOURCE_GSTACK_DIR "browse\dist\.version"
    if (-not (Test-Path $versionFile)) {
        try { git -C $SOURCE_GSTACK_DIR rev-parse HEAD 2>$null | Out-File -FilePath $versionFile -Encoding ascii } catch {}
    }
}

# Check browse binary exists (may be .exe on Windows or plain name via bun compile)
$BROWSE_BIN_ALT = Join-Path $SOURCE_GSTACK_DIR "browse\dist\browse"
if (-not (Test-Path $BROWSE_BIN) -and -not (Test-Path $BROWSE_BIN_ALT)) {
    Write-Error "gstack setup failed: browse binary missing at $BROWSE_BIN"
    exit 1
}
# Use whichever exists
if (-not (Test-Path $BROWSE_BIN) -and (Test-Path $BROWSE_BIN_ALT)) {
    $BROWSE_BIN = $BROWSE_BIN_ALT
}

# ─── 1b. Generate .agents/ Codex skill docs ──────────────────
$AGENTS_DIR = Join-Path $SOURCE_GSTACK_DIR ".agents\skills"
if (-not $NEEDS_BUILD) {
    Log-Message "Generating .agents/ skill docs..."
    Push-Location $SOURCE_GSTACK_DIR
    try {
        bun install --frozen-lockfile 2>$null
        if ($LASTEXITCODE -ne 0) { bun install }
        bun run gen:skill-docs --host codex
    } finally { Pop-Location }
}

# ─── 1c. Generate .factory/ Factory Droid skill docs ─────────
if ($INSTALL_FACTORY -and -not $NEEDS_BUILD) {
    Log-Message "Generating .factory/ skill docs..."
    Push-Location $SOURCE_GSTACK_DIR
    try {
        bun install --frozen-lockfile 2>$null
        if ($LASTEXITCODE -ne 0) { bun install }
        bun run gen:skill-docs --host factory
    } finally { Pop-Location }
}

# ─── 2. Ensure Playwright Chromium ────────────────────────────
# Windows: Bun can't launch Chromium (oven-sh/bun#4253), use Node.js + npx instead
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error @"
gstack setup failed: Node.js is required on Windows (Bun cannot launch Chromium due to a pipe bug)
  Install Node.js: https://nodejs.org/
"@
    exit 1
}

if (-not (Test-PlaywrightBrowser)) {
    Write-Host "Installing Playwright Chromium via npx..."
    Push-Location $SOURCE_GSTACK_DIR
    try {
        # Ensure playwright is available to Node
        node -e "require('playwright')" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Installing playwright for Node.js..."
            npm install --no-save playwright
        }
        npx playwright install chromium
    } finally { Pop-Location }
}

if (-not (Test-PlaywrightBrowser)) {
    Write-Error @"
gstack setup failed: Playwright Chromium could not be launched via Node.js
  Ensure Node.js is installed and 'node -e "require('playwright')"' works.
"@
    exit 1
}

# ─── 3. Ensure ~/.gstack global state directory ──────────────
New-Item -ItemType Directory -Force -Path (Join-Path $HOME ".gstack\projects") | Out-Null

# ─── Helper: create symlink (Windows) ────────────────────────
function New-SymLink {
    param([string]$Path, [string]$Target, [switch]$Directory)
    # Remove existing link/file
    if (Test-Path $Path) { Remove-Item $Path -Force -Recurse -ErrorAction SilentlyContinue }
    if ($Directory) {
        New-Item -ItemType Junction -Path $Path -Target $Target -Force | Out-Null
    } else {
        # For files, use copy on Windows (symlinks require admin or dev mode)
        try {
            New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force | Out-Null
        } catch {
            # Fallback: copy the file
            Copy-Item -Path $Target -Destination $Path -Force
        }
    }
}

# ─── Helper: link Claude skill directories ────────────────────
function Link-ClaudeSkillDirs {
    param([string]$GstackDir, [string]$SkillsDir)
    $linked = @()
    $skillDirs = Get-ChildItem -Path $GstackDir -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $skillDirs) {
        $skillMd = Join-Path $dir.FullName "SKILL.md"
        if (-not (Test-Path $skillMd)) { continue }
        if ($dir.Name -eq "node_modules") { continue }

        # Read frontmatter name
        $skillName = $dir.Name
        $nameMatch = Select-String -Path $skillMd -Pattern '^name:\s*(.+)$' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($nameMatch) {
            $extracted = $nameMatch.Matches[0].Groups[1].Value.Trim()
            if ($extracted) { $skillName = $extracted }
        }

        # Apply prefix
        if ($SKILL_PREFIX) {
            if ($skillName -notmatch '^gstack-') { $linkName = "gstack-$skillName" }
            else { $linkName = $skillName }
        } else {
            $linkName = $skillName
        }

        $target = Join-Path $SkillsDir $linkName
        New-Item -ItemType Directory -Force -Path $target | Out-Null

        # Create symlink for SKILL.md
        $skillMdLink = Join-Path $target "SKILL.md"
        $skillMdSource = Join-Path $GstackDir "$($dir.Name)\SKILL.md"
        New-SymLink -Path $skillMdLink -Target $skillMdSource
        $linked += $linkName
    }
    if ($linked.Count -gt 0) {
        Write-Host "  linked skills: $($linked -join ' ')"
    }
}

# ─── Helper: cleanup old Claude symlinks ──────────────────────
function Remove-OldClaudeSymlinks {
    param([string]$GstackDir, [string]$SkillsDir, [switch]$Prefixed)
    $removed = @()
    $skillDirs = Get-ChildItem -Path $GstackDir -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $skillDirs) {
        $skillMd = Join-Path $dir.FullName "SKILL.md"
        if (-not (Test-Path $skillMd)) { continue }
        if ($dir.Name -eq "node_modules") { continue }
        if ($dir.Name -match '^gstack-') { continue }

        if ($Prefixed) {
            $oldTarget = Join-Path $SkillsDir "gstack-$($dir.Name)"
        } else {
            $oldTarget = Join-Path $SkillsDir $dir.Name
        }

        if (Test-Path $oldTarget) {
            $skillMdInTarget = Join-Path $oldTarget "SKILL.md"
            if ((Test-Path $skillMdInTarget) -and ((Get-Item $skillMdInTarget -ErrorAction SilentlyContinue).Attributes -match 'ReparsePoint')) {
                Remove-Item $oldTarget -Recurse -Force -ErrorAction SilentlyContinue
                $removed += $dir.Name
            }
        }
    }
    if ($removed.Count -gt 0) {
        Write-Host "  cleaned up entries: $($removed -join ' ')"
    }
}

# ─── Helper: link Codex skill dirs ────────────────────────────
function Link-CodexSkillDirs {
    param([string]$GstackDir, [string]$SkillsDir)
    $agentsDir = Join-Path $GstackDir ".agents\skills"
    if (-not (Test-Path $agentsDir)) {
        Write-Host "  Generating .agents/ skill docs..."
        Push-Location $GstackDir
        try { bun run gen:skill-docs --host codex } finally { Pop-Location }
    }
    if (-not (Test-Path $agentsDir)) {
        Write-Warning ".agents/skills/ generation failed — run 'bun run gen:skill-docs --host codex' manually"
        return
    }

    $linked = @()
    $gstackSkills = Get-ChildItem -Path $agentsDir -Directory -Filter "gstack*" -ErrorAction SilentlyContinue
    foreach ($dir in $gstackSkills) {
        if ($dir.Name -eq "gstack") { continue }
        $skillMd = Join-Path $dir.FullName "SKILL.md"
        if (-not (Test-Path $skillMd)) { continue }
        $target = Join-Path $SkillsDir $dir.Name
        New-SymLink -Path $target -Target $dir.FullName -Directory
        $linked += $dir.Name
    }
    if ($linked.Count -gt 0) {
        Write-Host "  linked skills: $($linked -join ' ')"
    }
}

# ─── Helper: create Codex runtime root ────────────────────────
function New-CodexRuntimeRoot {
    param([string]$GstackDir, [string]$CodexGstack)
    $agentsDir = Join-Path $GstackDir ".agents\skills"

    if (Test-Path $CodexGstack) { Remove-Item $CodexGstack -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Force -Path $CodexGstack | Out-Null
    foreach ($sub in @("browse","gstack-upgrade","review")) {
        New-Item -ItemType Directory -Force -Path (Join-Path $CodexGstack $sub) | Out-Null
    }

    $agentsGstackSkill = Join-Path $agentsDir "gstack\SKILL.md"
    if (Test-Path $agentsGstackSkill) { New-SymLink -Path (Join-Path $CodexGstack "SKILL.md") -Target $agentsGstackSkill }

    $binDir = Join-Path $GstackDir "bin"
    if (Test-Path $binDir) { New-SymLink -Path (Join-Path $CodexGstack "bin") -Target $binDir -Directory }

    $browseDist = Join-Path $GstackDir "browse\dist"
    if (Test-Path $browseDist) { New-SymLink -Path (Join-Path $CodexGstack "browse\dist") -Target $browseDist -Directory }

    $browseBin = Join-Path $GstackDir "browse\bin"
    if (Test-Path $browseBin) { New-SymLink -Path (Join-Path $CodexGstack "browse\bin") -Target $browseBin -Directory }

    $upgradeSkill = Join-Path $agentsDir "gstack-upgrade\SKILL.md"
    if (Test-Path $upgradeSkill) { New-SymLink -Path (Join-Path $CodexGstack "gstack-upgrade\SKILL.md") -Target $upgradeSkill }

    foreach ($f in @("checklist.md","design-checklist.md","greptile-triage.md","TODOS-format.md")) {
        $src = Join-Path $GstackDir "review\$f"
        if (Test-Path $src) { New-SymLink -Path (Join-Path $CodexGstack "review\$f") -Target $src }
    }

    $ethos = Join-Path $GstackDir "ETHOS.md"
    if (Test-Path $ethos) { New-SymLink -Path (Join-Path $CodexGstack "ETHOS.md") -Target $ethos }
}

# ─── Helper: create .agents sidecar ──────────────────────────
function New-AgentsSidecar {
    param([string]$RepoRoot)
    $agentsGstack = Join-Path $RepoRoot ".agents\skills\gstack"
    New-Item -ItemType Directory -Force -Path $agentsGstack | Out-Null

    foreach ($asset in @("bin","browse","review","qa")) {
        $src = Join-Path $SOURCE_GSTACK_DIR $asset
        $dst = Join-Path $agentsGstack $asset
        if (Test-Path $src) { New-SymLink -Path $dst -Target $src -Directory }
    }
    foreach ($file in @("ETHOS.md")) {
        $src = Join-Path $SOURCE_GSTACK_DIR $file
        $dst = Join-Path $agentsGstack $file
        if (Test-Path $src) { New-SymLink -Path $dst -Target $src }
    }
}

# ─── 4. Install for Claude ────────────────────────────────────
$SKILLS_BASENAME = Split-Path $INSTALL_SKILLS_DIR -Leaf

if ($INSTALL_CLAUDE) {
    if ($SKILLS_BASENAME -eq "skills") {
        # Clean up stale symlinks from opposite prefix mode
        if ($SKILL_PREFIX) {
            Remove-OldClaudeSymlinks -GstackDir $SOURCE_GSTACK_DIR -SkillsDir $INSTALL_SKILLS_DIR
        } else {
            Remove-OldClaudeSymlinks -GstackDir $SOURCE_GSTACK_DIR -SkillsDir $INSTALL_SKILLS_DIR -Prefixed
        }
        # Patch name fields
        $patchNames = Join-Path $SOURCE_GSTACK_DIR "bin\gstack-patch-names"
        $prefixArg = if ($SKILL_PREFIX) { "1" } else { "0" }
        & bun run $patchNames $SOURCE_GSTACK_DIR $prefixArg 2>$null

        Link-ClaudeSkillDirs -GstackDir $SOURCE_GSTACK_DIR -SkillsDir $INSTALL_SKILLS_DIR

        # Self-healing relink
        $relink = Join-Path $SOURCE_GSTACK_DIR "bin\gstack-relink"
        if (Test-Path $relink) {
            $env:GSTACK_SKILLS_DIR = $INSTALL_SKILLS_DIR
            $env:GSTACK_INSTALL_DIR = $SOURCE_GSTACK_DIR
            try { & bun run $relink 2>$null } catch {}
        }

        if ($LOCAL_INSTALL) {
            Log-Message "gstack ready (project-local)."
            Log-Message "  skills: $INSTALL_SKILLS_DIR"
        } else {
            Log-Message "gstack ready (claude)."
        }
        Log-Message "  browse: $BROWSE_BIN"
    } else {
        # Not inside skills/ — symlink into ~/.claude/skills/
        $CLAUDE_SKILLS_DIR = Join-Path $HOME ".claude\skills"
        $CLAUDE_GSTACK_LINK = Join-Path $CLAUDE_SKILLS_DIR "gstack"
        New-Item -ItemType Directory -Force -Path $CLAUDE_SKILLS_DIR | Out-Null
        New-SymLink -Path $CLAUDE_GSTACK_LINK -Target $SOURCE_GSTACK_DIR -Directory
        Log-Message "  symlinked $CLAUDE_GSTACK_LINK -> $SOURCE_GSTACK_DIR"
        $INSTALL_SKILLS_DIR = $CLAUDE_SKILLS_DIR
        $INSTALL_GSTACK_DIR = $CLAUDE_GSTACK_LINK

        if ($SKILL_PREFIX) {
            Remove-OldClaudeSymlinks -GstackDir $SOURCE_GSTACK_DIR -SkillsDir $INSTALL_SKILLS_DIR
        } else {
            Remove-OldClaudeSymlinks -GstackDir $SOURCE_GSTACK_DIR -SkillsDir $INSTALL_SKILLS_DIR -Prefixed
        }

        $patchNames = Join-Path $SOURCE_GSTACK_DIR "bin\gstack-patch-names"
        $prefixArg = if ($SKILL_PREFIX) { "1" } else { "0" }
        & bun run $patchNames $SOURCE_GSTACK_DIR $prefixArg 2>$null

        Link-ClaudeSkillDirs -GstackDir $SOURCE_GSTACK_DIR -SkillsDir $INSTALL_SKILLS_DIR

        $relink = Join-Path $SOURCE_GSTACK_DIR "bin\gstack-relink"
        if (Test-Path $relink) {
            $env:GSTACK_SKILLS_DIR = $INSTALL_SKILLS_DIR
            $env:GSTACK_INSTALL_DIR = $SOURCE_GSTACK_DIR
            try { & bun run $relink 2>$null } catch {}
        }

        Log-Message "gstack ready (claude)."
        Log-Message "  browse: $BROWSE_BIN"
    }
}

# ─── 5. Install for Codex ─────────────────────────────────────
if ($INSTALL_CODEX) {
    $CODEX_REPO_LOCAL = $false
    $skillsParent = Split-Path $INSTALL_SKILLS_DIR -Leaf
    $skillsGrandparent = Split-Path (Split-Path $INSTALL_SKILLS_DIR -Parent) -Leaf
    if ($skillsParent -eq "skills" -and $skillsGrandparent -eq ".agents") { $CODEX_REPO_LOCAL = $true }

    if ($CODEX_REPO_LOCAL) {
        $CODEX_SKILLS = $INSTALL_SKILLS_DIR
        $CODEX_GSTACK = $INSTALL_GSTACK_DIR
    }
    New-Item -ItemType Directory -Force -Path $CODEX_SKILLS | Out-Null

    if (-not $CODEX_REPO_LOCAL) {
        New-CodexRuntimeRoot -GstackDir $SOURCE_GSTACK_DIR -CodexGstack $CODEX_GSTACK
    }
    Link-CodexSkillDirs -GstackDir $SOURCE_GSTACK_DIR -SkillsDir $CODEX_SKILLS

    Log-Message "gstack ready (codex)."
    Log-Message "  browse: $BROWSE_BIN"
    Log-Message "  codex skills: $CODEX_SKILLS"
}

# ─── 6. Install for Kiro CLI ──────────────────────────────────
if ($INSTALL_KIRO) {
    $KIRO_SKILLS = Join-Path $HOME ".kiro\skills"
    $KIRO_GSTACK = Join-Path $KIRO_SKILLS "gstack"
    New-Item -ItemType Directory -Force -Path $KIRO_SKILLS | Out-Null
    New-Item -ItemType Directory -Force -Path $KIRO_GSTACK | Out-Null
    foreach ($sub in @("browse","gstack-upgrade","review")) {
        New-Item -ItemType Directory -Force -Path (Join-Path $KIRO_GSTACK $sub) | Out-Null
    }

    # Link runtime assets
    New-SymLink -Path (Join-Path $KIRO_GSTACK "bin") -Target (Join-Path $SOURCE_GSTACK_DIR "bin") -Directory
    New-SymLink -Path (Join-Path $KIRO_GSTACK "browse\dist") -Target (Join-Path $SOURCE_GSTACK_DIR "browse\dist") -Directory
    $browseBinDir = Join-Path $SOURCE_GSTACK_DIR "browse\bin"
    if (Test-Path $browseBinDir) {
        New-SymLink -Path (Join-Path $KIRO_GSTACK "browse\bin") -Target $browseBinDir -Directory
    }
    $ethos = Join-Path $SOURCE_GSTACK_DIR "ETHOS.md"
    if (Test-Path $ethos) { New-SymLink -Path (Join-Path $KIRO_GSTACK "ETHOS.md") -Target $ethos }

    # Rewrite SKILL.md paths for Kiro
    $skillMdContent = Get-Content (Join-Path $SOURCE_GSTACK_DIR "SKILL.md") -Raw
    $skillMdContent = $skillMdContent -replace '~/.claude/skills/gstack', '~/.kiro/skills/gstack'
    $skillMdContent = $skillMdContent -replace '\.claude/skills/gstack', '.kiro/skills/gstack'
    $skillMdContent = $skillMdContent -replace '\.claude/skills', '.kiro/skills'
    $skillMdContent | Out-File -FilePath (Join-Path $KIRO_GSTACK "SKILL.md") -Encoding utf8

    Log-Message "gstack ready (kiro)."
    Log-Message "  browse: $BROWSE_BIN"
    Log-Message "  kiro skills: $KIRO_SKILLS"
}

# ─── 6b. Install for Factory Droid ────────────────────────────
if ($INSTALL_FACTORY) {
    New-Item -ItemType Directory -Force -Path $FACTORY_SKILLS | Out-Null
    # Factory runtime root (simplified — same pattern as Codex)
    $factoryDir = Join-Path $SOURCE_GSTACK_DIR ".factory\skills"
    if (Test-Path $FACTORY_GSTACK) { Remove-Item $FACTORY_GSTACK -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Force -Path $FACTORY_GSTACK | Out-Null
    foreach ($sub in @("browse","gstack-upgrade","review")) {
        New-Item -ItemType Directory -Force -Path (Join-Path $FACTORY_GSTACK $sub) | Out-Null
    }
    $factorySkillMd = Join-Path $factoryDir "gstack\SKILL.md"
    if (Test-Path $factorySkillMd) { New-SymLink -Path (Join-Path $FACTORY_GSTACK "SKILL.md") -Target $factorySkillMd }
    if (Test-Path (Join-Path $SOURCE_GSTACK_DIR "bin")) { New-SymLink -Path (Join-Path $FACTORY_GSTACK "bin") -Target (Join-Path $SOURCE_GSTACK_DIR "bin") -Directory }
    if (Test-Path (Join-Path $SOURCE_GSTACK_DIR "browse\dist")) { New-SymLink -Path (Join-Path $FACTORY_GSTACK "browse\dist") -Target (Join-Path $SOURCE_GSTACK_DIR "browse\dist") -Directory }

    Log-Message "gstack ready (factory)."
    Log-Message "  browse: $BROWSE_BIN"
    Log-Message "  factory skills: $FACTORY_SKILLS"
}

# ─── 7. Create .agents/ sidecar symlinks ──────────────────────
if ($INSTALL_CODEX) {
    New-AgentsSidecar -RepoRoot $SOURCE_GSTACK_DIR
}

# ─── 8. First-time welcome ─────────────────────────────────────
New-Item -ItemType Directory -Force -Path (Join-Path $HOME ".gstack") | Out-Null
$welcomeFile = Join-Path $HOME ".gstack\.welcome-seen"
if (-not (Test-Path $welcomeFile)) {
    Log-Message "  Welcome to gstack-kor!"
    New-Item -ItemType File -Force -Path $welcomeFile | Out-Null
}
