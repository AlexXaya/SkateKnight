$ErrorActionPreference = "Stop"

# Try common locations and PATH for a local Godot install.
$Candidates = @(
  $env:GODOT_EXE,
  "C:\Users\mhink\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.2-stable_win64.exe",
  "C:\Users\mhink\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.2-stable_win64_console.exe",
  "C:\Users\mhink\OneDrive\Desktop\Godot_v4.5.1-stable_win64.exe",
  "C:\Users\mhink\OneDrive\Desktop\Godot_v4.5.1-stable_win64_console.exe",
  "C:\Users\mhink\Downloads\Godot_v4.6.2-stable_win64.exe",
  "C:\Users\mhink\Downloads\Godot_v4.6.2-stable_win64_console.exe",
  "C:\Users\mhink\Downloads\Godot_v4.6.1-stable_win64.exe",
  "C:\Users\mhink\Downloads\Godot_v4.6.1-stable_win64_console.exe",
  "C:\Users\mhink\Downloads\Godot_v4.5.1-stable_win64.exe",
  "C:\Users\mhink\Downloads\Godot_v4.5.1-stable_win64_console.exe"
) | Where-Object { $_ -and $_.Trim().Length -gt 0 }

$GodotCmd = Get-Command godot -ErrorAction SilentlyContinue
if ($GodotCmd) {
  $Candidates = @($GodotCmd.Source) + $Candidates
}

$GodotExe = $null
foreach ($Candidate in $Candidates) {
  if (Test-Path -LiteralPath $Candidate -PathType Leaf) {
    $GodotExe = $Candidate
    break
  }
}

if (-not $GodotExe) {
  throw "Godot executable not found. Set GODOT_EXE or install Godot in Downloads."
}

$ProjectPath = Split-Path -Parent $PSScriptRoot

Write-Host "Launching Godot:"
Write-Host "  exe:     $GodotExe"
Write-Host "  project: $ProjectPath"

& $GodotExe --path $ProjectPath

