$ErrorActionPreference = "Stop"

# Godot install folder (as requested)
$GodotDir = "C:\Users\matth\Downloads\Godot_v4.6.2-stable_win64.exe"

# Prefer GUI binary; fall back to console binary if needed.
$GodotExe = Join-Path $GodotDir "Godot_v4.6.2-stable_win64.exe"
if (-not (Test-Path $GodotExe)) {
  $GodotExe = Join-Path $GodotDir "Godot_v4.6.2-stable_win64_console.exe"
}

if (-not (Test-Path $GodotExe)) {
  throw "Godot executable not found in: $GodotDir"
}

$ProjectPath = Split-Path -Parent $PSScriptRoot

Write-Host "Launching Godot:"
Write-Host "  exe:     $GodotExe"
Write-Host "  project: $ProjectPath"

& $GodotExe --path $ProjectPath

