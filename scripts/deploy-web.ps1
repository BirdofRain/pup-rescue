# Export Godot web build and deploy to Vercel (requires: vercel login once)
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path $PSScriptRoot -Parent
Set-Location $ProjectRoot

$Godot = $env:GODOT_PATH
if (-not $Godot) {
    $candidates = @(
        "$env:TEMP\godot-463\Godot_v4.6.3-stable_win64_console.exe",
        "C:\Program Files\Godot\Godot_v4.6.3-stable_win64_console.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $Godot = $c; break }
    }
}
if (-not $Godot) {
    Write-Error "Set GODOT_PATH to Godot_*_console.exe or install Godot 4.6.3"
}

New-Item -ItemType Directory -Force -Path "build\web" | Out-Null
& $Godot --headless --path $ProjectRoot --export-release "Web" "build/web/index.html"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Set-Location "build\web"
npx vercel deploy --prod
