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

# Lista de nombres de paquete AppX a detectar (nombre exacto de familia de paquete)
$TargetApps = @(
    "Microsoft.MinecraftJavaEdition",
    "Microsoft.MinecraftUWP",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MicrosoftSudoku"
)

# =============================================================================
# 1. Paquetes AppX instalados (todos los usuarios)
# =============================================================================
Write-Host "Comprobando paquetes AppX instalados (todos los usuarios)..."
foreach ($appName in $TargetApps) {
    try {
        $pkgs = Get-AppxPackage -AllUsers -Name $appName -ErrorAction SilentlyContinue
        foreach ($pkg in $pkgs) {
            $detected = $true
            $Reasons.Add("[$appName] Paquete instalado detectado: $($pkg.PackageFullName) (Usuario: $($pkg.PackageUserInformation.UserSecurityId.Value -join ', '))")
        }
    } catch {
        Write-Host "Advertencia al buscar '$appName' (AllUsers): $_"
    }
}

# =============================================================================
# 2. Paquetes AppX provisionados (imagen del sistema)
# =============================================================================
Write-Host "Comprobando paquetes AppX provisionados..."
try {
    $provisionedPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    foreach ($appName in $TargetApps) {
        $matches = $provisionedPkgs | Where-Object { $_.DisplayName -eq $appName }
        foreach ($pkg in $matches) {
            $detected = $true
            $Reasons.Add("[$appName] Paquete provisionado detectado: $($pkg.PackageName)")
        }
    }
} catch {
    Write-Host "Advertencia al buscar paquetes provisionados: $_"
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
