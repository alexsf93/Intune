<#
.SYNOPSIS
    REMEDIATION SCRIPT: RESOLUCION INTEGRAL DE WINDOWS AUTOPATCH (MASTER FIX)

.DESCRIPTION
    Script integral de remediacion para Windows Autopatch que resuelve de forma unificada:
    
    1. Eliminacion y saneamiento de directivas de Registro conflictivas:
       - Elimina HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate.
       - Elimina HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\AUOptions si tiene valores incompatibles.
       - Elimina directivas que impiden conexion (DoNotConnectToWindowsUpdateInternetLocations, DisableWindowsUpdateAccess).
    
    2. Saneamiento de PolicyManager (si estaba corrupto).
    
    3. Desencadena sincronizacion MDM con Intune a traves de PushLaunch / deviceenroller.exe (sin bloquear).
    
    4. Verificacion final de que ningun conflicto persiste en el registro.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Windows Autopatch Fix - Remediation.ps1
    Author: Alejandro Suarez (@alexsf93)
    Version: 2.1.0
    Date: 2026-10-06
    Context: System
#>

# Forzar codificacion UTF-8 segura
$OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Asegurar entorno de ejecucion de 64 bits para evitar redirecciones de registro (WOW6432Node)
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Host "Ejecutando en proceso de 32 bits en SO de 64 bits. Relanzando en PowerShell de 64 bits..."
    $powershell64 = Join-Path $env:SystemRoot "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $powershell64) {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process -FilePath $powershell64 -ArgumentList $arguments -Wait -NoNewWindow
        exit $LASTEXITCODE
    } else {
        Write-Warning "No se pudo encontrar PowerShell de 64 bits en Sysnative. Continuando en modo actual..."
    }
}

Write-Host "=== INICIANDO REMEDIACION INTEGRAL DE WINDOWS AUTOPATCH ==="

# ---------------------------------------------------------------------------
# BLOQUE 1: Corregir Directivas Conflictivas (WindowsUpdate y AU)
# ---------------------------------------------------------------------------
$regAU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
$regWU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

try {
    # 1.1 Eliminar NoAutoUpdate (Debe eliminarse completamente para Autopatch)
    if (Test-Path $regAU) {
        $auKey = Get-Item -Path $regAU -ErrorAction SilentlyContinue
        if ($null -ne $auKey -and ($auKey.GetValueNames() -contains "NoAutoUpdate")) {
            Write-Host "Eliminando valor conflictivo 'NoAutoUpdate' de '$regAU'..."
            Remove-ItemProperty -Path $regAU -Name "NoAutoUpdate" -Force -ErrorAction SilentlyContinue
            Write-Host "Propiedad 'NoAutoUpdate' eliminada."
        }

        # 1.2 Corregir o eliminar AUOptions si entra en conflicto (distinto de 4 o 5)
        if ($null -ne $auKey -and ($auKey.GetValueNames() -contains "AUOptions")) {
            $auOpt = [int]$auKey.GetValue("AUOptions")
            if ($auOpt -ne 4 -and $auOpt -ne 5) {
                Write-Host "Eliminando valor conflictivo 'AUOptions' (valor actual: $auOpt) de '$regAU'..."
                Remove-ItemProperty -Path $regAU -Name "AUOptions" -Force -ErrorAction SilentlyContinue
                Write-Host "Propiedad 'AUOptions' eliminada."
            }
        }
    }

    # 1.3 Eliminar directivas que bloquean la conexion o acceso a Windows Update
    if (Test-Path $regWU) {
        $wuKey = Get-Item -Path $regWU -ErrorAction SilentlyContinue
        if ($null -ne $wuKey -and ($wuKey.GetValueNames() -contains "DoNotConnectToWindowsUpdateInternetLocations")) {
            $valConn = [int]$wuKey.GetValue("DoNotConnectToWindowsUpdateInternetLocations")
            if ($valConn -ne 0) {
                Write-Host "Eliminando directiva restrictiva 'DoNotConnectToWindowsUpdateInternetLocations' de '$regWU'..."
                Remove-ItemProperty -Path $regWU -Name "DoNotConnectToWindowsUpdateInternetLocations" -Force -ErrorAction SilentlyContinue
                Write-Host "Propiedad eliminada."
            }
        }

        if ($null -ne $wuKey -and ($wuKey.GetValueNames() -contains "DisableWindowsUpdateAccess")) {
            $valDis = [int]$wuKey.GetValue("DisableWindowsUpdateAccess")
            if ($valDis -ne 0) {
                Write-Host "Eliminando directiva restrictiva 'DisableWindowsUpdateAccess' de '$regWU'..."
                Remove-ItemProperty -Path $regWU -Name "DisableWindowsUpdateAccess" -Force -ErrorAction SilentlyContinue
                Write-Host "Propiedad eliminada."
            }
        }
    }
}
catch {
    Write-Warning "Advertencia durante saneamiento de claves: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# BLOQUE 2: Saneamiento de PolicyManager (solo si esta corrupto)
# ---------------------------------------------------------------------------
$policyManagerPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update"
if (Test-Path -Path $policyManagerPath -ErrorAction SilentlyContinue) {
    try {
        $pmKey = Get-Item -Path $policyManagerPath -ErrorAction Stop
        $null = $pmKey.GetValueNames()
    }
    catch {
        Write-Host "Clave PolicyManagerUpdate corrupta. Intentando saneamiento..."
        try {
            Remove-Item -Path $policyManagerPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Subclave de PolicyManager limpiada."
        } catch {
            Write-Warning "No se pudo limpiar la clave PolicyManager: $($_.Exception.Message)"
        }
    }
}

# ---------------------------------------------------------------------------
# BLOQUE 3: Sincronizacion MDM no bloqueante con Intune
# ---------------------------------------------------------------------------
Write-Host "Iniciando sincronizacion MDM con Intune..."
$syncStarted = $false

try {
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -like "*EnterpriseMgmt*" -and $_.TaskName -eq "PushLaunch" }
    if ($tasks) {
        foreach ($task in $tasks) {
            Start-ScheduledTask -InputObject $task -ErrorAction SilentlyContinue
            $syncStarted = $true
        }
        if ($syncStarted) {
            Write-Host "Tarea PushLaunch iniciada correctamente."
        }
    }
} catch {
    Write-Warning "Aviso al invocar PushLaunch: $($_.Exception.Message)"
}

if (-not $syncStarted) {
    try {
        # Lanzar de forma asincrona / no bloqueante para evitar timeouts en Intune
        Start-Process -FilePath "$env:SystemRoot\System32\deviceenroller.exe" -ArgumentList "/c /mobileenrollment" -NoNewWindow -ErrorAction SilentlyContinue
        Write-Host "Sincronizacion MDM invocada via deviceenroller.exe."
    } catch {
        Write-Warning "Aviso al invocar deviceenroller.exe: $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# BLOQUE 4: Verificacion posterior a la remediacion
# ---------------------------------------------------------------------------
Write-Host "Realizando verificacion final de estado en el Registro..."
$finalIssues = 0

if (Test-Path $regAU) {
    $checkAU = Get-Item -Path $regAU -ErrorAction SilentlyContinue
    if ($null -ne $checkAU) {
        if ($checkAU.GetValueNames() -contains "NoAutoUpdate") {
            Write-Output "Error de verificacion: 'NoAutoUpdate' todavia persiste en '$regAU'."
            $finalIssues++
        }
        if ($checkAU.GetValueNames() -contains "AUOptions") {
            $valAUCheck = [int]$checkAU.GetValue("AUOptions")
            if ($valAUCheck -ne 4 -and $valAUCheck -ne 5) {
                Write-Output "Error de verificacion: 'AUOptions' todavia tiene valor incompatible '$valAUCheck'."
                $finalIssues++
            }
        }
    }
}

if (Test-Path $regWU) {
    $checkWU = Get-Item -Path $regWU -ErrorAction SilentlyContinue
    if ($null -ne $checkWU) {
        if ($checkWU.GetValueNames() -contains "DoNotConnectToWindowsUpdateInternetLocations") {
            $valConnCheck = [int]$checkWU.GetValue("DoNotConnectToWindowsUpdateInternetLocations")
            if ($valConnCheck -ne 0) {
                Write-Output "Error de verificacion: 'DoNotConnectToWindowsUpdateInternetLocations' sigue activo."
                $finalIssues++
            }
        }
        if ($checkWU.GetValueNames() -contains "DisableWindowsUpdateAccess") {
            $valDisCheck = [int]$checkWU.GetValue("DisableWindowsUpdateAccess")
            if ($valDisCheck -ne 0) {
                Write-Output "Error de verificacion: 'DisableWindowsUpdateAccess' sigue activo."
                $finalIssues++
            }
        }
    }
}

if ($finalIssues -eq 0) {
    Write-Host "Remediacion completada con exito. Todos los conflictos han sido subsanados."
    exit 0
} else {
    Write-Output "Remediacion incompleta: persisten $finalIssues anomalia(s) en el registro."
    exit 1
}
