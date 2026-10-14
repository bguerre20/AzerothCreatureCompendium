# deploy.ps1 - Copies development files to your World of Warcraft AddOns folder
param(
    [string]$TargetDir = "c:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\AzerothCreatureCompendium"
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Azeroth Creature Compendium -> WoW Deploy" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (-not (Test-Path $TargetDir)) {
    Write-Host "Creating target folder: $TargetDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

$CurrentDir = $PSScriptRoot
if (-not $CurrentDir) { $CurrentDir = Get-Location }

# 1. Pre-Deploy Static Analysis Gate (LuaCheck)
$LintScript = Join-Path $CurrentDir "lint.ps1"
if (Test-Path $LintScript) {
    Write-Host "`n[Step 1/2] Running pre-deploy LuaCheck gate..." -ForegroundColor Cyan
    & $LintScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[ABORTED] LuaCheck failed! Fix lint errors before deploying to World of Warcraft." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Write-Host "`n[Step 2/2] Copying addon files to World of Warcraft..." -ForegroundColor Cyan

# List of items/patterns to exclude from the in-game folder
$Excludes = @(
    ".git*",
    "deploy.ps1",
    "deploy.bat",
    "lint.ps1",
    "lint-report.txt",
    ".tools*",
    ".luacheck*",
    ".vscode*",
    ".gemini*",
    ".agents*",
    "AGENTS.md",
    "DEPLOYMENT_PIPELINE.md",
    ".pkgmeta",
    "docs*",
    "Art*"
)

Write-Host "Source: $CurrentDir" -ForegroundColor Gray
Write-Host "Target: $TargetDir" -ForegroundColor Gray

# Copy all files/folders except excluded patterns
Get-ChildItem -Path $CurrentDir -Force | Where-Object {
    $item = $_
    $skip = $false
    foreach ($pattern in $Excludes) {
        if ($item.Name -like $pattern) {
            $skip = $true
            break
        }
    }
    -not $skip
} | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $TargetDir -Recurse -Force
    Write-Host " [OK] Copied $($_.Name)" -ForegroundColor Green
}

Write-Host "`n Deployment complete!" -ForegroundColor Cyan
Write-Host " In-game: Type /reload to apply changes." -ForegroundColor Yellow
