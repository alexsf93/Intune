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
      - SideQuest

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
    Version: 1.6.0
    Date: 2026-06-28
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
    "*sidequest*"
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
            $matches = $allPkgs | Where-Object { ($_.Name -like $pattern -or $_.PackageFullName -like $pattern) -and $_.Name -notlike "*Teams*" }
            foreach ($pkg in $matches) {
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
            $matches = $provisionedPkgs | Where-Object { $_.DisplayName -eq $appName }
            foreach ($pkg in $matches) {
                $detected = $true
                $Reasons.Add("[Store/AppX Provisionado] Paquete provisionado detectado: $($pkg.PackageName)")
            }
        }
        # Por comodines
        foreach ($pattern in $WildcardAppxNames) {
            $matches = $provisionedPkgs | Where-Object { ($_.DisplayName -like $pattern -or $_.PackageName -like $pattern) -and $_.DisplayName -notlike "*Teams*" }
            foreach ($pkg in $matches) {
                $detected = $true
                $Reasons.Add("[Store/AppX Provisionado] Paquete provisionado detectado por patron '$pattern': $($pkg.PackageName)")
            }
        }
    }
} catch {
    Write-Host "Advertencia al buscar paquetes provisionados: $_"
}

# =============================================================================
# 3. Aplicaciones Tradicionales vía Registro (Uninstall Keys)
# =============================================================================
Write-Host "Comprobando claves de registro de desinstalacion..."
$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
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
    "hakchi2",
    "Transmission",
    "qBittorrent",
    "EA app",
    "Electronic Arts",
    "Origin",
    "SideQuest"
)

foreach ($path in $RegistryPaths) {
    try {
        $keys = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        foreach ($key in $keys) {
            $displayName = $key.DisplayName
            if ($null -ne $displayName) {
                foreach ($disallowedName in $DisallowedAppNames) {
                    if ($displayName -like "*$disallowedName*" -and $displayName -notlike "*Teams*") {
                        $detected = $true
                        $Reasons.Add("[Registro] Programa detectado: $displayName (Ubicacion: $($key.InstallLocation), Clave: $($key.PSChildName))")
                    }
                }
            }
        }
    } catch {
        # La ruta del registro podria no existir
    }
}

# =============================================================================
# 4. Comprobacion de Archivos Fisicos (Common Paths)
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
    [PSCustomObject]@{ Name = "EA app / EA Launcher / Origin"; Paths = @(
        "$env:ProgramFiles\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe",
        "${env:ProgramFiles(x86)}\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe",
        "$env:ProgramFiles\Electronic Arts\EA Desktop\EA Desktop\EALauncher.exe",
        "${env:ProgramFiles(x86)}\Electronic Arts\EA Desktop\EA Desktop\EALauncher.exe",
        "${env:ProgramFiles(x86)}\Origin\Origin.exe",
        "C:\Users\*\AppData\Local\Programs\EA Desktop\EA Desktop\EADesktop.exe"
    ) },
    [PSCustomObject]@{ Name = "SideQuest"; Paths = @("$env:ProgramFiles\SideQuest\SideQuest.exe", "${env:ProgramFiles(x86)}\SideQuest\SideQuest.exe", "C:\Users\*\AppData\Local\Programs\SideQuest\SideQuest.exe") }
)

foreach ($app in $PhysicalPaths) {
    foreach ($path in $app.Paths) {
        if (Test-Path -Path $path) {
            $detected = $true
            $Reasons.Add("[Ruta Fisica] Ejecutable de $($app.Name) detectado: $path")
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
