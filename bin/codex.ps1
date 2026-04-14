#!/usr/bin/env pwsh
# my-codex Windows PowerShell wrapper - runs SessionStart hook then delegates to real codex.ps1.
# Required because Windows shells don't execute the extensionless bash wrapper at ~/.codex/bin/codex.

# Run SessionStart hook via bash if available (Git Bash / WSL / MSYS).
# Failures are swallowed; hook output is discarded.
$bash = Get-Command bash -ErrorAction SilentlyContinue
$hookPath = Join-Path $env:USERPROFILE ".codex\hooks\session-start.sh"
if ($bash) {
    if (Test-Path $hookPath) {
        & bash $hookPath *> $null
    }
}

# Diagnostic log
try {
    $logPath = Join-Path $env:USERPROFILE ".codex\last-invocation.log"
    $ts = Get-Date -UFormat '%Y-%m-%dT%H:%M:%SZ'
    $cwd = (Get-Location).Path
    $hookInstalled = if (Test-Path $hookPath) { 'yes' } else { 'no' }
    "$ts`twrapper=codex.ps1`tcwd=$cwd`thook_installed=$hookInstalled" | Out-File -FilePath $logPath -Append -Encoding utf8
} catch {}

# Find the real codex.ps1 - skip our own wrapper directory to avoid recursion.
$selfDir = $PSScriptRoot
$realPs1 = $null
$candidates = Get-Command codex.ps1 -All -ErrorAction SilentlyContinue
foreach ($c in $candidates) {
    $dir = Split-Path -Parent $c.Source
    if ($dir -and ($dir -ne $selfDir)) {
        $realPs1 = $c.Source
        break
    }
}

if (-not $realPs1) {
    Write-Error "my-codex: real codex.ps1 not found in PATH."
    exit 127
}

& $realPs1 @args
$codexExit = $LASTEXITCODE

try {
    $sessionEndPath = Join-Path $env:USERPROFILE ".codex\hooks\session-end.js"
    if (Test-Path $sessionEndPath) {
        $payload = '{"agent_id":"codex-wrapper-stop","agent_type":"wrapper"}'
        $env:MY_CODEX_SESSION_END_AGENT_ID = "codex-wrapper-stop"
        $env:MY_CODEX_SESSION_END_AGENT_TYPE = "wrapper"
        $payload | node $sessionEndPath *> $null
        Remove-Item Env:MY_CODEX_SESSION_END_AGENT_ID -ErrorAction SilentlyContinue
        Remove-Item Env:MY_CODEX_SESSION_END_AGENT_TYPE -ErrorAction SilentlyContinue
    }
} catch {}

exit $codexExit
