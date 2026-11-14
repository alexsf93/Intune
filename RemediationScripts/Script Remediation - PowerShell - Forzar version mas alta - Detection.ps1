<#
.SYNOPSIS
    DETECTION SCRIPT: VERIFICAR SI EL EQUIPO TIENE FORZADA LA VERSION MAS ALTA DE POWERSHELL

.DESCRIPTION
    Script de deteccion para Microsoft Intune.
    Comprueba si el equipo cumple con la politica de estandarizacion de PowerShell:
    1. Detecta la version mas alta de PowerShell disponible en la maquina.
    2. Comprueba si existen versiones intermedias obsoletas de PowerShell 7.x.
    3. Comprueba si existen accesos directos obsoletos x86.
    4. Comprueba si los accesos directos de PowerShell apuntan a la version mas alta.
    5. Comprueba si el directorio de la version mas alta esta en el PATH del Sistema.

    Salida Intune:
    - Exit 0: Compliant (El equipo ya esta correctamente estandarizado).
    - Exit 1: Non-Compliant (Requiere remediacion).

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name:       Script Remediation - PowerShell - Forzar version mas alta - Detection.ps1
    Author:     Alejandro Suarez (@alexsf93)
    Date:       2026-11-14
    Version:    1.3.0
    Context:    System
#>

$ErrorActionPreference = 'SilentlyContinue'

# --- 1. Deteccion exhaustiva de versiones de PowerShell ---
# NOTA: Bajo SYSTEM, $env:LOCALAPPDATA y $env:APPDATA apuntan al perfil de SYSTEM,
# no al perfil del usuario. Se usan rutas absolutas y enumeracion de C:\Users\* .

$detected = [System.Collections.Generic.List[PSCustomObject]]::new()

# Rutas MSI/Win32 en Program Files (siempre validas bajo SYSTEM)
$searchPaths = @(
    "C:\Program Files\PowerShell\*\pwsh.exe",
    "C:\Program Files (x86)\PowerShell\*\pwsh.exe"
)

# Rutas de instalacion por usuario (enumeracion explicita, NO $env:LOCALAPPDATA)
Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -notmatch '^(Public|All Users|Default|Default User)$'
} | ForEach-Object {
    $searchPaths += Join-Path $_.FullName "AppData\Local\Microsoft\PowerShell\*\pwsh.exe"
    $searchPaths += Join-Path $_.FullName "AppData\Local\Programs\PowerShell\*\pwsh.exe"
}

foreach ($path in $searchPaths) {
    Get-Item -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
        $vStr = if ($_.VersionInfo.FileVersion) { $_.VersionInfo.FileVersion } else { $_.VersionInfo.ProductVersion }
        if ($vStr -match '^(\d+(\.\d+){1,3})') {
            $detected.Add([PSCustomObject]@{
                Version        = [System.Version]$Matches[1]
                ExecutablePath = $_.FullName
                Directory      = $_.DirectoryName
                InstallType    = "Win32/MSI"
            })
        }
    }
}

# AppX / MSIX (Store) - Get-AppxPackage -AllUsers funciona bajo SYSTEM
try {
    Get-AppxPackage -AllUsers -Name "*PowerShell*" -ErrorAction SilentlyContinue | ForEach-Object {
        $appxExe = Join-Path $_.InstallLocation "pwsh.exe"
        if (Test-Path $appxExe) {
            if ($_.Version -match '^(\d+(\.\d+){1,3})') {
                $detected.Add([PSCustomObject]@{
                    Version        = [System.Version]$Matches[1]
                    ExecutablePath = $appxExe
                    Directory      = Split-Path $appxExe -Parent
                    InstallType    = "AppX"
                })
            }
        }
    }
} catch {}

# Windows PowerShell 5.1 (siempre disponible)
$winPS = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (Test-Path $winPS) {
    $psVerStr = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine" -Name "PowerShellVersion" -ErrorAction SilentlyContinue).PowerShellVersion
    if (-not $psVerStr) { $psVerStr = "5.1.0" }
    if ($psVerStr -match '^(\d+(\.\d+){1,3})') {
        $detected.Add([PSCustomObject]@{
            Version        = [System.Version]$Matches[1]
            ExecutablePath = $winPS
            Directory      = Split-Path $winPS -Parent
            InstallType    = "Windows PowerShell 5.1"
        })
    }
}

if ($detected.Count -eq 0) {
    Write-Output "Compliant: No se detectaron instalaciones de PowerShell en el equipo."
    Exit 0
}

$highest = ($detected | Sort-Object -Property Version -Descending) | Select-Object -First 1

if ($highest.Version.Major -lt 6) {
    Write-Output "Compliant: Solo existe Windows PowerShell 5.1 instalado. No hay version Core que forzar."
    Exit 0
}

$issues = [System.Collections.Generic.List[string]]::new()

# --- 2. Comprobar versiones intermedias obsoletas de PowerShell 7 ---
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
                $issues.Add("Existe una version intermedia obsoleta instalada: $($_.DisplayName)")
            }
        }
    }
}

# --- 3. Recopilar directorios de accesos directos ---
# NOTA: NO se usa $env:APPDATA ni [Environment]::GetFolderPath() porque bajo
# SYSTEM resuelven al perfil del sistema, no al perfil del usuario.

$shortcutDirs = [System.Collections.Generic.List[string]]::new()
$shortcutDirs.Add("$env:ProgramData\Microsoft\Windows\Start Menu\Programs")
$shortcutDirs.Add("$env:PUBLIC\Desktop")

# Enumeracion explicita de perfiles de usuario reales
Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -notmatch '^(Public|All Users|Default|Default User)$'
} | ForEach-Object {
    $shortcutDirs.Add((Join-Path $_.FullName "AppData\Roaming\Microsoft\Windows\Start Menu\Programs"))
    $shortcutDirs.Add((Join-Path $_.FullName "Desktop"))
}

$uniqueDirs = $shortcutDirs | Where-Object { Test-Path -Path $_ } | Select-Object -Unique

# 3.1. Accesos directos obsoletos x86
foreach ($dir in $uniqueDirs) {
    $foundX86 = Get-ChildItem -Path $dir -Filter "*powershell*x86*.lnk" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '(?i)ISE' }
    if ($foundX86) {
        $issues.Add("Existen accesos directos obsoletos x86 en el sistema ($($foundX86.Count) detectados).")
        break
    }
}

# 3.2. Accesos directos de PowerShell que no apuntan a la version mas alta
$wsh = New-Object -ComObject WScript.Shell
$misconfiguredShortcuts = 0

foreach ($dir in $uniqueDirs) {
    Get-ChildItem -Path $dir -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $sc = $wsh.CreateShortcut($_.FullName)
            if ($sc.TargetPath -match '(?i)(powershell\.exe|pwsh\.exe)$' -and $_.Name -notmatch '(?i)ISE') {
                if ($sc.TargetPath.TrimEnd('\') -ine $highest.ExecutablePath.TrimEnd('\')) {
                    $misconfiguredShortcuts++
                }
            }
        } catch {}
    }
}
if ($misconfiguredShortcuts -gt 0) {
    $issues.Add("Existen $misconfiguredShortcuts acceso(s) directo(s) que aun apuntan a Windows PowerShell 5.1 en lugar de v$($highest.Version).")
}

# --- 4. Comprobar variable PATH del Sistema ---
$machinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
$entries = $machinePath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$pathFound = $false
foreach ($e in $entries) {
    if ($e.TrimEnd('\') -ieq $highest.Directory.TrimEnd('\')) {
        $pathFound = $true
        break
    }
}
if (-not $pathFound) {
    $issues.Add("El directorio de PowerShell v$($highest.Version) ($($highest.Directory)) no esta presente en el PATH del Sistema.")
}

# --- Conclusion de la deteccion ---
if ($issues.Count -gt 0) {
    Write-Output "Non-Compliant: Se detectaron $($issues.Count) discrepancia(s) respecto a PowerShell v$($highest.Version):"
    $issues | ForEach-Object { Write-Output " - $_" }
    Exit 1
}

Write-Output "Compliant: El equipo tiene correctamente forzada la version mas alta de PowerShell (v$($highest.Version))."
Exit 0
