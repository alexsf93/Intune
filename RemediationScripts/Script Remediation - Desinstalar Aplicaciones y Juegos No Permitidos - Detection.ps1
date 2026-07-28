<#
.SYNOPSIS
    DETECTION SCRIPT: DETECTAR APLICACIONES Y JUEGOS NO PERMITIDOS

.DESCRIPTION
    Este script comprueba si alguna de las siguientes aplicaciones de juego o software no permitido esta
    instalada en el sistema como paquete UWP/AppX, registro o ejecutable fisico:

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
      - Amazon Kindle
      - AnyDesk
      - Backblaze
      - Bandicam
      - Comet Browser
      - Helium Browser
      - Dropbox
      - Google Drive
      - Icecream Screen Recorder
      - iCloud
      - BlueStacks X / OG Store
      - Xiph.Org Open Codecs

    Busca tanto paquetes instalados para todos los usuarios como paquetes
    provisionados en la imagen del sistema, registros de desinstalacion y rutas de ejecutables comunes.

    Salida:
      - Exit 1: Al menos una aplicacion detectada -> Intune lanza Remediation
      - Exit 0: Dispositivo limpio -> no se requiere accion

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Desinstalar Aplicaciones y Juegos No Permitidos - Detection.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.8.0
    Date: 2026-07-28
    Context: System
#>


$OutputEncoding = [System.Text.Encoding]::UTF8

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

$detected = $false
$Reasons  = [System.Collections.Generic.List[string]]::new()

# =============================================================================
# 1. Paquetes AppX (UWP/Store) a buscar (incluyendo comodines para Steam, Epic, Riot)
# =============================================================================
$TargetAppxNames = @(
    "Microsoft.MinecraftJavaEdition",
    "Microsoft.MinecraftUWP",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MicrosoftSudoku"
)

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
    "*Just Okay*",
    "*Kindle*",
    "*AmazonKindle*",
    "*Amazon.Kindle*",
    "*AnyDesk*",
    "*Backblaze*",
    "*Bandicam*",
    "*Bandisoft*",
    "*Comet*",
    "*CometBrowser*",
    "*Helium*",
    "*HeliumBrowser*",
    "*Dropbox*",
    "*GoogleDrive*",
    "*Google*Drive*",
    "*Icecream*",
    "*iCloud*",
    "*BlueStacksX*",
    "*OGStore*",
    "*nowgg*",
    "*Xiph*"
)

Write-Host "Comprobando paquetes AppX instalados (todos los usuarios)..."
# Buscar por nombres exactos
foreach ($appName in $TargetAppxNames) {
    try {
        $pkgs = Get-AppxPackage -AllUsers -Name $appName -ErrorAction SilentlyContinue
        foreach ($pkg in $pkgs) {
            $detected = $true
            $Reasons.Add("[Store/AppX] Paquete instalado detectado: $($pkg.PackageFullName) (Usuario: $($pkg.PackageUserInformation.UserSecurityId.Value -join ', '))")
        }
    } catch {
        Write-Host "Advertencia al buscar '$appName' (AllUsers): $_"
    }
}
# Buscar por comodines
try {
    $allPkgs = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    if ($allPkgs) {
        foreach ($pattern in $WildcardAppxNames) {
            $pkgMatches = $allPkgs | Where-Object { ($_.Name -like $pattern -or $_.PackageFullName -like $pattern) -and $_.Name -notlike "*Teams*" }
            foreach ($pkg in $pkgMatches) {
                $detected = $true
                $Reasons.Add("[Store/AppX] Paquete instalado detectado por patron '$pattern': $($pkg.PackageFullName)")
            }
        }
    }
} catch {
    Write-Host "Advertencia al escanear todos los paquetes AppX: $_"
}

# =============================================================================
# 2. Paquetes AppX provisionados (imagen del sistema)
# =============================================================================
Write-Host "Comprobando paquetes AppX provisionados..."
try {
    $provisionedPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    if ($provisionedPkgs) {
        # Por nombres exactos
        foreach ($appName in $TargetAppxNames) {
            $pkgMatches = $provisionedPkgs | Where-Object { $_.DisplayName -eq $appName }
            foreach ($pkg in $pkgMatches) {
                $detected = $true
                $Reasons.Add("[Store/AppX Provisionado] Paquete provisionado detectado: $($pkg.PackageName)")
            }
        }
        # Por comodines
        foreach ($pattern in $WildcardAppxNames) {
            $pkgMatches = $provisionedPkgs | Where-Object { ($_.DisplayName -like $pattern -or $_.PackageName -like $pattern) -and $_.DisplayName -notlike "*Teams*" }
            foreach ($pkg in $pkgMatches) {
                $detected = $true
                $Reasons.Add("[Store/AppX Provisionado] Paquete provisionado detectado por patron '$pattern': $($pkg.PackageName)")
            }
        }
    }
} catch {
    Write-Host "Advertencia al buscar paquetes provisionados: $_"
}

# =============================================================================
# 3. Aplicaciones Tradicionales vía Registro (Uninstall Keys - HKLM, HKCU y HKU)
# =============================================================================
Write-Host "Comprobando claves de registro de desinstalacion..."
$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

# Agregar colmenas de registro de usuarios activos en HKEY_USERS (HKU) para detectar per-user installs (ej. Discord) en contexto SYSTEM
try {
    $hkuSids = Get-ChildItem -Path "Registry::HKEY_USERS" -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -notlike "*.DEFAULT" -and $_.PSChildName -notlike "*_Classes" -and $_.PSChildName -match "^S-1-5-21-" } |
        Select-Object -ExpandProperty PSChildName

    foreach ($sid in $hkuSids) {
        $RegistryPaths += "Registry::HKEY_USERS\$sid\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $RegistryPaths += "Registry::HKEY_USERS\$sid\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    }
} catch {
    Write-Host "Advertencia al obtener colmenas HKU: $_"
}

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
    "hakchi2",
    "Transmission",
    "qBittorrent",
    "Tixati",
    "BiglyBT",
    "EA app",
    "Electronic Arts",
    "Origin",
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
    "Amazon Kindle",
    "Kindle",
    "Amazon.Kindle",
    "AnyDesk",
    "AnyDesk Software GmbH",
    "Backblaze",
    "Backblaze, Inc.",
    "Bandicam",
    "Bandisoft",
    "Bandicam Company",
    "Comet",
    "Comet Browser",
    "Helium",
    "Helium Browser",
    "Dropbox",
    "Google Drive",
    "Google Drive File Stream",
    "Icecream Screen Recorder",
    "Icecream Apps",
    "iCloud",
    "iCloud Drive",
    "iCloud Photos",
    "iCloud Shared Photo Library",
    "BlueStacks X",
    "BlueStacksX",
    "OG Store",
    "OGStore",
    "now.gg",
    "Xiph.Org",
    "Xiph.Org Open Codecs",
    "Xiph",
    "{A27B17B9-90C8-4B07-83C6-1303FC186B6B}"
)

foreach ($path in $RegistryPaths) {
    try {
        $keys = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        foreach ($key in $keys) {
            $displayName = $key.DisplayName
            $publisher   = $key.Publisher
            if ($null -ne $displayName -or $null -ne $publisher) {
                foreach ($disallowedName in $DisallowedAppNames) {
                    if (($displayName -like "*$disallowedName*" -or $publisher -like "*$disallowedName*") -and $displayName -notlike "*Teams*") {
                        $detected = $true
                        $Reasons.Add("[Registro] Programa detectado: $displayName / $publisher (Ubicacion: $($key.InstallLocation), Clave: $($key.PSChildName))")
                    }
                }
            }
        }
    } catch {
        # La ruta del registro podria no existir
    }
}

# =============================================================================
# 4. Comprobacion de Archivos Fisicos (Common Paths & User AppData)
# =============================================================================
Write-Host "Comprobando rutas fisicas comunes..."
$PhysicalPaths = @(
    [PSCustomObject]@{ Name = "Steam"; Paths = @("$env:ProgramFiles\Steam\steam.exe", "${env:ProgramFiles(x86)}\Steam\steam.exe") },
    [PSCustomObject]@{ Name = "Epic Games Launcher"; Paths = @("$env:ProgramFiles\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe", "${env:ProgramFiles(x86)}\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe") },
    [PSCustomObject]@{ Name = "Riot Client"; Paths = @("C:\Riot Games\Riot Client\RiotClientServices.exe") },
    [PSCustomObject]@{ Name = "Riot Vanguard"; Paths = @("$env:ProgramFiles\Riot Vanguard\vgtray.exe") },
    [PSCustomObject]@{ Name = "Rocket League"; Paths = @("$env:ProgramFiles\Epic Games\rocketleague\Binaries\Win64\RocketLeague.exe", "${env:ProgramFiles(x86)}\Epic Games\rocketleague\Binaries\Win64\RocketLeague.exe", "$env:ProgramFiles\Steam\steamapps\common\rocketleague\Binaries\Win64\RocketLeague.exe", "${env:ProgramFiles(x86)}\Steam\steamapps\common\rocketleague\Binaries\Win64\RocketLeague.exe") },
    [PSCustomObject]@{ Name = "Hytale Launcher"; Paths = @("$env:LocalAppData\Hytale\hytale-launcher.exe", "$env:ProgramFiles\Hytale\hytale-launcher.exe", "${env:ProgramFiles(x86)}\Hytale\hytale-launcher.exe") },
    [PSCustomObject]@{ Name = "WinDS Pro"; Paths = @("$env:ProgramFiles\WinDS PRO\windspro.exe", "${env:ProgramFiles(x86)}\WinDS PRO\windspro.exe", "$env:ProgramFiles\WinDS PRO\windsprox.exe", "${env:ProgramFiles(x86)}\WinDS PRO\windsprox.exe") },
    [PSCustomObject]@{ Name = "Porofessor / Overwolf"; Paths = @("$env:LocalAppData\Overwolf\Overwolf.exe", "$env:ProgramFiles\Overwolf\Overwolf.exe", "${env:ProgramFiles(x86)}\Overwolf\Overwolf.exe", "$env:LocalAppData\Porofessor\Porofessor.exe") },
    [PSCustomObject]@{ Name = "WeMod / Wand"; Paths = @("$env:LocalAppData\WeMod\WeMod.exe", "$env:LocalAppData\Wand\Wand.exe") },
    [PSCustomObject]@{ Name = "Wargaming Game Center"; Paths = @("$env:ProgramFiles\Wargaming.net\GameCenter\wgc.exe", "${env:ProgramFiles(x86)}\Wargaming.net\GameCenter\wgc.exe", "C:\Games\Wargaming.net\GameCenter\wgc.exe") },
    [PSCustomObject]@{ Name = "World of Tanks"; Paths = @("C:\Games\World_of_Tanks\WorldOfTanks.exe", "C:\Games\World_of_Tanks_EU\WorldOfTanks.exe") },
    [PSCustomObject]@{ Name = "World of Warships"; Paths = @("C:\Games\World_of_Warships\WorldOfWarships.exe", "C:\Games\World_of_Warships_EU\WorldOfWarships.exe") },
    [PSCustomObject]@{ Name = "World of Warplanes"; Paths = @("C:\Games\World_of_Warplanes\WorldOfWarplanes.exe") },
    [PSCustomObject]@{ Name = "Hakchi2 CE"; Paths = @("${env:ProgramFiles(x86)}\Team Shinkansen\Hakchi2 CE\hakchi.exe", "$env:ProgramFiles\Team Shinkansen\Hakchi2 CE\hakchi.exe", "C:\Users\*\Documents\Hakchi2\hakchi.exe", "C:\Users\*\AppData\Local\hakchi2-ce\hakchi.exe") },
    [PSCustomObject]@{ Name = "Transmission"; Paths = @("$env:ProgramFiles\Transmission\transmission-qt.exe", "${env:ProgramFiles(x86)}\Transmission\transmission-qt.exe", "$env:ProgramFiles\Transmission\transmission-daemon.exe", "${env:ProgramFiles(x86)}\Transmission\transmission-daemon.exe") },
    [PSCustomObject]@{ Name = "qBittorrent"; Paths = @("$env:ProgramFiles\qBittorrent\qbittorrent.exe", "${env:ProgramFiles(x86)}\qBittorrent\qbittorrent.exe", "C:\Users\*\AppData\Local\Programs\qBittorrent\qbittorrent.exe") },
    [PSCustomObject]@{ Name = "Tixati"; Paths = @("$env:ProgramFiles\Tixati\tixati.exe", "${env:ProgramFiles(x86)}\Tixati\tixati.exe", "C:\Users\*\AppData\Local\Programs\Tixati\tixati.exe") },
    [PSCustomObject]@{ Name = "BiglyBT"; Paths = @("$env:ProgramFiles\BiglyBT\BiglyBT.exe", "${env:ProgramFiles(x86)}\BiglyBT\BiglyBT.exe", "C:\Users\*\AppData\Local\Programs\BiglyBT\BiglyBT.exe") },
    [PSCustomObject]@{ Name = "EA app / EA Launcher / Origin"; Paths = @(
        "$env:ProgramFiles\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe",
        "${env:ProgramFiles(x86)}\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe",
        "$env:ProgramFiles\Electronic Arts\EA Desktop\EA Desktop\EALauncher.exe",
        "${env:ProgramFiles(x86)}\Electronic Arts\EA Desktop\EA Desktop\EALauncher.exe",
        "${env:ProgramFiles(x86)}\Origin\Origin.exe",
        "C:\Users\*\AppData\Local\Programs\EA Desktop\EA Desktop\EADesktop.exe"
    ) },
    [PSCustomObject]@{ Name = "SideQuest"; Paths = @("$env:ProgramFiles\SideQuest\SideQuest.exe", "${env:ProgramFiles(x86)}\SideQuest\SideQuest.exe", "C:\Users\*\AppData\Local\Programs\SideQuest\SideQuest.exe") },
    [PSCustomObject]@{ Name = "JDownloader"; Paths = @(
        "$env:ProgramFiles\JDownloader 2\JDownloader2.exe",
        "${env:ProgramFiles(x86)}\JDownloader 2\JDownloader2.exe",
        "C:\Users\*\AppData\Local\JDownloader 2\JDownloader2.exe",
        "C:\Users\*\AppData\Local\JDownloader 2.0\JDownloader2.exe",
        "$env:ProgramFiles\JDownloader\JDownloader2.exe",
        "${env:ProgramFiles(x86)}\JDownloader\JDownloader2.exe",
        "C:\Users\*\AppData\Local\JDownloader\JDownloader2.exe"
    ) },
    [PSCustomObject]@{ Name = "Battle.net"; Paths = @(
        "$env:ProgramFiles\Battle.net\Battle.net.exe",
        "${env:ProgramFiles(x86)}\Battle.net\Battle.net.exe",
        "$env:ProgramFiles\Battle.net\Battle.net Launcher.exe",
        "${env:ProgramFiles(x86)}\Battle.net\Battle.net Launcher.exe",
        "C:\Users\*\AppData\Local\Battle.net\Battle.net.exe"
    ) },
    [PSCustomObject]@{ Name = "Discord"; Paths = @(
        "$env:LocalAppData\Discord\Update.exe",
        "$env:LocalAppData\DiscordCanary\Update.exe",
        "$env:LocalAppData\DiscordPTB\Update.exe",
        "$env:ProgramFiles\Discord\Discord.exe",
        "${env:ProgramFiles(x86)}\Discord\Discord.exe",
        "C:\Users\*\AppData\Local\Discord*\Update.exe",
        "C:\Users\*\AppData\Local\Discord*\app-*\Discord.exe",
        "C:\Users\*\AppData\Local\Discord*\Discord.exe",
        "C:\Users\*\AppData\Local\Programs\Discord\Discord.exe"
    ) },
    [PSCustomObject]@{ Name = "DroidKit"; Paths = @("$env:ProgramFiles\iMobie\DroidKit\DroidKit.exe", "${env:ProgramFiles(x86)}\iMobie\DroidKit\DroidKit.exe", "$env:ProgramFiles\DroidKit\DroidKit.exe", "${env:ProgramFiles(x86)}\DroidKit\DroidKit.exe", "C:\Users\*\AppData\Local\Programs\DroidKit\DroidKit.exe") },
    [PSCustomObject]@{ Name = "AutoHotkey"; Paths = @("$env:ProgramFiles\AutoHotkey\AutoHotkey.exe", "${env:ProgramFiles(x86)}\AutoHotkey\AutoHotkey.exe", "$env:LocalAppData\AutoHotkey\AutoHotkey.exe", "C:\Users\*\AppData\Local\AutoHotkey\AutoHotkey.exe", "C:\Users\*\AppData\Local\Programs\AutoHotkey\AutoHotkey.exe") },
    [PSCustomObject]@{ Name = "Move Mouse"; Paths = @("$env:ProgramFiles\Move Mouse\MoveMouse.exe", "${env:ProgramFiles(x86)}\Move Mouse\MoveMouse.exe", "$env:ProgramData\Move Mouse\MoveMouse.exe", "C:\Users\*\AppData\Local\Move Mouse\MoveMouse.exe", "C:\Users\*\AppData\Roaming\Move Mouse\MoveMouse.exe", "C:\Users\*\Downloads\*MoveMouse*.exe", "C:\Users\*\Desktop\*MoveMouse*.exe") },
    [PSCustomObject]@{ Name = "OP Auto Clicker"; Paths = @(
        "$env:LocalAppData\Programs\OP Auto Clicker\OPAutoClicker.exe",
        "$env:LocalAppData\Programs\OP Auto Clicker\AutoClicker.exe",
        "$env:ProgramFiles\OP Auto Clicker\OPAutoClicker.exe",
        "$env:ProgramFiles\OP Auto Clicker\AutoClicker.exe",
        "${env:ProgramFiles(x86)}\OP Auto Clicker\OPAutoClicker.exe",
        "${env:ProgramFiles(x86)}\OP Auto Clicker\AutoClicker.exe",
        "C:\Users\*\AppData\Roaming\OP Auto Clicker\AutoClicker.exe",
        "C:\Users\*\AppData\Roaming\OP Auto Clicker\OPAutoClicker.exe",
        "C:\Users\*\AppData\Local\Programs\OP Auto Clicker\AutoClicker.exe",
        "C:\Users\*\AppData\Local\Programs\OP Auto Clicker\OPAutoClicker.exe",
        "C:\Users\*\Downloads\*OP*AutoClicker*.exe",
        "C:\Users\*\Desktop\*OP*AutoClicker*.exe",
        "C:\Users\*\Downloads\*AutoClicker*.exe",
        "C:\Users\*\Desktop\*AutoClicker*.exe"
    ) },
    [PSCustomObject]@{ Name = "PlayStation Accessories"; Paths = @("C:\Program Files\Sony\PlayStationAccessories\PlayStationAccessories.exe", "${env:ProgramFiles(x86)}\Sony\PlayStationAccessories\PlayStationAccessories.exe") },
    [PSCustomObject]@{ Name = "JiggleMouse"; Paths = @(
        "$env:ProgramFiles\JiggleMouse\JiggleMouse.exe",
        "${env:ProgramFiles(x86)}\JiggleMouse\JiggleMouse.exe",
        "$env:LocalAppData\Programs\JiggleMouse\JiggleMouse.exe",
        "C:\Users\*\AppData\Local\JiggleMouse\JiggleMouse.exe",
        "C:\Users\*\AppData\Local\Programs\JiggleMouse\JiggleMouse.exe",
        "C:\Users\*\AppData\Roaming\JiggleMouse\JiggleMouse.exe",
        "C:\Users\*\Downloads\*JiggleMouse*.exe",
        "C:\Users\*\Desktop\*JiggleMouse*.exe"
    ) },
    [PSCustomObject]@{ Name = "Stremio"; Paths = @(
        "$env:LocalAppData\Programs\LStudio\Stremio\stremio.exe",
        "$env:ProgramFiles\Stremio\stremio.exe",
        "${env:ProgramFiles(x86)}\Stremio\stremio.exe",
        "C:\Users\*\AppData\Local\Programs\LStudio\Stremio\stremio.exe",
        "C:\Users\*\AppData\Local\Stremio\stremio.exe"
    ) },
    [PSCustomObject]@{ Name = "Plex"; Paths = @(
        "$env:ProgramFiles\Plex\Plex\Plex.exe",
        "${env:ProgramFiles(x86)}\Plex\Plex\Plex.exe",
        "$env:ProgramFiles\Plex\Plex Media Player\PlexMediaPlayer.exe",
        "${env:ProgramFiles(x86)}\Plex\Plex Media Player\PlexMediaPlayer.exe",
        "C:\Users\*\AppData\Local\Programs\Plex\Plex\Plex.exe",
        "C:\Users\*\AppData\Local\Plex\Plex.exe"
    ) },
    [PSCustomObject]@{ Name = "Kodi"; Paths = @(
        "$env:ProgramFiles\Kodi\kodi.exe",
        "${env:ProgramFiles(x86)}\Kodi\kodi.exe"
    ) },
    [PSCustomObject]@{ Name = "Twitch"; Paths = @("$env:LocalAppData\Programs\Twitch\Twitch.exe", "C:\Users\*\AppData\Local\Programs\Twitch\Twitch.exe") },
    [PSCustomObject]@{ Name = "BlueStacks"; Paths = @("$env:ProgramFiles\BlueStacks_nxt\HD-Player.exe", "${env:ProgramFiles(x86)}\BlueStacks\HD-Player.exe") },
    [PSCustomObject]@{ Name = "LDPlayer"; Paths = @("C:\LDPlayer\LDPlayer9\dnplayer.exe", "C:\XuanZhi\LDPlayer\dnplayer.exe") },
    [PSCustomObject]@{ Name = "RetroArch"; Paths = @("$env:ProgramFiles\RetroArch-Win64\retroarch.exe", "${env:ProgramFiles(x86)}\RetroArch\retroarch.exe") },
    [PSCustomObject]@{ Name = "Dolphin Emulator"; Paths = @("$env:ProgramFiles\Dolphin-x64\Dolphin.exe") },
    [PSCustomObject]@{ Name = "PCSX2"; Paths = @("$env:ProgramFiles\PCSX2\pcsx2-qt.exe", "${env:ProgramFiles(x86)}\PCSX2\pcsx2.exe") },
    [PSCustomObject]@{ Name = "uTorrent"; Paths = @("$env:LocalAppData\uTorrent\uTorrent.exe", "$env:ProgramFiles\uTorrent\uTorrent.exe", "${env:ProgramFiles(x86)}\uTorrent\uTorrent.exe", "C:\Users\*\AppData\Roaming\uTorrent\uTorrent.exe", "$env:LocalAppData\uTorrent Web\utweb.exe") },
    [PSCustomObject]@{ Name = "BitTorrent"; Paths = @("$env:LocalAppData\BitTorrent\BitTorrent.exe", "C:\Users\*\AppData\Roaming\BitTorrent\BitTorrent.exe") },
    [PSCustomObject]@{ Name = "MEGAsync"; Paths = @("$env:LocalAppData\MEGAsync\MEGAsync.exe", "C:\Users\*\AppData\Local\MEGAsync\MEGAsync.exe") },
    [PSCustomObject]@{ Name = "Cheat Engine"; Paths = @("$env:ProgramFiles\Cheat Engine\cheatengine-x86_64.exe", "${env:ProgramFiles(x86)}\Cheat Engine\cheatengine-i386.exe", "$env:ProgramFiles\Cheat Engine\Cheat Engine.exe", "${env:ProgramFiles(x86)}\Cheat Engine\Cheat Engine.exe", "C:\Users\*\AppData\Local\Programs\Cheat Engine\Cheat Engine.exe") },
    [PSCustomObject]@{ Name = "Just Okay Auto Clicker"; Paths = @("$env:LocalAppData\Programs\Just Okay Limited\*AutoClicker*.exe", "$env:ProgramFiles\Just Okay Limited\*AutoClicker*.exe") },
    [PSCustomObject]@{ Name = "Amazon Kindle"; Paths = @("$env:LocalAppData\Amazon\Kindle\Kindle.exe", "$env:ProgramFiles\Amazon\Kindle\Kindle.exe", "${env:ProgramFiles(x86)}\Amazon\Kindle\Kindle.exe", "C:\Users\*\AppData\Local\Amazon\Kindle\Kindle.exe") },
    [PSCustomObject]@{ Name = "AnyDesk"; Paths = @("$env:ProgramFiles\AnyDesk\AnyDesk.exe", "${env:ProgramFiles(x86)}\AnyDesk\AnyDesk.exe", "C:\Users\*\AppData\Local\Programs\AnyDesk\AnyDesk.exe", "C:\Users\*\Downloads\AnyDesk.exe", "C:\Users\*\Desktop\AnyDesk.exe") },
    [PSCustomObject]@{ Name = "Backblaze"; Paths = @("$env:ProgramFiles\Backblaze\bztransmit.exe", "${env:ProgramFiles(x86)}\Backblaze\bztransmit.exe", "$env:ProgramFiles\Backblaze\bzui.exe", "${env:ProgramFiles(x86)}\Backblaze\bzui.exe") },
    [PSCustomObject]@{ Name = "Bandicam"; Paths = @("$env:ProgramFiles\Bandicam\bdcam.exe", "${env:ProgramFiles(x86)}\Bandicam\bdcam.exe", "C:\Users\*\AppData\Roaming\Bandicam\bdcam.exe") },
    [PSCustomObject]@{ Name = "Comet Browser"; Paths = @("$env:LocalAppData\Comet\Application\comet.exe", "$env:ProgramFiles\Comet\Application\comet.exe", "${env:ProgramFiles(x86)}\Comet\Application\comet.exe", "C:\Users\*\AppData\Local\Comet\Application\comet.exe") },
    [PSCustomObject]@{ Name = "Helium Browser"; Paths = @("$env:LocalAppData\Helium\Application\helium.exe", "$env:ProgramFiles\Helium\helium.exe", "${env:ProgramFiles(x86)}\Helium\helium.exe", "C:\Users\*\AppData\Local\Programs\Helium\helium.exe") },
    [PSCustomObject]@{ Name = "Dropbox"; Paths = @("$env:ProgramFiles\Dropbox\Client\Dropbox.exe", "${env:ProgramFiles(x86)}\Dropbox\Client\Dropbox.exe", "C:\Users\*\AppData\Local\Dropbox\bin\Dropbox.exe", "C:\Users\*\AppData\Roaming\Dropbox\bin\Dropbox.exe") },
    [PSCustomObject]@{ Name = "Google Drive"; Paths = @("$env:ProgramFiles\Google\Drive File Stream\*\GoogleDriveFSSetup.exe", "$env:ProgramFiles\Google\Drive\GoogleDriveFSSetup.exe", "${env:ProgramFiles(x86)}\Google\Drive\GoogleDriveFSSetup.exe", "C:\Users\*\AppData\Local\Google\DriveFS\*\GoogleDriveFSSetup.exe") },
    [PSCustomObject]@{ Name = "Icecream Screen Recorder"; Paths = @("$env:ProgramFiles\Icecream Screen Recorder\recorder.exe", "${env:ProgramFiles(x86)}\Icecream Screen Recorder\recorder.exe", "$env:ProgramFiles\Icecream Apps\Icecream Screen Recorder\recorder.exe", "${env:ProgramFiles(x86)}\Icecream Apps\Icecream Screen Recorder\recorder.exe", "C:\Users\*\AppData\Local\Icecream Screen Recorder\recorder.exe") },
    [PSCustomObject]@{ Name = "iCloud"; Paths = @("$env:ProgramFiles\Common Files\Apple\Internet Services\iCloud.exe", "${env:ProgramFiles(x86)}\Common Files\Apple\Internet Services\iCloud.exe", "$env:ProgramFiles\Apple\iCloud\iCloud.exe", "${env:ProgramFiles(x86)}\Apple\iCloud\iCloud.exe", "C:\Users\*\AppData\Local\Programs\iCloud\iCloud.exe") },
    [PSCustomObject]@{ Name = "BlueStacks X"; Paths = @("$env:ProgramFiles\BlueStacksX\BlueStacksX.exe", "${env:ProgramFiles(x86)}\BlueStacksX\BlueStacksX.exe", "C:\Users\*\AppData\Local\Programs\BlueStacksX\BlueStacksX.exe", "C:\ProgramData\BlueStacksX\BlueStacksX.exe") },
    [PSCustomObject]@{ Name = "OG Store"; Paths = @("$env:ProgramFiles\OGStore\OGStore.exe", "${env:ProgramFiles(x86)}\OGStore\OGStore.exe", "C:\Users\*\AppData\Local\Programs\OGStore\OGStore.exe") },
    [PSCustomObject]@{ Name = "Xiph.Org Open Codecs"; Paths = @("$env:ProgramFiles\Xiph.Org\Open Codecs\*.dll", "${env:ProgramFiles(x86)}\Xiph.Org\Open Codecs\*.dll", "C:\Program Files\Xiph.Org\Open Codecs\dsfOggMux.dll", "C:\Program Files (x86)\Xiph.Org\Open Codecs\dsfOggMux.dll") }
)

foreach ($app in $PhysicalPaths) {
    foreach ($pathPattern in $app.Paths) {
        try {
            $matchedFiles = Get-ChildItem -Path $pathPattern -ErrorAction SilentlyContinue
            if ($matchedFiles) {
                foreach ($file in $matchedFiles) {
                    $detected = $true
                    $Reasons.Add("[Ruta Fisica] Ejecutable de $($app.Name) detectado: $($file.FullName)")
                }
            } elseif (Test-Path -Path $pathPattern) {
                $detected = $true
                $Reasons.Add("[Ruta Fisica] Ejecutable de $($app.Name) detectado: $pathPattern")
            }
        } catch {}
    }
}

# =============================================================================
# 5. Comprobacion de Accesos Directos (.lnk, .url) en Escritorios y Menus de Inicio
# =============================================================================
Write-Host "Comprobando accesos directos residuales en Escritorios y Menus de Inicio..."

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
    "Cheat Engine", "CheatEngine", "Amstion", "Just Okay", "Kindle", "Amazon Kindle", "AnyDesk", "Backblaze", "Bandicam", "Comet", "Comet Browser", "Helium", "Helium Browser",
    "Dropbox", "Google Drive", "Icecream", "Icecream Screen Recorder", "iCloud", "BlueStacks X", "BlueStacksX", "OG Store", "OGStore", "Xiph"
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
            $hkuSids = Get-ChildItem -Path "Registry::HKEY_USERS" -ErrorAction SilentlyContinue |
                Where-Object { $_.PSChildName -notlike "*.DEFAULT" -and $_.PSChildName -notlike "*_Classes" -and $_.PSChildName -match "^S-1-5-21-" } |
                Select-Object -ExpandProperty PSChildName

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
                        # Comprobar si es un acceso directo huérfano (su archivo ejecutable/destino en disco ya no existe)
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
                $detected = $true
                $Reasons.Add("[Acceso Directo] Acceso directo no permitido o huerfano detectado: $($sc.FullName)")
            }
        }
    }
}

# =============================================================================
# Evaluacion final
# =============================================================================
if ($detected) {
    Write-Host "Detected: Se han encontrado aplicaciones o juegos no permitidos."
    foreach ($reason in $Reasons) { Write-Host " - $reason" }
    exit 1
} else {
    Write-Host "No se ha encontrado ninguna aplicacion o juego no permitido."
    exit 0
}
