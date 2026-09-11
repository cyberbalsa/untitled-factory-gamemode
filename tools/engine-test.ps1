param(
    [string]$GarrysModPath = 'C:\Program Files (x86)\Steam\steamapps\common\GarrysMod',
    [string]$WireSource = ''
)
$ErrorActionPreference = 'Stop'
if (Get-Process -Name gmod,hl2 -ErrorAction SilentlyContinue) {
    throw 'Close Garry''s Mod before running the disposable engine test.'
}
$taskRepo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskGame = Join-Path $GarrysModPath 'garrysmod'
$taskAddons = Join-Path $taskGame 'addons'
$taskResult = Join-Path $taskGame 'data\gmod_factory\smoke_result.json'
$taskBoot = Join-Path $taskRepo '.cache\engine-test-addon'
$taskLink = Join-Path $taskAddons 'ufg_engine_test'
$taskWireLink = Join-Path $taskAddons 'ufg_wire_test'
$taskCreated = @()
$taskProcess = $null
$taskStarted = Get-Date

function New-TestLink([string]$linkPath, [string]$targetPath) {
    if (Test-Path -LiteralPath $linkPath) { throw "Existing path blocks test setup: $linkPath" }
    $taskResolvedTarget = (Resolve-Path -LiteralPath $targetPath).Path
    New-Item -ItemType Junction -Path $linkPath -Target $taskResolvedTarget | Out-Null
    return [pscustomobject]@{Path=$linkPath; Target=$taskResolvedTarget}
}

try {
    & (Join-Path $PSScriptRoot 'install-local.ps1') -GarrysModPath $GarrysModPath
    $taskAutorun = Join-Path $taskBoot 'lua\autorun\server'
    New-Item -ItemType Directory -Path $taskAutorun -Force | Out-Null
    @'
hook.Add("InitPostEntity", "ufg_smoke_boot", function()
    timer.Simple(3, function() include("ufg/tests/smoke.lua") end)
end)
'@ | Set-Content -LiteralPath (Join-Path $taskAutorun 'ufg_test_boot.lua') -Encoding ascii
    $taskCreated += New-TestLink $taskLink $taskBoot
    if ($WireSource) { $taskCreated += New-TestLink $taskWireLink $WireSource }
    $taskProcess = Start-Process -FilePath (Join-Path $GarrysModPath 'gmod.exe') -WorkingDirectory $GarrysModPath `
        -ArgumentList @('-windowed','-w','1280','-h','720','-novid','-nosound','-condebug','-console',
            '+sv_lan','1','+maxplayers','1','+gamemode','gmod_factory','+map','gm_construct') `
        -WindowStyle Hidden -PassThru
    Write-Output "Started disposable GMod test (PID $($taskProcess.Id))."
    $taskDeadline = (Get-Date).AddSeconds(110)
    while ((Get-Date) -lt $taskDeadline) {
        if ((Test-Path -LiteralPath $taskResult) -and (Get-Item -LiteralPath $taskResult).LastWriteTime -gt $taskStarted) {
            Get-Content -LiteralPath $taskResult
            $taskReport = Get-Content -LiteralPath $taskResult -Raw | ConvertFrom-Json
            if (-not $taskReport.ok) { throw 'GMod integration test failed; see the report above.' }
            exit 0
        }
        if ($taskProcess.HasExited) { throw 'GMod exited without a new test report.' }
        Start-Sleep -Seconds 1
    }
    throw 'GMod integration test timed out. Inspect garrysmod/console.log.'
}
finally {
    if ($taskProcess -and -not $taskProcess.HasExited) { Stop-Process -Id $taskProcess.Id }
    foreach ($taskEntry in $taskCreated) {
        $taskCurrent = Get-Item -LiteralPath $taskEntry.Path -Force
        # Remove only our exact junction, never recurse into its target.
        if ($taskCurrent.LinkType -eq 'Junction' -and $taskCurrent.Target -eq $taskEntry.Target) {
            Remove-Item -LiteralPath $taskEntry.Path -Force
        } else {
            Write-Warning "Test link changed; left it in place: $($taskEntry.Path)"
        }
    }
}
