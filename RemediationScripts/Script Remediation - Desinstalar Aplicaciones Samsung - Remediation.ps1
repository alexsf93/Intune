<#
.SYNOPSIS
    REMEDIATION SCRIPT: DESINSTALAR APLICACIONES DE SAMSUNG (UWP/STORE)

.DESCRIPTION
    Este script elimina por completo y de forma definitiva todas las aplicaciones 
    de Samsung (paquetes AppX/MSIX) instaladas en el sistema para todos los usuarios,
    así como sus provisiones para nuevos perfiles de usuario.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Desinstalar Aplicaciones Samsung - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-07-16
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

Write-Host "CORRECCION: Iniciando proceso de eliminacion de aplicaciones Samsung..."

# 2. Finalizacion de procesos activos relacionados con Samsung
Write-Host "CORRECCION: Deteniendo procesos en ejecucion relacionados con Samsung..."
try {
    $processes = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Samsung*" -or $_.Description -like "*Samsung*" }
    foreach ($proc in $processes) {
        Write-Host "CORRECCION: Terminando proceso $($proc.Name) (PID: $($proc.Id))..."
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "CORRECCION: Advertencia al detener procesos: $_"
}

# 2.1. Detencion de servicios activos relacionados con Samsung
Write-Host "CORRECCION: Deteniendo servicios relacionados con Samsung..."
try {
    # Exclusiones de servicios de controladores esenciales (como NVMe)
    $services = Get-Service -ErrorAction SilentlyContinue | Where-Object { 
        ($_.Name -like "*Samsung*" -or $_.DisplayName -like "*Samsung*") -and 
        ($_.Name -notmatch "NVMe|SSD")
    }
    foreach ($srv in $services) {
        if ($srv.Status -eq 'Running') {
            Write-Host "CORRECCION: Deteniendo servicio $($srv.Name) ($($srv.DisplayName))..."
            Stop-Service -Name $srv.Name -Force -ErrorAction SilentlyContinue
        }
    }
} catch {
    Write-Host "CORRECCION: Advertencia al detener servicios: $_"
}

# 3. Desinstalacion del paquete AppX (UWP) para todos los usuarios
Write-Host "CORRECCION: Desinstalando paquetes AppX de Samsung para todos los usuarios..."
try {
    $appxPackages = Get-AppxPackage -AllUsers -Name "*Samsung*" -ErrorAction SilentlyContinue
    if ($appxPackages) {
        foreach ($pkg in $appxPackages) {
            Write-Host "CORRECCION: Removiendo paquete UWP: $($pkg.PackageFullName)..."
            Remove-AppxPackage -AllUsers -Package $pkg.PackageFullName -ErrorAction Stop
        }
    } else {
        Write-Host "CORRECCION: No se encontraron paquetes AppX de Samsung instalados."
    }
} catch {
    Write-Host "CORRECCION: ERROR al desinstalar el paquete AppX: $_"
}

# 4. Desprovisionamiento del paquete AppX del sistema (evita reinstalacion al iniciar sesion)
Write-Host "CORRECCION: Eliminando provision de paquetes AppX de Samsung de la imagen del sistema..."
try {
    $provPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Samsung*" }
    if ($provPackages) {
        foreach ($pkg in $provPackages) {
            Write-Host "CORRECCION: Eliminando provision del paquete: $($pkg.DisplayName)..."
            Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop
        }
    } else {
        Write-Host "CORRECCION: No se encontraron paquetes provisionados de Samsung."
    }
} catch {
    Write-Host "CORRECCION: ERROR al desprovisionar el paquete de la imagen: $_"
}

# 5. Desinstalacion de aplicaciones de Samsung registradas en el Panel de Control (Registro)
Write-Host "CORRECCION: Desinstalando aplicaciones Win32 de Samsung registradas en el sistema..."
$Exclusions = @("NVMe", "USB Driver", "Printer", "Print", "Magician", "SSD", "Display", "Graphics", "Audio", "WLAN", "Bluetooth")
try {
    $registryPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $win32Apps = Get-ItemProperty -Path $registryPaths -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -and (
            ($_.DisplayName -like "*Samsung*") -or ($_.Publisher -like "*Samsung*")
        )
    }
    
    # Aplicar exclusiones
    $targetedWin32Apps = $win32Apps | Where-Object {
        $displayName = $_.DisplayName
        $matchExclusion = $false
        foreach ($exclusion in $Exclusions) {
            if ($displayName -like "*$exclusion*") {
                $matchExclusion = $true
                break
            }
        }
        -not $matchExclusion
    }
    
    if ($targetedWin32Apps) {
        foreach ($app in $targetedWin32Apps) {
            $name = $app.DisplayName
            $uninstallString = $app.UninstallString
            $quietUninstallString = $app.QuietUninstallString
            
            Write-Host "CORRECCION: Detectada aplicacion Win32 para desinstalar: $name"
            
            if (-not $uninstallString -and -not $quietUninstallString) {
                Write-Host "CORRECCION: Advertencia: No se encontro cadena de desinstalacion para $name. Se omitira."
                continue
            }
            
            # Determinar comando de desinstalacion silenciosa
            $isMsi = $false
            $msiGuid = ""
            
            # Comprobar si es un MSI
            if ($uninstallString -match '(?i)msiexec') {
                $isMsi = $true
                if ($uninstallString -match '\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}') {
                    $msiGuid = $Matches[0]
                }
            }
            
            if ($isMsi -and $msiGuid) {
                Write-Host "CORRECCION: Desinstalando paquete MSI con GUID: $msiGuid"
                $arguments = "/x $msiGuid /qn /norestart"
                try {
                    $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -NoNewWindow -PassThru -ErrorAction Stop
                    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 1605 -or $proc.ExitCode -eq 3010) {
                        Write-Host "CORRECCION: Desinstalacion exitosa o ya desinstalado (Codigo: $($proc.ExitCode))."
                    } else {
                        Write-Host "CORRECCION: ERROR al desinstalar MSI $name. Codigo de salida: $($proc.ExitCode)"
                    }
                } catch {
                    Write-Host "CORRECCION: ERROR critico al ejecutar msiexec: $_"
                }
            } else {
                # No es MSI o no tiene GUID
                $uninstallCmd = if ($quietUninstallString) { $quietUninstallString } else { $uninstallString }
                $uninstallCmd = $uninstallCmd.Trim()
                
                # Intentar parsear exe y argumentos
                $exePath = ""
                $arguments = ""
                
                if ($uninstallCmd -like '"*') {
                    $closeQuoteIdx = $uninstallCmd.IndexOf('"', 1)
                    if ($closeQuoteIdx -gt 0) {
                        $exePath = $uninstallCmd.Substring(1, $closeQuoteIdx - 1)
                        $arguments = $uninstallCmd.Substring($closeQuoteIdx + 1).Trim()
                    } else {
                        $exePath = $uninstallCmd -replace '"', ''
                    }
                } else {
                    if (Test-Path $uninstallCmd) {
                        $exePath = $uninstallCmd
                    } else {
                        $argStartIdx = $uninstallCmd.IndexOf(' /')
                        if ($argStartIdx -lt 0) {
                            $argStartIdx = $uninstallCmd.IndexOf(' -')
                        }
                        if ($argStartIdx -gt 0) {
                            $exePath = $uninstallCmd.Substring(0, $argStartIdx).Trim()
                            $arguments = $uninstallCmd.Substring($argStartIdx).Trim()
                        } else {
                            $parts = $uninstallCmd -split ' ', 2
                            $exePath = $parts[0]
                            if ($parts.Count -gt 1) { $arguments = $parts[1] }
                        }
                    }
                }
                
                # Agregar silent arguments si no estan ya presentes
                if (-not $quietUninstallString) {
                    if ($exePath -match '(?i)unins\d+\.exe') {
                        if ($arguments -notlike "*/VERYSILENT*") { $arguments += " /VERYSILENT /SUPPRESSMSGBOXES /NORESTART" }
                    } elseif ($exePath -match '(?i)uninstall\.exe|setup\.exe') {
                        if ($arguments -notlike "*/S*" -and $arguments -notlike "*-s*") { $arguments += " /S" }
                    } else {
                        if ($arguments -notlike "*/S*" -and $arguments -notlike "*/quiet*") { $arguments += " /S" }
                    }
                }
                
                Write-Host "CORRECCION: Ejecutando: $exePath $arguments"
                try {
                    $proc = Start-Process -FilePath $exePath -ArgumentList $arguments -Wait -NoNewWindow -PassThru -ErrorAction Stop
                    Write-Host "CORRECCION: Desinstalacion de $name finalizada. Codigo de salida: $($proc.ExitCode)"
                } catch {
                    Write-Host "CORRECCION: ERROR al desinstalar $($name): $_. Reintentando con cmd.exe /c..."
                    try {
                        $fallbackCmd = if ($quietUninstallString) { $quietUninstallString } else { "$uninstallCmd /S" }
                        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$fallbackCmd`"" -Wait -NoNewWindow -PassThru -ErrorAction Stop
                        Write-Host "CORRECCION: Desinstalacion fallback finalizada. Codigo de salida: $($proc.ExitCode)"
                    } catch {
                        Write-Host "CORRECCION: ERROR critico al ejecutar desinstalador fallback: $_"
                    }
                }
            }
        }
    } else {
        Write-Host "CORRECCION: No se encontraron aplicaciones Win32 de Samsung para desinstalar."
    }
} catch {
    Write-Host "CORRECCION: ERROR al procesar la desinstalacion de aplicaciones Win32: $_"
}

# 6. Doble verificacion (Post-auditoria)
Write-Host "CORRECCION: Iniciando post-auditoria rapida de validacion..."
$PostVerificationFailed = $false

$residualAppx = Get-AppxPackage -AllUsers -Name "*Samsung*" -ErrorAction SilentlyContinue
if ($residualAppx) {
    Write-Host "CORRECCION: ERROR: Siguen existiendo paquetes AppX de Samsung instalados para algun usuario."
    $PostVerificationFailed = $true
}

$residualProv = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Samsung*" }
if ($residualProv) {
    Write-Host "CORRECCION: ERROR: Siguen existiendo paquetes provisionados de Samsung."
    $PostVerificationFailed = $true
}

# Verificacion residual de Win32
try {
    $residualWin32 = Get-ItemProperty -Path $registryPaths -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -and (
            ($_.DisplayName -like "*Samsung*") -or ($_.Publisher -like "*Samsung*")
        )
    } | Where-Object {
        $displayName = $_.DisplayName
        $matchExclusion = $false
        foreach ($exclusion in $Exclusions) {
            if ($displayName -like "*$exclusion*") {
                $matchExclusion = $true
                break
            }
        }
        -not $matchExclusion
    }
    
    if ($residualWin32) {
        foreach ($app in $residualWin32) {
            Write-Host "CORRECCION: ERROR: Sigue existiendo la aplicacion Win32 instalada: $($app.DisplayName)"
        }
        $PostVerificationFailed = $true
    }
} catch {
    Write-Host "CORRECCION: Advertencia en la validacion residual Win32: $_"
}

# Finalizar script
if ($PostVerificationFailed) {
    Write-Host "CORRECCION: ERROR CRITICO: La remediacion fallo. Algunos componentes no pudieron eliminarse."
    exit 1
} else {
    Write-Host "CORRECCION: Remediacion finalizada con exito de manera conforme."
    exit 0
}
