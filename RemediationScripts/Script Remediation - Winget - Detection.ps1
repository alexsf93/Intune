<#
.SYNOPSIS
    Script de deteccion para actualizacion automatizada de software mediante Winget en Intune.

.DESCRIPTION
    Determina si existen aplicaciones en el sistema que requieran actualizacion mediante Winget,
    respetando las exclusiones estaticas y dinamicas del script de remediacion.

.NOTES
    Nombre:     Script - Winget - Detection.ps1
    Autor:      Alejandro Suarez (@alexsf93)
    Fecha:      2026-06-15
    Version:    1.0
#>

$ExcludePatterns = @(
    "Corsair", "iCUE", "Discord", "Logitech", "Razer", "Synapse", 
    "VMware", "VirtualBox", "Nvidia", "GeForce", "AMD", "Adrenalin",
    "Steam", "Epic Games", "Battle.net", "Spotify", "Teams", "WhatsApp", 
    "Skype", "Zoom", "Office", "SSMS", "SQL Server Management Studio"
)

$CompanyFolder = Join-Path $env:ProgramData 'Naxvan'
$TelemetryFile = Join-Path $CompanyFolder 'winget_telemetry.json'

if ([System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) {
    $env:XDG_CONFIG_HOME = Join-Path $env:ProgramData "WingetConfig"
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
    Write-Output "No se pudo encontrar winget.exe en el sistema."
    exit 0 # Si no existe winget, marcamos como conforme para no intentar remediar
}

$UpdatesAvailable = 0
$PendingAppsList = New-Object System.Collections.Generic.List[string]

try {
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

            # 1. Validacion estatica
            $shouldSkip = $false
            foreach ($pattern in $ExcludePatterns) {
                if ($appName -match [regex]::Escape($pattern) -or $appId -match [regex]::Escape($pattern)) {
                    $shouldSkip = $true; break
                }
            }

            if ($shouldSkip) { continue }

            $cleanKey = $appId -replace '\.', ''

            # 2. Validacion de telemetria anti-bucles utilizando la clave limpia
            if ($Telemetry.ContainsKey($cleanKey)) {
                $appData = $Telemetry[$cleanKey]
                
                if ($null -ne $appData.BlockUntil -and $appData.BlockUntil -ne "") {
                    $parsedBlockDate = [datetime]::MinValue
                    if ([DateTime]::TryParseExact($appData.BlockUntil, 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedBlockDate)) {
                        if ((Get-Date) -lt $parsedBlockDate) {
                            continue
                        }
                    }
                }
                
                if ($null -ne $appData.LastSuccessDate -and $appData.LastSuccessDate -ne "") {
                    $parsedSuccessDate = [datetime]::MinValue
                    if ([DateTime]::TryParseExact($appData.LastSuccessDate, 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedSuccessDate)) {
                        if ($parsedSuccessDate.Date -eq (Get-Date).Date) {
                            continue
                        }
                    }
                }
            }

            $UpdatesAvailable++
            [void]$PendingAppsList.Add("$appName ($appId)")
        }
    }
}
catch {
    Write-Error "Error durante la comprobacion de actualizaciones: $_"
    exit 0
}

if ($UpdatesAvailable -gt 0) {
    $apps = $PendingAppsList -join ", "
    Write-Output "Deteccion: Hay $UpdatesAvailable aplicaciones pendientes de actualizar: $apps"
    exit 1 # No conforme -> Ejecutar remediacion
} else {
    Write-Output "Deteccion: El sistema esta al dia o las aplicaciones pendientes estan excluidas."
    exit 0 # Conforme -> No ejecutar remediacion
}
