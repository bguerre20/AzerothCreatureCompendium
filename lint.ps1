# lint.ps1 - Runs LuaCheck static analysis on Azeroth Creature Compendium
param(
    [switch]$SaveReport,
    [string]$ReportPath = "lint-report.txt"
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Azeroth Creature Compendium -> Lua Lint" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$CurrentDir = $PSScriptRoot
if (-not $CurrentDir) { $CurrentDir = Get-Location }

# 1. Locate or download luacheck binary
$LuacheckCmd = Get-Command luacheck -ErrorAction SilentlyContinue
$LuacheckExe = $null

if ($LuacheckCmd) {
    $LuacheckExe = $LuacheckCmd.Source
    Write-Host "Using system luacheck: $LuacheckExe" -ForegroundColor Gray
} else {
    $ToolsDir = Join-Path $CurrentDir ".tools"
    $LocalExe = Join-Path $ToolsDir "luacheck.exe"
    
    if (-not (Test-Path $LocalExe)) {
        Write-Host "Luacheck not found in PATH. Downloading standalone binary to .tools\..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
        $DownloadUrl = "https://github.com/lunarmodules/luacheck/releases/download/v1.2.0/luacheck.exe"
        try {
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $LocalExe -UseBasicParsing
            Write-Host "Downloaded luacheck.exe successfully." -ForegroundColor Green
        } catch {
            Write-Host "Error downloading luacheck.exe: $_" -ForegroundColor Red
            exit 1
        }
    }
    $LuacheckExe = $LocalExe
    Write-Host "Using local luacheck: $LuacheckExe" -ForegroundColor Gray
}

# 2. Run luacheck with repository .luacheckrc
Write-Host "Running LuaCheck across codebase...`n" -ForegroundColor Cyan

$ConfigPath = Join-Path $CurrentDir ".luacheckrc"
$Arguments = @($CurrentDir)
if (Test-Path $ConfigPath) {
    $Arguments += @("--config", $ConfigPath)
}

if ($SaveReport) {
    $FullReportPath = Join-Path $CurrentDir $ReportPath
    & $LuacheckExe $Arguments | Tee-Object -FilePath $FullReportPath
    Write-Host "`nReport saved to: $FullReportPath" -ForegroundColor Green
} else {
    & $LuacheckExe $Arguments
}

$ExitCode = $LASTEXITCODE
if ($ExitCode -eq 0) {
    Write-Host "`n[PASS] No linting errors or warnings found!" -ForegroundColor Green
} else {
    Write-Host "`n[WARN/FAIL] LuaCheck detected issues (exit code $ExitCode)." -ForegroundColor Yellow
}

exit $ExitCode
