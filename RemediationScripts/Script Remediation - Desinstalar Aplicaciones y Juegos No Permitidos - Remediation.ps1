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
      - EA app / EA Launcher / Origin (EA Desktop)
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
      - Tixati (P2P Torrent Downloader)
      - BiglyBT (P2P Torrent Downloader)
      - SideQuest
      - JDownloader (Java Downloader)
      - Battle.net (Blizzard Launcher)
      - Apple TV (AppX / UWP)
      - Discord
      - DroidKit
      - AutoHotkey
      - Move Mouse
      - OP Auto Clicker
      - PlayStation Accessories
      - JiggleMouse
      - HBO / HBO Max / Max
      - Netflix
      - Amazon Prime Video
      - Stremio
      - Plex
      - Kodi
      - Disney+ / Disney Plus
      - Twitch
      - TikTok
      - Crunchyroll
      - BlueStacks
      - LDPlayer
      - RetroArch
      - Dolphin Emulator
      - PCSX2
      - uTorrent / uTorrent Web
      - BitTorrent
      - MEGAsync / MegaSync
      - Cheat Engine / Amstion Limited
      - Just Okay Limited (Auto Clicker)

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
    Version: 1.7.0
    Date: 2026-06-29
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
    [PSCustomObject]@{ PackageName = "Microsoft.MicrosoftSudoku"; DisplayName = "Microsoft Sudoku" },
    [PSCustomObject]@{ PackageName = "Disney.37853FC22B2CE"; DisplayName = "Disney+" }
)

# Patrones para paquetes AppX/Store comodines
$WildcardAppxNames = @(
    "*Steam*",
    "*EpicGames*",
    "*EAapp*",
    "*EA app*",
    "*ElectronicArts*",
    "*Origin*",
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
    "*tixati*",
    "*biglybt*",
    "*sidequest*",
    "*jdownloader*",
    "*battle.net*",
    "*blizzard*",
    "*AppleTV*",
    "*Apple.AppleTV*",
    "*Apple*TV*",
    "*AppleInc*TV*",
    "*Discord*",
    "*DroidKit*",
    "*AutoHotkey*",
    "*MoveMouse*",
    "*Move Mouse*",
    "*AutoClicker*",
    "*OPAutoClicker*",
    "*OP*AutoClicker*",
    "*AutoTap*",
    "*MouseClicker*",
    "*PlayStationAccessories*",
    "*PlayStation Accessories*",
    "*JiggleMouse*",
    "*Jiggle Mouse*",
    "*HBO*",
    "*HBOMax*",
    "*HBO.Max*",
    "*Netflix*",
    "*PrimeVideo*",
    "*Prime Video*",
    "*AmazonVideo*",
    "*Amazon.PrimeVideo*",
    "*Stremio*",
    "*Plex*",
    "*Kodi*",
    "*Disney*",
    "*DisneyPlus*",
    "*Disney*Plus*",
    "*Disney.37853FC22B2CE*",
    "*Twitch*",
    "*TikTok*",
    "*Crunchyroll*",
    "*BlueStacks*",
    "*HD-Player*",
    "*LDPlayer*",
    "*RetroArch*",
    "*Dolphin*",
    "*PCSX2*",
    "*uTorrent*",
    "*BitTorrent*",
    "*MEGAsync*",
    "*MegaSync*",
    "*CheatEngine*",
    "*Cheat Engine*",
    "*Amstion*",
    "*JustOkay*",
    "*Just Okay*"
)

# Nombres de procesos a finalizar
$ProcessNamesToKill = @(
    "Minecraft", "MinecraftLauncher", "javaw", "MinecraftJavaEdition",
    "Minecraft.Windows", "MinecraftUWP",
    "MicrosoftSolitaireCollection", "Solitaire",
    "MicrosoftSudoku",
    "steam", "steamwebhelper", "GameOverlayUI",
    "EpicGamesLauncher", "EpicWebHelper", "UnrealCEFSubProcess",
    "EADesktop", "EALauncher", "EABackgroundService", "Origin", "OriginWebHelperService", "OriginClientService",
    "RiotClientServices", "RiotClientUx", "RiotClient", "RiotClientUxRender",
    "vgc", "vgk", "Valorant", "LeagueClient", "League of Legends",
    "RocketLeague", "hytale-launcher", "hytale", "windspro", "windsprox",
    "WinDSpro2", "WinDSpro3", "config", "Overwolf", "OverwolfLauncher",
    "Porofessor", "Porofessor.gg", "WeMod", "Wand", "WeModAuxiliaryService",
    "wgc", "wgc_api", "WorldOfWarships", "WorldOfTanks", "WorldOfWarplanes",
    "hakchi", "hakchi2", "transmission-qt", "transmission-daemon", "qbittorrent", "tixati", "BiglyBT", "SideQuest",
    "JDownloader", "JDownloader2", "Battle.net", "Battle.net Launcher", "Battle.net Helper", "Agent",
    "AppleTV", "AppleTVWin", "Discord", "DiscordCanary", "DiscordPTB", "DiscordDevelopment", "Update", "DroidKit", "iMobieDroidKit", "DroidKitComponent",
    "AutoHotkey", "AutoHotkeyUX", "ahk2exe", "WindowSpy", "MoveMouse", "Move Mouse", "opautoclicker", "autoclicker", "AutoTap", "OPAutoClicker", "OP_AutoClicker", "AutoClicker3", "AutoClicker2", "OP_AutoClicker_3.0", "PlayStationAccessories", "PlayStationAccessoriesInstaller", "PSAInstall", "JiggleMouse", "Jiggle Mouse", "JiggleMouseApp",
    "HBOMax", "Max", "Netflix", "NetflixApp", "PrimeVideo", "AmazonPrimeVideo", "stremio", "Stremio", "Plex", "PlexMediaPlayer", "PlexDesktop", "PlexHTPC", "kodi", "Kodi",
    "DisneyPlus", "Disney", "Disney.37853FC22B2CE", "Twitch", "TikTok", "Crunchyroll", "HD-Player", "BlueStacks", "BlueStacksX", "BGAgent", "dnplayer", "ldplayer", "retroarch", "Dolphin", "pcsx2", "pcsx2-qt", "uTorrent", "uTorrentWeb", "utweb", "bittorrent", "MEGAsync",
    "cheatengine-x86_64", "cheatengine-i386", "Cheat Engine", "CheatEngine"
)

$DisallowedAppNames = @(
    "Steam",
    "Epic Games Launcher",
    "EA app",
    "Electronic Arts",
    "Origin",
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
    "Tixati",
    "BiglyBT",
    "SideQuest",
    "JDownloader",
    "JDownloader 2",
    "Battle.net",
    "Blizzard Entertainment",
    "Apple TV",
    "Discord",
    "DroidKit",
    "iMobie DroidKit",
    "AutoHotkey",
    "Move Mouse",
    "MoveMouse",
    "OP Auto Clicker",
    "OPAutoClicker",
    "Auto Clicker",
    "Auto Tap",
    "PlayStation Accessories",
    "PlayStationAccessories",
    "JiggleMouse",
    "Jiggle Mouse",
    "HBO",
    "HBO Max",
    "Max",
    "Netflix",
    "Prime Video",
    "Amazon Prime Video",
    "Stremio",
    "Plex",
    "Plex Media Player",
    "Plex Desktop",
    "Plex HTPC",
    "Kodi",
    "Disney",
    "Disney+",
    "Disney Plus",
    "Disney.37853FC22B2CE",
    "Twitch",
    "TikTok",
    "Crunchyroll",
    "BlueStacks",
    "BlueStacks App Player",
    "LDPlayer",
    "RetroArch",
    "Dolphin Emulator",
    "PCSX2",
    "uTorrent",
    "uTorrent Web",
    "BitTorrent",
    "MEGAsync",
    "MegaSync",
    "Cheat Engine",
    "CheatEngine",
    "Amstion",
    "Amstion Limited",
    "Just Okay",
    "Just Okay Limited",
    "{A27B17B9-90C8-4B07-83C6-1303FC186B6B}"
)

# =============================================================================
# PASO 1: Finalizar procesos activos de los juegos y aplicaciones
# =============================================================================
Write-Host "--- Paso 1: Finalizando procesos activos ---"
foreach ($procName in $ProcessNamesToKill) {
    try {
        Get-Process -Name $procName -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "  Terminando proceso PowerShell: $($_.Name) (PID: $($_.Id))"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
        # Refuerzo forzado vía cmd/taskkill para procesos activos en sesiones de usuario cuando se corre como SYSTEM
        cmd.exe /c "taskkill.exe /F /T /IM `${procName}.exe 2>nul" | Out-Null
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
# PASO 3: Desinstalacion nativa tradicional de aplicaciones desde el Registro (HKLM, HKCU, HKU)
# =============================================================================
Write-Host "--- Paso 3: Ejecutando desinstaladores tradicionales ---"

$registryUninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

try {
    $hkuSids = Get-ChildItem -Path "Registry::HKEY_USERS" -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -notlike "*.DEFAULT" -and $_.PSChildName -notlike "*_Classes" -and $_.PSChildName -match "^S-1-5-21-" } |
        Select-Object -ExpandProperty PSChildName

    foreach ($sid in $hkuSids) {
        $registryUninstallPaths += "Registry::HKEY_USERS\$sid\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $registryUninstallPaths += "Registry::HKEY_USERS\$sid\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    }
} catch {
    Write-Host "  Advertencia al obtener colmenas HKU para desinstalacion: $_"
}

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

# 3.4 Otras aplicaciones (incluyendo desinstaladores de usuario como Discord, DroidKit, AutoHotkey, etc.)
Write-Host "  Buscando desinstaladores para Discord, DroidKit, Apple TV, Steam, Epic Games, Riot, Torrent, launchers y herramientas en Registro (HKLM, HKCU, HKU)..."
$OtherDisallowedApps = @("Hytale", "WinDS Pro", "Porofessor", "Overwolf", "WeMod", "Wand", "Wargaming", "World of Tanks", "World of Warships", "World of Warplanes", "Hakchi2", "Hakchi2 CE", "Transmission", "qBittorrent", "EA app", "Origin", "Electronic Arts", "Tixati", "BiglyBT", "SideQuest", "JDownloader", "JDownloader 2", "Battle.net", "Blizzard Entertainment", "Discord", "DroidKit", "iMobie DroidKit", "AutoHotkey", "Move Mouse", "MoveMouse", "OP Auto Clicker", "OPAutoClicker", "Auto Clicker", "PlayStation Accessories", "PlayStationAccessories", "JiggleMouse", "Jiggle Mouse", "HBO", "HBO Max", "Max", "Netflix", "Prime Video", "Amazon Prime Video", "Stremio", "Plex", "Plex Media Player", "Kodi", "Disney", "Disney+", "Disney Plus", "Disney.37853FC22B2CE", "Twitch", "TikTok", "Crunchyroll", "BlueStacks", "LDPlayer", "RetroArch", "Dolphin", "PCSX2", "uTorrent", "BitTorrent", "MEGAsync", "Cheat Engine", "CheatEngine", "Amstion", "Just Okay")
foreach ($path in $registryUninstallPaths) {
    try {
        if (Test-Path $path) {
            $subkeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
            foreach ($subkey in $subkeys) {
                $displayName = (Get-ItemProperty -Path $subkey.PSPath -ErrorAction SilentlyContinue).DisplayName
                $publisher   = (Get-ItemProperty -Path $subkey.PSPath -ErrorAction SilentlyContinue).Publisher
                if ($null -ne $displayName -or $null -ne $publisher) {
                    $match = $false
                    foreach ($app in $OtherDisallowedApps) {
                        if ($displayName -like "*$app*" -or $publisher -like "*$app*") {
                            $match = $true
                        }
                    }
                    if ($match) {
                        $uninstallString = (Get-ItemProperty -Path $subkey.PSPath -ErrorAction SilentlyContinue).UninstallString
                        $quietUninstallString = (Get-ItemProperty -Path $subkey.PSPath -ErrorAction SilentlyContinue).QuietUninstallString
                        
                        $uninstallCommand = ""
                        if ($displayName -like "*Discord*") {
                            if ($uninstallString) {
                                if ($uninstallString -notlike "*--uninstall*") {
                                    $uninstallCommand = "$uninstallString --uninstall"
                                } else {
                                    $uninstallCommand = $uninstallString
                                }
                            }
                        } elseif ($displayName -like "*BiglyBT*" -or $displayName -like "*JDownloader*") {
                            if ($uninstallString) {
                                $cleanUninstallString = $uninstallString -replace '"', ''
                                $uninstallCommand = "`"$cleanUninstallString`" -q"
                            }
                        } elseif ($displayName -like "*Battle.net*" -or $displayName -like "*Blizzard*") {
                            if ($uninstallString) {
                                $cleanUninstallString = $uninstallString -replace '"', ''
                                if ($cleanUninstallString -notlike "*--uninstall*") {
                                    $uninstallCommand = "`"$cleanUninstallString`" --uninstall"
                                } else {
                                    $uninstallCommand = $uninstallString
                                }
                            }
                        } elseif ($uninstallString -like "*--uninstall-app-id*" -or $uninstallString -like "*msedge*" -or $uninstallString -like "*chrome*") {
                            $uninstallCommand = $uninstallString
                        } elseif ($quietUninstallString) {
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

                        # Si se trata de una app instalada por Edge/Chrome o de Disney, forzar la eliminación de la clave de registro
                        if ($displayName -like "*Disney*" -or $subkey.PSPath -like "*edgeapp_*") {
                            Remove-Item -Path $subkey.PSPath -Recurse -Force -ErrorAction SilentlyContinue
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

# 4.2 Paquetes comodines (Steam, Epic, Riot, Apple TV, Discord, DroidKit, etc.)
try {
    $allAppx = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    if ($allAppx) {
        foreach ($pattern in $WildcardAppxNames) {
            $pkgMatches = $allAppx | Where-Object { ($_.Name -like $pattern -or $_.PackageFullName -like $pattern) -and $_.Name -notlike "*Teams*" }
            foreach ($pkg in $pkgMatches) {
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
            $pkgMatches = $provisionedPkgs | Where-Object { $_.DisplayName -eq $app.PackageName }
            foreach ($pkg in $pkgMatches) {
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
            $pkgMatches = $provisionedPkgs | Where-Object { ($_.DisplayName -like $pattern -or $_.PackageName -like $pattern) -and $_.DisplayName -notlike "*Teams*" }
            foreach ($pkg in $pkgMatches) {
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
    "$env:ProgramFiles\Electronic Arts\EA Desktop",
    "${env:ProgramFiles(x86)}\Electronic Arts\EA Desktop",
    "${env:ProgramFiles(x86)}\Origin",
    "$env:ProgramData\Origin",
    "$env:ProgramData\Electronic Arts\EA Desktop",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\EA app",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Origin",
    "$env:ProgramFiles\SideQuest",
    "${env:ProgramFiles(x86)}\SideQuest",
    "$env:ProgramFiles\Tixati",
    "${env:ProgramFiles(x86)}\Tixati",
    "$env:ProgramFiles\BiglyBT",
    "${env:ProgramFiles(x86)}\BiglyBT",
    "$env:ProgramFiles\JDownloader 2",
    "${env:ProgramFiles(x86)}\JDownloader 2",
    "$env:ProgramFiles\JDownloader",
    "${env:ProgramFiles(x86)}\JDownloader",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\JDownloader 2",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\JDownloader",
    "$env:ProgramFiles\Battle.net",
    "${env:ProgramFiles(x86)}\Battle.net",
    "$env:ProgramData\Battle.net",
    "$env:ProgramData\Blizzard Entertainment",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Battle.net",
    "$env:ProgramFiles\Discord",
    "${env:ProgramFiles(x86)}\Discord",
    "$env:ProgramData\Discord",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Discord",
    "$env:ProgramFiles\iMobie\DroidKit",
    "${env:ProgramFiles(x86)}\iMobie\DroidKit",
    "$env:ProgramFiles\DroidKit",
    "${env:ProgramFiles(x86)}\DroidKit",
    "$env:ProgramData\iMobie\DroidKit",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\DroidKit",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\iMobie\DroidKit",
    "$env:ProgramFiles\AutoHotkey",
    "${env:ProgramFiles(x86)}\AutoHotkey",
    "$env:LocalAppData\AutoHotkey",
    "$env:ProgramFiles\Move Mouse",
    "${env:ProgramFiles(x86)}\Move Mouse",
    "$env:ProgramData\Move Mouse",
    "$env:LocalAppData\Programs\OP Auto Clicker",
    "$env:ProgramFiles\OP Auto Clicker",
    "${env:ProgramFiles(x86)}\OP Auto Clicker",
    "C:\Program Files\Sony\PlayStationAccessories",
    "${env:ProgramFiles(x86)}\Sony\PlayStationAccessories",
    "$env:ProgramFiles\JiggleMouse",
    "${env:ProgramFiles(x86)}\JiggleMouse",
    "$env:LocalAppData\Programs\JiggleMouse",
    "$env:ProgramFiles\Stremio",
    "${env:ProgramFiles(x86)}\Stremio",
    "$env:LocalAppData\Programs\LStudio\Stremio",
    "$env:ProgramFiles\Plex",
    "${env:ProgramFiles(x86)}\Plex",
    "$env:ProgramFiles\Kodi",
    "${env:ProgramFiles(x86)}\Kodi",
    "$env:ProgramFiles\BlueStacks_nxt",
    "${env:ProgramFiles(x86)}\BlueStacks",
    "$env:ProgramData\BlueStacks",
    "C:\LDPlayer",
    "C:\XuanZhi",
    "$env:ProgramFiles\RetroArch-Win64",
    "${env:ProgramFiles(x86)}\RetroArch",
    "$env:ProgramFiles\Dolphin-x64",
    "$env:ProgramFiles\PCSX2",
    "${env:ProgramFiles(x86)}\PCSX2",
    "$env:ProgramFiles\uTorrent",
    "${env:ProgramFiles(x86)}\uTorrent",
    "$env:ProgramFiles\Cheat Engine",
    "${env:ProgramFiles(x86)}\Cheat Engine",
    "C:\Program Files (x86)\InstallShield Installation Information\{A27B17B9-90C8-4B07-83C6-1303FC186B6B}",
    "C:\Program Files\InstallShield Installation Information\{A27B17B9-90C8-4B07-83C6-1303FC186B6B}"
)

# Obtener perfiles de usuarios locales para AppData, Packages y Documentos
$userProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
foreach ($userProfile in $userProfiles) {
    $username = $userProfile.Name
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
            "C:\Users\$username\AppData\Local\Electronic Arts",
            "C:\Users\$username\AppData\Roaming\Electronic Arts",
            "C:\Users\$username\AppData\Local\Origin",
            "C:\Users\$username\AppData\Roaming\Origin",
            "C:\Users\$username\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\EA app",
            "C:\Users\$username\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Origin",
            "C:\Users\$username\AppData\Local\Programs\SideQuest",
            "C:\Users\$username\AppData\Local\SideQuest",
            "C:\Users\$username\AppData\Roaming\SideQuest",
            "C:\Users\$username\AppData\Local\Tixati",
            "C:\Users\$username\AppData\Roaming\Tixati",
            "C:\Users\$username\AppData\Local\Programs\Tixati",
            "C:\Users\$username\AppData\Local\BiglyBT",
            "C:\Users\$username\AppData\Roaming\BiglyBT",
            "C:\Users\$username\AppData\Local\Programs\BiglyBT",
            "C:\Users\$username\AppData\Local\JDownloader 2",
            "C:\Users\$username\AppData\Local\JDownloader 2.0",
            "C:\Users\$username\AppData\Local\JDownloader",
            "C:\Users\$username\AppData\Local\Programs\JDownloader",
            "C:\Users\$username\AppData\Roaming\JDownloader 2",
            "C:\Users\$username\AppData\Roaming\JDownloader",
            "C:\Users\$username\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\JDownloader 2",
            "C:\Users\$username\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\JDownloader",
            "C:\Users\$username\AppData\Local\Battle.net",
            "C:\Users\$username\AppData\Roaming\Battle.net",
            "C:\Users\$username\AppData\Local\Blizzard Entertainment",
            "C:\Users\$username\AppData\Roaming\Blizzard",
            "C:\Users\$username\AppData\Roaming\Blizzard Entertainment",
            "C:\Users\$username\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Battle.net",
            "C:\Users\$username\AppData\Local\Discord",
            "C:\Users\$username\AppData\Local\DiscordCanary",
            "C:\Users\$username\AppData\Local\DiscordPTB",
            "C:\Users\$username\AppData\Local\Programs\Discord",
            "C:\Users\$username\AppData\Roaming\Discord",
            "C:\Users\$username\AppData\Roaming\DiscordCanary",
            "C:\Users\$username\AppData\Roaming\DiscordPTB",
            "C:\Users\$username\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Discord",
            "C:\Users\$username\AppData\Local\iMobie\DroidKit",
            "C:\Users\$username\AppData\Roaming\iMobie\DroidKit",
            "C:\Users\$username\AppData\Local\DroidKit",
            "C:\Users\$username\AppData\Roaming\DroidKit",
            "C:\Users\$username\AppData\Local\AutoHotkey",
            "C:\Users\$username\AppData\Local\Programs\AutoHotkey",
            "C:\Users\$username\AppData\Local\Move Mouse",
            "C:\Users\$username\AppData\Roaming\Move Mouse",
            "C:\Users\$username\AppData\Roaming\OP Auto Clicker",
            "C:\Users\$username\AppData\Local\Programs\OP Auto Clicker",
            "C:\Users\$username\AppData\Local\JiggleMouse",
            "C:\Users\$username\AppData\Roaming\JiggleMouse",
            "C:\Users\$username\AppData\Local\Programs\JiggleMouse",
            "C:\Users\$username\AppData\Local\Programs\LStudio\Stremio",
            "C:\Users\$username\AppData\Local\Stremio",
            "C:\Users\$username\AppData\Roaming\Stremio",
            "C:\Users\$username\AppData\Roaming\stremio",
            "C:\Users\$username\AppData\Local\Plex",
            "C:\Users\$username\AppData\Local\Programs\Plex",
            "C:\Users\$username\AppData\Roaming\Plex",
            "C:\Users\$username\AppData\Roaming\Plex Media Player",
            "C:\Users\$username\AppData\Roaming\Kodi",
            "C:\Users\$username\AppData\Local\Kodi",
            "C:\Users\$username\AppData\Local\Programs\Twitch",
            "C:\Users\$username\AppData\Local\BlueStacks",
            "C:\Users\$username\AppData\Local\ldplayer",
            "C:\Users\$username\AppData\Roaming\RetroArch",
            "C:\Users\$username\AppData\Roaming\Dolphin Emulator",
            "C:\Users\$username\Documents\PCSX2",
            "C:\Users\$username\AppData\Roaming\PCSX2",
            "C:\Users\$username\AppData\Local\uTorrent",
            "C:\Users\$username\AppData\Local\uTorrent Web",
            "C:\Users\$username\AppData\Roaming\uTorrent",
            "C:\Users\$username\AppData\Local\BitTorrent",
            "C:\Users\$username\AppData\Roaming\BitTorrent",
            "C:\Users\$username\AppData\Local\MEGAsync"
        )

        # Añadir carpetas de datos de AppX UWP residuales para streaming, comunicación, emuladores y P2P no permitidas
        $pkgFolders = Get-ChildItem -Path "C:\Users\$username\AppData\Local\Packages" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*Apple*TV*" -or $_.Name -like "*Discord*" -or $_.Name -like "*JiggleMouse*" -or $_.Name -like "*HBO*" -or $_.Name -like "*Netflix*" -or $_.Name -like "*PrimeVideo*" -or $_.Name -like "*Stremio*" -or $_.Name -like "*Plex*" -or $_.Name -like "*Kodi*" -or $_.Name -like "*Disney*" -or $_.Name -like "*Twitch*" -or $_.Name -like "*TikTok*" -or $_.Name -like "*Crunchyroll*" -or $_.Name -like "*BlueStacks*" -or $_.Name -like "*LDPlayer*" -or $_.Name -like "*RetroArch*" -or $_.Name -like "*uTorrent*" -or $_.Name -like "*BitTorrent*" -or $_.Name -like "*MEGAsync*" }
        foreach ($pkgDir in $pkgFolders) {
            $FoldersToDelete += $pkgDir.FullName
        }
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
# PASO 6: Limpiar claves de registro residuales (HKLM, HKCU, HKU)
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
    "HKCU:\Software\qBittorrent",
    "HKLM:\SOFTWARE\Electronic Arts",
    "HKLM:\SOFTWARE\Wow6432Node\Electronic Arts",
    "HKCU:\Software\Electronic Arts",
    "HKLM:\SOFTWARE\Origin",
    "HKLM:\SOFTWARE\Wow6432Node\Origin",
    "HKCU:\Software\Origin",
    "HKLM:\SOFTWARE\Tixati",
    "HKLM:\SOFTWARE\Wow6432Node\Tixati",
    "HKCU:\Software\Tixati",
    "HKLM:\SOFTWARE\BiglyBT",
    "HKLM:\SOFTWARE\Wow6432Node\BiglyBT",
    "HKCU:\Software\BiglyBT",
    "HKLM:\SOFTWARE\JDownloader",
    "HKLM:\SOFTWARE\Wow6432Node\JDownloader",
    "HKCU:\Software\JDownloader",
    "HKLM:\SOFTWARE\JDownloader 2",
    "HKLM:\SOFTWARE\Wow6432Node\JDownloader 2",
    "HKCU:\Software\JDownloader 2",
    "HKLM:\SOFTWARE\Blizzard Entertainment",
    "HKLM:\SOFTWARE\Wow6432Node\Blizzard Entertainment",
    "HKCU:\Software\Blizzard Entertainment",
    "HKLM:\SOFTWARE\Battle.net",
    "HKLM:\SOFTWARE\Wow6432Node\Battle.net",
    "HKCU:\Software\Battle.net",
    "HKLM:\SOFTWARE\Discord",
    "HKLM:\SOFTWARE\Wow6432Node\Discord",
    "HKCU:\Software\Discord",
    "HKLM:\SOFTWARE\iMobie",
    "HKLM:\SOFTWARE\Wow6432Node\iMobie",
    "HKCU:\Software\iMobie",
    "HKLM:\SOFTWARE\DroidKit",
    "HKLM:\SOFTWARE\Wow6432Node\DroidKit",
    "HKCU:\Software\DroidKit",
    "HKLM:\SOFTWARE\AutoHotkey",
    "HKLM:\SOFTWARE\Wow6432Node\AutoHotkey",
    "HKCU:\Software\AutoHotkey",
    "HKLM:\SOFTWARE\Classes\.ahk",
    "HKLM:\SOFTWARE\Classes\AutoHotkeyScript",
    "HKLM:\SOFTWARE\Move Mouse",
    "HKLM:\SOFTWARE\Wow6432Node\Move Mouse",
    "HKCU:\Software\Move Mouse",
    "HKLM:\SOFTWARE\OP Auto Clicker",
    "HKLM:\SOFTWARE\Wow6432Node\OP Auto Clicker",
    "HKCU:\Software\OP Auto Clicker",
    "HKLM:\SOFTWARE\AutoClicker",
    "HKLM:\SOFTWARE\Wow6432Node\AutoClicker",
    "HKCU:\Software\AutoClicker",
    "HKLM:\SOFTWARE\Sony\PlayStationAccessories",
    "HKLM:\SOFTWARE\Wow6432Node\Sony\PlayStationAccessories",
    "HKCU:\Software\Sony\PlayStationAccessories",
    "HKLM:\SOFTWARE\JiggleMouse",
    "HKLM:\SOFTWARE\Wow6432Node\JiggleMouse",
    "HKCU:\Software\JiggleMouse",
    "HKLM:\SOFTWARE\A2GROUP",
    "HKLM:\SOFTWARE\Wow6432Node\A2GROUP",
    "HKCU:\Software\A2GROUP",
    "HKLM:\SOFTWARE\Stremio",
    "HKLM:\SOFTWARE\Wow6432Node\Stremio",
    "HKCU:\Software\Stremio",
    "HKLM:\SOFTWARE\Plex, Inc.",
    "HKLM:\SOFTWARE\Wow6432Node\Plex, Inc.",
    "HKCU:\Software\Plex, Inc.",
    "HKLM:\SOFTWARE\Kodi",
    "HKLM:\SOFTWARE\Wow6432Node\Kodi",
    "HKCU:\Software\Kodi",
    "HKLM:\SOFTWARE\BlueStacks",
    "HKLM:\SOFTWARE\LDPlayer",
    "HKLM:\SOFTWARE\RetroArch",
    "HKLM:\SOFTWARE\Dolphin",
    "HKLM:\SOFTWARE\PCSX2",
    "HKLM:\SOFTWARE\uTorrent",
    "HKCU:\Software\uTorrent",
    "HKCU:\Software\BitTorrent",
    "HKCU:\Software\MEGAsync",
    "HKLM:\SOFTWARE\Classes\Installer\Products\9B71B72A8C0970B4386C3130CF81B6B6",
    "HKLM:\SOFTWARE\Microsoft\Installer\Products\9B71B72A8C0970B4386C3130CF81B6B6"
)

try {
    foreach ($sid in $hkuSids) {
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\Discord"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\iMobie"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\DroidKit"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\AutoHotkey"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\Valve"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\Epic Games"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\Riot Games"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\JiggleMouse"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\A2GROUP"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\Stremio"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\Plex, Inc."
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\Kodi"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\BlueStacks"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\uTorrent"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\BitTorrent"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\MEGAsync"
        $softwareKeys += "Registry::HKEY_USERS\$sid\Software\Cheat Engine"
    }
} catch {}

foreach ($key in $softwareKeys) {
    if (Test-Path $key) {
        Write-Host "  Eliminando clave de software: $key"
        Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# =============================================================================
# PASO 7: Limpiar accesos directos residuales (.lnk, .url) en Escritorios y Menus de Inicio
# =============================================================================
Write-Host "--- Paso 7: Eliminando accesos directos residuales ---"
$DisallowedShortcutKeywords = @(
    "Steam", "Epic Games", "Riot Client", "League of Legends", "Valorant", "Rocket League",
    "Hytale", "WinDS", "Porofessor", "Overwolf", "WeMod", "Wand", "Wargaming", "WGC",
    "World of Tanks", "World of Warships", "WorldOfTanks", "WorldOfWarships", "hakchi",
    "transmission", "qbittorrent", "tixati", "biglybt", "EA App", "EAapp", "EA Desktop",
    "Origin", "sidequest", "JDownloader", "Battle.net", "Blizzard", "Apple TV", "AppleTV",
    "Apple.AppleTV", "AppleInc", "Discord", "DroidKit", "AutoHotkey", "MoveMouse", "Move Mouse",
    "OP Auto Clicker", "AutoClicker", "AutoTap", "PlayStationAccessories", "PlayStation Accessories",
    "JiggleMouse", "Jiggle Mouse", "HBO", "HBOMax", "Netflix", "Prime Video", "PrimeVideo", "Amazon Prime", "Stremio", "Plex", "Kodi",
    "Disney", "Disney+", "Disney Plus", "Twitch", "TikTok", "Crunchyroll", "BlueStacks", "LDPlayer", "RetroArch", "Dolphin", "PCSX2", "uTorrent", "BitTorrent", "MEGAsync", "MegaSync",
    "Cheat Engine", "CheatEngine", "Amstion", "Just Okay"
)

$SearchShortcutFolders = [System.Collections.Generic.List[string]]::new()
$SearchShortcutFolders.Add("C:\Users\Public\Desktop")
$SearchShortcutFolders.Add("C:\Users\Public\Escritorio")
$SearchShortcutFolders.Add("C:\ProgramData\Microsoft\Windows\Start Menu")

$userProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
foreach ($userProfile in $userProfiles) {
    $username = $userProfile.Name
    if ($username -notin @("Public", "Default", "All Users")) {
        $SearchShortcutFolders.Add("C:\Users\$username\Desktop")
        $SearchShortcutFolders.Add("C:\Users\$username\Escritorio")
        $SearchShortcutFolders.Add("C:\Users\$username\OneDrive\Desktop")
        $SearchShortcutFolders.Add("C:\Users\$username\OneDrive\Escritorio")
        $SearchShortcutFolders.Add("C:\Users\$username\AppData\Roaming\Microsoft\Windows\Start Menu")
        $SearchShortcutFolders.Add("C:\Users\$username\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch")

        try {
            $dynDesktops = Get-ChildItem -Path $userProfile.FullName -Recurse -Depth 3 -ErrorAction SilentlyContinue |
                Where-Object { $_.PSIsContainer -and ($_.Name -like "*Desktop*" -or $_.Name -like "*Escritorio*") }
            foreach ($dd in $dynDesktops) {
                if (-not $SearchShortcutFolders.Contains($dd.FullName)) {
                    $SearchShortcutFolders.Add($dd.FullName)
                }
            }
        } catch {}

        try {
            foreach ($sid in $hkuSids) {
                $regDesktop = (Get-ItemProperty -Path "Registry::HKEY_USERS\$sid\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Desktop" -ErrorAction SilentlyContinue).Desktop
                if ($regDesktop) {
                    $expandedPath = [System.Environment]::ExpandEnvironmentVariables($regDesktop)
                    if (-not $SearchShortcutFolders.Contains($expandedPath)) {
                        $SearchShortcutFolders.Add($expandedPath)
                    }
                }
            }
        } catch {}
    }
}

$wshShell = $null
try {
    $wshShell = New-Object -ComObject WScript.Shell -ErrorAction SilentlyContinue
} catch {}

foreach ($folderPath in $SearchShortcutFolders) {
    if (Test-Path $folderPath) {
        $shortcuts = Get-ChildItem -Path $folderPath -Recurse -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer -and ($_.Extension -eq ".lnk" -or $_.Extension -eq ".url" -or $_.Name -like "*.lnk" -or $_.Name -like "*.url") }

        foreach ($sc in $shortcuts) {
            $scName = $sc.Name
            $matched = $false

            foreach ($kw in $DisallowedShortcutKeywords) {
                if ($scName -like "*$kw*") {
                    $matched = $true
                    break
                }
            }

            if (-not $matched -and $sc.Extension -eq ".lnk" -and $wshShell) {
                try {
                    $targetPath = $wshShell.CreateShortcut($sc.FullName).TargetPath
                    if ($targetPath) {
                        foreach ($kw in $DisallowedShortcutKeywords) {
                            if ($targetPath -like "*$kw*") {
                                $matched = $true
                                break
                            }
                        }
                        if (-not $matched -and (-not (Test-Path $targetPath))) {
                            foreach ($kw in $DisallowedShortcutKeywords) {
                                if ($scName -like "*$kw*" -or $targetPath -like "*$kw*") {
                                    $matched = $true
                                    break
                                }
                            }
                        }
                    }
                } catch {}
            }

            if (-not $matched -and $sc.Extension -eq ".lnk") {
                try {
                    $rawText = [System.IO.File]::ReadAllText($sc.FullName)
                    if ($rawText) {
                        foreach ($kw in $DisallowedShortcutKeywords) {
                            if ($rawText -like "*$kw*") {
                                $matched = $true
                                break
                            }
                        }
                    }
                } catch {}
            }

            if ($matched) {
                Write-Host "  Eliminando acceso directo: $($sc.FullName)"
                try {
                    Remove-Item -Path $sc.FullName -Force -ErrorAction Stop
                } catch {
                    cmd.exe /c "del /f /q `"$($sc.FullName)`"" 2>nul
                }
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
    "$env:ProgramFiles\Tixati\tixati.exe",
    "${env:ProgramFiles(x86)}\Tixati\tixati.exe",
    "C:\Users\*\AppData\Local\Programs\Tixati\tixati.exe",
    "$env:ProgramFiles\BiglyBT\BiglyBT.exe",
    "${env:ProgramFiles(x86)}\BiglyBT\BiglyBT.exe",
    "C:\Users\*\AppData\Local\Programs\BiglyBT\BiglyBT.exe",
    "$env:ProgramFiles\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe",
    "${env:ProgramFiles(x86)}\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe",
    "$env:ProgramFiles\Electronic Arts\EA Desktop\EA Desktop\EALauncher.exe",
    "${env:ProgramFiles(x86)}\Electronic Arts\EA Desktop\EA Desktop\EALauncher.exe",
    "${env:ProgramFiles(x86)}\Origin\Origin.exe",
    "$env:ProgramFiles\SideQuest\SideQuest.exe",
    "${env:ProgramFiles(x86)}\SideQuest\SideQuest.exe",
    "C:\Users\*\AppData\Local\Programs\SideQuest\SideQuest.exe",
    "$env:ProgramFiles\JDownloader 2\JDownloader2.exe",
    "${env:ProgramFiles(x86)}\JDownloader 2\JDownloader2.exe",
    "C:\Users\*\AppData\Local\JDownloader 2\JDownloader2.exe",
    "C:\Users\*\AppData\Local\JDownloader 2.0\JDownloader2.exe",
    "$env:ProgramFiles\JDownloader\JDownloader2.exe",
    "${env:ProgramFiles(x86)}\JDownloader\JDownloader2.exe",
    "C:\Users\*\AppData\Local\JDownloader\JDownloader2.exe",
    "$env:ProgramFiles\Battle.net\Battle.net.exe",
    "${env:ProgramFiles(x86)}\Battle.net\Battle.net.exe",
    "$env:ProgramFiles\Battle.net\Battle.net Launcher.exe",
    "${env:ProgramFiles(x86)}\Battle.net\Battle.net Launcher.exe",
    "C:\Users\*\AppData\Local\Battle.net\Battle.net.exe",
    "$env:ProgramFiles\Discord\Discord.exe",
    "${env:ProgramFiles(x86)}\Discord\Discord.exe",
    "C:\Users\*\AppData\Local\Discord*\Update.exe",
    "C:\Users\*\AppData\Local\Discord*\app-*\Discord.exe",
    "$env:ProgramFiles\iMobie\DroidKit\DroidKit.exe",
    "${env:ProgramFiles(x86)}\iMobie\DroidKit\DroidKit.exe",
    "$env:ProgramFiles\DroidKit\DroidKit.exe",
    "${env:ProgramFiles(x86)}\DroidKit\DroidKit.exe",
    "C:\Users\*\AppData\Local\Programs\DroidKit\DroidKit.exe",
    "$env:ProgramFiles\AutoHotkey\AutoHotkey.exe",
    "${env:ProgramFiles(x86)}\AutoHotkey\AutoHotkey.exe",
    "$env:LocalAppData\AutoHotkey\AutoHotkey.exe",
    "C:\Users\*\AppData\Local\AutoHotkey\AutoHotkey.exe",
    "C:\Users\*\AppData\Local\Programs\AutoHotkey\AutoHotkey.exe",
    "$env:ProgramFiles\Move Mouse\MoveMouse.exe",
    "${env:ProgramFiles(x86)}\Move Mouse\MoveMouse.exe",
    "$env:ProgramData\Move Mouse\MoveMouse.exe",
    "C:\Users\*\AppData\Local\Move Mouse\MoveMouse.exe",
    "C:\Users\*\AppData\Roaming\Move Mouse\MoveMouse.exe",
    "$env:LocalAppData\Programs\OP Auto Clicker\OPAutoClicker.exe",
    "$env:LocalAppData\Programs\OP Auto Clicker\AutoClicker.exe",
    "$env:ProgramFiles\OP Auto Clicker\OPAutoClicker.exe",
    "$env:ProgramFiles\OP Auto Clicker\AutoClicker.exe",
    "${env:ProgramFiles(x86)}\OP Auto Clicker\OPAutoClicker.exe",
    "${env:ProgramFiles(x86)}\OP Auto Clicker\AutoClicker.exe",
    "C:\Users\*\AppData\Roaming\OP Auto Clicker\AutoClicker.exe",
    "C:\Users\*\AppData\Roaming\OP Auto Clicker\OPAutoClicker.exe",
    "C:\Users\*\AppData\Local\Programs\OP Auto Clicker\AutoClicker.exe",
    "C:\Users\*\AppData\Local\Programs\OP Auto Clicker\AutoClicker.exe",
    "C:\Program Files\Sony\PlayStationAccessories\PlayStationAccessories.exe",
    "${env:ProgramFiles(x86)}\Sony\PlayStationAccessories\PlayStationAccessories.exe",
    "$env:ProgramFiles\JiggleMouse\JiggleMouse.exe",
    "${env:ProgramFiles(x86)}\JiggleMouse\JiggleMouse.exe",
    "$env:LocalAppData\Programs\JiggleMouse\JiggleMouse.exe",
    "C:\Users\*\AppData\Local\JiggleMouse\JiggleMouse.exe",
    "C:\Users\*\AppData\Local\Programs\JiggleMouse\JiggleMouse.exe",
    "C:\Users\*\AppData\Roaming\JiggleMouse\JiggleMouse.exe",
    "$env:LocalAppData\Programs\LStudio\Stremio\stremio.exe",
    "$env:ProgramFiles\Stremio\stremio.exe",
    "${env:ProgramFiles(x86)}\Stremio\stremio.exe",
    "C:\Users\*\AppData\Local\Programs\LStudio\Stremio\stremio.exe",
    "C:\Users\*\AppData\Local\Stremio\stremio.exe",
    "$env:ProgramFiles\Plex\Plex\Plex.exe",
    "${env:ProgramFiles(x86)}\Plex\Plex\Plex.exe",
    "$env:ProgramFiles\Plex\Plex Media Player\PlexMediaPlayer.exe",
    "${env:ProgramFiles(x86)}\Plex\Plex Media Player\PlexMediaPlayer.exe",
    "C:\Users\*\AppData\Local\Programs\Plex\Plex\Plex.exe",
    "C:\Users\*\AppData\Local\Plex\Plex.exe",
    "$env:ProgramFiles\Kodi\kodi.exe",
    "${env:ProgramFiles(x86)}\Kodi\kodi.exe",
    "C:\Users\*\AppData\Local\Programs\Twitch\Twitch.exe",
    "$env:ProgramFiles\BlueStacks_nxt\HD-Player.exe",
    "${env:ProgramFiles(x86)}\BlueStacks\HD-Player.exe",
    "C:\LDPlayer\LDPlayer9\dnplayer.exe",
    "C:\XuanZhi\LDPlayer\dnplayer.exe",
    "$env:ProgramFiles\RetroArch-Win64\retroarch.exe",
    "$env:ProgramFiles\Dolphin-x64\Dolphin.exe",
    "$env:ProgramFiles\PCSX2\pcsx2-qt.exe",
    "C:\Users\*\AppData\Roaming\uTorrent\uTorrent.exe",
    "$env:LocalAppData\uTorrent Web\utweb.exe",
    "C:\Users\*\AppData\Roaming\BitTorrent\BitTorrent.exe",
    "C:\Users\*\AppData\Local\MEGAsync\MEGAsync.exe"
)

foreach ($pathPattern in $PhysicalPathsToCheck) {
    try {
        $matchedFiles = Get-ChildItem -Path $pathPattern -ErrorAction SilentlyContinue
        if ($matchedFiles) {
            foreach ($file in $matchedFiles) {
                Write-Host "ERROR: Ejecutable fisico residual detectado: $($file.FullName)"
                $Failed = $true
            }
        } elseif (Test-Path -Path $pathPattern) {
            Write-Host "ERROR: Ejecutable fisico residual detectado: $pathPattern"
            $Failed = $true
        }
    } catch {}
}

# 5. Verificar accesos directos residuales
foreach ($folderPath in $SearchShortcutFolders) {
    if (Test-Path $folderPath) {
        $shortcuts = Get-ChildItem -Path $folderPath -Recurse -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer -and ($_.Extension -eq ".lnk" -or $_.Extension -eq ".url" -or $_.Name -like "*.lnk" -or $_.Name -like "*.url") }

        foreach ($sc in $shortcuts) {
            $scName = $sc.Name
            $matched = $false

            foreach ($kw in $DisallowedShortcutKeywords) {
                if ($scName -like "*$kw*") {
                    $matched = $true
                    break
                }
            }

            if (-not $matched -and $sc.Extension -eq ".lnk" -and $wshShell) {
                try {
                    $targetPath = $wshShell.CreateShortcut($sc.FullName).TargetPath
                    if ($targetPath) {
                        foreach ($kw in $DisallowedShortcutKeywords) {
                            if ($targetPath -like "*$kw*") {
                                $matched = $true
                                break
                            }
                        }
                    }
                } catch {}
            }

            if (-not $matched -and $sc.Extension -eq ".lnk") {
                try {
                    $rawText = [System.IO.File]::ReadAllText($sc.FullName)
                    if ($rawText) {
                        foreach ($kw in $DisallowedShortcutKeywords) {
                            if ($rawText -like "*$kw*") {
                                $matched = $true
                                break
                            }
                        }
                    }
                } catch {}
            }

            if ($matched) {
                Write-Host "ERROR: Acceso directo residual detectado: $($sc.FullName)"
                $Failed = $true
            }
        }
    }
}

if ($Failed) {
    Write-Host "ERROR CRITICO: Algunas aplicaciones o accesos directos no pudieron eliminarse completamente."
    exit 1
} else {
    Write-Host "Remediacion finalizada con exito. Todas las aplicaciones, juegos y accesos directos no permitidos han sido eliminados."
    exit 0
}
