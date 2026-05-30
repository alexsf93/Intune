<#
.SYNOPSIS
    Script de mantenimiento para actualizacion automatizada de software mediante Winget en Intune.

.DESCRIPTION
    Realiza la actualizacion desatendida de aplicaciones instaladas en el sistema utilizando Winget.
    Esta optimizado para ejecutarse bajo el contexto de SYSTEM en Intune, gestionando exclusiones
    de software critico y mantenimiento de los ficheros de log generados.

.NOTES
    Nombre:     Script - Winget - NonInteractive.ps1
    Autor:      Alejandro Suarez (@alexsf93)
    Fecha:      2026-05-30
    Version:    1.6
#>

$ExcludePatterns = @(
    "Corsair", "iCUE", "Discord", "Logitech", "Razer", "Synapse", 
    "VMware", "VirtualBox", "Nvidia", "GeForce", "AMD", "Adrenalin",
    "Steam", "Epic Games", "Battle.net", "Spotify", "Teams", "WhatsApp", 
    "Skype", "Zoom", "Office", "SSMS", "SQL Server Management Studio"
)

$CompanyFolder = Join-Path $env:ProgramData 'Inkoova'
$LogFile = Join-Path $CompanyFolder 'winget_upgrade_log.txt'

if (-not (Test-Path $CompanyFolder)) { 
    New-Item -ItemType Directory -Path $CompanyFolder -Force | Out-Null 
}

function Remove-OldLogs {
    param(
        [string]$path,
        [int]$monthsToKeep = 1
    )
    if (Test-Path $path) {
        try {
            $limitDate = (Get-Date).AddMonths(-$monthsToKeep)
            $lines = Get-Content -Path $path -ErrorAction SilentlyContinue
            if ($null -ne $lines) {
                $newLines = New-Object System.Collections.Generic.List[string]
                foreach ($line in $lines) {
                    if ($line -match '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') {
                        $dateStr = $Matches[1]
                        $parsedDate = [datetime]::MinValue
                        if ([DateTime]::TryParseExact($dateStr, 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
                            if ($parsedDate -ge $limitDate) {
                                [void]$newLines.Add($line)
                            }
                        }
                        else {
                            [void]$newLines.Add($line)
                        }
                    }
                    else {
                        [void]$newLines.Add($line)
                    }
                }
                Set-Content -Path $path -Value $newLines -Encoding UTF8 -Force -ErrorAction Stop
            }
        }
        catch {
            # Ignorar errores de acceso/bloqueo en entorno desatendido (SYSTEM)
        }
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
function Write-ErrorRed { param([string]$m); Write-Host "[FAIL] $m"; Log "ERROR: $m" }
function Write-Summary { param([string]$m); Write-Host "[====] $m" }
function Write-Done { param([string]$m); Write-Host "[DONE] $m" }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-ErrorRed "El script requiere permisos de administrador para ejecutarse."
    exit 1
}

# Resolucion de la ruta de winget.exe para el contexto SYSTEM
function Get-WingetPath {
    $winget = Get-Command winget -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if ($winget -and (Test-Path $winget)) {
        return $winget
    }

    $windowsAppsPath = Join-Path $env:ProgramFiles "WindowsApps"
    if (Test-Path $windowsAppsPath) {
        $installerPaths = Get-ChildItem -Path $windowsAppsPath -Filter "Microsoft.DesktopAppInstaller*_*_8wekyb3d8bbwe" -Directory -ErrorAction SilentlyContinue
        if ($installerPaths) {
            $latestInstaller = $installerPaths | Sort-Object Name -Descending | Select-Object -First 1
            $wingetPath = Join-Path $latestInstaller.FullName "winget.exe"
            if (Test-Path $wingetPath) {
                return $wingetPath
            }
        }
    }

    $systemAppInstallerPath = "C:\Windows\System32\winget.exe"
    if (Test-Path $systemAppInstallerPath) {
        return $systemAppInstallerPath
    }

    return $null
}

$WingetPath = Get-WingetPath
if (-not $WingetPath) {
    Write-ErrorRed "No se pudo encontrar el ejecutable de winget.exe en el sistema."
    exit 1
}

$Stats_Updated = 0
$Stats_Skipped = 0
$Stats_Errors = 0

Write-Info "Inicio del proceso de actualizacion mediante Winget."
Write-Info "Ejecutable de Winget detectado en: $WingetPath"
Log "Parametros: ExcludePatterns=$($ExcludePatterns -join ','), LogFile=$LogFile, WingetPath=$WingetPath"

# Verificacion y restablecimiento de fuentes de Winget si es necesario
try {
    $env:WINGET_DISABLE_PROGRESS = "1"
    $testRun = & $WingetPath list --accept-source-agreements -n 1 --disable-interactivity 2>&1
    if ($LASTEXITCODE -ne 0 -and ($testRun -match "0x8a15000f" -or $testRun -match "source" -or $testRun -match "origen")) {
        Write-Skip "Se detectaron problemas con los origenes de datos de Winget. Intentando restablecer (source reset)..."
        & $WingetPath source reset --force | Out-Null
    }
}
catch {
    Write-Skip "Error al validar los origenes de Winget. Intentando restablecer (source reset)..."
    try { & $WingetPath source reset --force | Out-Null } catch {}
}

try {
    Write-Info "Consultando actualizaciones disponibles..."
    $env:WINGET_DISABLE_PROGRESS = "1"
    $wingetOutput = & $WingetPath upgrade --accept-source-agreements

    if ($null -ne $wingetOutput) {
        foreach ($line in $wingetOutput) {
            # Remover secuencias de color ANSI
            $line = $line -replace "`e\[[0-9;]*m", ""

            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line.Length -lt 15) { continue }
            if ($line -match '^-+$') { continue }
            
            if ($line -match "^Name\s+" -or $line -match "^Nombre\s+") { continue }
            if ($line -match "The following packages" -or $line -match "Los siguientes paquetes") { continue }
            if ($line -match "A newer version" -or $line -match "upgrades available") { continue }

            if ($line -match "[\u2588\u2593\u2592\u2591\u250C\u00FB\u00EA]") { continue }
            if ($line -match "\d+(\.\d+)?\s*(KB|MB|GB|B|Bytes)") { continue }

            $tokens = $line.Trim() -split '\s+'
            if ($tokens.Count -lt 5) { continue }

            $appId = $tokens[-4]
            $appName = ($tokens[0..($tokens.Count - 5)]) -join ' '

            if ([string]::IsNullOrWhiteSpace($appId)) { continue }
            if ($appId -match '^(KB|MB|GB|Bytes|/)$' -or $appName -match '[\u2588\u2593\u2592\u2591\u250C\u00FB\u00EA]') { continue }

            $shouldSkip = $false
            foreach ($pattern in $ExcludePatterns) {
                if ($appName -match [regex]::Escape($pattern) -or $appId -match [regex]::Escape($pattern)) {
                    $shouldSkip = $true
                    break
                }
            }

            if ($shouldSkip) {
                Write-Skip "Omitido: $appName ($appId)"
                $Stats_Skipped++
                continue
            }

            Write-Update "Actualizando: $appName ($appId)"
            $null = & $WingetPath upgrade --id "$appId" --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
            
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
                $Stats_Updated++
                Write-Success "  -> Actualizado correctamente"
            }
            else {
                $Stats_Errors++
                Write-ErrorRed "  -> Error al actualizar (ExitCode: $LASTEXITCODE)"
            }
        }
    }

    Write-Host ""
    Write-Summary "RESUMEN DE ACTUALIZACION"
    Write-Host "--------------------------------"

    Write-Host "[OK]   Actualizados : $Stats_Updated"
    Write-Host "[SKIP] Omitidos     : $Stats_Skipped"
    Write-Host "[FAIL] Errores      : $Stats_Errors"

    Write-Host "--------------------------------"
    Write-Done "Proceso completado."
}
catch {
    $err = $_.Exception.Message
    Write-ErrorRed "ERROR FATAL: $err"
    Log "EXCEPTION: $($_ | Out-String)"
}
finally {
    Write-Host "Fin del script. Log local en: $LogFile"
    Write-Host ""
}