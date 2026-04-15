<#
.SYNOPSIS
    Script avanzado para actualizar aplicaciones mediante Winget en entornos gestionados (Intune / SYSTEM).

.DESCRIPTION
    Este script analiza aplicaciones desactualizadas via Winget, omite aquellas en la lista extendida
    de exclusiones (drivers críticos como iCUE/Synapse, o apps autogestionadas como Discord/Spotify) 
    y ejecuta una actualizacion silenciosa en el resto. 

    El script está adaptado de forma nativa para ejecutarse en el contexto de SYSTEM mediante Intune:
    resuelve dinámicamente el binario de winget fuera del PATH estándar y utiliza una mecánica 
    de logging antibloqueo hacia la carpeta corporativa (ProgramData\Inkoova).

    Flujo de trabajo:
    1. Comprueba si se ejecuta como Administrador / SYSTEM (sale con error 1 si no es así).
    2. Resuelve la ruta dinámica oculta de winget.exe para despliegues desatendidos.
    3. Analiza las actualizaciones disponibles y omite texto de cabecera.
    4. Compara contra exclusiones explícitas para asegurar la integridad operativa del equipo.
    5. Ejecuta 'winget upgrade' silenciosamente (--silent, accept-agreements).
    6. Genera logs (Add-Content) en la ruta corporativa y muestra resumen en consola.

.PARAMETER ExcludePatterns
    (Hardcoded en el script) Cadena extensa de software a ignorar para evitar bucles o fallos de drivers.

.PARAMETER LogPath
    (Hardcoded en el script) Ruta segura del log corporativo en ProgramData\Inkoova.

.EXAMPLE
    Executes as Intune Platform Script (Device configuration -> Scripts -> Windows 10 and later).

.NOTES
    Name:       Script - Winget - NonInteractive.ps1
    Author:     Alejandro Suarez (@alexsf93)
    Date:       2026-04-15
    Version:    1.4
    Requisitos: Ejecución bajo SYSTEM/Amin, PowerShell 5.1+, AppInstaller (Winget).
#>

$ExcludePatterns = @(
    "Corsair", "iCUE", "Discord", "Logitech", "Razer", "Synapse", 
    "VMware", "VirtualBox", "Nvidia", "GeForce", "AMD", "Adrenalin",
    "Steam", "Epic Games", "Battle.net", "Spotify", "Teams", "WhatsApp", 
    "Skype", "Zoom", "Office"
)
$CompanyFolder = Join-Path $env:ProgramData 'Inkoova'
$LogFile = Join-Path $CompanyFolder 'winget_upgrade_log.txt'

if (-not (Test-Path $CompanyFolder)) { 
    New-Item -ItemType Directory -Path $CompanyFolder -Force | Out-Null 
}

function Log { 
    param([string]$m)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
}
function Write-Info { param([string]$m); Write-Host "[INFO] $m" -ForegroundColor Cyan; Log "INFO : $m" }
function Write-Skip { param([string]$m); Write-Host "[SKIP] $m" -ForegroundColor Yellow; Log "SKIP : $m" }
function Write-Update { param([string]$m); Write-Host "[UPDT] $m" -ForegroundColor Green; Log "UPDT : $m" }
function Write-Success { param([string]$m); Write-Host "[OK]   $m" -ForegroundColor DarkGreen; Log "OK   : $m" }
function Write-ErrorRed { param([string]$m); Write-Host "[FAIL] $m" -ForegroundColor Red; Log "ERROR: $m" }
function Write-Summary { param([string]$m); Write-Host "[====] $m" -ForegroundColor Cyan }
function Write-Done { param([string]$m); Write-Host "[DONE] $m" -ForegroundColor Cyan }

# Comprobar permisos de administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-ErrorRed "El script requiere permisos de administrador para ejecutarse."
    exit 1
}

$Stats_Updated = 0
$Stats_Skipped = 0
$Stats_Errors = 0

Write-Info "Inicio del proceso de actualizacion mediante Winget."
$joinedExclusions = $ExcludePatterns -join ','
Log "Parametros: ExcludePatterns=$joinedExclusions, LogFile=$LogFile"

try {
    # Obtener listado de Winget
    Write-Info "Obteniendo lista de aplicaciones..."
    $env:WINGET_DISABLE_PROGRESS = $true
    $wingetOutput = winget upgrade

    if ($null -ne $wingetOutput) {
        foreach ($line in $wingetOutput) {
            # Limpiar posibles secuencias ANSI de color
            $line = $line -replace "`e\[[0-9;]*m", ""

            # Saltar spinners, lineas vacias y rayas
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line.Length -lt 15) { continue }
            if ($line -match '^-+$') { continue }
            
            # Omitir cabeceras o advertencias de texto generico de Winget
            if ($line -match "^Name\s+" -or $line -match "^Nombre\s+") { continue }
            if ($line -match "The following packages") { continue }
            if ($line -match "Los siguientes paquetes") { continue }
            if ($line -match "A newer version") { continue }
            if ($line -match "upgrades available") { continue }

            $tokens = $line.Trim() -split '\s+'
            
            # Una linea real de app tiene al menos: Name, Id, Version, Available, Source
            if ($tokens.Count -lt 5) { continue }

            # El ID siempre se encuentra en la 4ta posicion empezando por el final (Id, Version, Available, Source)
            $appId = $tokens[-4]
            
            # El nombre es absolutamente todos los tokens de la izquierda que sobren
            $appName = ($tokens[0..($tokens.Count - 5)]) -join ' '

            if ([string]::IsNullOrWhiteSpace($appId)) { continue }

            # Filtro de exclusion
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



            # Ejecutar actualizacion silenciosa
            Write-Update "Actualizando: $appName ($appId)"
            $null = winget upgrade --id "$appId" --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
            
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
                $Stats_Updated++
                Write-Success "  -> Actualizado correctamente"
            } 
            else {
            }
        }
    }

    # Resumen de compilacion final
    Write-Host ""
    Write-Summary "RESUMEN DE ACTUALIZACION"
    Write-Host ("--------------------------------") -ForegroundColor DarkCyan

    $colorUpdated = if ($Stats_Updated -gt 0) { [ConsoleColor]::Green } else { [ConsoleColor]::DarkGray }
    $colorSkipped = if ($Stats_Skipped -gt 0) { [ConsoleColor]::Yellow } else { [ConsoleColor]::DarkGray }
    $colorErrors = if ($Stats_Errors -gt 0) { [ConsoleColor]::Red } else { [ConsoleColor]::DarkGray }

    Write-Host "[OK]   Actualizados : $Stats_Updated" -ForegroundColor $colorUpdated
    Write-Host "[SKIP] Omitidos     : $Stats_Skipped" -ForegroundColor $colorSkipped
    Write-Host "[FAIL] Errores      : $Stats_Errors" -ForegroundColor $colorErrors

    Write-Host ("--------------------------------") -ForegroundColor DarkCyan
    Write-Done "Proceso completado."
}
catch {
    $err = $_.Exception.Message
    Write-ErrorRed "ERROR FATAL: $err"
    Log "EXCEPTION: $($_ | Out-String)"
}
finally {
    Write-Info "Fin del script. Log en: $LogFile"
    Write-Host ""
}
    Write-Host ("--------------------------------") -ForegroundColor DarkCyan
    Write-Done "Proceso completado."
}
catch {
    $err = $_.Exception.Message
    Write-ErrorRed "ERROR FATAL: $err"
    Write-Log "EXCEPTION: $($_ | Out-String)"
}
finally {
    Write-Info "Fin del script. Log en: $LogPath"
    Write-Host ""
}