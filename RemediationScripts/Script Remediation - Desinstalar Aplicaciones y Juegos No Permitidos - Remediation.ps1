<#
.SYNOPSIS
    REMEDIATION SCRIPT: ELIMINAR APLICACIONES Y JUEGOS NO PERMITIDOS

.DESCRIPTION
    Este script elimina las siguientes aplicaciones de juego o software no permitido de dispositivos
    Windows 10/11 gestionados por Intune:

      - Microsoft.MinecraftJavaEdition  (Minecraft Java Edition)
      - Microsoft.MinecraftUWP          (Minecraft para Windows)
      - Microsoft.MicrosoftSolitaireCollection (Microsoft Solitaire Collection)
      - Microsoft.MicrosoftSudoku       (Microsoft Sudoku)
      - Steam
      - Epic Games Launcher
      - Riot Client / Riot Vanguard / Valorant / League of Legends
      - Rocket League
      - Hytale Launcher
      - WinDS Pro
      - Porofessor Standalone (Overwolf)
      - WeMod / Wand
      - Wargaming Group (World of Tanks, World of Warships, World of Warplanes)
      - Hakchi2 CE
      - Transmission (P2P Torrent Downloader)
      - qBittorrent (P2P Torrent Downloader)
      - SideQuest

    Pasos de remediacion:
      1. Finalizar procesos activos de los juegos y aplicaciones no permitidas
      2. Detener y eliminar servicios de Riot Vanguard
      3. Ejecutar desinstaladores tradicionales nativos/registro de forma silenciosa
      4. Eliminar paquetes AppX para todos los usuarios y provisionados
      5. Limpiar carpetas fisicas de instalacion y archivos residuales (AppData)
      6. Limpiar claves de registro de software residuales
      7. Limpiar accesos directos residuales de escritorios y menus de inicio

    Salida:
      - Exit 0: Remediacion completada con exito
      - Exit 1: Alguno de los componentes no pudo eliminarse

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Desinstalar Aplicaciones y Juegos No Permitidos - Remediation.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.5.0
    Date: 2026-06-27
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

Write-Host "Iniciando eliminacion de aplicaciones y juegos no permitidos..."

# 1. Definiciones de aplicaciones AppX a desinstalar por nombre de paquete exacto
$TargetAppxApps = @(
    [PSCustomObject]@{ PackageName = "Microsoft.MinecraftJavaEdition"; DisplayName = "Minecraft Java Edition" },
    [PSCustomObject]@{ PackageName = "Microsoft.MinecraftUWP"; DisplayName = "Minecraft para Windows" },
    [PSCustomObject]@{ PackageName = "Microsoft.MicrosoftSolitaireCollection"; DisplayName = "Microsoft Solitaire Collection" },
    [PSCustomObject]@{ PackageName = "Microsoft.MicrosoftSudoku"; DisplayName = "Microsoft Sudoku" }
)

# Patrones para paquetes AppX/Store comodines
$WildcardAppxNames = @(
    "*Steam*",
    "*EpicGames*",
    "*RiotClient*",
    "*RiotVanguard*",
    "*Valorant*",
    "*LeagueOfLegends*",
    "*RocketLeague*",
    "*Rocket League*",
    "*Hytale*",
    "*WinDS*",
    "*Porofessor*",
    "*Overwolf*",
    "*WeMod*",
    "*Wand*",
    "*Wargaming*",
    "*World of Tanks*",
    "*World of Warships*",
    "*WorldOfTanks*",
    "*WorldOfWarships*",
    "*hakchi*",
    "*transmission*",
    "*qbittorrent*",
    "*sidequest*"
)

# Nombres de procesos a finalizar
$ProcessNamesToKill = @(
    "Minecraft", "MinecraftLauncher", "javaw", "MinecraftJavaEdition",
    "Minecraft.Windows", "MinecraftUWP",
    "MicrosoftSolitaireCollection", "Solitaire",
    "MicrosoftSudoku",
    "steam", "steamwebhelper", "GameOverlayUI",
    "EpicGamesLauncher", "EpicWebHelper", "UnrealCEFSubProcess",
    "RiotClientServices", "RiotClientUx", "RiotClient", "RiotClientUxRender",
    "vgc", "vgk", "Valorant", "LeagueClient", "League of Legends",
    "RocketLeague", "hytale-launcher", "hytale", "windspro", "windsprox",
    "WinDSpro2", "WinDSpro3", "config", "Overwolf", "OverwolfLauncher",
    "Porofessor", "Porofessor.gg", "WeMod", "Wand", "WeModAuxiliaryService",
    "wgc", "wgc_api", "WorldOfWarships", "WorldOfTanks", "WorldOfWarplanes",
    "hakchi", "hakchi2", "transmission-qt", "transmission-daemon", "qbittorrent", "SideQuest"
)

$DisallowedAppNames = @(
    "Steam",
    "Epic Games Launcher",
    "Riot Client",
    "Riot Vanguard",
    "League of Legends",
    "Valorant",
    "Rocket League",
    "Hytale",
    "WinDS Pro",
    "Porofessor",
    "Overwolf",
    "WeMod",
    "Wand",
    "Wargaming",
    "World of Tanks",
    "World of Warships",
    "World of Warplanes",
    "Hakchi2",
    "Hakchi2 CE",
    "Transmission",
    "qBittorrent",
    "SideQuest"
)

# =============================================================================
# PASO 1: Finalizar procesos activos de los juegos
# =============================================================================
Write-Host "--- Paso 1: Finalizando procesos activos ---"
foreach ($procName in $ProcessNamesToKill) {
    try {
        Get-Process -Name $procName -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "  Terminando proceso: $($_.Name) (PID: $($_.Id))"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "  Advertencia al terminar '$procName': $_"
    }
}
Start-Sleep -Seconds 2

# =============================================================================
# PASO 2: Detener y eliminar servicios de Riot Vanguard
# =============================================================================
Write-Host "--- Paso 2: Eliminando servicios de Riot Vanguard ---"
$VanguardServices = @("vgc", "vgk")
foreach ($svc in $VanguardServices) {
    try {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Write-Host "  Deteniendo servicio: $svc"
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Write-Host "  Eliminando servicio: $svc"
            sc.exe delete $svc | Out-Null
        }
    } catch {
        Write-Host "  Advertencia al detener/eliminar el servicio ${svc}: $_"
    }
}

# =============================================================================
# PASO 3: Desinstalacion nativa tradicional de aplicaciones desde el Registro
# =============================================================================
Write-Host "--- Paso 3: Ejecutando desinstaladores tradicionales ---"

# 3.1 Steam
$steamKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam"
)

foreach ($keyPath in $steamKeys) {
    if (Test-Path $keyPath) {
        $uninstallString = (Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue).UninstallString
        if ($uninstallString) {
            $uninstallString = $uninstallString -replace '"', ''
            if (Test-Path $uninstallString) {
                Write-Host "  Ejecutando desinstalador de Steam: $uninstallString /S"
                try {
                    $proc = Start-Process -FilePath $uninstallString -ArgumentList "/S" -Wait -NoNewWindow -PassThru -ErrorAction Stop
                    Write-Host "  -> Codigo de salida Steam uninstaller: $($proc.ExitCode)"
                } catch {
                    Write-Host "  -> Advertencia: No se pudo iniciar desinstalador nativo de Steam ($($_.Exception.Message)). Se delegara la eliminacion al borrado de carpetas."
                }
            }
        }
    }
}

# 3.2 Epic Games Launcher (MSI)
$registryUninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($path in $registryUninstallPaths) {
    try {
        $keys = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        foreach ($key in $keys) {
            if ($key.DisplayName -like "*Epic Games Launcher*") {
                $uninstallString = $key.UninstallString
                if ($uninstallString) {
                    if ($uninstallString -match '({[A-Z0-9\-]+})') {
                        $guid = $Matches[1]
                        Write-Host "  Ejecutando desinstalacion MSI para Epic Games ($guid)..."
                        try {
                            $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/X $guid /qn /norestart" -Wait -NoNewWindow -PassThru -ErrorAction Stop
                            Write-Host "  -> Codigo de salida Epic Games uninstaller: $($proc.ExitCode)"
                        } catch {
                            Write-Host "  -> Advertencia: No se pudo iniciar desinstalador MSI de Epic Games ($($_.Exception.Message)). Se delegara la eliminacion al borrado de carpetas."
                        }
                    } else {
                        Write-Host "  Ejecutando desinstalador Epic Games: $uninstallString"
                        $cmd = $uninstallString -replace '"', ''
                        try {
                            if (Test-Path $cmd) {
                                Start-Process -FilePath $cmd -ArgumentList "/S" -Wait -NoNewWindow -ErrorAction Stop
                            } else {
                                cmd.exe /c $uninstallString /S
                            }
                        } catch {
                            Write-Host "  -> Advertencia: No se pudo iniciar desinstalador nativo de Epic Games ($($_.Exception.Message)). Se delegara la eliminacion al borrado de carpetas."
                        }
                    }
                }
            }
        }
    } catch {
        # Ignorar errores
    }
}

# 3.3 Riot Client
$riotClientPath = "C:\Riot Games\Riot Client\RiotClientServices.exe"
if (Test-Path $riotClientPath) {
    Write-Host "  Ejecutando desinstalador de Riot Client..."
    try {
        $proc = Start-Process -FilePath $riotClientPath -ArgumentList "--uninstall-product=Riot_Client --uninstall-patchline=" -Wait -NoNewWindow -PassThru -ErrorAction Stop
        Write-Host "  -> Codigo de salida Riot Client uninstaller: $($proc.ExitCode)"
    } catch {
        Write-Host "  -> Advertencia: No se pudo iniciar desinstalador nativo de Riot ($($_.Exception.Message)). Se delegara la eliminacion al borrado de carpetas."
    }
}

# 3.4 Otras aplicaciones (Hytale, WinDS Pro, Porofessor, Overwolf, WeMod, Wand, Wargaming, World of Tanks, World of Warships, World of Warplanes, Hakchi2 CE, Transmission, qBittorrent, SideQuest)
Write-Host "  Buscando desinstaladores para Hytale, WinDS Pro, Porofessor, Overwolf, WeMod, Wand, Wargaming, World of Tanks, World of Warships, World of Warplanes, Hakchi2 CE, Transmission, qBittorrent y SideQuest en el Registro..."
$OtherDisallowedApps = @("Hytale", "WinDS Pro", "Porofessor", "Overwolf", "WeMod", "Wand", "Wargaming", "World of Tanks", "World of Warships", "World of Warplanes", "Hakchi2", "Hakchi2 CE", "Transmission", "qBittorrent", "SideQuest")
foreach ($path in $registryUninstallPaths) {
    try {
        if (Test-Path $path) {
            $subkeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
            foreach ($subkey in $subkeys) {
                $displayName = (Get-ItemProperty -Path $subkey.PSPath -ErrorAction SilentlyContinue).DisplayName
                if ($null -ne $displayName) {
                    $match = $false
                    foreach ($app in $OtherDisallowedApps) {
                        if ($displayName -like "*$app*") {
                            $match = $true
                        }
                    }
                    if ($match) {
                        $uninstallString = (Get-ItemProperty -Path $subkey.PSPath -ErrorAction SilentlyContinue).UninstallString
                        $quietUninstallString = (Get-ItemProperty -Path $subkey.PSPath -ErrorAction SilentlyContinue).QuietUninstallString
                        
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
                                    $uninstallCommand = "`"$cleanUninstallString`" /S"
                                } else {
                                    $uninstallCommand = $uninstallString
                                }
                            } else {
                                $uninstallCommand = "$uninstallString /S /silent /quiet /qn /norestart"
                            }
                        }
                        
                        if ($uninstallCommand) {
                            Write-Host "  Ejecutando desinstalacion para ${displayName}: $uninstallCommand"
                            try {
                                $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallCommand" -Wait -NoNewWindow -PassThru
                                Write-Host "  -> Codigo de salida uninstaller: $($proc.ExitCode)"
                            } catch {
                                Write-Host "  -> Advertencia: No se pudo iniciar desinstalador nativo para $displayName ($($_.Exception.Message))"
                            }
                        }
                    }
                }
            }
        }
    } catch {
        # Ignorar errores de registro
    }
}

# =============================================================================
# PASO 4: Eliminar paquetes AppX/Store
# =============================================================================
Write-Host "--- Paso 4: Eliminando paquetes AppX (todos los usuarios y provisionados) ---"

# 4.1 Paquetes exactos (Minecraft, Solitaire, Sudoku)
foreach ($app in $TargetAppxApps) {
    try {
        $pkgs = Get-AppxPackage -AllUsers -Name $app.PackageName -ErrorAction SilentlyContinue
        foreach ($pkg in $pkgs) {
            Write-Host "  Eliminando [$($app.DisplayName)]: $($pkg.PackageFullName)"
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                Write-Host "  -> Eliminado correctamente."
            } catch {
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                    Write-Host "  -> Eliminado (sin -AllUsers)."
                } catch {
                    Write-Host "  -> Advertencia al eliminar paquete: $_"
                }
            }
        }
    } catch {
        Write-Host "  Advertencia al buscar '$($app.PackageName)': $_"
    }
}

# 4.2 Paquetes comodines (Steam, Epic, Riot)
try {
    $allAppx = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    if ($allAppx) {
        foreach ($pattern in $WildcardAppxNames) {
            $matches = $allAppx | Where-Object { ($_.Name -like $pattern -or $_.PackageFullName -like $pattern) -and $_.Name -notlike "*Teams*" }
            foreach ($pkg in $matches) {
                Write-Host "  Eliminando paquete detectado por patron '$pattern': $($pkg.PackageFullName)"
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                } catch {
                    try {
                        Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                    } catch {
                        Write-Host "  -> Advertencia al eliminar paquete comodín: $_"
                    }
                }
            }
        }
    }
} catch {
    Write-Host "  Advertencia al buscar todos los AppX: $_"
}

# 4.3 Paquetes provisionados
try {
    $provisionedPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    if ($provisionedPkgs) {
        # Exactos
        foreach ($app in $TargetAppxApps) {
            $matches = $provisionedPkgs | Where-Object { $_.DisplayName -eq $app.PackageName }
            foreach ($pkg in $matches) {
                Write-Host "  Eliminando paquete provisionado [$($app.DisplayName)]: $($pkg.PackageName)"
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
                } catch {
                    Write-Host "  -> Advertencia al eliminar paquete provisionado exacto: $_"
                }
            }
        }
        # Comodines
        foreach ($pattern in $WildcardAppxNames) {
            $matches = $provisionedPkgs | Where-Object { ($_.DisplayName -like $pattern -or $_.PackageName -like $pattern) -and $_.DisplayName -notlike "*Teams*" }
            foreach ($pkg in $matches) {
                Write-Host "  Eliminando paquete provisionado detectado por patron '$pattern': $($pkg.PackageName)"
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
                } catch {
                    Write-Host "  -> Advertencia al eliminar paquete provisionado comodín: $_"
                }
            }
        }
    }
} catch {
    Write-Host "  Advertencia al obtener paquetes provisionados: $_"
}

# =============================================================================
# PASO 5: Limpiar carpetas fisicas y archivos residuales
# =============================================================================
Write-Host "--- Paso 5: Limpiando directorios fisicos residuales ---"
$FoldersToDelete = @(
    "$env:ProgramFiles\Steam",
    "${env:ProgramFiles(x86)}\Steam",
    "$env:ProgramFiles\Epic Games",
    "${env:ProgramFiles(x86)}\Epic Games",
    "C:\Riot Games",
    "$env:ProgramFiles\Riot Vanguard",
    "${env:ProgramFiles(x86)}\Riot Vanguard",
    "$env:ProgramData\Epic",
    "$env:ProgramData\Riot Games",
    "$env:ProgramFiles\Epic Games\rocketleague",
    "${env:ProgramFiles(x86)}\Epic Games\rocketleague",
    "$env:ProgramFiles\Steam\steamapps\common\rocketleague",
    "${env:ProgramFiles(x86)}\Steam\steamapps\common\rocketleague",
    "$env:ProgramFiles\Hytale",
    "${env:ProgramFiles(x86)}\Hytale",
    "$env:ProgramData\Hytale",
    "$env:ProgramFiles\WinDS PRO",
    "${env:ProgramFiles(x86)}\WinDS PRO",
    "$env:ProgramFiles\Overwolf",
    "${env:ProgramFiles(x86)}\Overwolf",
    "$env:ProgramData\Overwolf",
    "$env:ProgramFiles\Wargaming.net",
    "${env:ProgramFiles(x86)}\Wargaming.net",
    "C:\Games\Wargaming.net",
    "C:\Games\World_of_Tanks",
    "C:\Games\World_of_Tanks_EU",
    "C:\Games\World_of_Warships",
    "C:\Games\World_of_Warships_EU",
    "C:\Games\World_of_Warplanes",
    "${env:ProgramFiles(x86)}\Team Shinkansen",
    "$env:ProgramFiles\Team Shinkansen",
    "$env:ProgramData\Team Shinkansen",
    "$env:ProgramFiles\Transmission",
    "${env:ProgramFiles(x86)}\Transmission",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Transmission",
    "$env:ProgramFiles\qBittorrent",
    "${env:ProgramFiles(x86)}\qBittorrent",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\qBittorrent",
    "$env:ProgramFiles\SideQuest",
    "${env:ProgramFiles(x86)}\SideQuest"
)

# Obtener perfiles de usuarios locales para AppData y Documentos
$userProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
foreach ($profile in $userProfiles) {
    $username = $profile.Name
    if ($username -notin @("Public", "Default", "All Users")) {
        $FoldersToDelete += @(
            "C:\Users\$username\AppData\Local\Steam",
            "C:\Users\$username\AppData\Roaming\Steam",
            "C:\Users\$username\AppData\Local\EpicGamesLauncher",
            "C:\Users\$username\AppData\Roaming\EpicGamesLauncher",
            "C:\Users\$username\AppData\Local\Riot Games",
            "C:\Users\$username\AppData\Roaming\Riot Games",
            "C:\Users\$username\AppData\Local\Rocket League",
            "C:\Users\$username\Documents\My Games\Rocket League",
            "C:\Users\$username\AppData\Local\Hytale",
            "C:\Users\$username\AppData\Roaming\Hytale",
            "C:\Users\$username\AppData\Local\WinDS PRO",
            "C:\Users\$username\AppData\Roaming\WinDS PRO",
            "C:\Users\$username\AppData\Local\Overwolf",
            "C:\Users\$username\AppData\Roaming\Overwolf",
            "C:\Users\$username\AppData\Local\Porofessor",
            "C:\Users\$username\AppData\Local\WeMod",
            "C:\Users\$username\AppData\Roaming\WeMod",
            "C:\Users\$username\AppData\Local\Wand",
            "C:\Users\$username\AppData\Roaming\Wand",
            "C:\Users\$username\AppData\Local\Wargaming.net",
            "C:\Users\$username\AppData\Roaming\Wargaming.net",
            "C:\Users\$username\Documents\Hakchi2",
            "C:\Users\$username\AppData\Local\hakchi2-ce",
            "C:\Users\$username\AppData\Local\Transmission",
            "C:\Users\$username\AppData\Roaming\Transmission",
            "C:\Users\$username\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Transmission",
            "C:\Users\$username\AppData\Local\qBittorrent",
            "C:\Users\$username\AppData\Roaming\qBittorrent",
            "C:\Users\$username\AppData\Local\Programs\qBittorrent",
            "C:\Users\$username\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\qBittorrent",
            "C:\Users\$username\AppData\Local\Programs\SideQuest",
            "C:\Users\$username\AppData\Local\SideQuest",
            "C:\Users\$username\AppData\Roaming\SideQuest"
        )
    }
}

foreach ($folder in $FoldersToDelete) {
    if (Test-Path $folder) {
        Write-Host "  Eliminando carpeta: $folder"
        try {
            Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
            Write-Host "  -> Eliminada correctamente."
        } catch {
            Write-Host "  -> Advertencia al eliminar carpeta: $_. Reintentando por comandos..."
            try {
                cmd.exe /c "rmdir /s /q `"$folder`""
            } catch {}
        }
    }
}

# =============================================================================
# PASO 6: Limpiar claves de registro residuales
# =============================================================================
Write-Host "--- Paso 6: Limpiando claves de registro residuales ---"
foreach ($path in $registryUninstallPaths) {
    try {
        if (Test-Path $path) {
            $subkeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
            foreach ($subkey in $subkeys) {
                $displayName = (Get-ItemProperty -Path $subkey.PSPath -ErrorAction SilentlyContinue).DisplayName
                if ($null -ne $displayName) {
                    $match = $false
                    foreach ($disallowedName in $DisallowedAppNames) {
                        if ($displayName -like "*$disallowedName*" -and $displayName -notlike "*Teams*") {
                            $match = $true
                        }
                    }
                    if ($match) {
                        Write-Host "  Eliminando clave de registro: $($subkey.PSPath)"
                        Remove-Item -Path $subkey.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    } catch {
        # Ignorar errores de registro
    }
}

$softwareKeys = @(
    "HKLM:\SOFTWARE\Riot Games",
    "HKLM:\SOFTWARE\Wow6432Node\Riot Games",
    "HKCU:\Software\Riot Games",
    "HKLM:\SOFTWARE\Valve",
    "HKLM:\SOFTWARE\Wow6432Node\Valve",
    "HKCU:\Software\Valve",
    "HKLM:\SOFTWARE\Epic Games",
    "HKLM:\SOFTWARE\Wow6432Node\Epic Games",
    "HKCU:\Software\Epic Games",
    "HKLM:\SOFTWARE\EpicGames",
    "HKLM:\SOFTWARE\Wow6432Node\EpicGames",
    "HKCU:\Software\EpicGames",
    "HKLM:\SOFTWARE\Hypixel Studios",
    "HKLM:\SOFTWARE\Wow6432Node\Hypixel Studios",
    "HKCU:\Software\Hypixel Studios",
    "HKLM:\SOFTWARE\WinDS PRO",
    "HKLM:\SOFTWARE\Wow6432Node\WinDS PRO",
    "HKCU:\Software\WinDS PRO",
    "HKLM:\SOFTWARE\Overwolf",
    "HKLM:\SOFTWARE\Wow6432Node\Overwolf",
    "HKCU:\Software\Overwolf",
    "HKLM:\SOFTWARE\WeMod",
    "HKLM:\SOFTWARE\Wow6432Node\WeMod",
    "HKCU:\Software\WeMod",
    "HKLM:\SOFTWARE\Wand",
    "HKLM:\SOFTWARE\Wow6432Node\Wand",
    "HKCU:\Software\Wand",
    "HKLM:\SOFTWARE\Wargaming.net",
    "HKLM:\SOFTWARE\Wow6432Node\Wargaming.net",
    "HKCU:\Software\Wargaming.net",
    "HKLM:\SOFTWARE\Team Shinkansen",
    "HKLM:\SOFTWARE\Wow6432Node\Team Shinkansen",
    "HKCU:\Software\Team Shinkansen",
    "HKLM:\SOFTWARE\Transmission",
    "HKLM:\SOFTWARE\Wow6432Node\Transmission",
    "HKCU:\Software\Transmission",
    "HKLM:\SOFTWARE\SideQuest",
    "HKLM:\SOFTWARE\Wow6432Node\SideQuest",
    "HKCU:\Software\SideQuest",
    "HKLM:\SOFTWARE\qBittorrent",
    "HKLM:\SOFTWARE\Wow6432Node\qBittorrent",
    "HKCU:\Software\qBittorrent"
)

foreach ($key in $softwareKeys) {
    if (Test-Path $key) {
        Write-Host "  Eliminando clave de software: $key"
        Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# =============================================================================
# PASO 7: Limpiar accesos directos residuales
# =============================================================================
Write-Host "--- Paso 7: Eliminando accesos directos residuales ---"
$ShortcutPatterns = @(
    "*Steam*",
    "*Epic Games*",
    "*Riot Client*",
    "*League of Legends*",
    "*Valorant*",
    "*Rocket League*",
    "*Hytale*",
    "*WinDS*",
    "*Porofessor*",
    "*Overwolf*",
    "*WeMod*",
    "*Wand*",
    "*Wargaming*",
    "*WGC*",
    "*World of Tanks*",
    "*World of Warships*",
    "*WorldOfTanks*",
    "*WorldOfWarships*",
    "*hakchi*",
    "*transmission*",
    "*qbittorrent*",
    "*sidequest*"
)

$ShortcutPaths = @(
    "C:\Users\Public\Desktop",
    "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
)

foreach ($profile in $userProfiles) {
    $username = $profile.Name
    if ($username -notin @("Public", "Default", "All Users")) {
        $ShortcutPaths += @(
            "C:\Users\$username\Desktop",
            "C:\Users\$username\AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
        )
    }
}

foreach ($folderPath in $ShortcutPaths) {
    if (Test-Path $folderPath) {
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
    }
}

Start-Sleep -Seconds 3

# =============================================================================
# POST-VERIFICACION
# =============================================================================
Write-Host "--- Post-verificacion ---"
$Failed = $false

# 1. Verificar AppX exactas restantes
foreach ($app in $TargetAppxApps) {
    $remaining = Get-AppxPackage -AllUsers -Name $app.PackageName -ErrorAction SilentlyContinue
    if ($remaining) {
        foreach ($pkg in $remaining) {
            Write-Host "ERROR: Paquete residual detectado [$($app.DisplayName)]: $($pkg.PackageFullName)"
            $Failed = $true
        }
    }
    $remainingProv = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $app.PackageName }
    if ($remainingProv) {
        foreach ($pkg in $remainingProv) {
            Write-Host "ERROR: Paquete provisionado residual [$($app.DisplayName)]: $($pkg.PackageName)"
            $Failed = $true
        }
    }
}

# 2. Verificar AppX comodines restantes
try {
    $allAppx = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    if ($allAppx) {
        foreach ($pattern in $WildcardAppxNames) {
            $remaining = $allAppx | Where-Object { ($_.Name -like $pattern -or $_.PackageFullName -like $pattern) -and $_.Name -notlike "*Teams*" }
            if ($remaining) {
                foreach ($pkg in $remaining) {
                    Write-Host "ERROR: Paquete residual detectado por patron '$pattern': $($pkg.PackageFullName)"
                    $Failed = $true
                }
            }
        }
    }
    $provisionedPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    if ($provisionedPkgs) {
        foreach ($pattern in $WildcardAppxNames) {
            $remainingProv = $provisionedPkgs | Where-Object { ($_.DisplayName -like $pattern -or $_.PackageName -like $pattern) -and $_.DisplayName -notlike "*Teams*" }
            if ($remainingProv) {
                foreach ($pkg in $remainingProv) {
                    Write-Host "ERROR: Paquete provisionado residual por patron '$pattern': $($pkg.PackageName)"
                    $Failed = $true
                }
            }
        }
    }
} catch {
    # Ignorar errores de búsqueda final
}

# 3. Verificar procesos activos residuales
foreach ($procName in $ProcessNamesToKill) {
    if (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
        Write-Host "ERROR: Proceso residual detectado: $procName"
        $Failed = $true
    }
}

# 4. Verificar rutas fisicas residuales
$PhysicalPathsToCheck = @(
    "$env:ProgramFiles\Steam\steam.exe",
    "${env:ProgramFiles(x86)}\Steam\steam.exe",
    "$env:ProgramFiles\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe",
    "${env:ProgramFiles(x86)}\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe",
    "C:\Riot Games\Riot Client\RiotClientServices.exe",
    "$env:ProgramFiles\Riot Vanguard\vgtray.exe",
    "$env:ProgramFiles\Epic Games\rocketleague\Binaries\Win64\RocketLeague.exe",
    "${env:ProgramFiles(x86)}\Epic Games\rocketleague\Binaries\Win64\RocketLeague.exe",
    "$env:ProgramFiles\Steam\steamapps\common\rocketleague\Binaries\Win64\RocketLeague.exe",
    "${env:ProgramFiles(x86)}\Steam\steamapps\common\rocketleague\Binaries\Win64\RocketLeague.exe",
    "$env:LocalAppData\Hytale\hytale-launcher.exe",
    "$env:ProgramFiles\Hytale\hytale-launcher.exe",
    "${env:ProgramFiles(x86)}\Hytale\hytale-launcher.exe",
    "$env:ProgramFiles\WinDS PRO\windspro.exe",
    "${env:ProgramFiles(x86)}\WinDS PRO\windspro.exe",
    "$env:LocalAppData\Overwolf\Overwolf.exe",
    "$env:ProgramFiles\Overwolf\Overwolf.exe",
    "${env:ProgramFiles(x86)}\Overwolf\Overwolf.exe",
    "$env:LocalAppData\Porofessor\Porofessor.exe",
    "$env:LocalAppData\WeMod\WeMod.exe",
    "$env:LocalAppData\Wand\Wand.exe",
    "$env:ProgramFiles\Wargaming.net\GameCenter\wgc.exe",
    "${env:ProgramFiles(x86)}\Wargaming.net\GameCenter\wgc.exe",
    "C:\Games\Wargaming.net\GameCenter\wgc.exe",
    "C:\Games\World_of_Tanks\WorldOfTanks.exe",
    "C:\Games\World_of_Tanks_EU\WorldOfTanks.exe",
    "C:\Games\World_of_Warships\WorldOfWarships.exe",
    "C:\Games\World_of_Warships_EU\WorldOfWarships.exe",
    "C:\Games\World_of_Warplanes\WorldOfWarplanes.exe",
    "${env:ProgramFiles(x86)}\Team Shinkansen\Hakchi2 CE\hakchi.exe",
    "$env:ProgramFiles\Team Shinkansen\Hakchi2 CE\hakchi.exe",
    "C:\Users\*\Documents\Hakchi2\hakchi.exe",
    "C:\Users\*\AppData\Local\hakchi2-ce\hakchi.exe",
    "$env:ProgramFiles\Transmission\transmission-qt.exe",
    "${env:ProgramFiles(x86)}\Transmission\transmission-qt.exe",
    "$env:ProgramFiles\Transmission\transmission-daemon.exe",
    "${env:ProgramFiles(x86)}\Transmission\transmission-daemon.exe",
    "$env:ProgramFiles\qBittorrent\qbittorrent.exe",
    "${env:ProgramFiles(x86)}\qBittorrent\qbittorrent.exe",
    "C:\Users\*\AppData\Local\Programs\qBittorrent\qbittorrent.exe",
    "$env:ProgramFiles\SideQuest\SideQuest.exe",
    "${env:ProgramFiles(x86)}\SideQuest\SideQuest.exe",
    "C:\Users\*\AppData\Local\Programs\SideQuest\SideQuest.exe"
)

foreach ($path in $PhysicalPathsToCheck) {
    if (Test-Path $path) {
        Write-Host "ERROR: Ejecutable fisico residual detectado: $path"
        $Failed = $true
    }
}

if ($Failed) {
    Write-Host "ERROR CRITICO: Algunas aplicaciones no pudieron eliminarse completamente."
    exit 1
} else {
    Write-Host "Remediacion finalizada con exito. Todas las aplicaciones y juegos no permitidos han sido eliminados."
    exit 0
}
