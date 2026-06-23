<#
.SYNOPSIS
    REMEDIATION SCRIPT: ELIMINAR APLICACIONES DE JUEGOS NO PERMITIDAS

.DESCRIPTION
    Este script elimina los siguientes paquetes UWP/AppX de juego de dispositivos
    Windows 10/11 gestionados por Intune:

      - Microsoft.MinecraftJavaEdition  (Minecraft Java Edition)
      - Microsoft.MinecraftUWP          (Minecraft para Windows)
      - Microsoft.MicrosoftSolitaireCollection (Microsoft Solitaire Collection)
      - Microsoft.MicrosoftSudoku       (Microsoft Sudoku)

    Pasos de remediacion:
      1. Finalizar procesos activos de los juegos
      2. Eliminar paquetes AppX para todos los usuarios
      3. Eliminar paquetes AppX provisionados (evita reinstalacion en nuevos perfiles)
      4. Post-verificacion para confirmar la eliminacion completa

    Salida:
      - Exit 0: Remediacion completada con exito
      - Exit 1: Alguno de los componentes no pudo eliminarse

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Desinstalar Juegos No Permitidos - Remediation.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 1.0.0
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

Write-Host "Iniciando eliminacion de aplicaciones de juego no permitidas..."

# Aplicaciones objetivo: nombre de paquete AppX y procesos asociados
$TargetApps = @(
    [PSCustomObject]@{
        PackageName    = "Microsoft.MinecraftJavaEdition"
        DisplayName    = "Minecraft Java Edition"
        ProcessNames   = @("Minecraft", "MinecraftLauncher", "javaw", "MinecraftJavaEdition")
    },
    [PSCustomObject]@{
        PackageName    = "Microsoft.MinecraftUWP"
        DisplayName    = "Minecraft para Windows"
        ProcessNames   = @("Minecraft.Windows", "MinecraftUWP")
    },
    [PSCustomObject]@{
        PackageName    = "Microsoft.MicrosoftSolitaireCollection"
        DisplayName    = "Microsoft Solitaire Collection"
        ProcessNames   = @("MicrosoftSolitaireCollection", "Solitaire")
    },
    [PSCustomObject]@{
        PackageName    = "Microsoft.MicrosoftSudoku"
        DisplayName    = "Microsoft Sudoku"
        ProcessNames   = @("MicrosoftSudoku")
    }
)

# =============================================================================
# PASO 1: Finalizar procesos activos de los juegos
# =============================================================================
Write-Host "--- Paso 1: Finalizando procesos activos ---"
foreach ($app in $TargetApps) {
    foreach ($procName in $app.ProcessNames) {
        try {
            Get-Process -Name $procName -ErrorAction SilentlyContinue | ForEach-Object {
                Write-Host "  Terminando proceso: $($_.Name) (PID: $($_.Id)) [$($app.DisplayName)]"
                Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Host "  Advertencia al terminar '$procName': $_"
        }
    }
}
Start-Sleep -Seconds 2

# =============================================================================
# PASO 2: Eliminar paquetes AppX para todos los usuarios
# =============================================================================
Write-Host "--- Paso 2: Eliminando paquetes AppX (todos los usuarios) ---"
foreach ($app in $TargetApps) {
    try {
        $pkgs = Get-AppxPackage -AllUsers -Name $app.PackageName -ErrorAction SilentlyContinue
        if ($pkgs) {
            foreach ($pkg in $pkgs) {
                Write-Host "  Eliminando [$($app.DisplayName)]: $($pkg.PackageFullName)"
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                    Write-Host "  -> Eliminado correctamente."
                } catch {
                    # Reintentar sin -AllUsers (algunos paquetes no admiten ese parametro)
                    try {
                        Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                        Write-Host "  -> Eliminado (sin -AllUsers)."
                    } catch {
                        Write-Host "  -> Advertencia al eliminar paquete: $_"
                    }
                }
            }
        } else {
            Write-Host "  [$($app.DisplayName)] No encontrado como paquete instalado."
        }
    } catch {
        Write-Host "  Advertencia al buscar '$($app.PackageName)': $_"
    }
}

# =============================================================================
# PASO 3: Eliminar paquetes AppX provisionados
# =============================================================================
Write-Host "--- Paso 3: Eliminando paquetes AppX provisionados ---"
try {
    $provisionedPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    foreach ($app in $TargetApps) {
        $matches = $provisionedPkgs | Where-Object { $_.DisplayName -eq $app.PackageName }
        if ($matches) {
            foreach ($pkg in $matches) {
                Write-Host "  Eliminando paquete provisionado [$($app.DisplayName)]: $($pkg.PackageName)"
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
                    Write-Host "  -> Paquete provisionado eliminado correctamente."
                } catch {
                    Write-Host "  -> Advertencia al eliminar paquete provisionado: $_"
                }
            }
        } else {
            Write-Host "  [$($app.DisplayName)] No encontrado como paquete provisionado."
        }
    }
} catch {
    Write-Host "  Advertencia al obtener paquetes provisionados: $_"
}

Start-Sleep -Seconds 3

# =============================================================================
# POST-VERIFICACION
# =============================================================================
Write-Host "--- Post-verificacion ---"
$Failed = $false

foreach ($app in $TargetApps) {
    # Verificar paquetes instalados
    $remaining = Get-AppxPackage -AllUsers -Name $app.PackageName -ErrorAction SilentlyContinue
    if ($remaining) {
        foreach ($pkg in $remaining) {
            Write-Host "ERROR: Paquete residual detectado [$($app.DisplayName)]: $($pkg.PackageFullName)"
            $Failed = $true
        }
    }

    # Verificar paquetes provisionados
    $remainingProv = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $app.PackageName }
    if ($remainingProv) {
        foreach ($pkg in $remainingProv) {
            Write-Host "ERROR: Paquete provisionado residual [$($app.DisplayName)]: $($pkg.PackageName)"
            $Failed = $true
        }
    }

    # Verificar procesos activos residuales
    foreach ($procName in $app.ProcessNames) {
        if (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
            Write-Host "ERROR: Proceso residual detectado [$($app.DisplayName)]: $procName"
            $Failed = $true
        }
    }
}

if ($Failed) {
    Write-Host "ERROR CRITICO: Algunas aplicaciones no pudieron eliminarse completamente."
    exit 1
} else {
    Write-Host "Remediacion finalizada con exito. Todos los juegos no permitidos han sido eliminados."
    exit 0
}
