Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$homeRoot = if ($env:HOME) { $env:HOME } else { $HOME }
$codexRoot = Join-Path $homeRoot '.codex'
$agentsDir = Join-Path $codexRoot 'agents'
$agentPacksDir = Join-Path $codexRoot 'agent-packs'
$skillsDir = Join-Path $codexRoot 'skills'
$configFile = Join-Path $codexRoot 'config.toml'
$metadataFile = Join-Path $codexRoot 'my-codex-install.env'
$managedConfig = @'

# my-codex managed settings
[features]
multi_agent = true
child_agents_md = true

[agents]
max_threads = 8
'@
$coreAwesomeCategories = @(
    '01-core-development',
    '03-infrastructure',
    '04-quality-security',
    '09-meta-orchestration'
)

function Require-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "ERROR: $Name not found"
    }
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Copy-TomlFiles {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$DestinationDir
    )

    if (-not (Test-Path $SourceDir)) {
        return
    }

    Ensure-Directory -Path $DestinationDir
    Get-ChildItem -Path $SourceDir -Filter '*.toml' -File -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination (Join-Path $DestinationDir $_.Name) -Force
    }
}

function Copy-DirectoryContents {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$DestinationDir
    )

    if (-not (Test-Path $SourceDir)) {
        return
    }

    Ensure-Directory -Path $DestinationDir
    Copy-Item -Path (Join-Path $SourceDir '*') -Destination $DestinationDir -Recurse -Force -ErrorAction SilentlyContinue
}

function Get-FileCount {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Filter
    )

    if (-not (Test-Path $Path)) {
        return 0
    }

    return (Get-ChildItem -Path $Path -Recurse -Filter $Filter -File -ErrorAction SilentlyContinue | Measure-Object).Count
}

function Test-McpServer {
    param([Parameter(Mandatory = $true)][string]$Name)

    $codexCmd = Get-Command codex -ErrorAction SilentlyContinue
    if (-not $codexCmd) {
        return $false
    }

    $mcpList = & $codexCmd.Source mcp list 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return [bool]($mcpList | Select-String -Pattern ("^{0}\s" -f [regex]::Escape($Name)))
}

function Write-InstallMetadata {
    Ensure-Directory -Path $codexRoot
    $repoCommit = (& git -C $repoRoot rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0) { $repoCommit = '' }
    $repoRef = (& git -C $repoRoot describe --tags --always 2>$null)
    if ($LASTEXITCODE -ne 0) { $repoRef = $repoCommit }
    $installedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    @(
        'MY_CODEX_REPO_URL=https://github.com/sehoon787/my-codex.git'
        "MY_CODEX_INSTALL_COMMIT=$repoCommit"
        "MY_CODEX_INSTALL_REF=$repoRef"
        "MY_CODEX_INSTALL_AT=$installedAt"
    ) | Set-Content -Path $metadataFile
}

Write-Host "=== my-codex installer ==="
Write-Host ""

Write-Host "[0/7] Checking prerequisites..."
Require-Command -Name node
Require-Command -Name npm
Require-Command -Name git

$codexCmd = Get-Command codex -ErrorAction SilentlyContinue
if (-not $codexCmd) {
    Write-Host "WARNING: codex CLI not found. Install from https://github.com/openai/codex"
    Write-Host "  Continuing anyway - agents will be ready when codex is installed."
}
Write-Host "  Prerequisites OK"

Write-Host "[0.5/7] Cleaning previous agent installation..."
Ensure-Directory -Path $agentsDir
Ensure-Directory -Path $agentPacksDir
Ensure-Directory -Path $skillsDir
Get-ChildItem -Path $agentsDir -Filter '*.toml' -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
if (Test-Path $agentPacksDir) {
    Remove-Item -Path $agentPacksDir -Recurse -Force -ErrorAction SilentlyContinue
}
Ensure-Directory -Path $agentPacksDir

$sourceSkillsRoot = Join-Path $repoRoot 'skills/ecc'
if ((Test-Path $sourceSkillsRoot) -and (Test-Path $skillsDir)) {
    Get-ChildItem -Path $sourceSkillsRoot -Directory | ForEach-Object {
        $installedSkillDir = Join-Path $skillsDir $_.Name
        if (Test-Path $installedSkillDir) {
            Remove-Item -Path $installedSkillDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
Write-Host "  Previous agents cleaned"

Write-Host "[1/7] Installing Codex agents..."
Copy-TomlFiles -SourceDir (Join-Path $repoRoot 'codex-agents/core') -DestinationDir $agentsDir
Copy-TomlFiles -SourceDir (Join-Path $repoRoot 'codex-agents/omo') -DestinationDir $agentsDir
Copy-TomlFiles -SourceDir (Join-Path $repoRoot 'codex-agents/omc') -DestinationDir $agentsDir
Copy-TomlFiles -SourceDir (Join-Path $repoRoot 'codex-agents/awesome-core') -DestinationDir $agentsDir
Write-Host ("  Core agents: {0} installed" -f (Get-FileCount -Path $agentsDir -Filter '*.toml'))

$agencyRoot = Join-Path $repoRoot 'codex-agents/agency'
if (Test-Path $agencyRoot) {
    Get-ChildItem -Path $agencyRoot -Directory | ForEach-Object {
        Copy-TomlFiles -SourceDir $_.FullName -DestinationDir (Join-Path $agentPacksDir $_.Name)
    }
    Write-Host "  Agency agents installed to agent-packs"
}

$packRoot = Join-Path $repoRoot 'codex-agents/agent-packs'
if (Test-Path $packRoot) {
    Get-ChildItem -Path $packRoot -Directory | ForEach-Object {
        Copy-TomlFiles -SourceDir $_.FullName -DestinationDir (Join-Path $agentPacksDir $_.Name)
    }
}
Write-Host ("  Agent packs: {0} installed" -f (Get-FileCount -Path $agentPacksDir -Filter '*.toml'))

$awesomeRoot = Join-Path $repoRoot 'codex-agents/awesome'
if (Test-Path $awesomeRoot) {
    Get-ChildItem -Path $awesomeRoot -Directory | ForEach-Object {
        if ($coreAwesomeCategories -contains $_.Name) {
            Copy-TomlFiles -SourceDir $_.FullName -DestinationDir $agentsDir
        }
        else {
            Copy-TomlFiles -SourceDir $_.FullName -DestinationDir (Join-Path $agentPacksDir $_.Name)
        }
    }
    Write-Host "  Awesome agents installed"
}

Write-Host "[2/7] Installing skills..."
Ensure-Directory -Path $skillsDir
Copy-DirectoryContents -SourceDir (Join-Path $repoRoot 'skills/ecc') -DestinationDir $skillsDir
Write-Host ("  Skills: {0} installed" -f (Get-FileCount -Path $skillsDir -Filter 'SKILL.md'))

Write-Host "[3/7] Setting up AGENTS.md..."
Ensure-Directory -Path $codexRoot
$agentsMd = Join-Path $codexRoot 'AGENTS.md'
if (-not (Test-Path $agentsMd)) {
    Copy-Item -Path (Join-Path $repoRoot 'templates/codex-AGENTS.md') -Destination $agentsMd -Force
    Write-Host "  AGENTS.md created"
}
else {
    Write-Host "  AGENTS.md already exists - skipping (delete to regenerate)"
}

Write-Host "[4/7] Configuring config.toml..."
Ensure-Directory -Path $codexRoot
if (-not (Test-Path $configFile)) {
    New-Item -ItemType File -Path $configFile -Force | Out-Null
}
if (-not (Select-String -Path $configFile -Pattern 'multi_agent' -Quiet)) {
    Add-Content -Path $configFile -Value $managedConfig
    Write-Host "  config.toml updated (multi_agent enabled, max_threads=8)"
}
else {
    Write-Host "  config.toml already configured"
}

Write-Host "[4.5/7] Installing Codex attribution defaults..."
$codexBinDir = Join-Path $codexRoot 'bin'
$codexLibDir = Join-Path $codexRoot 'lib'
$gitHooksDir = Join-Path $codexRoot 'git-hooks'
Ensure-Directory -Path $codexBinDir
Ensure-Directory -Path $codexLibDir
Ensure-Directory -Path $gitHooksDir
Copy-Item -Path (Join-Path $repoRoot 'scripts/codex-attribution-lib.sh') -Destination (Join-Path $codexLibDir 'codex-attribution.sh') -Force
Copy-Item -Path (Join-Path $repoRoot 'scripts/codex-wrapper.sh') -Destination (Join-Path $codexBinDir 'codex') -Force
Copy-Item -Path (Join-Path $repoRoot 'scripts/codex-mark-used.sh') -Destination (Join-Path $codexBinDir 'codex-mark-used') -Force
Copy-Item -Path (Join-Path $repoRoot 'templates/git-hooks/commit-msg') -Destination (Join-Path $gitHooksDir 'commit-msg') -Force
Copy-Item -Path (Join-Path $repoRoot 'templates/git-hooks/post-commit') -Destination (Join-Path $gitHooksDir 'post-commit') -Force
& git config --global my-codex.codexAttribution true
$currentHooksPath = (& git config --global core.hooksPath 2>$null)
if ($LASTEXITCODE -eq 0 -and $currentHooksPath -and $currentHooksPath -ne $gitHooksDir) {
    & git config --global my-codex.previousHooksPath $currentHooksPath
}
& git config --global core.hooksPath $gitHooksDir
Write-Host "  Codex wrapper and git hooks installed"

Write-Host "[5/7] Registering MCP servers..."
if ($codexCmd) {
    if (-not (Test-McpServer -Name 'context7')) {
        & $codexCmd.Source mcp add context7 --url https://mcp.context7.com/mcp 2>$null
    }
    if (-not (Test-McpServer -Name 'exa')) {
        & $codexCmd.Source mcp add exa --url "https://mcp.exa.ai/mcp?tools=web_search_exa" 2>$null
    }
    if (-not (Test-McpServer -Name 'grep_app')) {
        & $codexCmd.Source mcp add grep_app --url https://mcp.grep.app 2>$null
    }
    Write-Host "  MCP registration attempted for context7, exa, grep_app"
}
else {
    Write-Host "  codex not found - MCP servers will be registered when codex is installed"
}

Write-Host "[6/7] Installing companion tools..."
Write-Host "  [6a] ast-grep..."
if (Get-Command ast-grep -ErrorAction SilentlyContinue) {
    Write-Host "    ast-grep already installed"
}
else {
    npm i -g @ast-grep/cli@0.42.0 | Out-Null
    Write-Host "    ast-grep installed"
}

Write-InstallMetadata

Write-Host ""
Write-Host "[7/7] Verification"
Write-Host ("  Core agents:   {0} files" -f (Get-FileCount -Path $agentsDir -Filter '*.toml'))
Write-Host ("  Agent packs:   {0} files" -f (Get-FileCount -Path $agentPacksDir -Filter '*.toml'))
Write-Host ("  Skills:        {0} installed" -f (Get-FileCount -Path $skillsDir -Filter 'SKILL.md'))
Write-Host ("  AGENTS.md:     {0}" -f $(if (Test-Path $agentsMd) { 'OK' } else { 'MISSING' }))
Write-Host ("  config.toml:   {0}" -f $(if (Select-String -Path $configFile -Pattern 'multi_agent' -Quiet) { 'OK' } else { 'NEEDS CONFIG' }))
Write-Host ("  hooksPath:     {0}" -f ((& git config --global --get core.hooksPath 2>$null) | ForEach-Object { $_ }))
Write-Host ("  Codex attr:    {0}" -f ((& git config --global --get my-codex.codexAttribution 2>$null) | ForEach-Object { $_ }))
if ($codexCmd) {
    $codexVersion = & $codexCmd.Source --version 2>$null
    if ($LASTEXITCODE -eq 0 -and $codexVersion) {
        Write-Host ("  codex:         OK ({0})" -f $codexVersion)
    }
    else {
        Write-Host "  codex:         OK"
    }
}
else {
    Write-Host "  codex:         NOT INSTALLED"
}
$installRef = ''
if (Test-Path $metadataFile) {
    $installRef = (Get-Content $metadataFile | Where-Object { $_ -like 'MY_CODEX_INSTALL_REF=*' } | Select-Object -First 1)
    $installRef = $installRef -replace '^MY_CODEX_INSTALL_REF=', ''
}
Write-Host ("  install ref:   {0}" -f $(if ($installRef) { $installRef } else { 'UNKNOWN' }))

Write-Host ""
Write-Host "=== Install complete ==="
Write-Host ""
Write-Host "Rerun the bootstrap command to update to the latest my-codex main build."
Write-Host "Activate domain agent packs with symlinks:"
$symlinkPath = Join-Path $homeRoot '.codex\agents\<agent-name>.toml'
$targetPath = Join-Path $homeRoot '.codex\agent-packs\<category>\<agent-name>.toml'
Write-Host ("  New-Item -ItemType SymbolicLink -Path '{0}' -Target '{1}'" -f $symlinkPath, $targetPath)
