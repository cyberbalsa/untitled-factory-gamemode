param(
    [string]$GarrysModPath = 'C:\Program Files (x86)\Steam\steamapps\common\GarrysMod'
)
$ErrorActionPreference = 'Stop'
$taskSource = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$taskAddons = Join-Path $GarrysModPath 'garrysmod\addons'
if (-not (Test-Path -LiteralPath $taskAddons -PathType Container)) {
    throw "Garry's Mod addons directory not found: $taskAddons"
}
$taskLink = Join-Path $taskAddons 'untitled_factory_gamemode'
if (Test-Path -LiteralPath $taskLink) {
    $taskExisting = Get-Item -LiteralPath $taskLink -Force
    if ($taskExisting.LinkType -eq 'Junction' -and $taskExisting.Target -eq $taskSource) {
        Write-Output "Already linked: $taskLink"
        exit 0
    }
    throw "A different file or directory already exists at $taskLink. Nothing was replaced."
}
New-Item -ItemType Junction -Path $taskLink -Target $taskSource | Out-Null
Write-Output "Installed development link: $taskLink -> $taskSource"
Write-Output 'Enable Wiremod and select Untitled Factory Gamemode in the main menu.'
