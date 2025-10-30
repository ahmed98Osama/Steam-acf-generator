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
param(
    [string]$GeneratorPath,
    [switch]$Debug,
    [string]$WorkingDirectory,
    [string]$AppId
)

$ErrorActionPreference = 'Stop'

# Ensure modern TLS for GitHub and others, and higher connection limits
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
} catch {}
try { [Net.ServicePointManager]::DefaultConnectionLimit = 64 } catch {}

# Global trap: on any terminating error, pause (if double-click) before exit
trap {
    try { Write-Err ("Fatal error: " + $_.Exception.Message) } catch {}
    Show-PauseIfLaunchedFromExplorer
    exit 1
}

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

# Normalize any locale-specific digits to ASCII 0-9
function Convert-ToAsciiDigits {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $Text }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        $digit = [System.Globalization.CharUnicodeInfo]::GetDigitValue($ch)
        if ($digit -ge 0) {
            $zero = [int][char]'0'
            [void]$sb.Append([char]($zero + [int]$digit))
        }
        else {
            [void]$sb.Append($ch)
        }
    }
    return $sb.ToString()
}

# Extract only ASCII digits from text (drops any non-digit characters)
function Convert-ExtractDigits {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in (Convert-ToAsciiDigits $Text).ToCharArray()) {
        if ($ch -ge '0' -and $ch -le '9') { [void]$sb.Append($ch) }
    }
    return $sb.ToString()
}

# Pause helper to keep window open when launched by Explorer (double-click)
function Show-PauseIfLaunchedFromExplorer {
    try {
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
        if ($proc) {
            $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.ParentProcessId)"
            if ($parent -and ($parent.Name -ieq 'explorer.exe')) {
                Write-Host ""; Read-Host "Press Enter to close this window"
            }
        }
    } catch {}
}

# Attempt to extract ZIP archives using multiple strategies (Expand-Archive, Shell.Application, tar)
function Expand-ZipWithFallback {
    param(
        [Parameter(Mandatory = $true)][string]$ZipPath,
        [Parameter(Mandatory = $true)][string]$Destination,
        [SecureString]$Password
    )

    try {
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    } catch {}

    # 1) If password provided, try 7-Zip first (native APIs don't support passwords)
    if (-not [string]::IsNullOrWhiteSpace($Password)) {
        try {
            $sevenZipCandidates = @('7z.exe', 'C:\\Program Files\\7-Zip\\7z.exe', 'C:\\Program Files (x86)\\7-Zip\\7z.exe')
            $sevenZip = $null
            foreach ($c in $sevenZipCandidates) {
                $p = (Get-Command $c -ErrorAction SilentlyContinue).Path
                if ($p) { $sevenZip = $p; break }
            }
            if ($sevenZip) {
                $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
                try {
                    $plainPwd = [Runtime.InteropServices.Marshal]::PtrToStringUni($bstr)
                } finally {
                    if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
                }
                $sevenZipArgs = @('x', '-y', ("-p" + $plainPwd), ("-o" + $Destination), $ZipPath)
                $proc = Start-Process -FilePath $sevenZip -ArgumentList $sevenZipArgs -NoNewWindow -PassThru -Wait
                if ($proc.ExitCode -eq 0) { return $true } else { Write-Warn ("7-Zip extraction failed with code " + $proc.ExitCode) }
            } else {
                Write-Warn '7-Zip not found; cannot extract password-protected archive with native tools.'
            }
        } catch {
            Write-Warn ("7-Zip extraction error: " + $_.Exception.Message)
        }
    }

    # 2) Try native Expand-Archive
    try {
        Expand-Archive -Path $ZipPath -DestinationPath $Destination -Force
        return $true
    } catch {
        Write-Warn ("Expand-Archive failed: " + $_.Exception.Message)
    }

    # 3) Try Windows Shell COM (supports more compression methods like Deflate64)
    try {
        $shell = New-Object -ComObject Shell.Application
        $zipNs = $shell.NameSpace($ZipPath)
        $dstNs = $shell.NameSpace($Destination)
        if ($null -eq $zipNs -or $null -eq $dstNs) { throw "Shell namespaces not available" }
        # 0x10 (16) = FOF_NOCONFIRMMKDIR, suppress UI
        $dstNs.CopyHere($zipNs.Items(), 16)
        # Wait briefly for async copy to finish (up to ~10s)
        $expected = $zipNs.Items().Count
        for ($i = 0; $i -lt 100; $i++) {
            $current = ($dstNs.Items()).Count
            if ($current -ge $expected -and $expected -gt 0) { break }
            Start-Sleep -Milliseconds 100
        }
        return $true
    } catch {
        Write-Warn ("Shell extraction failed: " + $_.Exception.Message)
    }

    # 4) Try tar (available on recent Windows builds)
    try {
        & tar -xf $ZipPath -C $Destination
        if ($LASTEXITCODE -eq 0) { return $true }
    } catch {
        Write-Warn ("tar extraction failed: " + $_.Exception.Message)
    }

    return $false
}

# High-priority multi-connection downloader to maximize throughput
function Invoke-HighSpeedDownload {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$OutFile,
        [int]$Segments = 8,
        [int]$TimeoutSeconds = 600,
        [switch]$PreferBits
    )

    $oldProgress = $ProgressPreference
    $ProgressPreference = 'Continue'
    try {
        # 1) Prefer curl.exe for maximum reliability (handles redirects, TLS, proxies)
        try {
            $curl = (Get-Command curl.exe -ErrorAction SilentlyContinue).Path
            if ($curl) {
                Write-Info "Using curl download..."
                $tmpOut = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ("dl_" + [Guid]::NewGuid())
                $args = @('-fL','--retry','3','--retry-delay','2','--connect-timeout','20','--max-time',[string]$TimeoutSeconds,'-A','PowerShell-HighSpeedDownloader/1.0','-o', $tmpOut, $Uri)
                $proc = Start-Process -FilePath $curl -ArgumentList $args -NoNewWindow -PassThru -Wait
                if ($proc.ExitCode -eq 0 -and (Test-Path -LiteralPath $tmpOut)) {
                    $fi = Get-Item -LiteralPath $tmpOut -ErrorAction Stop
                    if ($fi.Length -gt 0) { Move-Item -LiteralPath $tmpOut -Destination $OutFile -Force; return }
                    else { Remove-Item -LiteralPath $tmpOut -Force -ErrorAction SilentlyContinue; throw "curl produced empty file" }
                } else { throw "curl exited with code $($proc.ExitCode)" }
            }
        } catch {
            Write-Warn ("curl download failed or not available: " + $_.Exception.Message)
        }

        # 2) Prefer .NET 6+ SocketsHttpHandler when available; otherwise fall back to default HttpClient, and finally WebClient
        $client = $null
        try {
            $handler = [System.Net.Http.SocketsHttpHandler]::new()
            $handler.MaxConnectionsPerServer = 64
            $handler.PooledConnectionLifetime = [TimeSpan]::FromMinutes(5)
            $handler.EnableMultipleHttp2Connections = $true
            $client = [System.Net.Http.HttpClient]::new($handler)
        } catch {
            try {
                $client = [System.Net.Http.HttpClient]::new()
            } catch {
                $client = $null
            }
        }
        if ($client) {
            $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
            $client.DefaultRequestHeaders.UserAgent.ParseAdd('PowerShell-HighSpeedDownloader/1.0')
        }

        # Try HEAD to get content length and range support (HttpClient path)
        $contentLength = $null
        $acceptRanges = $false
        if ($client) {
            try {
                $head = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, $Uri)
                $headResp = $client.Send($head)
                if ($headResp.IsSuccessStatusCode -and $headResp.Content.Headers.ContentLength) {
                    $contentLength = [int64]$headResp.Content.Headers.ContentLength
                }
                if ($headResp.Headers.AcceptRanges -contains 'bytes') { $acceptRanges = $true }
                if (-not $acceptRanges) {
                    $tmp = $null
                    $acceptRanges = $headResp.Content.Headers.TryGetValues('Accept-Ranges', [ref]([string[]]$tmp))
                }
            } catch {}
        }

        # Segmented downloader disabled for stability in Windows PowerShell; use single-stream HTTP
        {
            # Single stream fallback
            if ($client) {
                $resp = $client.GetAsync($Uri, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
                $resp.Wait()
                $msg = $resp.Result
                if (-not $msg.IsSuccessStatusCode) { throw "Download failed with status $($msg.StatusCode)" }
                $inTask = $msg.Content.ReadAsStreamAsync(); $inTask.Wait(); $inStream = $inTask.Result
                $outStream = [System.IO.File]::Open($OutFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                $total = $null
                if ($msg.Content.Headers.ContentLength) { $total = [int64]$msg.Content.Headers.ContentLength }
                [long]$done = 0
                try {
                    $buffer = New-Object byte[] 1048576
                    while (($read = $inStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                        $outStream.Write($buffer, 0, $read)
                        $done += $read
                        if ($total) {
                            $pct = [int]([Math]::Min(100, [Math]::Round(($done * 100.0) / $total)))
                            $mbDone = [Math]::Round($done / 1MB, 1)
                            $mbTotal = [Math]::Round($total / 1MB, 1)
                            Write-Progress -Activity "Downloading" -Status ("{0}% ({1}/{2} MB)" -f $pct, $mbDone, $mbTotal) -PercentComplete $pct
                        } else {
                            Write-Progress -Activity "Downloading" -Status ("{0} MB" -f ([Math]::Round($done / 1MB,1))) -PercentComplete 0
                        }
                    }
                } finally {
                    $outStream.Dispose()
                    $inStream.Dispose()
                    Write-Progress -Activity "Downloading" -Completed
                }
            }
            else {
                # Final fallback: WebClient, then BITS if needed
                $webDownloaded = $false
                try {
                    $wc = New-Object System.Net.WebClient
                    try {
                        $wc.Headers.Add('User-Agent', 'PowerShell-HighSpeedDownloader/1.0')
                        $wc.Proxy = [System.Net.WebRequest]::DefaultWebProxy
                        $progHandler = [System.Net.DownloadProgressChangedEventHandler]{
                            param($s, [System.Net.DownloadProgressChangedEventArgs]$e)
                            $script:__dlBytes = $e.BytesReceived
                            $script:__dlTotal = $e.TotalBytesToReceive
                            $script:__dlPercent = $e.ProgressPercentage
                        }
                        $compHandler = [System.ComponentModel.AsyncCompletedEventHandler]{
                            param($s, [System.ComponentModel.AsyncCompletedEventArgs]$e)
                            Write-Progress -Activity "Downloading" -Completed
                            if ($e.Error) { $script:__dlError = $e.Error }
                            $script:__dlCompleted = $true
                        }
                        $wc.add_DownloadProgressChanged($progHandler)
                        $wc.add_DownloadFileCompleted($compHandler)
                        $script:__dlCompleted = $false
                        $script:__dlError = $null
                        $script:__dlBytes = 0
                        $script:__dlTotal = 0
                        $script:__dlPercent = 0
                        # Download to temp and then move into place
                        $tmpOut = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ("dl_" + [Guid]::NewGuid())
                        $wc.DownloadFileAsync([uri]$Uri, $tmpOut)
                        $lastBytes = 0
                        $stallMs = 0
                        while (-not $script:__dlCompleted) {
                            if ($script:__dlTotal -gt 0) {
                                $pct = [int]$script:__dlPercent
                                $mbDone = [Math]::Round($script:__dlBytes / 1MB, 1)
                                $mbTotal = [Math]::Round($script:__dlTotal / 1MB, 1)
                                Write-Progress -Activity "Downloading" -Status ("{0}% ({1}/{2} MB)" -f $pct, $mbDone, $mbTotal) -PercentComplete $pct
                            } else {
                                Write-Progress -Activity "Downloading" -Status ("{0} MB" -f ([Math]::Round($script:__dlBytes / 1MB,1))) -PercentComplete 0
                            }
                            if ($script:__dlBytes -le $lastBytes) { $stallMs += 200 } else { $stallMs = 0; $lastBytes = $script:__dlBytes }
                            if ($stallMs -ge 15000) { throw "Download stalled" }
                            Start-Sleep -Milliseconds 200
                        }
                        if ($script:__dlError) { throw $script:__dlError }
                        if (-not (Test-Path -LiteralPath $tmpOut)) { throw "Download produced no file" }
                        $fi = Get-Item -LiteralPath $tmpOut -ErrorAction Stop
                        if ($fi.Length -le 0) { throw "Download produced empty file" }
                        Move-Item -LiteralPath $tmpOut -Destination $OutFile -Force
                        $webDownloaded = $true
                    } finally {
                        Write-Progress -Activity "Downloading" -Completed
                        if ($wc) { $wc.Dispose() }
                    }
                } catch {
                    Write-Warn ("WebClient download failed: " + $_.Exception.Message)
                }

                if (-not $webDownloaded) {
                    # BITS fallback with progress
                    try {
                        Write-Info "Falling back to BITS download..."
                        $job = Start-BitsTransfer -Source $Uri -Destination $OutFile -Asynchronous -Priority Foreground -Description "HighSpeedDownload"
                        while ($job.JobState -in @('Connecting','Transferring','Queued')) {
                            $pct = [int]([Math]::Min(100, $job.Progress.PercentComplete))
                            $mbDone = [Math]::Round(($job.Progress.BytesTransferred) / 1MB, 1)
                            $mbTotal = if ($job.Progress.BytesTotal -gt 0) { [Math]::Round($job.Progress.BytesTotal / 1MB, 1) } else { 0 }
                            $status = if ($mbTotal -gt 0) { "{0}% ({1}/{2} MB)" -f $pct, $mbDone, $mbTotal } else { "{0} MB" -f $mbDone }
                            Write-Progress -Activity "Downloading" -Status $status -PercentComplete $pct
                            Start-Sleep -Milliseconds 300
                            $job = Get-BitsTransfer -Id $job.Id -ErrorAction SilentlyContinue
                            if (-not $job) { throw "BITS job disappeared" }
                        }
                        if ($job.JobState -eq 'Transferred') {
                            Complete-BitsTransfer -BitsJob $job
                        } else {
                            $err = ($job | Format-List -Property * -Force | Out-String)
                            throw "BITS failed with state $($job.JobState): $err"
                        }
                    } catch {
                        Write-Progress -Activity "Downloading" -Completed
                        throw $_
                    }
                }
            }
        }
    }
    finally {
        $ProgressPreference = $oldProgress
    }
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
    throw "WorkingDirectory not found"
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
            Invoke-HighSpeedDownload -Uri $primaryUrl -OutFile $zipPath
            Write-Info "Extracting to: $extractDir"
            $expanded = Expand-ZipWithFallback -ZipPath $zipPath -Destination $extractDir -Password (ConvertTo-SecureString 'cs.rin.ru' -AsPlainText -Force)
            if (-not $expanded) { throw "All extraction strategies failed" }
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
                # Download to temp, then atomically move into place
                $tmpExe = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ("SKSAppManifestGenerator_x64_" + [Guid]::NewGuid() + ".exe")
                Invoke-HighSpeedDownload -Uri $secondaryUrl -OutFile $tmpExe
                if (-not (Test-Path -LiteralPath $tmpExe)) { throw "Secondary download produced no file" }
                $fileInfo = Get-Item -LiteralPath $tmpExe -ErrorAction Stop
                if ($fileInfo.Length -le 0) { throw "Secondary download produced empty file" }
                New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
                Move-Item -LiteralPath $tmpExe -Destination $GeneratorPath -Force
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
                throw 'Valid generator path was not provided.'
            }
            $GeneratorPath = $custom
        }
        else {
            Write-Info "Installed SKSAppManifestGenerator to: $GeneratorPath"
            # Verify on disk and non-empty
            try {
                $genInfo = Get-Item -LiteralPath $GeneratorPath -ErrorAction Stop
                if ($genInfo.Length -le 0) { throw "File length is zero" }
            } catch {
                Write-Err "Downloaded file validation failed: $($_.Exception.Message)"
                throw "Generator path invalid"
            }
        }
    }
    else {
        # Allow manual input of the path
        $custom = Read-Host 'Enter full path to SKSAppManifestGenerator_x64.exe'
        if ([string]::IsNullOrWhiteSpace($custom) -or -not (Test-Path -LiteralPath $custom)) {
            Write-Err 'Valid generator path was not provided.'
            throw 'Valid generator path was not provided.'
        }
        $GeneratorPath = $custom
    }
}

# Final existence check
if (-not (Test-Path -LiteralPath $GeneratorPath)) {
    Write-Err "Generator still not found at: $GeneratorPath"
    throw "Generator path invalid"
}

Write-Info "Using generator: $GeneratorPath"
Write-Info "Working directory: $WorkingDirectory"

# Resolve App IDs (parameter or prompt)
function Parse-AppIdsFromText {
    param([string]$text)
    $ids = @()
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        $normalized = Convert-ToAsciiDigits $text
        # Split on any non-digit sequence to robustly handle zero-width characters and mixed separators
        $parts = [System.Text.RegularExpressions.Regex]::Split($normalized, '[^0-9]+')
        foreach ($p in $parts) { if ($p -and ($p -match '^[0-9]+$')) { $ids += $p } }
    }
    return $ids
}

$combinedText = ''
if ($AppId) { $combinedText += (" " + $AppId) }

$appIds = Parse-AppIdsFromText $combinedText

if ($Debug.IsPresent) {
    Write-Host "[DEBUG] AppId='$AppId'" -ForegroundColor DarkGray
    Write-Host "[DEBUG] CombinedText='$combinedText'" -ForegroundColor DarkGray
    $normalizedDebug = Convert-ToAsciiDigits $combinedText
    Write-Host "[DEBUG] NormalizedCombined='$normalizedDebug'" -ForegroundColor DarkGray
    $codePoints = ($normalizedDebug.ToCharArray() | ForEach-Object { [int][char]$_ }) -join ','
    Write-Host "[DEBUG] CodePoints='$codePoints'" -ForegroundColor DarkGray
    Write-Host "[DEBUG] Parsed Ids='$(($appIds -join ', '))'" -ForegroundColor DarkGray
}

while ($appIds.Count -eq 0) {
    $appIdsInput = Read-Host 'Enter one or more App IDs (space or comma separated)'
    $appIds = Parse-AppIdsFromText $appIdsInput
    if ($appIds.Count -eq 0) { Write-Warn 'No valid numeric App IDs were detected. Please try again.' }
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
    throw
}
finally {
    Pop-Location
}

# Attempt to verify output files (common patterns)
$created = @()
$currentDir = Get-Location
foreach ($id in $appIds) {
    $candidates = @(
        (Join-Path -Path $currentDir -ChildPath ("appmanifest_" + $id + ".acf")),
        (Join-Path -Path $currentDir -ChildPath ($id + ".acf")),
        (Join-Path -Path $currentDir -ChildPath (Join-Path -Path 'SKSAppManifestGenerator' -ChildPath (Join-Path -Path $id -ChildPath ("appmanifest_" + $id + ".acf"))))
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

# Keep window open when run by double-click
Show-PauseIfLaunchedFromExplorer
