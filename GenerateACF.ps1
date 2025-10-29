<#
.SYNOPSIS
    Generates ACF files for specified Steam App IDs using SKSAppManifestGenerator.

.DESCRIPTION
    This script prompts the user to enter one or more Steam App IDs, verifies or downloads SKSAppManifestGenerator v2.0.3 if not present, and generates the corresponding ACF files. It supports optional parameters for specifying the generator's path, enabling debug mode, and setting a custom working directory.

    The script will automatically download the generator from the official source if missing, with a fallback to a secondary source.

.PARAMETER GeneratorPath
    Optional. Specifies the path to SKSAppManifestGenerator_x64.exe. 
    Default: tools\SKSAppManifestGenerator\SKSAppManifestGenerator_x64.exe (relative to script directory)
    If not provided and the file doesn't exist, the script will prompt to download it.

.PARAMETER Debug
    Optional. Switch parameter to enable debug output during the generation process.
    Passes the -d flag to SKSAppManifestGenerator.

.PARAMETER WorkingDirectory
    Optional. Specifies the directory where the ACF files will be generated. 
    Defaults to the current directory if not specified.

.EXAMPLE
    .\GenerateACF.ps1
    Prompts for App IDs and generates ACF files in the current directory.

.EXAMPLE
    .\GenerateACF.ps1 -Debug
    Enables debug output and prompts for App IDs.

.EXAMPLE
    .\GenerateACF.ps1 -GeneratorPath "C:\Tools\SKSAppManifestGenerator\SKSAppManifestGenerator_x64.exe" -WorkingDirectory "C:\Steam\ACF"
    Uses the specified generator path and outputs ACF files to the specified directory.

.NOTES
    Steam App IDs can be entered as space or comma separated values (e.g., "570 730" or "570,730,440")
    View detailed help: Get-Help .\GenerateACF.ps1 -Detailed
#>

# Requires PowerShell 5.1+
$ErrorActionPreference = 'Stop'

param(
    [string]$GeneratorPath,
    [switch]$Debug,
    [string]$WorkingDirectory
)

# Set default values if not provided
if (-not $GeneratorPath) {
    $GeneratorPath = Join-Path -Path $PSScriptRoot -ChildPath 'tools\SKSAppManifestGenerator\SKSAppManifestGenerator_x64.exe'
}
if (-not $WorkingDirectory) {
    $WorkingDirectory = (Get-Location).Path
}

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Show-Welcome {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Steam ACF File Generator" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script generates ACF files for Steam App IDs using SKSAppManifestGenerator." -ForegroundColor White
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  You will be prompted to enter one or more Steam App IDs" -ForegroundColor Gray
    Write-Host "  (e.g., '570 730' or '570,730,440')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -GeneratorPath     Path to SKSAppManifestGenerator_x64.exe" -ForegroundColor Gray
    Write-Host "  -Debug             Enable debug output" -ForegroundColor Gray
    Write-Host "  -WorkingDirectory  Where to save ACF files" -ForegroundColor Gray
    Write-Host ""
    Write-Host "For detailed help: Get-Help .\GenerateACF.ps1 -Detailed" -ForegroundColor DarkGray
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# Check if parameters were passed via command line
$hasCommandLineParams = $PSBoundParameters.Count -gt 0 -or $args.Count -gt 0

# Display welcome message
Show-Welcome

# Interactive parameter selection (only if no command line parameters)
function Get-UserParameters {
    Write-Host "Configuration Options:" -ForegroundColor Yellow
    Write-Host "1. Use default settings (recommended for first-time users)" -ForegroundColor Green
    Write-Host "2. Configure custom parameters" -ForegroundColor Green
    Write-Host ""
    
    do {
        $choice = Read-Host "Select option (1 or 2)"
    } while ($choice -notin @('1', '2'))
    
    if ($choice -eq '1') {
        Write-Info "Using default settings..."
        return @{
            GeneratorPath = $GeneratorPath
            Debug = $Debug
            WorkingDirectory = $WorkingDirectory
        }
    }
    
    # Custom configuration
    Write-Host ""
    Write-Host "Custom Configuration:" -ForegroundColor Yellow
    
    # Generator path
    Write-Host ""
    Write-Host "Generator Path:" -ForegroundColor Cyan
    Write-Host "Current: $GeneratorPath" -ForegroundColor Gray
    $customPath = Read-Host "Enter custom path or press Enter to keep current"
    if (-not [string]::IsNullOrWhiteSpace($customPath)) {
        $GeneratorPath = $customPath
    }
    
    # Debug mode
    Write-Host ""
    Write-Host "Debug Mode:" -ForegroundColor Cyan
    Write-Host "Current: $($Debug.IsPresent)" -ForegroundColor Gray
    do {
        $debugChoice = Read-Host "Enable debug output? (Y/N)"
    } while ($debugChoice -notin @('Y', 'y', 'N', 'n', ''))
    $Debug = if ($debugChoice -in @('Y', 'y')) { [switch]$true } else { [switch]$false }
    
    # Working directory
    Write-Host ""
    Write-Host "Working Directory:" -ForegroundColor Cyan
    Write-Host "Current: $WorkingDirectory" -ForegroundColor Gray
    $customDir = Read-Host "Enter custom directory or press Enter to keep current"
    if (-not [string]::IsNullOrWhiteSpace($customDir)) {
        $WorkingDirectory = $customDir
    }
    
    Write-Host ""
    Write-Host "Configuration Summary:" -ForegroundColor Green
    Write-Host "  Generator Path: $GeneratorPath" -ForegroundColor Gray
    Write-Host "  Debug Mode: $($Debug.IsPresent)" -ForegroundColor Gray
    Write-Host "  Working Directory: $WorkingDirectory" -ForegroundColor Gray
    Write-Host ""
    
    return @{
        GeneratorPath = $GeneratorPath
        Debug = $Debug
        WorkingDirectory = $WorkingDirectory
    }
}

# Get user parameters (only if no command line parameters provided)
if ($hasCommandLineParams) {
    Write-Info "Using command line parameters..."
    Write-Info "Generator Path: $GeneratorPath"
    Write-Info "Debug Mode: $($Debug.IsPresent)"
    Write-Info "Working Directory: $WorkingDirectory"
    Write-Host ""
} else {
    $userParams = Get-UserParameters
    $GeneratorPath = $userParams.GeneratorPath
    $Debug = $userParams.Debug
    $WorkingDirectory = $userParams.WorkingDirectory
}

# Ensure working directory exists
if (-not (Test-Path -LiteralPath $WorkingDirectory)) {
    Write-Err "WorkingDirectory not found: $WorkingDirectory"
    exit 1
}

# Ensure generator exists or offer to download
if (-not (Test-Path -LiteralPath $GeneratorPath)) {
    Write-Warn "SKSAppManifestGenerator not found at: $GeneratorPath"
    $answer = Read-Host "Download SKSAppManifestGenerator v2.0.3 now? (Y/n)"
    if ([string]::IsNullOrWhiteSpace($answer) -or $answer.Trim().ToLower() -eq 'y') {
        $primaryUrl = 'https://github.com/Sak32009/SKSAppManifestGenerator/releases/download/v2.0.3/SKSAppManifestGenerator_x64_v2.0.3.zip'
        $secondaryUrl = 'https://github.com/ahmed98Osama/Steam-acf-generator/raw/master/SKSAppManifestGenerator_x64.exe'
        $toolsDir = Split-Path -Parent $GeneratorPath
        $zipPath = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ("SKSAppManifestGenerator_x64_v2.0.3_" + [Guid]::NewGuid() + ".zip")
        $extractDir = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ("SKSAppManifestGenerator_" + [Guid]::NewGuid())
        $downloadSuccess = $false
        
        # Try primary source (ZIP download)
        try {
            Write-Info "Attempting primary download: $primaryUrl"
            New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
            Invoke-WebRequest -Uri $primaryUrl -OutFile $zipPath
            Write-Info "Extracting to: $extractDir"
            Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
            # Find the x64 exe inside the extracted content
            $exe = Get-ChildItem -LiteralPath $extractDir -Recurse -Filter 'SKSAppManifestGenerator_x64.exe' | Select-Object -First 1
            if ($exe) {
                Copy-Item -LiteralPath $exe.FullName -Destination $GeneratorPath -Force
                $downloadSuccess = $true
                Write-Info "Successfully downloaded from primary source"
            }
            else {
                Write-Warn "Failed to locate SKSAppManifestGenerator_x64.exe in the archive"
            }
        }
        catch {
            Write-Warn "Primary download failed: $($_.Exception.Message)"
        }
        finally {
            # Cleanup temp files
            Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Try secondary source if primary failed
        if (-not $downloadSuccess) {
            try {
                Write-Info "Attempting secondary download: $secondaryUrl"
                New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
                Invoke-WebRequest -Uri $secondaryUrl -OutFile $GeneratorPath
                $downloadSuccess = $true
                Write-Info "Successfully downloaded from secondary source"
            }
            catch {
                Write-Err "Secondary download also failed: $($_.Exception.Message)"
            }
        }
        
        if (-not $downloadSuccess) {
            Write-Err "Failed to download SKSAppManifestGenerator from both sources"
            # Allow manual input of the path
            $custom = Read-Host 'Enter full path to SKSAppManifestGenerator_x64.exe'
            if ([string]::IsNullOrWhiteSpace($custom) -or -not (Test-Path -LiteralPath $custom)) {
                Write-Err 'Valid generator path was not provided.'
                exit 1
            }
            $GeneratorPath = $custom
        }
        else {
            Write-Info "Installed SKSAppManifestGenerator to: $GeneratorPath"
        }
    }
    else {
        # Allow manual input of the path
        $custom = Read-Host 'Enter full path to SKSAppManifestGenerator_x64.exe'
        if ([string]::IsNullOrWhiteSpace($custom) -or -not (Test-Path -LiteralPath $custom)) {
            Write-Err 'Valid generator path was not provided.'
            exit 1
        }
        $GeneratorPath = $custom
    }
}

# Final existence check
if (-not (Test-Path -LiteralPath $GeneratorPath)) {
    Write-Err "Generator still not found at: $GeneratorPath"
    exit 1
}

Write-Info "Using generator: $GeneratorPath"
Write-Info "Working directory: $WorkingDirectory"

# Prompt for App IDs
$appIdsInput = Read-Host 'Enter one or more App IDs (space or comma separated)'
if ([string]::IsNullOrWhiteSpace($appIdsInput)) {
    Write-Err 'No App IDs provided.'
    exit 1
}

# Normalize into array and keep only numeric IDs
$appIds = @()
foreach ($token in ($appIdsInput -split '[\s,]+')) {
    $t = $token.Trim()
    if ($t -match '^[0-9]+$') { $appIds += $t } else { if ($t) { Write-Warn "Skipping invalid App ID token: '$t'" } }
}

if ($appIds.Count -eq 0) {
    Write-Err 'No valid numeric App IDs were provided.'
    exit 1
}

# Build arguments
$argsList = @()
if ($Debug.IsPresent) { $argsList += '-d' }
$argsList += $appIds

# Execute generator in the chosen working directory
Push-Location $WorkingDirectory
try {
    Write-Info ("Running generator with App IDs: " + ($appIds -join ', '))
    & $GeneratorPath @argsList
    $exitCode = $LASTEXITCODE
    if ($null -ne $exitCode -and $exitCode -ne 0) {
        Write-Warn "Generator exited with code $exitCode"
    }
}
catch {
    Write-Err ("Generator failed: " + $_.Exception.Message)
    exit 1
}
finally {
    Pop-Location
}

# Attempt to verify output files (common patterns)
$created = @()
foreach ($id in $appIds) {
    $candidates = @(
        (Join-Path -Path $WorkingDirectory -ChildPath ("appmanifest_" + $id + ".acf")),
        (Join-Path -Path $WorkingDirectory -ChildPath ($id + ".acf"))
    )
    $found = $false
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { $created += $c; $found = $true; break }
    }
    if (-not $found) { Write-Warn "Could not confirm ACF for App ID $id. Check generator output." }
}

if ($created.Count -gt 0) {
    Write-Info "Generated files:"
    $created | ForEach-Object { Write-Host " - $_" -ForegroundColor Green }
}
else {
    Write-Warn 'No ACF files were detected. If you enabled debug, review the output.'
}
