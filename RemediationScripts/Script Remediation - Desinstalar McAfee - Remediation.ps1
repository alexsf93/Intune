<#
.SYNOPSIS
    REMEDIATION SCRIPT: ELIMINAR COMPLETAMENTE MCAFEE Y TRELLIX

.DESCRIPTION
    Este script detiene procesos relacionados con McAfee/Trellix, ejecuta los desinstaladores
    nativos silenciosamente si están disponibles, detiene/deshabilita/elimina todos sus servicios,
    y borra de forma forzada todos los archivos, carpetas, claves de registro y accesos directos
    residuales del sistema.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Desinstalar McAfee - Remediation.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.0.0
    Date: 2026-06-29
    Context: System
#>

# Forzar codificacion UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Comprobar privilegios de administrador/SYSTEM
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "CORRECCION: ERROR: El script requiere ejecutarse con privilegios elevados (Administrator/SYSTEM)."
    exit 1
}

# 1. Asegurar entorno de ejecucion de 64 bits
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Host "CORRECCION: Ejecutando en proceso de 32 bits. Relanzando en PowerShell de 64 bits..."
    $powershell64 = Join-Path $env:SystemRoot "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $powershell64) {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process -FilePath $powershell64 -ArgumentList $arguments -Wait -NoNewWindow
        exit $LASTEXITCODE
    } else {
        Write-Host "CORRECCION: No se pudo encontrar el ejecutable de PowerShell de 64 bits en Sysnative. Continuando en modo actual."
    }
}

Write-Host "CORRECCION: Iniciando proceso de eliminacion total de McAfee / Trellix..."

# =============================================================================
# PASO 1: Detener procesos activos para desbloquear archivos
# =============================================================================
Write-Host "--- Paso 1: Finalizando procesos activos de McAfee/Trellix ---"
$ProcessPatterns = @(
    "*McAfee*", "*Trellix*", "mcshield*", "masvc*", "macmnsvc*", "mfevtps*", 
    "mfemms*", "McUICnt*", "cmdagent*", "Mcchs*", "mcui*", "mcagent*", 
    "mcupdmgr*", "mfefire*", "mfetp*", "macompatsvc*", "WebAdvisor*"
)

foreach ($pattern in $ProcessPatterns) {
    try {
        Get-Process -Name $pattern -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "  Terminando proceso: $($_.Name) (PID: $($_.Id))"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "  Advertencia al terminar proceso por patron '$pattern': $_"
    }
}
Start-Sleep -Seconds 2

# =============================================================================
# PASO 2: Desinstalacion silenciosa nativa desde el Registro
# =============================================================================
Write-Host "--- Paso 2: Ejecutando desinstaladores nativos desde el Registro ---"
$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($path in $UninstallPaths) {
    try {
        $keys = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        foreach ($key in $keys) {
            $displayName = $key.DisplayName
            $publisher = $key.Publisher
            $psChildName = $key.PSChildName
            
            $isMcAfee = ($null -ne $displayName -and ($displayName -like "*McAfee*" -or $displayName -like "*Trellix*")) -or
                        ($null -ne $publisher -and ($publisher -like "*McAfee*" -or $publisher -like "*Trellix*"))
            
            if ($isMcAfee) {
                $uninstallString = $key.UninstallString
                $quietUninstallString = $key.QuietUninstallString
                
                $uninstallCommand = ""
                if ($quietUninstallString) {
                    $uninstallCommand = $quietUninstallString
                } elseif ($uninstallString) {
                    if ($uninstallString -match '({[A-Z0-9\-]+})' -or $uninstallString -like "*MsiExec.exe*") {
                        if ($uninstallString -match '({[A-Z0-9\-]+})') {
                            $guid = $Matches[1]
                            $uninstallCommand = "msiexec.exe /X $guid /qn /norestart"
                        } else {
                            $uninstallCommand = $uninstallString -replace "/I", "/X"
                            if ($uninstallCommand -notlike "*/qn*") {
                                $uninstallCommand = "$uninstallCommand /qn /norestart"
                            }
                        }
                    } elseif ($uninstallString -like "*uninst.exe*" -or $uninstallString -like "*uninstall.exe*") {
                        $cleanUninstallString = $uninstallString -replace '"', ''
                        if ($cleanUninstallString -notlike "*/S*" -and $cleanUninstallString -notlike "*/s*") {
                            $uninstallCommand = "`"$cleanUninstallString`" /S /silent /quiet"
                        } else {
                            $uninstallCommand = $uninstallString
                        }
                    } else {
                        $uninstallCommand = "$uninstallString /S /silent /quiet /qn /norestart"
                    }
                }
                
                if ($uninstallCommand) {
                    Write-Host "  Ejecutando desinstalacion para: $displayName ($psChildName) -> $uninstallCommand"
                    try {
                        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallCommand" -Wait -NoNewWindow -PassThru
                        Write-Host "    -> Codigo de salida uninstaller: $($proc.ExitCode)"
                    } catch {
                        Write-Host "    -> Advertencia: No se pudo iniciar desinstalador nativo para $displayName ($($_.Exception.Message))"
                    }
                }
            }
        }
    } catch {
        # Ignorar errores de registro
    }
}
Start-Sleep -Seconds 5

# =============================================================================
# PASO 3: Detener, deshabilitar y eliminar servicios y controladores
# =============================================================================
Write-Host "--- Paso 3: Deteniendo y eliminando servicios de McAfee/Trellix ---"
$McAfeeServices = Get-Service -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -like "*McAfee*" -or 
    $_.DisplayName -like "*McAfee*" -or 
    $_.Name -like "*Trellix*" -or 
    $_.DisplayName -like "*Trellix*" -or
    $_.Name -like "mfe*" -or
    $_.Name -like "masvc*" -or
    $_.Name -like "macmnsvc*" -or
    $_.Name -like "Mcamnsmt*"
}

foreach ($svc in $McAfeeServices) {
    try {
        Write-Host "  Procesando servicio: $($svc.Name) ($($svc.DisplayName))"
        # Intentar detener
        if ($svc.Status -ne "Stopped") {
            Write-Host "    -> Deteniendo..."
            Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
        }
        # Deshabilitar
        Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
        # Eliminar
        Write-Host "    -> Eliminando..."
        sc.exe delete $svc.Name | Out-Null
    } catch {
        Write-Host "    -> Advertencia con servicio $($svc.Name): $_"
    }
}

# =============================================================================
# PASO 4: Limpiar directorios fisicos y archivos residuales
# =============================================================================
Write-Host "--- Paso 4: Limpiando directorios fisicos residuales ---"
$FoldersToDelete = @(
    "$env:ProgramFiles\McAfee",
    "${env:ProgramFiles(x86)}\McAfee",
    "$env:ProgramData\McAfee",
    "$env:ProgramFiles\McAfee.com",
    "${env:ProgramFiles(x86)}\McAfee.com",
    "$env:ProgramFiles\Trellix",
    "${env:ProgramFiles(x86)}\Trellix",
    "$env:ProgramData\Trellix"
)

# Obtener perfiles de usuarios locales para AppData
$userProfiles = @()
try {
    $userProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
    foreach ($userProfile in $userProfiles) {
        $username = $userProfile.Name
        if ($username -notin @("Public", "Default", "All Users")) {
            $userDir = $userProfile.FullName
            $FoldersToDelete += @(
                "$userDir\AppData\Local\McAfee",
                "$userDir\AppData\Roaming\McAfee",
                "$userDir\AppData\Local\Trellix",
                "$userDir\AppData\Roaming\Trellix"
            )
        }
    }
} catch {
    # Ignorar errores al buscar usuarios
}

foreach ($folder in $FoldersToDelete) {
    if (Test-Path $folder) {
        Write-Host "  Eliminando carpeta: $folder"
        try {
            Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
            Write-Host "    -> Eliminada con exito."
        } catch {
            Write-Host "    -> Advertencia al eliminar carpeta: $_. Reintentando por cmd..."
            try {
                cmd.exe /c "rmdir /s /q `"$folder`""
            } catch {}
        }
    }
}

# =============================================================================
# PASO 5: Limpiar claves de registro residuales
# =============================================================================
Write-Host "--- Paso 5: Limpiando claves de registro residuales ---"
$RegistryPathsToSearch = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

# 5.1 Eliminar del Registro de Desinstalacion de Windows
foreach ($path in $RegistryPathsToSearch) {
    try {
        $keys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        foreach ($subkey in $keys) {
            $displayName = (Get-ItemProperty -Path $subkey.PSPath -ErrorAction SilentlyContinue).DisplayName
            $publisher = (Get-ItemProperty -Path $subkey.PSPath -ErrorAction SilentlyContinue).Publisher
            
            $isMcAfee = ($null -ne $displayName -and ($displayName -like "*McAfee*" -or $displayName -like "*Trellix*")) -or
                        ($null -ne $publisher -and ($publisher -like "*McAfee*" -or $publisher -like "*Trellix*"))
            
            if ($isMcAfee) {
                Write-Host "  Eliminando clave de desinstalacion del registro: $($subkey.PSPath)"
                Remove-Item -Path $subkey.PSPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        # Ignorar errores
    }
}

# 5.2 Eliminar Claves de Software
$SoftwareKeys = @(
    "HKLM:\SOFTWARE\McAfee",
    "HKLM:\SOFTWARE\Wow6432Node\McAfee",
    "HKCU:\Software\McAfee",
    "HKLM:\SOFTWARE\Trellix",
    "HKLM:\SOFTWARE\Wow6432Node\Trellix",
    "HKCU:\Software\Trellix",
    "HKLM:\SOFTWARE\McAfee.com",
    "HKLM:\SOFTWARE\Wow6432Node\McAfee.com",
    "HKCU:\Software\McAfee.com"
)

foreach ($key in $SoftwareKeys) {
    if (Test-Path $key) {
        Write-Host "  Eliminando clave de software: $key"
        try {
            Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "    -> Advertencia al eliminar clave $($key): $_"
        }
    }
}

# 5.3 Eliminar Claves de Software de usuarios cargados actualmente (HKEY_USERS)
try {
    $loadedUserHives = Get-ChildItem -Path "Registry::HKEY_USERS" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^S-1-5-21-[\d\-]+$' }
    foreach ($hive in $loadedUserHives) {
        $sid = $hive.PSChildName
        $userSoftwareKeys = @(
            "Registry::HKEY_USERS\$sid\Software\McAfee",
            "Registry::HKEY_USERS\$sid\Software\Trellix",
            "Registry::HKEY_USERS\$sid\Software\McAfee.com"
        )
        foreach ($key in $userSoftwareKeys) {
            if (Test-Path $key) {
                Write-Host "  Eliminando clave de software de usuario ($sid): $key"
                try {
                    Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
                } catch {
                    Write-Host "    -> Advertencia al eliminar clave de usuario $($key): $_"
                }
            }
        }
    }
} catch {
    # Ignorar errores
}

# =============================================================================
# PASO 6: Limpiar accesos directos residuales
# =============================================================================
Write-Host "--- Paso 6: Eliminando accesos directos residuales ---"
$ShortcutPatterns = @("*McAfee*", "*Trellix*")
$ShortcutPaths = @(
    "C:\Users\Public\Desktop",
    "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
)

foreach ($userProfile in $userProfiles) {
    $username = $userProfile.Name
    if ($username -notin @("Public", "Default", "All Users")) {
        $userDir = $userProfile.FullName
        $ShortcutPaths += @(
            "$userDir\Desktop",
            "$userDir\AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
        )
    }
}

foreach ($folderPath in $ShortcutPaths) {
    if (Test-Path $folderPath) {
        # 1. Eliminar accesos directos (.lnk)
        foreach ($pattern in $ShortcutPatterns) {
            try {
                Get-ChildItem -Path $folderPath -Filter "$pattern.lnk" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                    Write-Host "  Eliminando acceso directo: $($_.FullName)"
                    Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                }
            } catch {
                # Ignorar errores
            }
        }
        # 2. Eliminar carpetas residuales de Start Menu y Escritorio
        try {
            Get-ChildItem -Path $folderPath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -like "*McAfee*" -or $_.Name -like "*Trellix*"
            } | ForEach-Object {
                Write-Host "  Eliminando carpeta de Start Menu/Escritorio: $($_.FullName)"
                Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        } catch {
            # Ignorar errores
        }
    }
}

Write-Host "CORRECCION: Proceso de remediacion de McAfee / Trellix completado con exito."
exit 0
