<#
.SYNOPSIS
    DETECTION SCRIPT: DETECTAR EL JUEGO "WARCRAFT I Y II REMASTERED" (ELAMIGOS)

.DESCRIPTION
    Este script comprueba si el juego "Warcraft I and II Remastered" (de ElAmigos u otros instaladores)
    está presente en el sistema. Busca en el registro de desinstalación (HKLM, HKCU, HKEY_USERS),
    en rutas de instalación física comunes, accesos directos y procesos activos.

    Salida:
      - Exit 1: El juego fue detectado -> Intune activa la remediación.
      - Exit 0: El dispositivo está limpio -> No se requiere acción.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Desinstalar Warcraft I y II Remastered - Detection.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.0.0
    Date: 2026-06-27
    Context: System
#>

$OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Asegurar entorno de ejecución de 64 bits para evitar redirección de carpetas y registro
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Host "DETECCION: Ejecutando en proceso de 32 bits. Relanzando en PowerShell de 64 bits..."
    $powershell64 = Join-Path $env:SystemRoot "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $powershell64) {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process -FilePath $powershell64 -ArgumentList $arguments -Wait -NoNewWindow
        exit $LASTEXITCODE
    } else {
        Write-Host "DETECCION: No se pudo encontrar el ejecutable de PowerShell de 64 bits en Sysnative. Continuando en modo actual."
    }
}

$detected = $false
$Reasons = [System.Collections.Generic.List[string]]::new()

Write-Host "DETECCION: Iniciando auditoria de 'Warcraft I and II Remastered'..."

# =============================================================================
# 2. Comprobación de Procesos Activos
# =============================================================================
$ProcessNames = @(
    "Warcraft I Remastered",
    "Warcraft II Remastered",
    "Warcraft 1 Remastered",
    "Warcraft 2 Remastered",
    "Warcraft I Remastered Launcher",
    "Warcraft II Remastered Launcher"
)

foreach ($procName in $ProcessNames) {
    $processes = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($processes) {
        $detected = $true
        foreach ($proc in $processes) {
            $Reasons.Add("Proceso activo detectado: $($proc.Name) (PID: $($proc.Id))")
        }
    }
}

# =============================================================================
# 3. Comprobación en Registro (Uninstall Keys)
# =============================================================================
$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$SearchPatterns = @(
    "*Warcraft I and II Remastered*",
    "*Warcraft I & II Remastered*",
    "*Warcraft*ElAmigos*"
)

# 3.1 Buscar en registros del sistema estándar (HKLM/HKCU del usuario que ejecuta)
foreach ($path in $UninstallPaths) {
    if (Test-Path (Split-Path $path -Parent)) {
        try {
            $keys = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            foreach ($key in $keys) {
                $displayName = $key.DisplayName
                $psChildName = $key.PSChildName
                if ($null -ne $displayName) {
                    foreach ($pattern in $SearchPatterns) {
                        if ($displayName -like $pattern) {
                            $detected = $true
                            $Reasons.Add("Registro de desinstalacion detectado: '$displayName' (Clave: $psChildName en $path)")
                            break
                        }
                    }
                }
            }
        } catch {
            # Omitir errores de ruta
        }
    }
}

# 3.2 Buscar en perfiles de usuario cargados en HKEY_USERS (HKU)
try {
    $loadedUsers = Get-ChildItem -Path "Registry::HKEY_USERS" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like "S-1-5-21-*" -and $_.PSChildName -notlike "*-Classes" }
    foreach ($user in $loadedUsers) {
        $sid = $user.PSChildName
        $userUninstallPath = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        if (Test-Path (Split-Path $userUninstallPath -Parent)) {
            $keys = Get-ItemProperty -Path $userUninstallPath -ErrorAction SilentlyContinue
            foreach ($key in $keys) {
                $displayName = $key.DisplayName
                if ($null -ne $displayName) {
                    foreach ($pattern in $SearchPatterns) {
                        if ($displayName -like $pattern) {
                            $detected = $true
                            $Reasons.Add("Registro de desinstalacion detectado en perfil cargado (SID: $sid): '$displayName'")
                            break
                        }
                    }
                }
            }
        }
    }
} catch {
    # Omitir errores
}

# =============================================================================
# 4. Comprobación de Rutas Físicas de Instalación Comunes
# =============================================================================
$CommonInstallDirs = [System.Collections.Generic.List[string]]::new()

# Directorios de instalación comunes conocidos
$KnownDirs = @(
    "C:\Games\Warcraft I and II Remastered",
    "C:\Games\Warcraft I & II Remastered",
    "C:\Games\Warcraft I and II Remastered MULTi11 - ElAmigos",
    "$env:ProgramFiles\Warcraft I and II Remastered",
    "${env:ProgramFiles(x86)}\Warcraft I and II Remastered",
    "$env:ProgramFiles\Warcraft I & II Remastered",
    "${env:ProgramFiles(x86)}\Warcraft I & II Remastered"
)
foreach ($kd in $KnownDirs) { $CommonInstallDirs.Add($kd) }

# Escanear dinámicamente directorios relacionados con Warcraft en C:\Games
if (Test-Path "C:\Games") {
    try {
        $dynamicGames = Get-ChildItem -Path "C:\Games" -Directory -Filter "*Warcraft*" -ErrorAction SilentlyContinue
        foreach ($dg in $dynamicGames) {
            if ($CommonInstallDirs -notcontains $dg.FullName) { $CommonInstallDirs.Add($dg.FullName) }
        }
    } catch {}
}

# Escanear también perfiles de usuario C:\Users\<usuario>\Games o similar
$profiles = Get-ChildItem -Path "C:\Users" -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }
foreach ($profile in $profiles) {
    if ($profile.Name -in @("All Users", "Default", "Default User", "Public")) { continue }
    $userPath = $profile.FullName
    
    # Agregar directorios fijos
    $CommonInstallDirs.Add((Join-Path $userPath "Games\Warcraft I and II Remastered"))
    $CommonInstallDirs.Add((Join-Path $userPath "Games\Warcraft I & II Remastered"))
    $CommonInstallDirs.Add((Join-Path $userPath "AppData\Local\Programs\Warcraft I and II Remastered"))

    # Escanear dinámicamente el directorio Games del usuario
    $userGames = Join-Path $userPath "Games"
    if (Test-Path $userGames) {
        try {
            $dynamicUserGames = Get-ChildItem -Path $userGames -Directory -Filter "*Warcraft*" -ErrorAction SilentlyContinue
            foreach ($dug in $dynamicUserGames) {
                if ($CommonInstallDirs -notcontains $dug.FullName) { $CommonInstallDirs.Add($dug.FullName) }
            }
        } catch {}
    }

    # Datos y partidas guardadas residuales específicas de la versión ElAmigos/Crack y del juego
    $CommonInstallDirs.Add((Join-Path $userPath "AppData\Local\Warcraft I Remastered"))
    $CommonInstallDirs.Add((Join-Path $userPath "AppData\Local\Warcraft II Remastered"))
    $CommonInstallDirs.Add((Join-Path $userPath "AppData\Roaming\Warcraft I Remastered"))
    $CommonInstallDirs.Add((Join-Path $userPath "AppData\Roaming\Warcraft II Remastered"))
    $CommonInstallDirs.Add((Join-Path $userPath "Saved Games\Warcraft I Remastered"))
    $CommonInstallDirs.Add((Join-Path $userPath "Saved Games\Warcraft II Remastered"))
    $CommonInstallDirs.Add((Join-Path $userPath "Documents\Warcraft I Remastered"))
    $CommonInstallDirs.Add((Join-Path $userPath "Documents\Warcraft II Remastered"))
}

foreach ($dir in $CommonInstallDirs) {
    if (Test-Path $dir -ErrorAction SilentlyContinue) {
        # Verificar si contiene ejecutables relacionados para evitar falsos positivos
        $executables = Get-ChildItem -Path $dir -Filter "*.exe" -File -ErrorAction SilentlyContinue | Where-Object { 
            $_.Name -like "*Warcraft*.exe" -or $_.Name -like "*unins*.exe"
        }
        if ($executables.Count -gt 0) {
            $detected = $true
            $Reasons.Add("Directorio del juego detectado en: $dir (Contiene ejecutables: $($executables.Name -join ', '))")
        }
    }
}

# =============================================================================
# 5. Comprobación de Accesos Directos (.lnk)
# =============================================================================
$ShortcutPaths = [System.Collections.Generic.List[string]]::new()
if (Test-Path "C:\Users\Public\Desktop") { $ShortcutPaths.Add("C:\Users\Public\Desktop") }
if (Test-Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs") { $ShortcutPaths.Add("$env:ProgramData\Microsoft\Windows\Start Menu\Programs") }

foreach ($profile in $profiles) {
    if ($profile.Name -in @("All Users", "Default", "Default User", "Public")) { continue }
    $userPath = $profile.FullName
    $userDesktop = Join-Path $userPath "Desktop"
    $userStartMenu = Join-Path $userPath "AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
    if (Test-Path $userDesktop) { $ShortcutPaths.Add($userDesktop) }
    if (Test-Path $userStartMenu) { $ShortcutPaths.Add($userStartMenu) }
}

$lnkFiles = @()
foreach ($dir in $ShortcutPaths) {
    $lnkFiles += Get-ChildItem -Path $dir -Filter "*.lnk" -Recurse -File -ErrorAction SilentlyContinue
}

if ($lnkFiles.Count -gt 0) {
    try {
        $wshShell = New-Object -ComObject WScript.Shell
        foreach ($file in $lnkFiles) {
            # Si el nombre del acceso directo contiene Warcraft, auditar su destino
            if ($file.Name -like "*Warcraft*") {
                try {
                    $shortcut = $wshShell.CreateShortcut($file.FullName)
                    $target = $shortcut.TargetPath
                    if ($target -like "*Warcraft*" -or $target -like "*unins000.exe*") {
                        $detected = $true
                        $Reasons.Add("Acceso directo detectado: $($file.FullName) (Apunta a: $target)")
                    }
                } catch {
                    # Omitir fallos de accesos directos
                }
            }
        }
    } catch {
        # Omitir fallos de inicialización COM
    }
}

# =============================================================================
# 6. Evaluación Final y Salida
# =============================================================================
if ($detected) {
    Write-Host "DETECCION: No conforme. Se detectaron trazas de Warcraft I y II Remastered."
    foreach ($reason in $Reasons) {
        Write-Host "DETECCION: Detalle -> $reason"
    }
    exit 1
} else {
    Write-Host "DETECCION: Conforme. No se ha encontrado ninguna traza de Warcraft I y II Remastered."
    exit 0
}
