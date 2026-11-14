<#
.SYNOPSIS
    REMEDIATION SCRIPT: FORZAR VERSION MAS ALTA DE POWERSHELL, LIMPIAR VERSIONES OBSOLETAS Y ACTUALIZAR ACCESOS E ICONOS

.DESCRIPTION
    Script de remediacion periodica para Microsoft Intune.
    Realiza las siguientes acciones correctivas:
    1. Desinstala versiones intermedias obsoletas de PowerShell 7.x conservando unicamente la 5.1 y la mas reciente.
    2. Elimina los accesos directos obsoletos de 32 bits (x86) en perfiles de usuario y ProgramData.
    3. Actualiza todos los accesos directos de PowerShell al ejecutable de la version mas alta (pwsh.exe).
    4. Configura el perfil por defecto de Windows Terminal a PowerShell 7 / Core en los perfiles de usuario.
    5. Antepone el directorio de la version mas alta a la variable PATH del Sistema.
    6. Refresca la cache del shell y el indexador de Windows Search en caliente sin necesidad de reinicios.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name:       Script Remediation - Forzar version mas alta PowerShell - Remediation.ps1
    Author:     Alejandro Suarez (@alexsf93)
    Date:       2026-11-14
    Version:    1.2.0
    Context:    System
#>

$ErrorActionPreference = 'SilentlyContinue'

function Test-IsAdminOrSystem {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        if ($identity.IsSystem) { return $true }
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

try {
    # --- 1. Deteccion exhaustiva de versiones instaladas ---
    $detected = [System.Collections.Generic.List[PSCustomObject]]::new()

    $searchPaths = @(
        "$env:ProgramFiles\PowerShell\*\pwsh.exe",
        "${env:ProgramFiles(x86)}\PowerShell\*\pwsh.exe",
        "C:\Program Files\PowerShell\*\pwsh.exe",
        "C:\Program Files (x86)\PowerShell\*\pwsh.exe"
    )

    Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -notmatch '^(Public|All Users)$'
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
                    IconSource     = $_.FullName
                    InstallType    = "MSI/Win32"
                })
            }
        }
    }

    # AppX / MSIX / Store
    try {
        Get-AppxPackage -AllUsers -Name "*PowerShell*" -ErrorAction SilentlyContinue | ForEach-Object {
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

    # Windows PowerShell 5.1
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
        Write-Output "No se encontraron instalaciones de PowerShell en el equipo."
        Exit 0
    }

    $highest = ($detected | Sort-Object -Property Version -Descending) | Select-Object -First 1

    if ($highest.Version.Major -lt 6) {
        Write-Output "Solo existe Windows PowerShell 5.1 instalado. Sin cambios requeridos."
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
                    try {
                        Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $code /qn /norestart" -Wait -NoNewWindow -ErrorAction SilentlyContinue
                    } catch {}
                }
            }
        }
    }

    # Deshabilitar PowerShell 2.0 opcional por seguridad
    if (Test-IsAdminOrSystem) {
        try {
            $ps2 = Get-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2Root" -ErrorAction SilentlyContinue
            if ($ps2 -and $ps2.State -eq 'Enabled') {
                Disable-WindowsOptionalFeature -Online -FeatureName "MicrosoftWindowsPowerShellV2Root" -NoRestart -ErrorAction SilentlyContinue | Out-Null
            }
        } catch {}
    }

    # --- 3. Limpiar accesos directos obsoletos x86 en todos los ambitos ---
    $searchDirs = [System.Collections.Generic.List[string]]::new()
    $searchDirs.Add("$env:ProgramData\Microsoft\Windows\Start Menu\Programs")
    $searchDirs.Add("$env:PUBLIC\Desktop")
    $searchDirs.Add("$env:APPDATA\Microsoft\Windows\Start Menu\Programs")
    $searchDirs.Add([Environment]::GetFolderPath('Desktop'))

    Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -notmatch '^(Public|All Users)$'
    } | ForEach-Object {
        $searchDirs.Add((Join-Path $_.FullName "AppData\Roaming\Microsoft\Windows\Start Menu\Programs"))
        $searchDirs.Add((Join-Path $_.FullName "Desktop"))
    }

    $uniqueDirs = $searchDirs | Where-Object { Test-Path -Path $_ } | Select-Object -Unique

    foreach ($dir in $uniqueDirs) {
        Get-ChildItem -Path $dir -Filter "*powershell*x86*.lnk" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Name -notmatch '(?i)ISE') {
                try { Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue } catch {}
            }
        }
    }

    # --- 4. Actualizar accesos directos principales al ejecutable de la version mas alta ---
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

    # --- 5. Configurar perfil predeterminado de Windows Terminal ---
    $pwshGuid = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"
    Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -notmatch '^(Public|All Users)$'
    } | ForEach-Object {
        $settingsPath = Join-Path $_.FullName "AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        if (Test-Path $settingsPath) {
            try {
                $raw = Get-Content -Path $settingsPath -Raw -ErrorAction SilentlyContinue
                if ($raw) {
                    $cleanJson = $raw -replace '(?m)^\s*//.*$', ''
                    $json = $cleanJson | ConvertFrom-Json -ErrorAction SilentlyContinue
                    if ($json) {
                        $targetGuid = $pwshGuid
                        if ($json.profiles.list) {
                            $foundProf = $json.profiles.list | Where-Object {
                                $_.name -match '(?i)^PowerShell$' -or $_.source -match '(?i)PowershellCore' -or $_.commandline -match '(?i)pwsh\.exe'
                            } | Select-Object -First 1
                            if ($foundProf -and $foundProf.guid) {
                                $targetGuid = $foundProf.guid
                            }
                        }
                        $json.defaultProfile = $targetGuid
                        $json | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8 -Force
                    }
                }
            } catch {}
        }
    }

    # --- 6. Actualizar PATH de Sistema de forma segura ---
    $targetDir = $highest.Directory
    try {
        $machinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
        $entries = $machinePath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $filtered = @($entries | Where-Object { $_.TrimEnd('\') -ine $targetDir.TrimEnd('\') })
        $newMachinePath = (@($targetDir) + $filtered) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newMachinePath, [EnvironmentVariableTarget]::Machine)
    } catch {}

    # --- 7. Refresco en caliente de la cache del shell y Windows Search ---
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

    try {
        Get-Process -Name "SearchHost" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    } catch {}

    Write-Output "Remediacion completada: Accesos directos, perfil de Terminal y PATH configurados con exito a PowerShell v$($highest.Version)."
    Exit 0

} catch {
    Write-Output "Error durante la remediacion: $($_.Exception.Message)"
    Exit 1
}
