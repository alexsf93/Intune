<#
.SYNOPSIS
    Script de mantenimiento para actualizacion automatizada de software mediante Winget en Intune.

.DESCRIPTION
    Realiza la actualizacion desatendida de aplicaciones instaladas en el sistema utilizando Winget.
    Gestiona exclusiones de software critico, evita bucles infinitos de instalacion mediante telemetria
    local y mantiene los ficheros de log generados.

.NOTES
    Nombre:     Script - Winget - NonInteractive.ps1
    Autor:      Alejandro Suarez (@alexsf93)
    Fecha:      2026-06-15
    Version:    2.8 (Sanitized Key Fix)
#>

$ExcludePatterns = @(
    "Corsair", "iCUE", "Discord", "Logitech", "Razer", "Synapse", 
    "VMware", "VirtualBox", "Nvidia", "GeForce", "AMD", "Adrenalin",
    "Steam", "Epic Games", "Battle.net", "Spotify", "Teams", "WhatsApp", 
    "Skype", "Zoom", "Office", "SSMS", "SQL Server Management Studio"
)

$CompanyFolder = Join-Path $env:ProgramData 'Naxvan'
$LogFile = Join-Path $CompanyFolder 'winget_upgrade_log.txt'
$TelemetryFile = Join-Path $CompanyFolder 'winget_telemetry.json'
$MaxRetriesBeforeBlock = 1       
$BlockDurationDays = 7           

$ProcessedInCurrentRun = New-Object System.Collections.Generic.List[string]

if ([System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) {
    $env:XDG_CONFIG_HOME = Join-Path $env:ProgramData "WingetConfig"
}

if (-not (Test-Path $CompanyFolder)) { 
    New-Item -ItemType Directory -Path $CompanyFolder -Force | Out-Null 
}

function Convert-ObjectToHashtable {
    param($InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $hash = @{}
        foreach ($prop in $InputObject.psobject.Properties) {
            $hash[$prop.Name] = Convert-ObjectToHashtable $prop.Value
        }
        return $hash
    } elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($item in $InputObject) {
            [void]$list.Add((Convert-ObjectToHashtable $item))
        }
        return $list
    } else {
        return $InputObject
    }
}

$Telemetry = @{}
if (Test-Path $TelemetryFile) {
    try { 
        $rawJson = Get-Content -Path $TelemetryFile -Raw -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($rawJson)) {
            $rawObj = ConvertFrom-Json -InputObject $rawJson
            $Telemetry = Convert-ObjectToHashtable $rawObj
        }
        if ($null -eq $Telemetry) { $Telemetry = @{} }
    } catch { 
        $Telemetry = @{} 
    }
}

function Save-Telemetry {
    try { $Telemetry | ConvertTo-Json -Depth 5 | Set-Content -Path $TelemetryFile -Force } catch {}
}

function Remove-OldLogs {
    param([string]$path, [int]$monthsToKeep = 1)
    if (Test-Path $path) {
        try {
            $limitDate = (Get-Date).AddMonths(-$monthsToKeep)
            $lines = Get-Content -Path $path -ErrorAction SilentlyContinue
            if ($null -ne $lines) {
                $newLines = New-Object System.Collections.Generic.List[string]
                foreach ($line in $lines) {
                    if ($line -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') {
                        if ([DateTime]::TryParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
                            if ($parsedDate -ge $limitDate) { [void]$newLines.Add($line) }
                        } else { [void]$newLines.Add($line) }
                    } else { [void]$newLines.Add($line) }
                }
                Set-Content -Path $path -Value $newLines -Encoding UTF8 -Force -ErrorAction Stop
            }
        } catch {}
    }
}

Remove-OldLogs -path $LogFile -monthsToKeep 1

function Log { 
    param([string]$m)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
}

function Write-Info { param([string]$m); Log "INFO : $m" }
function Write-Skip { param([string]$m); Log "SKIP : $m" }
function Write-Update { param([string]$m); Log "UPDT : $m" }
function Write-Success { param([string]$m); Log "OK   : $m" }
function Write-ErrorRed { param([string]$m); Log "ERROR: $m" }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "El script requiere permisos de administrador."
    exit 1
}

function Get-WingetPath {
    $winget = Get-Command winget -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if ($winget -and (Test-Path $winget)) { return $winget }
    $windowsAppsPath = Join-Path $env:ProgramFiles "WindowsApps"
    if (Test-Path $windowsAppsPath) {
        $installerPaths = Get-ChildItem -Path $windowsAppsPath -Filter "Microsoft.DesktopAppInstaller*_*_8wekyb3d8bbwe" -Directory -ErrorAction SilentlyContinue
        if ($installerPaths) {
            $latestInstaller = $installerPaths | Sort-Object Name -Descending | Select-Object -First 1
            $wingetPath = Join-Path $latestInstaller.FullName "winget.exe"
            if (Test-Path $wingetPath) { return $wingetPath }
        }
    }
    $systemAppInstallerPath = "C:\Windows\System32\winget.exe"
    if (Test-Path $systemAppInstallerPath) { return $systemAppInstallerPath }
    return $null
}

$WingetPath = Get-WingetPath
if (-not $WingetPath) {
    Write-Error "No se pudo encontrar winget.exe."
    exit 1
}

$Stats_Updated = 0
$Stats_Skipped = 0
$Stats_Errors = 0

Write-Info "Inicio del proceso de actualizacion mediante Winget."

try {
    $env:WINGET_DISABLE_PROGRESS = "1"
    $testRun = & $WingetPath list --accept-source-agreements -n 1 --disable-interactivity 2>&1
    if ($LASTEXITCODE -ne 0 -and ($testRun -match "0x8a15000f" -or $testRun -match "source" -or $testRun -match "origen")) {
        Write-Skip "Problemas con origenes de Winget. Restableciendo..."
        & $WingetPath source reset --force | Out-Null
    }
} catch {
    try { & $WingetPath source reset --force | Out-Null } catch {}
}

try {
    Write-Info "Consultando actualizaciones disponibles..."
    $env:WINGET_DISABLE_PROGRESS = "1"
    $wingetOutput = & $WingetPath upgrade --accept-source-agreements 2>&1

    if ($null -ne $wingetOutput) {
        $headerProcessed = $false
        $idIdx = $null
        $versionIdx = $null

        foreach ($rawLine in $wingetOutput) {
            $line = $rawLine -replace "`e\[[0-9;]*m", "" 
            $line = $line -replace "[\u2588\u2593\u2592\u2591\u250C\u00FB\u00EA\u2550\u2502]", ""
            if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^-+$') { continue }

            if ($line -match "^Name\s+Id\s+" -or $line -match "^Nombre\s+Id\s+" -or $line -match "^\s*Name\s+Id" -or $line -match "^\s*Nombre\s+Id") {
                $idIdx = $line.IndexOf("Id")
                if ($line -match "Vers") { $versionIdx = $line.IndexOf($Matches[0]) }
                $headerProcessed = $true
                continue
            }

            if (-not $headerProcessed) { continue }
            if ($line -match "The following packages" -or $line -match "Los siguientes paquetes" -or $line -match "A newer version" -or $line -match "upgrades available" -or $line -match "disponibles\.") { continue }

            try {
                if ($null -ne $idIdx -and $null -ne $versionIdx -and $line.Length -gt $versionIdx) {
                    $appName = $line.Substring(0, $idIdx).Trim()
                    $appId = $line.Substring($idIdx, ($versionIdx - $idIdx)).Trim()
                } else {
                    $tokens = $line.Trim() -split '\s+'
                    if ($tokens.Count -lt 3) { continue }
                    $appId = $tokens[1].Trim(); $appName = $tokens[0].Trim()
                }
            } catch { continue }

            if ([string]::IsNullOrWhiteSpace($appId) -or $appId -eq "Id" -or $appId -match "---") { continue }

            if ($ProcessedInCurrentRun.Contains($appId)) {
                continue
            }

            # Validacion estatica
            $shouldSkip = $false
            foreach ($pattern in $ExcludePatterns) {
                if ($appName -match [regex]::Escape($pattern) -or $appId -match [regex]::Escape($pattern)) {
                    $shouldSkip = $true; break
                }
            }

            if ($shouldSkip) {
                Write-Skip "Omitido (Lista estatica): $appName ($appId)"
                $Stats_Skipped++; continue
            }

            $cleanKey = $appId -replace '\.', ''

            # Validacion de telemetria anti-bucles
            if ($Telemetry.ContainsKey($cleanKey)) {
                $appData = $Telemetry[$cleanKey]
                
                if ($null -ne $appData.BlockUntil -and $appData.BlockUntil -ne "") {
                    $parsedBlockDate = [datetime]::MinValue
                    if ([DateTime]::TryParseExact($appData.BlockUntil, 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedBlockDate)) {
                        if ((Get-Date) -lt $parsedBlockDate) {
                            Write-Skip "Omitido Dinamicamente (Bloqueado hasta $parsedBlockDate): $appName ($appId)"
                            $Stats_Skipped++; continue
                        } else {
                            $Telemetry[$cleanKey].BlockUntil = ""
                        }
                    }
                }
                
                if ($null -ne $appData.LastSuccessDate -and $appData.LastSuccessDate -ne "") {
                    $parsedSuccessDate = [datetime]::MinValue
                    if ([DateTime]::TryParseExact($appData.LastSuccessDate, 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedSuccessDate)) {
                        if ($parsedSuccessDate.Date -eq (Get-Date).Date) {
                            Write-Skip "Omitido Dinamicamente (Ya actualizado hoy): $appName ($appId)"
                            $Stats_Skipped++; continue
                        }
                    }
                }
            }

            [void]$ProcessedInCurrentRun.Add($appId)

            # Ejecutar actualizacion
            Write-Update "Actualizando: $appName ($appId)"
            & $WingetPath upgrade --id "$appId" --silent --accept-source-agreements --accept-package-agreements --disable-interactivity > $null 2>&1
            
            if (-not $Telemetry.ContainsKey($cleanKey)) {
                $Telemetry[$cleanKey] = @{ "ConsecutiveErrors" = 0; "LastSuccessDate" = ""; "BlockUntil" = "" }
            }

            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
                $Stats_Updated++
                Write-Success "  -> Actualizado correctamente."
                $Telemetry[$cleanKey].LastSuccessDate = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                $Telemetry[$cleanKey].ConsecutiveErrors = 0
                $Telemetry[$cleanKey].BlockUntil = ""
            }
            else {
                $Stats_Errors++
                Write-ErrorRed "  -> Error al actualizar (ExitCode: $LASTEXITCODE)"
                
                $currentErrors = [int]($Telemetry[$cleanKey].ConsecutiveErrors) + 1
                $Telemetry[$cleanKey].ConsecutiveErrors = $currentErrors
                
                if ($currentErrors -ge $MaxRetriesBeforeBlock) {
                    $blockUntilDate = (Get-Date).AddDays($BlockDurationDays).ToString('yyyy-MM-dd HH:mm:ss')
                    $Telemetry[$cleanKey].BlockUntil = $blockUntilDate
                    Write-ErrorRed "  -> Excluido dinamicamente hasta: $blockUntilDate"
                }
            }
            Save-Telemetry
        }
    }

    if ($Stats_Updated -gt 0 -or $Stats_Errors -gt 0) {
        Write-Output "Winget Summary - Updated: $Stats_Updated | Skipped: $Stats_Skipped | Errors: $Stats_Errors"
    }
}
catch {
    Write-Error "Fatal Error: $_"
    exit 1
}
finally {
    Save-Telemetry
}