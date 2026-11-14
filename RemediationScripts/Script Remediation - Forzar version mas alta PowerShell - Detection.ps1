<#
.SYNOPSIS
    DETECTION SCRIPT: VERIFICAR SI EL EQUIPO TIENE FORZADA LA VERSIÓN MÁS ALTA DE POWERSHELL

.DESCRIPTION
    Este script comprueba si el equipo cumple con la política de estandarización de PowerShell:
    1. Detecta la versión más alta de PowerShell disponible en la máquina.
    2. Comprueba si existen versiones intermedias obsoletas de PowerShell 7.x pendientes de desinstalar.
    3. Comprueba si los accesos directos principales de PowerShell apuntan a la versión más alta.
    4. Comprueba si existen accesos directos obsoletos de 32 bits (x86).
    5. Comprueba si el directorio de la versión más alta está en el PATH del sistema.

    Salida Intune:
    - Exit 0: Compliant (El equipo ya está correctamente configurado).
    - Exit 1: Non-Compliant (Requiere remediación).

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name:       Script Remediation - Forzar version mas alta PowerShell - Detection.ps1
    Author:     Alejandro Suárez (@alexsf93)
    Date:       2026-11-14
    Version:    1.0.0
    Context:    System
#>

$ErrorActionPreference = 'SilentlyContinue'

# 1. Obtener versiones instaladas
$detected = [System.Collections.Generic.List[PSCustomObject]]::new()

# 1.1. Rutas estándar en Program Files
$searchPaths = @(
    "$env:ProgramFiles\PowerShell\*\pwsh.exe",
    "${env:ProgramFiles(x86)}\PowerShell\*\pwsh.exe"
)
foreach ($path in $searchPaths) {
    Get-Item -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
        $vStr = if ($_.VersionInfo.FileVersion) { $_.VersionInfo.FileVersion } else { $_.VersionInfo.ProductVersion }
        if ($vStr -match '^(\d+(\.\d+){1,3})') {
            $detected.Add([PSCustomObject]@{
                Version        = [System.Version]$Matches[1]
                ExecutablePath = $_.FullName
                Directory      = $_.DirectoryName
            })
        }
    }
}

# 1.2. AppX / Store
try {
    Get-AppxPackage -Name "*PowerShell*" -ErrorAction SilentlyContinue | ForEach-Object {
        $appxExe = Join-Path $_.InstallLocation "pwsh.exe"
        if (Test-Path $appxExe) {
            if ($_.Version -match '^(\d+(\.\d+){1,3})') {
                $detected.Add([PSCustomObject]@{
                    Version        = [System.Version]$Matches[1]
                    ExecutablePath = $appxExe
                    Directory      = Split-Path $appxExe -Parent
                })
            }
        }
    }
} catch {}

# 1.3. Windows PowerShell 5.1 integrado
$winPS = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (Test-Path $winPS) {
    $psVerStr = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine" -Name "PowerShellVersion" -ErrorAction SilentlyContinue).PowerShellVersion
    if (-not $psVerStr) { $psVerStr = "5.1.0" }
    if ($psVerStr -match '^(\d+(\.\d+){1,3})') {
        $detected.Add([PSCustomObject]@{
            Version        = [System.Version]$Matches[1]
            ExecutablePath = $winPS
            Directory      = Split-Path $winPS -Parent
        })
    }
}

if ($detected.Count -eq 0) {
    Write-Output "No se detectaron versiones operativas de PowerShell."
    Exit 0
}

$highest = ($detected | Sort-Object -Property Version -Descending) | Select-Object -First 1

# Si la versión más alta es solo 5.1 (no está instalado PowerShell 7), no hay nada que forzar
if ($highest.Version.Major -lt 6) {
    Write-Output "PowerShell 7 no está instalado en este equipo. Estado: Compliant."
    Exit 0
}

$issues = [System.Collections.Generic.List[string]]::new()

# 2. Comprobar si existen versiones intermedias de PowerShell 7
$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
foreach ($reg in $regPaths) {
    Get-ItemProperty $reg -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -match '^PowerShell\s+\d+(\.\d+)?' -and $_.UninstallString
    } | ForEach-Object {
        if ($_.DisplayVersion -match '^(\d+(\.\d+){1,3})') {
            if ([System.Version]$Matches[1] -lt $highest.Version) {
                $issues.Add("Existe una versión intermedia obsoleta instalada: $($_.DisplayName)")
            }
        }
    }
}

# 3. Comprobar accesos directos x86 obsoletos
$x86Shortcuts = Get-ChildItem -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:PUBLIC\Desktop" -Filter "*powershell*x86*.lnk" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '(?i)ISE' }
if ($x86Shortcuts) {
    $issues.Add("Existen accesos directos obsoletos x86 en el sistema.")
}

# 4. Comprobar destino del acceso directo principal en ProgramData
$mainShortcut = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk"
if (Test-Path $mainShortcut) {
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($mainShortcut)
    if ($sc.TargetPath -ine $highest.ExecutablePath) {
        $issues.Add("El acceso directo principal en ProgramData no apunta a la versión más alta ($($highest.ExecutablePath)).")
    }
}

# 5. Comprobar PATH del sistema
$machinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
$entries = $machinePath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
if ($entries[0].TrimEnd('\') -ine $highest.Directory.TrimEnd('\')) {
    $issues.Add("El directorio de la versión más alta ($($highest.Directory)) no está al inicio del PATH del Sistema.")
}

# Conclusión de la detección
if ($issues.Count -gt 0) {
    Write-Output "Non-Compliant: Se detectaron $($issues.Count) discrepancias:"
    $issues | ForEach-Object { Write-Output " - $_" }
    Exit 1
}

Write-Output "Compliant: El equipo tiene correctamente forzada la versión más alta de PowerShell (v$($highest.Version))."
Exit 0
