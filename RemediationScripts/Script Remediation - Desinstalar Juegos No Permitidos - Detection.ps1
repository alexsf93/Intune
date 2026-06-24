<#
.SYNOPSIS
    DETECTION SCRIPT: DETECTAR APLICACIONES DE JUEGOS NO PERMITIDAS

.DESCRIPTION
    Este script comprueba si alguna de las siguientes aplicaciones de juego esta
    instalada en el sistema como paquete UWP/AppX:

      - Microsoft.MinecraftJavaEdition  (Minecraft Java Edition)
      - Microsoft.MinecraftUWP          (Minecraft para Windows)
      - Microsoft.MicrosoftSolitaireCollection (Microsoft Solitaire Collection)
      - Microsoft.MicrosoftSudoku       (Microsoft Sudoku)

    Busca tanto paquetes instalados para todos los usuarios como paquetes
    provisionados en la imagen del sistema.

    Salida:
      - Exit 1: Al menos una aplicacion detectada -> Intune lanza Remediation
      - Exit 0: Dispositivo limpio -> no se requiere accion

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Desinstalar Juegos No Permitidos - Detection.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.0.0
    Date: 2026-06-24
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
    "*RiotClient*",
    "*RiotVanguard*",
    "*Valorant*",
    "*LeagueOfLegends*",
    "*RocketLeague*",
    "*Rocket League*"
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
    "Rocket League"
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
    [PSCustomObject]@{ Name = "Rocket League"; Paths = @("$env:ProgramFiles\Epic Games\rocketleague\Binaries\Win64\RocketLeague.exe", "${env:ProgramFiles(x86)}\Epic Games\rocketleague\Binaries\Win64\RocketLeague.exe", "$env:ProgramFiles\Steam\steamapps\common\rocketleague\Binaries\Win64\RocketLeague.exe", "${env:ProgramFiles(x86)}\Steam\steamapps\common\rocketleague\Binaries\Win64\RocketLeague.exe") }
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
    Write-Host "Detected: Se han encontrado aplicaciones de juego no permitidas."
    foreach ($reason in $Reasons) { Write-Host " - $reason" }
    exit 1
} else {
    Write-Host "No se ha encontrado ninguna aplicacion de juego no permitida."
    exit 0
}
