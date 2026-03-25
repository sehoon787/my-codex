Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $repoRoot 'scripts/install.ps1'
& $script @args
exit $LASTEXITCODE
