<#
.SYNOPSIS
    REMEDIATION SCRIPT: ELIMINAR COMPLETAMENTE LA APLICACION "OP AUTO CLICKER"

.DESCRIPTION
    Este script elimina completamente "OP Auto Clicker" (tambien conocida como
    "OP Auto Clicker - Auto Tap") de dispositivos Windows 10/11 gestionados por Intune.

    Pasos de remediacion:
      1. Finalizar procesos activos de la aplicacion
      2. Eliminar paquetes AppX para todos los usuarios
      3. Eliminar paquetes AppX provisionados (evita reinstalacion en nuevos perfiles)
      4. Eliminar claves de registro Uninstall (standalone generico)
      5. Eliminar directorios standalone residuales (Program Files, LocalAppData)
      5b. Desinstalar version Inno Setup en AppData\Roaming de todos los perfiles
          (AutoClicker.exe + unins000.exe + unins000.dat)
      6. Eliminar accesos directos (.lnk) relacionados
      7. Post-verificacion para confirmar la eliminacion completa

    Salida:
      - Exit 0: Remediacion completada con exito
      - Exit 1: Alguno de los componentes no pudo eliminarse

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Desinstalar OP Auto Clicker - Remediation.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.1.0
    Date: 2026-06-24
    Context: System
#>

$OutputEncoding = [System.Text.Encoding]::UTF8

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "ERROR: El script requiere ejecutarse con privilegios elevados (Administrator/SYSTEM)."
    exit 1
}

if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Host "Ejecutando en proceso de 32 bits. Relanzando en PowerShell de 64 bits..."
    $powershell64 = Join-Path $env:SystemRoot "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $powershell64) {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process -FilePath $powershell64 -ArgumentList $arguments -Wait -NoNewWindow
        exit $LASTEXITCODE
    } else {
        Write-Host "No se pudo encontrar PowerShell de 64 bits en Sysnative. Continuando en modo actual."
    }
}

Write-Host "Iniciando proceso de eliminacion de 'OP Auto Clicker'..."

# Patrones de nombre de paquete AppX conocidos
$AppxNamePatterns = @(
    "*AutoClicker*",
    "*OPAutoClicker*",
    "*OP*AutoClicker*",
    "*AutoTap*"
)

# Nombres de proceso a terminar
$ProcessPatterns = @(
    "opautoclicker*",
    "autoclicker*",
    "AutoTap*"
)

# Patrones de DisplayName para busqueda en registro (standalone)
$DisplayNamePatterns = @(
    "*OP Auto Clicker*",
    "*OPAutoClicker*",
    "*Auto Clicker*Auto Tap*"
)

# =============================================================================
# PASO 1: Finalizar procesos activos
# =============================================================================
Write-Host "--- Paso 1: Finalizando procesos activos ---"
foreach ($pattern in $ProcessPatterns) {
    try {
        Get-Process -Name $pattern -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "Terminando proceso: $($_.Name) (PID: $($_.Id))"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "Advertencia al terminar procesos ($pattern): $_"
    }
}
Start-Sleep -Seconds 2

# =============================================================================
# PASO 2: Eliminar paquetes AppX para todos los usuarios
# =============================================================================
Write-Host "--- Paso 2: Eliminando paquetes AppX (todos los usuarios) ---"
foreach ($pattern in $AppxNamePatterns) {
    try {
        $pkgs = Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue
        foreach ($pkg in $pkgs) {
            Write-Host "Eliminando paquete AppX: $($pkg.PackageFullName)"
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                Write-Host "  Eliminado correctamente: $($pkg.PackageFullName)"
            } catch {
                # Algunos paquetes no admiten -AllUsers, reintentar sin el parametro
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                    Write-Host "  Eliminado (sin -AllUsers): $($pkg.PackageFullName)"
                } catch {
                    Write-Host "  Advertencia al eliminar paquete $($pkg.PackageFullName): $_"
                }
            }
        }
    } catch {
        Write-Host "Advertencia al buscar paquetes AppX ($pattern): $_"
    }
}

# =============================================================================
# PASO 3: Eliminar paquetes AppX provisionados
# =============================================================================
Write-Host "--- Paso 3: Eliminando paquetes AppX provisionados ---"
foreach ($pattern in $AppxNamePatterns) {
    try {
        $provPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $pattern }
        foreach ($pkg in $provPkgs) {
            Write-Host "Eliminando paquete provisionado: $($pkg.PackageName)"
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
                Write-Host "  Paquete provisionado eliminado correctamente."
            } catch {
                Write-Host "  Advertencia al eliminar paquete provisionado $($pkg.PackageName): $_"
            }
        }
    } catch {
        Write-Host "Advertencia al buscar paquetes provisionados ($pattern): $_"
    }
}

# =============================================================================
# PASO 4: Eliminar claves de registro Uninstall (instalacion standalone)
# =============================================================================
Write-Host "--- Paso 4: Eliminando claves de registro Uninstall ---"
$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($basePath in $UninstallPaths) {
    if (-not (Test-Path $basePath)) { continue }
    try {
        Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue | ForEach-Object {
            $keyPath     = $_.PSPath
            $displayName = $_.GetValue("DisplayName")
            $uninstallStr = $_.GetValue("UninstallString")
            $matched = $false
            foreach ($pattern in $DisplayNamePatterns) {
                if ($displayName -like $pattern) { $matched = $true }
            }
            if ($matched) {
                # Intentar desinstalacion silenciosa si existe UninstallString
                if ($uninstallStr) {
                    try {
                        Write-Host "Ejecutando desinstalador para: $displayName"
                        if ($uninstallStr -like "*MsiExec*") {
                            $msiCmd = $uninstallStr -replace "/I","/X"
                            if ($msiCmd -notlike "*/qn*") { $msiCmd = "$msiCmd /qn /norestart" }
                            $p = Start-Process "cmd.exe" -ArgumentList "/c `"$msiCmd`"" -Wait -NoNewWindow -PassThru
                            Write-Host "  Desinstalador MSI -> ExitCode $($p.ExitCode)"
                        } else {
                            $p = Start-Process "cmd.exe" -ArgumentList "/c `"$uninstallStr /S /silent /quiet`"" -Wait -NoNewWindow -PassThru
                            Write-Host "  Desinstalador -> ExitCode $($p.ExitCode)"
                        }
                    } catch {
                        Write-Host "  Advertencia al ejecutar desinstalador: $_"
                    }
                }
                # Eliminar la clave de registro
                try {
                    Write-Host "Eliminando clave de registro: $keyPath"
                    Remove-Item -Path $keyPath -Recurse -Force -ErrorAction Stop
                } catch {
                    Write-Host "  Advertencia al eliminar clave ($keyPath): $_"
                }
            }
        }
    } catch {
        Write-Host "Advertencia al buscar en $basePath : $_"
    }
}

# =============================================================================
# PASO 5: Eliminar directorios de instalacion standalone
# =============================================================================
Write-Host "--- Paso 5: Eliminando directorios residuales ---"
$StandalonePaths = @(
    "$env:LOCALAPPDATA\Programs\OP Auto Clicker",
    "$env:ProgramFiles\OP Auto Clicker",
    "${env:ProgramFiles(x86)}\OP Auto Clicker"
)
foreach ($path in $StandalonePaths) {
    if (Test-Path $path -ErrorAction SilentlyContinue) {
        try {
            Write-Host "Eliminando directorio: $path"
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "  Advertencia al eliminar directorio ($path): $_"
        }
    }
}

# =============================================================================
# PASO 5b: Desinstalar version Inno Setup de todos los perfiles de usuario
#          Ruta: %USERPROFILE%\AppData\Roaming\OP Auto Clicker\unins000.exe
# =============================================================================
Write-Host "--- Paso 5b: Desinstalando version Inno Setup (todos los perfiles) ---"
Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin @("All Users","Default","Default User","Public") } | ForEach-Object {
    $profileDir = $_.FullName
    $innoDir    = Join-Path $profileDir "AppData\Roaming\OP Auto Clicker"
    $uninsExe   = Join-Path $innoDir "unins000.exe"
    $acExe      = Join-Path $innoDir "AutoClicker.exe"

    if (Test-Path $innoDir -ErrorAction SilentlyContinue) {
        # Terminar el proceso si esta corriendo desde este perfil
        Get-Process -Name "AutoClicker" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Path -like "$innoDir*") {
                Write-Host "  Terminando AutoClicker.exe del perfil '$($_.Name)'..."
                Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
            }
        }

        # Ejecutar el desinstalador Inno Setup silencioso
        if (Test-Path $uninsExe -ErrorAction SilentlyContinue) {
            Write-Host "  Ejecutando desinstalador Inno Setup: $uninsExe"
            try {
                $p = Start-Process -FilePath $uninsExe -ArgumentList "/SILENT /NORESTART" -Wait -NoNewWindow -PassThru
                Write-Host "  Desinstalador Inno Setup -> ExitCode $($p.ExitCode)"
                Start-Sleep -Seconds 3
            } catch {
                Write-Host "  Advertencia al ejecutar desinstalador Inno Setup: $_"
            }
        } elseif (Test-Path $acExe -ErrorAction SilentlyContinue) {
            Write-Host "  No se encontro unins000.exe en $innoDir, se eliminara la carpeta directamente."
        }

        # Eliminar la carpeta completa si sigue existiendo
        if (Test-Path $innoDir -ErrorAction SilentlyContinue) {
            try {
                Write-Host "  Eliminando directorio Inno Setup residual: $innoDir"
                Remove-Item -Path $innoDir -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Host "  Advertencia al eliminar directorio Inno Setup ($innoDir): $_"
            }
        }
    }
}

# =============================================================================
# PASO 6: Eliminar accesos directos (.lnk)
# =============================================================================
Write-Host "--- Paso 6: Eliminando accesos directos ---"
$ShortcutPaths = [System.Collections.Generic.List[string]]::new()
@("$env:PUBLIC\Desktop","$env:USERPROFILE\Desktop","$env:PROGRAMDATA\Microsoft\Windows\Start Menu") | ForEach-Object {
    if (Test-Path $_) { $ShortcutPaths.Add($_) }
}
Get-ChildItem -Path "C:\Users" -ErrorAction SilentlyContinue |
    Where-Object { $_.PSIsContainer -and $_.Name -notin @("All Users","Default","Default User","Public") } | ForEach-Object {
    $d = Join-Path $_.FullName "Desktop"
    $s = Join-Path $_.FullName "AppData\Roaming\Microsoft\Windows\Start Menu"
    if (Test-Path $d) { $ShortcutPaths.Add($d) }
    if (Test-Path $s) { $ShortcutPaths.Add($s) }
}
$lnkFiles = @()
foreach ($dir in $ShortcutPaths) {
    if (Test-Path $dir) { $lnkFiles += Get-ChildItem -Path $dir -Filter "*.lnk" -Recurse -File -ErrorAction SilentlyContinue }
}
if ($lnkFiles.Count -gt 0) {
    try {
        $wshShell = New-Object -ComObject WScript.Shell
        foreach ($file in $lnkFiles) {
            try {
                $shortcut  = $wshShell.CreateShortcut($file.FullName)
                $lnkTarget = $shortcut.TargetPath
                if ($lnkTarget -like "*AutoClicker*" -or $lnkTarget -like "*OP Auto Clicker*" -or
                    $lnkTarget -like "*OPAutoClicker*" -or $lnkTarget -like "*AutoTap*") {
                    Write-Host "Eliminando acceso directo: $($file.FullName)"
                    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                }
            } catch { }
        }
    } catch {
        Write-Host "Advertencia al procesar accesos directos: $_"
    }
}

Start-Sleep -Seconds 3

# =============================================================================
# POST-VERIFICACION
# =============================================================================
Write-Host "--- Post-verificacion ---"
$Failed = $false

# Comprobar procesos residuales
foreach ($pattern in $ProcessPatterns) {
    if (Get-Process -Name $pattern -ErrorAction SilentlyContinue) {
        Write-Host "ERROR: Proceso residual detectado: $pattern"
        $Failed = $true
    }
}

# Comprobar paquetes AppX residuales
foreach ($pattern in $AppxNamePatterns) {
    $remaining = Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue
    if ($remaining) {
        foreach ($pkg in $remaining) {
            Write-Host "ERROR: Paquete AppX residual: $($pkg.PackageFullName)"
            $Failed = $true
        }
    }
    $remainingProv = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like $pattern }
    if ($remainingProv) {
        foreach ($pkg in $remainingProv) {
            Write-Host "ERROR: Paquete provisionado residual: $($pkg.PackageName)"
            $Failed = $true
        }
    }
}

# Comprobar directorios residuales standalone
foreach ($path in $StandalonePaths) {
    if (Test-Path $path -ErrorAction SilentlyContinue) {
        Write-Host "ERROR: Directorio standalone residual: $path"
        $Failed = $true
    }
}

# Comprobar directorios Inno Setup residuales por perfil
Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin @("All Users","Default","Default User","Public") } | ForEach-Object {
    $innoDir = Join-Path $_.FullName "AppData\Roaming\OP Auto Clicker"
    if (Test-Path $innoDir -ErrorAction SilentlyContinue) {
        Write-Host "ERROR: Directorio Inno Setup residual en perfil '$($_.Name)': $innoDir"
        $Failed = $true
    }
}

if ($Failed) {
    Write-Host "ERROR CRITICO: Algunos componentes no pudieron eliminarse."
    exit 1
} else {
    Write-Host "Remediacion finalizada con exito. OP Auto Clicker eliminado del sistema."
    exit 0
}
