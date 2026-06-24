<#
.SYNOPSIS
    REMEDIATION SCRIPT: ELIMINAR COMPLETAMENTE LA APLICACION "MOVE MOUSE"

.DESCRIPTION
    Este script elimina por completo y de forma definitiva la aplicacion "Move Mouse"
    (tanto la version UWP/Store como ejecutables independientes) para todos los usuarios.
    Realiza una post-auditoria para asegurar la efectividad de la remediacion.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Desinstalar Move Mouse - Remediation.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.0.0
    Date: 2026-06-23
    Context: System
#>

# Forzar codificacion UTF-8 para evitar problemas de caracteres en los logs
$OutputEncoding = [System.Text.Encoding]::UTF8

# Comprobar privilegios de administrador/SYSTEM
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "CORRECCION: ERROR: El script requiere ejecutarse con privilegios elevados (Administrator/SYSTEM)."
    exit 1
}

# 1. Asegurar entorno de ejecucion de 64 bits para evitar redireccion de carpetas y registro
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

Write-Host "CORRECCION: Iniciando proceso de eliminacion de 'Move Mouse'..."

# 2. Finalizacion agresiva de procesos activos
Write-Host "CORRECCION: Deteniendo procesos en ejecucion relacionados con Move Mouse..."
try {
    # Buscar procesos que coincidan por nombre o descripcion
    $processes = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*MoveMouse*" -or $_.Description -like "*Move Mouse*" }
    foreach ($proc in $processes) {
        Write-Host "CORRECCION: Terminando proceso $($proc.Name) (PID: $($proc.Id))..."
        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
    }
    # Asegurar con taskkill en caso de bloqueos
    taskkill.exe /F /IM "MoveMouse.exe" /T 2>&1 | Out-Null
    taskkill.exe /F /IM "Move Mouse.exe" /T 2>&1 | Out-Null
} catch {
    Write-Host "CORRECCION: Advertencia al detener procesos: $_"
}

# 3. Desinstalacion del paquete AppX (UWP) para todos los usuarios
Write-Host "CORRECCION: Desinstalando paquetes AppX de Move Mouse para todos los usuarios..."
try {
    $appxPackages = Get-AppxPackage -AllUsers -Name "*MoveMouse*" -ErrorAction SilentlyContinue
    if ($appxPackages) {
        foreach ($pkg in $appxPackages) {
            Write-Host "CORRECCION: Removiendo paquete UWP: $($pkg.PackageFullName)..."
            Remove-AppxPackage -AllUsers -Package $pkg.PackageFullName -ErrorAction Stop
        }
    } else {
        Write-Host "CORRECCION: No se encontraron paquetes AppX instalados."
    }
} catch {
    Write-Host "CORRECCION: ERROR al desinstalar el paquete AppX de usuario: $_"
}

# 4. Desprovisionamiento del paquete AppX del sistema (evita reinstalacion al iniciar sesion)
Write-Host "CORRECCION: Eliminando provision del paquete AppX de la imagen del sistema..."
try {
    $provPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*MoveMouse*" }
    if ($provPackages) {
        foreach ($pkg in $provPackages) {
            Write-Host "CORRECCION: Eliminando provision del paquete: $($pkg.DisplayName)..."
            Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop
        }
    } else {
        Write-Host "CORRECCION: No se encontraron paquetes provisionados del sistema."
    }
} catch {
    Write-Host "CORRECCION: ERROR al desprovisionar el paquete de la imagen: $_"
}

# 5. Limpieza de carpetas y ejecutables portables residuales en el disco
Write-Host "CORRECCION: Iniciando limpieza de directorios residuales y ejecutables portables..."
$ProfilePaths = Get-ChildItem -Path "C:\Users" -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }
$PathsToDelete = [System.Collections.Generic.List[string]]::new()

# Anadir rutas de sistema
$PathsToDelete.Add("$env:ProgramFiles\Move Mouse")
$PathsToDelete.Add("${env:ProgramFiles(x86)}\Move Mouse")
$PathsToDelete.Add("$env:ProgramData\Move Mouse")

# Anadir rutas de usuario
foreach ($profile in $ProfilePaths) {
    $userPath = $profile.FullName
    if ($profile.Name -in @("All Users", "Default", "Default User", "Public")) { continue }

    $PathsToDelete.Add("$userPath\AppData\Local\Move Mouse")
    $PathsToDelete.Add("$userPath\AppData\Roaming\Move Mouse")
    
    # Buscar carpetas huerfanas en Packages
    $packagesPath = "$userPath\AppData\Local\Packages"
    if (Test-Path $packagesPath -ErrorAction SilentlyContinue) {
        $userPackages = Get-ChildItem -Path $packagesPath -Filter "*MoveMouse*" -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $userPackages) {
            $PathsToDelete.Add($dir.FullName)
        }
    }

    # Buscar ejecutables independientes en descargas y escritorio
    $userDownloads = "$userPath\Downloads"
    if (Test-Path $userDownloads -ErrorAction SilentlyContinue) {
        $exes = Get-ChildItem -Path $userDownloads -Filter "*MoveMouse*.exe" -File -ErrorAction SilentlyContinue
        foreach ($exe in $exes) {
            $PathsToDelete.Add($exe.FullName)
        }
    }
    
    $userDesktop = "$userPath\Desktop"
    if (Test-Path $userDesktop -ErrorAction SilentlyContinue) {
        $exes = Get-ChildItem -Path $userDesktop -Filter "*MoveMouse*.exe" -File -ErrorAction SilentlyContinue
        foreach ($exe in $exes) {
            $PathsToDelete.Add($exe.FullName)
        }
    }
}

# Eliminar rutas identificadas
foreach ($target in $PathsToDelete) {
    if (Test-Path $target -ErrorAction SilentlyContinue) {
        try {
            Write-Host "CORRECCION: Eliminando: $($target)..."
            Remove-Item -Path $target -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "CORRECCION: ERROR al eliminar $($target): $_"
        }
    }
}

# 6. Limpieza de claves de registro (Autostart/Ejecucion automatica en perfiles de usuario)
Write-Host "CORRECCION: Purgando registros de ejecucion automatica (Run/Startup)..."
$profilesRegPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList"
if (Test-Path $profilesRegPath) {
    $profiles = Get-ChildItem -Path $profilesRegPath -ErrorAction SilentlyContinue
    foreach ($profile in $profiles) {
        $sid = $profile.PSChildName
        if ($sid -notlike "S-1-5-21-*") { continue }

        $profileImagePath = $profile.GetValue("ProfileImagePath")
        if (-not $profileImagePath -or -not (Test-Path $profileImagePath)) { continue }

        $userHiveLoaded = Test-Path "Registry::HKEY_USERS\$sid"

        if ($userHiveLoaded) {
            $runPath = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Run"
            if (Test-Path $runPath) {
                $runKey = Get-Item -Path $runPath -ErrorAction SilentlyContinue
                foreach ($valName in $runKey.GetValueNames()) {
                    $valData = $runKey.GetValue($valName)
                    if ($valName -like "*MoveMouse*" -or $valData -like "*MoveMouse*") {
                        try {
                            Write-Host "CORRECCION: Eliminando valor de registro en inicio de usuario ($($sid)): $valName..."
                            Remove-ItemProperty -Path $runPath -Name $valName -Force -ErrorAction Stop
                        } catch {
                            Write-Host "CORRECCION: Advertencia al eliminar clave de registro para $($sid): $_"
                        }
                    }
                }
            }
        } else {
            # Cargar colmena offline NTUSER.DAT
            $ntuserPath = Join-Path $profileImagePath "NTUSER.DAT"
            if (Test-Path $ntuserPath) {
                $tempHiveName = "MoveMouseClean_$sid"
                $loaded = $false
                try {
                    & reg.exe load "HKU\$tempHiveName" "$ntuserPath" 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        $loaded = $true
                        $runPath = "Registry::HKEY_USERS\$tempHiveName\Software\Microsoft\Windows\CurrentVersion\Run"
                        if (Test-Path $runPath) {
                            $runKey = Get-Item -Path $runPath -ErrorAction SilentlyContinue
                            foreach ($valName in $runKey.GetValueNames()) {
                                $valData = $runKey.GetValue($valName)
                                if ($valName -like "*MoveMouse*" -or $valData -like "*MoveMouse*") {
                                    Write-Host "CORRECCION: Eliminando valor de registro offline para $($sid): $valName..."
                                    Remove-ItemProperty -Path $runPath -Name $valName -Force -ErrorAction SilentlyContinue
                                }
                            }
                        }
                    }
                } catch {
                    Write-Host "CORRECCION: Advertencia al procesar registro offline para SID $($sid): $_"
                } finally {
                    if ($loaded) {
                        [GC]::Collect()
                        [GC]::WaitForPendingFinalizers()
                        & reg.exe unload "HKU\$tempHiveName" 2>&1 | Out-Null
                    }
                }
            }
        }
    }
}

# 7. Doble verificacion (Auto-reparacion/Post-auditoria en caliente)
Write-Host "CORRECCION: Iniciando post-auditoria rapida de validacion..."
$PostVerificationFailed = $false

# Comprobar procesos residuales
$residualProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*MoveMouse*" -or $_.Description -like "*Move Mouse*" }
if ($residualProcesses) {
    Write-Host "CORRECCION: ERROR: Siguen existiendo procesos activos de Move Mouse tras la remediacion."
    $PostVerificationFailed = $true
}

# Comprobar paquetes AppX residuales
$residualAppx = Get-AppxPackage -AllUsers -Name "*MoveMouse*" -ErrorAction SilentlyContinue
if ($residualAppx) {
    Write-Host "CORRECCION: ERROR: Siguen existiendo paquetes AppX instalados para algun usuario."
    $PostVerificationFailed = $true
}

# Comprobar directorios criticos residuales (excepto descargas/escritorio por precaucion de borrado de archivos)
$criticalDirs = @(
    "$env:ProgramFiles\Move Mouse",
    "${env:ProgramFiles(x86)}\Move Mouse",
    "$env:ProgramData\Move Mouse"
)
foreach ($dir in $criticalDirs) {
    if (Test-Path $dir -ErrorAction SilentlyContinue) {
        Write-Host "CORRECCION: ERROR: El directorio critico sigue existiendo: $dir"
        $PostVerificationFailed = $true
    }
}

# Finalizar script
if ($PostVerificationFailed) {
    Write-Host "CORRECCION: ERROR CRITICO: La remediacion fallo. Algunos componentes no pudieron eliminarse debido a bloqueos de archivos o del sistema."
    exit 1
} else {
    Write-Host "CORRECCION: Remediacion finalizada con exito de manera conforme."
    exit 0
}
