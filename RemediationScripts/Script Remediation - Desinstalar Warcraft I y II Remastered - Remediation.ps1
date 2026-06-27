<#
.SYNOPSIS
    REMEDIATION SCRIPT: ELIMINAR COMPLETAMENTE EL JUEGO "WARCRAFT I Y II REMASTERED" (ELAMIGOS)

.DESCRIPTION
    Este script elimina de forma completa y desatendida el juego "Warcraft I and II Remastered"
    en dispositivos Windows gestionados por Intune.
    Realiza las siguientes acciones:
      1. Detiene procesos activos relacionados para evitar bloqueos de archivos.
      2. Invoca el desinstalador nativo de forma silenciosa si existe en el registro.
      3. Fuerza la eliminación de carpetas de instalación físicas y datos residuales en todos los perfiles de usuario.
      4. Limpia las claves de registro de desinstalación.
      5. Elimina accesos directos de Escritorio y Menú Inicio.

    Salida:
      - Exit 0: Remediación completada con éxito.
      - Exit 1: Algunos componentes críticos del juego no pudieron ser eliminados.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Desinstalar Warcraft I y II Remastered - Remediation.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.0.0
    Date: 2026-06-27
    Context: System
#>

$OutputEncoding = [System.Text.Encoding]::UTF8

# Comprobar privilegios de administrador/SYSTEM
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "CORRECCION: ERROR: El script requiere ejecutarse con privilegios elevados (Administrator/SYSTEM)."
    exit 1
}

# 1. Asegurar entorno de ejecución de 64 bits para evitar redirección de carpetas y registro
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

Write-Host "CORRECCION: Iniciando proceso de eliminacion de 'Warcraft I and II Remastered'..."

# Helper para eliminar claves de registro de forma segura
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

# Helper para eliminar archivos o directorios de forma segura
function Remove-DirectoryOrFile {
    param (
        [string]$Path
    )
    if (Test-Path $Path -ErrorAction SilentlyContinue) {
        try {
            Write-Host "CORRECCION: Eliminando ruta en disco: $Path"
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "CORRECCION: Advertencia al eliminar ($Path): $_"
        }
    }
}

# =============================================================================
# PASO 1: Finalizar procesos activos para desbloquear archivos
# =============================================================================
Write-Host "CORRECCION: Buscando y finalizando procesos activos del juego..."
$ProcessNames = @(
    "Warcraft I Remastered",
    "Warcraft II Remastered",
    "Warcraft 1 Remastered",
    "Warcraft 2 Remastered",
    "Warcraft I Remastered Launcher",
    "Warcraft II Remastered Launcher"
)

foreach ($procName in $ProcessNames) {
    try {
        $processes = Get-Process -Name $procName -ErrorAction SilentlyContinue
        foreach ($proc in $processes) {
            Write-Host "CORRECCION: Terminando proceso $($proc.Name) (PID: $($proc.Id))..."
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "CORRECCION: Advertencia al finalizar el proceso '$procName': $_"
    }
}
Start-Sleep -Seconds 2

# =============================================================================
# PASO 2: Desinstalación nativa silenciosa usando UninstallString del registro
# =============================================================================
Write-Host "CORRECCION: Buscando claves de desinstalacion en el registro..."
$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
)
$SearchPatterns = @(
    "*Warcraft I and II Remastered*",
    "*Warcraft I & II Remastered*",
    "*Warcraft*ElAmigos*"
)

$detectedKeys = @()

# 2.1 Buscar en HKLM y HKCU (del sistema/usuario actual)
foreach ($basePath in $UninstallPaths) {
    if (Test-Path $basePath) {
        $keys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
        foreach ($key in $keys) {
            $displayName = $key.GetValue("DisplayName")
            if ($null -ne $displayName) {
                foreach ($pattern in $SearchPatterns) {
                    if ($displayName -like $pattern) {
                        $detectedKeys += [PSCustomObject]@{
                            RegistryPath = $key.PSPath
                            DisplayName  = $displayName
                            UninstallString = $key.GetValue("UninstallString")
                            QuietUninstallString = $key.GetValue("QuietUninstallString")
                        }
                        break
                    }
                }
            }
        }
    }
}

# 2.2 Buscar en perfiles de usuario cargados en HKEY_USERS (HKU)
try {
    $loadedUsers = Get-ChildItem -Path "Registry::HKEY_USERS" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like "S-1-5-21-*" -and $_.PSChildName -notlike "*-Classes" }
    foreach ($user in $loadedUsers) {
        $sid = $user.PSChildName
        $userUninstallPath = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall"
        if (Test-Path $userUninstallPath) {
            $keys = Get-ChildItem -Path $userUninstallPath -ErrorAction SilentlyContinue
            foreach ($key in $keys) {
                $displayName = $key.GetValue("DisplayName")
                if ($null -ne $displayName) {
                    foreach ($pattern in $SearchPatterns) {
                        if ($displayName -like $pattern) {
                            $detectedKeys += [PSCustomObject]@{
                                RegistryPath = $key.PSPath
                                DisplayName  = $displayName
                                UninstallString = $key.GetValue("UninstallString")
                                QuietUninstallString = $key.GetValue("QuietUninstallString")
                            }
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

# 2.3 Ejecutar los comandos de desinstalación de forma silenciosa
$uninstalledCount = 0
foreach ($app in $detectedKeys) {
    $uninstallCommand = ""
    if ($app.QuietUninstallString) {
        $uninstallCommand = $app.QuietUninstallString
    } elseif ($app.UninstallString) {
        $rawString = $app.UninstallString
        # ElAmigos utiliza comunmente instaladores basados en Inno Setup (unins000.exe)
        if ($rawString -like "*unins*.exe*") {
            # Extraer ruta del desinstalador (manejando comillas)
            if ($rawString -match '^"([^"]+)"') {
                $uninstallerPath = $Matches[1]
            } else {
                $uninstallerPath = $rawString.Split(' ')[0]
            }
            # Parámetros silenciosos típicos de Inno Setup
            $uninstallCommand = "`"$uninstallerPath`" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
        } else {
            # Intento genérico de parámetros silenciosos por si acaso
            $uninstallCommand = "$rawString /S /silent /quiet /qn /norestart"
        }
    }

    if ($uninstallCommand) {
        try {
            Write-Host "CORRECCION: Ejecutando comando de desinstalacion para '$($app.DisplayName)': $uninstallCommand"
            $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$uninstallCommand`"" -Wait -NoNewWindow -PassThru -ErrorAction Stop
            if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
                Write-Host "CORRECCION: Desinstalador ejecutado con éxito (ExitCode: $($proc.ExitCode))."
                $uninstalledCount++
            } else {
                Write-Host "CORRECCION: Advertencia: El desinstalador retorno exit code $($proc.ExitCode)."
            }
        } catch {
            Write-Host "CORRECCION: ERROR al invocar el desinstalador: $_"
        }
    }
}

if ($uninstalledCount -gt 0) {
    Start-Sleep -Seconds 5
}

# =============================================================================
# PASO 3: Forzar eliminación de carpetas de instalación físicas y datos residuales
# =============================================================================
Write-Host "CORRECCION: Eliminando carpetas residuales en el disco..."
$PathsToDelete = [System.Collections.Generic.List[string]]::new()

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
foreach ($kd in $KnownDirs) { $PathsToDelete.Add($kd) }

# Escanear dinámicamente directorios relacionados con Warcraft en C:\Games
if (Test-Path "C:\Games") {
    try {
        $dynamicGames = Get-ChildItem -Path "C:\Games" -Directory -Filter "*Warcraft*" -ErrorAction SilentlyContinue
        foreach ($dg in $dynamicGames) {
            if ($PathsToDelete -notcontains $dg.FullName) { $PathsToDelete.Add($dg.FullName) }
        }
    } catch {}
}

# Escaneo de perfiles de usuario
$ProfilePaths = Get-ChildItem -Path "C:\Users" -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }
foreach ($profile in $ProfilePaths) {
    if ($profile.Name -in @("All Users", "Default", "Default User", "Public")) { continue }
    $userPath = $profile.FullName
    
    # Directorios de juegos/programas en perfil de usuario
    $PathsToDelete.Add((Join-Path $userPath "Games\Warcraft I and II Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "Games\Warcraft I & II Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "AppData\Local\Programs\Warcraft I and II Remastered"))

    # Escanear dinámicamente el directorio Games del usuario
    $userGames = Join-Path $userPath "Games"
    if (Test-Path $userGames) {
        try {
            $dynamicUserGames = Get-ChildItem -Path $userGames -Directory -Filter "*Warcraft*" -ErrorAction SilentlyContinue
            foreach ($dug in $dynamicUserGames) {
                if ($PathsToDelete -notcontains $dug.FullName) { $PathsToDelete.Add($dug.FullName) }
            }
        } catch {}
    }

    # Datos de aplicación residuales (AppData)
    $PathsToDelete.Add((Join-Path $userPath "AppData\Local\Warcraft I and II Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "AppData\Roaming\Warcraft I and II Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "AppData\Local\Warcraft I & II Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "AppData\Roaming\Warcraft I & II Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "AppData\Local\Warcraft I Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "AppData\Local\Warcraft II Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "AppData\Roaming\Warcraft I Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "AppData\Roaming\Warcraft II Remastered"))

    # Documentos y Saved Games (partidas guardadas y configuraciones)
    $PathsToDelete.Add((Join-Path $userPath "Documents\Warcraft I and II Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "Documents\Warcraft I & II Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "Saved Games\Warcraft I and II Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "Saved Games\Warcraft I & II Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "Saved Games\Warcraft I Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "Saved Games\Warcraft II Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "Documents\Warcraft I Remastered"))
    $PathsToDelete.Add((Join-Path $userPath "Documents\Warcraft II Remastered"))
}

# Ejecutar eliminación física
foreach ($target in $PathsToDelete) {
    Remove-DirectoryOrFile -Path $target
}

# =============================================================================
# PASO 4: Limpieza de Claves de Registro Residuales (incluyendo perfiles offline)
# =============================================================================
Write-Host "CORRECCION: Limpiando claves de registro del sistema y de usuarios..."

# 4.1 Claves en HKLM
foreach ($app in $detectedKeys) {
    if ($app.RegistryPath -like "*HKEY_LOCAL_MACHINE*") {
        # Traducir a sintaxis de PowerShell Drive
        $psDrivePath = $app.RegistryPath -replace "HKEY_LOCAL_MACHINE", "HKLM:" -replace "Registry::", ""
        Remove-RegistryKey -Path $psDrivePath
    }
}

# 4.2 Limpieza y descarga en perfiles de usuario offline (NTUSER.DAT)
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
            Remove-RegistryKey -Path "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall\Warcraft I and II Remastered_elamigos"
            Remove-RegistryKey -Path "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Uninstall\Warcraft I and II Remastered"
            Remove-RegistryKey -Path "Registry::HKEY_USERS\$sid\Software\Warcraft I and II Remastered"
        } else {
            $ntuserPath = Join-Path $profileImagePath "NTUSER.DAT"
            if (Test-Path $ntuserPath) {
                $tempHiveName = "WarcraftClean_$sid"
                $loaded = $false
                try {
                    & reg.exe load "HKU\$tempHiveName" "$ntuserPath" 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        $loaded = $true
                        Remove-RegistryKey -Path "Registry::HKEY_USERS\$tempHiveName\Software\Microsoft\Windows\CurrentVersion\Uninstall\Warcraft I and II Remastered_elamigos"
                        Remove-RegistryKey -Path "Registry::HKEY_USERS\$tempHiveName\Software\Microsoft\Windows\CurrentVersion\Uninstall\Warcraft I and II Remastered"
                        Remove-RegistryKey -Path "Registry::HKEY_USERS\$tempHiveName\Software\Warcraft I and II Remastered"
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

# =============================================================================
# PASO 5: Escaneo y eliminación de accesos directos (.lnk)
# =============================================================================
Write-Host "CORRECCION: Eliminando accesos directos (.lnk) del juego..."
$ShortcutDirs = [System.Collections.Generic.List[string]]::new()
if (Test-Path "C:\Users\Public\Desktop") { $ShortcutDirs.Add("C:\Users\Public\Desktop") }
if (Test-Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs") { $ShortcutDirs.Add("$env:ProgramData\Microsoft\Windows\Start Menu\Programs") }

foreach ($profile in $ProfilePaths) {
    if ($profile.Name -in @("All Users", "Default", "Default User", "Public")) { continue }
    $userPath = $profile.FullName
    $userDesktop = Join-Path $userPath "Desktop"
    $userStartMenu = Join-Path $userPath "AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
    if (Test-Path $userDesktop) { $ShortcutDirs.Add($userDesktop) }
    if (Test-Path $userStartMenu) { $ShortcutDirs.Add($userStartMenu) }
}

$lnkFiles = @()
foreach ($dir in $ShortcutDirs) {
    $lnkFiles += Get-ChildItem -Path $dir -Filter "*.lnk" -Recurse -File -ErrorAction SilentlyContinue
}

if ($lnkFiles.Count -gt 0) {
    try {
        $wshShell = New-Object -ComObject WScript.Shell
        foreach ($file in $lnkFiles) {
            # Si el acceso directo contiene Warcraft o está bajo una carpeta de ElAmigos
            if ($file.Name -like "*Warcraft*" -or $file.FullName -like "*ElAmigos*") {
                try {
                    $shortcut = $wshShell.CreateShortcut($file.FullName)
                    $target = $shortcut.TargetPath
                    if ($target -like "*Warcraft*" -or $target -like "*unins000.exe*" -or $file.FullName -like "*ElAmigos*") {
                        Write-Host "CORRECCION: Eliminando acceso directo: $($file.FullName) (Apunta a: $target)"
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    }
                } catch {
                    Write-Host "CORRECCION: Advertencia al procesar acceso directo $($file.FullName): $_"
                }
            }
        }
    } catch {
        Write-Host "CORRECCION: ERROR al inicializar objeto COM de accesos directos: $_"
    }

    # Limpieza de carpetas vacías de ElAmigos en el Start Menu o Escritorio
    foreach ($dir in $ShortcutDirs) {
        $elAmigosFolder = Join-Path $dir "ElAmigos"
        if (Test-Path $elAmigosFolder) {
            try {
                $files = Get-ChildItem -Path $elAmigosFolder -Force -ErrorAction SilentlyContinue
                if ($null -eq $files -or $files.Count -eq 0) {
                    Write-Host "CORRECCION: Eliminando carpeta vacía de ElAmigos: $elAmigosFolder"
                    Remove-Item -Path $elAmigosFolder -Force -Recurse -ErrorAction SilentlyContinue
                }
            } catch {}
        }
    }
}

# =============================================================================
# PASO 6: Post-auditoria rápida de validación
# =============================================================================
Write-Host "CORRECCION: Iniciando post-auditoria de validacion..."
$PostVerificationFailed = $false

# Verificar si queda algún proceso ejecutándose
foreach ($procName in $ProcessNames) {
    $residualProcesses = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($residualProcesses) {
        Write-Host "CORRECCION: ERROR: Siguen existiendo procesos activos de: $procName"
        $PostVerificationFailed = $true
    }
}

# Comprobar directorios críticos residuales de sistema
$criticalDirs = @(
    "C:\Games\Warcraft I and II Remastered",
    "C:\Games\Warcraft I & II Remastered",
    "C:\Games\Warcraft I and II Remastered MULTi11 - ElAmigos"
)
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
