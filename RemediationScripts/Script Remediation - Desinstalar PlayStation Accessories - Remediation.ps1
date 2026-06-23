<#
.SYNOPSIS
    REMEDIATION SCRIPT: ELIMINAR COMPLETAMENTE LA APLICACION "PLAYSTATION ACCESSORIES"

.DESCRIPTION
    Este script detiene procesos relacionados con PlayStation Accessories, desinstala la aplicacion
    usando los registros de desinstalacion si estan disponibles, elimina los directorios
    asociados, y elimina los accesos directos (.lnk) que apuntan a ejecutables de la aplicacion
    en escritorios publicos/privados y el menu inicio.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Desinstalar PlayStation Accessories - Remediation.ps1
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

Write-Host "CORRECCION: Iniciando proceso de eliminacion de 'PlayStation Accessories'..."

# Helper para eliminar registros de forma segura
function Remove-RegistryKey {
    param (
        [string]$Path
    )
    if (Test-Path $Path) {
        try {
            Write-Host "CORRECCION: Eliminando clave de registro: $Path"
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "CORRECCION: Advertencia al eliminar clave de registro ($Path): $_"
        }
    }
}

# 2. Finalizacion de procesos activos para desbloquear archivos
Write-Host "CORRECCION: Buscando y finalizando procesos activos de PlayStation Accessories..."
try {
    $processes = Get-Process -Name "PlayStationAccessories*" -ErrorAction SilentlyContinue
    foreach ($proc in $processes) {
        Write-Host "CORRECCION: Terminando proceso $($proc.Name) (PID: $($proc.Id))..."
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "CORRECCION: Advertencia al finalizar procesos: $_"
}

# 3. Intentar desinstalacion silenciosa usando UninstallString del registro
Write-Host "CORRECCION: Buscando claves de desinstalacion en el registro HKLM..."
$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
$uninstalledCount = 0

foreach ($basePath in $UninstallPaths) {
    if (Test-Path $basePath) {
        $keys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
        foreach ($key in $keys) {
            $name = $key.PSChildName
            $displayName = $key.GetValue("DisplayName")
            if ($name -like "*PlayStationAccessories*" -or $name -like "*PlayStation Accessories*" -or $displayName -like "*PlayStationAccessories*" -or $displayName -like "*PlayStation Accessories*") {
                $uninstallString = $key.GetValue("UninstallString")
                $quietUninstallString = $key.GetValue("QuietUninstallString")
                
                $uninstallCommand = ""
                if ($quietUninstallString) {
                    $uninstallCommand = $quietUninstallString
                } elseif ($uninstallString) {
                    # Si es MSI, convertir a desinstalacion desatendida
                    if ($uninstallString -like "*MsiExec.exe*") {
                        $uninstallCommand = $uninstallString -replace "/I", "/X"
                        if ($uninstallCommand -notlike "*/qn*") {
                            $uninstallCommand = "$uninstallCommand /qn /norestart"
                        }
                    } else {
                        # Intentar pasar switches silenciosos estandar
                        $uninstallCommand = "$uninstallString /S /silent /quiet /qn /norestart /s /v`"/qn`""
                    }
                }

                if ($uninstallCommand) {
                    try {
                        Write-Host "CORRECCION: Ejecutando comando de desinstalacion: $uninstallCommand"
                        # Ejecutar via cmd.exe para un analisis nativo de rutas con espacios y comillas
                        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$uninstallCommand`"" -Wait -NoNewWindow -PassThru
                        if ($proc.ExitCode -eq 0) {
                            Write-Host "CORRECCION: Desinstalador ejecutado con exito (ExitCode 0)."
                            $uninstalledCount++
                        } else {
                            Write-Host "CORRECCION: Advertencia: El desinstalador retorno exit code $($proc.ExitCode)."
                        }
                    } catch {
                        Write-Host "CORRECCION: ERROR al invocar el desinstalador: $_"
                    }
                }
            }
        }
    }
}

# Desinstalacion de AppX/MSIX si existe (versiones modernas o de la Tienda)
try {
    $appxPackages = Get-AppxPackage -AllUsers -Name "*PlayStationAccessories*" -ErrorAction SilentlyContinue
    if ($appxPackages) {
        foreach ($pkg in $appxPackages) {
            Write-Host "CORRECCION: Removiendo paquete UWP/Store: $($pkg.PackageFullName)..."
            Remove-AppxPackage -AllUsers -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
        }
    }
} catch {
    Write-Host "CORRECCION: Advertencia al comprobar paquetes AppX: $_"
}

# Esperar unos segundos para permitir que el desinstalador complete
Start-Sleep -Seconds 5

# 4. Forzar eliminacion de carpetas de aplicacion identificadas
Write-Host "CORRECCION: Eliminando carpetas residuales en el disco..."
$PathsToDelete = @("C:\Program Files\Sony\PlayStationAccessories")

foreach ($target in $PathsToDelete) {
    if (Test-Path $target -ErrorAction SilentlyContinue) {
        try {
            Write-Host "CORRECCION: Eliminando carpeta: $target"
            Remove-Item -Path $target -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "CORRECCION: ERROR al eliminar la carpeta ($target): $_"
        }
    }
}

# 5. Escaneo y eliminacion agresiva de accesos directos (.lnk) en Escritorio y Menu Inicio
Write-Host "CORRECCION: Buscando y eliminando accesos directos (.lnk) de PlayStation Accessories..."
$ShortcutPaths = [System.Collections.Generic.List[string]]::new()
if (Test-Path "$env:PUBLIC\Desktop") { $ShortcutPaths.Add("$env:PUBLIC\Desktop") }
if (Test-Path "$env:USERPROFILE\Desktop") { $ShortcutPaths.Add("$env:USERPROFILE\Desktop") }
if (Test-Path "$env:PROGRAMDATA\Microsoft\Windows\Start Menu") { $ShortcutPaths.Add("$env:PROGRAMDATA\Microsoft\Windows\Start Menu") }

# Añadir perfiles de usuario como salvaguarda adicional
$ProfilePaths = Get-ChildItem -Path "C:\Users" -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }
foreach ($profile in $ProfilePaths) {
    if ($profile.Name -in @("All Users", "Default", "Default User", "Public")) { continue }
    $userDesktop = Join-Path $profile.FullName "Desktop"
    $userStartMenu = Join-Path $profile.FullName "AppData\Roaming\Microsoft\Windows\Start Menu"
    if (Test-Path $userDesktop) { $ShortcutPaths.Add($userDesktop) }
    if (Test-Path $userStartMenu) { $ShortcutPaths.Add($userStartMenu) }
}

$lnkFiles = @()
foreach ($dir in $ShortcutPaths) {
    if (Test-Path $dir) {
        $lnkFiles += Get-ChildItem -Path $dir -Filter "*.lnk" -Recurse -File -ErrorAction SilentlyContinue
    }
}

if ($lnkFiles.Count -gt 0) {
    try {
        $wshShell = New-Object -ComObject WScript.Shell
        foreach ($file in $lnkFiles) {
            try {
                $shortcut = $wshShell.CreateShortcut($file.FullName)
                $target = $shortcut.TargetPath
                if ($target -like "*PlayStationAccessories*" -or $target -like "*PlayStation Accessories*" -or $target -like "*C:\Program Files\Sony\PlayStationAccessories*") {
                    Write-Host "CORRECCION: Eliminando acceso directo: $($file.FullName) (Apunta a: $target)"
                    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                }
            } catch {
                Write-Host "CORRECCION: Advertencia al procesar acceso directo ($($file.FullName)): $_"
            }
        }
    } catch {
        Write-Host "CORRECCION: ERROR al inicializar objeto COM de accesos directos: $_"
    }
}

# 6. Post-auditoria rápida de validación
Write-Host "CORRECCION: Iniciando post-auditoria de validacion..."
$PostVerificationFailed = $false

# Comprobar procesos residuales
$residualProcesses = Get-Process -Name "PlayStationAccessories*" -ErrorAction SilentlyContinue
if ($residualProcesses) {
    Write-Host "CORRECCION: ERROR: Siguen existiendo procesos activos de PlayStation Accessories."
    $PostVerificationFailed = $true
}

# Comprobar directorios criticos residuales de sistema
$criticalDirs = @("C:\Program Files\Sony\PlayStationAccessories")
foreach ($dir in $criticalDirs) {
    if (Test-Path $dir -ErrorAction SilentlyContinue) {
        Write-Host "CORRECCION: ERROR: El directorio critico sigue existiendo: $dir"
        $PostVerificationFailed = $true
    }
}

if ($PostVerificationFailed) {
    Write-Host "CORRECCION: ERROR CRITICO: La remediacion fallo. Algunos componentes no pudieron eliminarse."
    exit 1
} else {
    Write-Host "CORRECCION: Remediacion finalizada con exito de manera conforme."
    exit 0
}
