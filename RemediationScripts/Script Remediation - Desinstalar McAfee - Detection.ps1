<#
.SYNOPSIS
    DETECTION SCRIPT: DETECTAR CUALQUIER INSTALACION O RUTA DE MCAFEE / TRELLIX

.DESCRIPTION
    Este script audita el sistema de forma exhaustiva para comprobar si hay alguna
    aplicacion, proceso, servicio, directorio o clave de registro relacionada con McAfee o Trellix.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Desinstalar McAfee - Detection.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.0.0
    Date: 2026-06-29
    Context: System
#>

# Forzar codificacion UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Asegurar entorno de ejecucion de 64 bits
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

Write-Host "DETECCION: Iniciando auditoria exhaustiva de McAfee / Trellix en el sistema..."

# 2. Comprobacion de Claves de Registro (Uninstall)
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
            
            if ($null -ne $displayName -and ($displayName -like "*McAfee*" -or $displayName -like "*Trellix*")) {
                $detected = $true
                $Reasons.Add("Registro de desinstalacion detectado por nombre: $displayName (Publisher: $publisher, Clave: $psChildName)")
            }
            elseif ($null -ne $publisher -and ($publisher -like "*McAfee*" -or $publisher -like "*Trellix*")) {
                $detected = $true
                $Reasons.Add("Registro de desinstalacion detectado por fabricante: $displayName (Publisher: $publisher, Clave: $psChildName)")
            }
        }
    } catch {
        # Ignorar errores de rutas inexistentes
    }
}

# 3. Comprobacion de Servicios Activos / Instalados
try {
    $services = Get-Service -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like "*McAfee*" -or 
        $_.DisplayName -like "*McAfee*" -or 
        $_.Name -like "*Trellix*" -or 
        $_.DisplayName -like "*Trellix*" -or
        $_.Name -like "mfe*" -or
        $_.Name -like "masvc*" -or
        $_.Name -like "macmnsvc*" -or
        $_.Name -like "Mcamnsmt*"
    }
    if ($services) {
        $detected = $true
        foreach ($svc in $services) {
            $Reasons.Add("Servicio de McAfee/Trellix detectado: $($svc.Name) (Estado: $($svc.Status), Mostrar Nombre: $($svc.DisplayName))")
        }
    }
} catch {
    Write-Host "DETECCION: Error al comprobar servicios: $_"
}

# 4. Comprobacion de Procesos Activos
try {
    $processes = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like "*McAfee*" -or 
        $_.Name -like "*Trellix*" -or
        $_.Name -like "mcshield*" -or
        $_.Name -like "masvc*" -or
        $_.Name -like "macmnsvc*" -or
        $_.Name -like "mfevtps*" -or
        $_.Name -like "mfemms*" -or
        $_.Name -like "McUICnt*" -or
        $_.Name -like "cmdagent*" -or
        $_.Name -like "Mcchs*" -or
        $_.Name -like "mcui*" -or
        $_.Name -like "mcagent*" -or
        $_.Name -like "mcupdmgr*" -or
        $_.Name -like "mfefire*" -or
        $_.Name -like "mfetp*" -or
        $_.Name -like "macompatsvc*" -or
        $_.Name -like "WebAdvisor*" -or
        $_.Company -like "*McAfee*" -or 
        $_.Company -like "*Trellix*" -or 
        $_.Description -like "*McAfee*" -or 
        $_.Description -like "*Trellix*"
    }
    if ($processes) {
        $detected = $true
        foreach ($proc in $processes) {
            $Reasons.Add("Proceso activo de McAfee/Trellix detectado: $($proc.Name) (PID: $($proc.Id), Compañia: $($proc.Company))")
        }
    }
} catch {
    Write-Host "DETECCION: Error al comprobar procesos: $_"
}

# 5. Comprobacion de Rutas Fisicas Comunes
$PhysicalPaths = @(
    "$env:ProgramFiles\McAfee",
    "${env:ProgramFiles(x86)}\McAfee",
    "$env:ProgramData\McAfee",
    "$env:ProgramFiles\McAfee.com",
    "${env:ProgramFiles(x86)}\McAfee.com",
    "$env:ProgramFiles\Trellix",
    "${env:ProgramFiles(x86)}\Trellix",
    "$env:ProgramData\Trellix"
)

# Buscar carpetas de usuario
$userProfiles = @()
try {
    $userProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
    foreach ($userProfile in $userProfiles) {
        $username = $userProfile.Name
        if ($username -notin @("Public", "Default", "All Users")) {
            $userDir = $userProfile.FullName
            $PhysicalPaths += @(
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

foreach ($path in $PhysicalPaths) {
    if (Test-Path $path -ErrorAction SilentlyContinue) {
        $detected = $true
        $Reasons.Add("Directorio fisico de McAfee/Trellix detectado: $path")
    }
}

# 5.1 Comprobacion de Claves de Registro de Software adicionales (Regedit)
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
    if (Test-Path $key -ErrorAction SilentlyContinue) {
        $detected = $true
        $Reasons.Add("Clave de registro de software de McAfee/Trellix detectada: $key")
    }
}

# Comprobar claves de software de usuarios cargados actualmente (HKEY_USERS)
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
            if (Test-Path $key -ErrorAction SilentlyContinue) {
                $detected = $true
                $Reasons.Add("Clave de registro de usuario ($sid) de McAfee/Trellix detectada: $key")
            }
        }
    }
} catch {
    # Ignorar errores
}

# 5.2 Comprobacion de Accesos Directos en Start Menu y Escritorio
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
    if (Test-Path $folderPath -ErrorAction SilentlyContinue) {
        # 1. Comprobar accesos directos (.lnk)
        foreach ($pattern in $ShortcutPatterns) {
            try {
                $shortcuts = Get-ChildItem -Path $folderPath -Filter "$pattern.lnk" -Recurse -ErrorAction SilentlyContinue
                if ($shortcuts) {
                    $detected = $true
                    foreach ($lnk in $shortcuts) {
                        $Reasons.Add("Acceso directo de McAfee/Trellix detectado: $($lnk.FullName)")
                    }
                }
            } catch {
                # Ignorar errores al buscar accesos directos
            }
        }
        # 2. Comprobar carpetas residuales en Start Menu y Escritorio
        try {
            $subfolders = Get-ChildItem -Path $folderPath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -like "*McAfee*" -or $_.Name -like "*Trellix*"
            }
            if ($subfolders) {
                $detected = $true
                foreach ($sub in $subfolders) {
                    $Reasons.Add("Directorio de Start Menu/Escritorio de McAfee/Trellix detectado: $($sub.FullName)")
                }
            }
        } catch {
            # Ignorar errores al buscar carpetas
        }
    }
}

# 6. Evaluacion Final y Salida
if ($detected) {
    Write-Host "DETECCION: No conforme. Se detectaron trazas de McAfee o Trellix en el equipo."
    foreach ($reason in $Reasons) {
        Write-Host "DETECCION: Detalle -> $reason"
    }
    exit 1
} else {
    Write-Host "DETECCION: Conforme. No se ha encontrado ninguna traza de McAfee o Trellix."
    exit 0
}
