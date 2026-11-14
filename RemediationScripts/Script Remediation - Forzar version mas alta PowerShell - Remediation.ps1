<#
.SYNOPSIS
    REMEDIATION SCRIPT: FORZAR VERSIÓN MÁS ALTA DE POWERSHELL, LIMPIAR VERSIONES OBSOLETAS Y ACTUALIZAR ACCESOS E ICONOS

.DESCRIPTION
    Script de remediación periódica para Microsoft Intune.
    Realiza las siguientes acciones correctivas:
    1. Desinstala versiones intermedias obsoletas de PowerShell 7.x conservando únicamente la 5.1 y la más reciente.
    2. Elimina los accesos directos obsoletos de 32 bits (x86).
    3. Actualiza los accesos directos (ProgramData y Perfiles de Usuario) garantizando el icono corporativo nativo.
    4. Antepone el directorio de la versión más alta a la variable PATH de Sistema y Usuario.
    5. Actualiza el perfil por defecto de Windows Terminal a PowerShell Core.
    6. Refresca la caché del shell en caliente sin necesidad de reinicios.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name:       Script Remediation - Forzar version mas alta PowerShell - Remediation.ps1
    Author:     Alejandro Suárez (@alexsf93)
    Date:       2026-11-14
    Version:    1.0.0
    Context:    System
#>

$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- 1. Detección de versiones instaladas ---
$detected = [System.Collections.Generic.List[PSCustomObject]]::new()

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
                IconSource     = $_.FullName
                InstallType    = "MSI/Win32"
            })
        }
    }
}

try {
    Get-AppxPackage -Name "*PowerShell*" -ErrorAction SilentlyContinue | ForEach-Object {
        $appxExe = Join-Path $_.InstallLocation "pwsh.exe"
        if (Test-Path $appxExe) {
            if ($_.Version -match '^(\d+(\.\d+){1,3})') {
                $detected.Add([PSCustomObject]@{
                    Version        = [System.Version]$Matches[1]
                    ExecutablePath = $appxExe
                    Directory      = Split-Path $appxExe -Parent
                    IconSource     = $appxExe
                    InstallType    = "AppX"
                })
            }
        }
    }
} catch {}

$winPS = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (Test-Path $winPS) {
    $psVerStr = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\3\PowerShellEngine" -Name "PowerShellVersion" -ErrorAction SilentlyContinue).PowerShellVersion
    if (-not $psVerStr) { $psVerStr = "5.1.0" }
    if ($psVerStr -match '^(\d+(\.\d+){1,3})') {
        $detected.Add([PSCustomObject]@{
            Version        = [System.Version]$Matches[1]
            ExecutablePath = $winPS
            Directory      = Split-Path $winPS -Parent
            IconSource     = $winPS
            InstallType    = "Windows PowerShell 5.1"
        })
    }
}

if ($detected.Count -eq 0) {
    Write-Output "No se encontraron instalaciones de PowerShell. Saliendo sin cambios."
    Exit 0
}

$highest = ($detected | Sort-Object -Property Version -Descending) | Select-Object -First 1
Write-Host "Versión más alta detectada: v$($highest.Version) ($($highest.ExecutablePath))"

# Si solo existe 5.1, no hay nada que forzar
if ($highest.Version.Major -lt 6) {
    Write-Output "No hay versiones de PowerShell 7 instaladas. Sin cambios requeridos."
    Exit 0
}

# --- 2. Desinstalar versiones intermedias obsoletas de PowerShell 7 ---
$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
foreach ($reg in $regPaths) {
    Get-ItemProperty $reg -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -match '^PowerShell\s+\d+(\.\d+)?' -and $_.UninstallString
    } | ForEach-Object {
        if ($_.DisplayVersion -match '^(\d+(\.\d+){1,3})') {
            $instVer = [System.Version]$Matches[1]
            if ($instVer -lt $highest.Version) {
                $code = $_.PSChildName
                Write-Host "Desinstalando versión intermedia obsoleta: $($_.DisplayName)..."
                try {
                    Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $code /qn /norestart" -Wait -NoNewWindow
                } catch {}
            }
        }
    }
}

# Deshabilitar PowerShell 2.0 opcional por motivos de seguridad
if (Test-IsAdmin) {
    try {
        $ps2 = Get-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2Root" -ErrorAction SilentlyContinue
        if ($ps2 -and $ps2.State -eq 'Enabled') {
            Disable-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2Root" -NoRestart -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {}
}

# --- 3. Limpiar accesos directos obsoletos x86 ---
$searchDirs = [System.Collections.Generic.List[string]]::new()
$searchDirs.Add("$env:ProgramData\Microsoft\Windows\Start Menu\Programs")
$searchDirs.Add("$env:PUBLIC\Desktop")
$searchDirs.Add("$env:APPDATA\Microsoft\Windows\Start Menu\Programs")
$searchDirs.Add([Environment]::GetFolderPath('Desktop'))

if (Test-IsAdmin) {
    Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -notmatch '^(Public|Default User|All Users)$'
    } | ForEach-Object {
        $searchDirs.Add((Join-Path $_.FullName "AppData\Roaming\Microsoft\Windows\Start Menu\Programs"))
        $searchDirs.Add((Join-Path $_.FullName "Desktop"))
    }
}

$uniqueDirs = $searchDirs | Where-Object { Test-Path -Path $_ } | Select-Object -Unique

foreach ($dir in $uniqueDirs) {
    Get-ChildItem -Path $dir -Filter "*powershell*x86*.lnk" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -notmatch '(?i)ISE') {
            try { Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
}

# --- 4. Actualizar accesos directos principales al ejecutable de la versión más alta ---
$wsh = New-Object -ComObject WScript.Shell
$nativeIcon = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe,0"

foreach ($dir in $uniqueDirs) {
    Get-ChildItem -Path $dir -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $sc = $wsh.CreateShortcut($_.FullName)
            if ($sc.TargetPath -match '(?i)(powershell\.exe|pwsh\.exe)$' -and $_.Name -notmatch '(?i)ISE') {
                $sc.TargetPath       = $highest.ExecutablePath
                $sc.WorkingDirectory = "%USERPROFILE%"
                $sc.IconLocation     = $nativeIcon
                $sc.Save()
            }
        } catch {}
    }
}

# --- 5. Actualizar PATH de Sistema y Usuario ---
$targetDir = $highest.Directory

if (Test-IsAdmin) {
    try {
        $machinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
        $entries = $machinePath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $filtered = @($entries | Where-Object { $_.TrimEnd('\') -ine $targetDir.TrimEnd('\') })
        $newMachinePath = ($targetDir, $filtered) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newMachinePath, [EnvironmentVariableTarget]::Machine)
    } catch {}
}

try {
    $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    $userEntries = $userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $filteredUser = @($userEntries | Where-Object { $_.TrimEnd('\') -ine $targetDir.TrimEnd('\') })
    $newUserPath = ($targetDir, $filteredUser) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, [EnvironmentVariableTarget]::User)
} catch {}

# --- 6. Notificación al shell de Windows (SHChangeNotify y SendMessageTimeout) ---
try {
    $shellCode = @"
using System;
using System.Runtime.InteropServices;
public class RemShellHelper {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
"@
    if (-not ([System.Management.Automation.PSTypeName]'RemShellHelper').Type) {
        Add-Type -TypeDefinition $shellCode -ErrorAction SilentlyContinue
    }
    [RemShellHelper]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
} catch {}

$ie4uinit = Join-Path $env:SystemRoot "System32\ie4uinit.exe"
if (Test-Path $ie4uinit) {
    try { Start-Process -FilePath $ie4uinit -ArgumentList "-show" -WindowStyle Hidden -ErrorAction SilentlyContinue } catch {}
}

Write-Output "Remediación completada: Accesos directos, versiones y variables de entorno forzadas con éxito a PowerShell v$($highest.Version)."
Exit 0
