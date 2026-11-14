<#
.SYNOPSIS
    DETECTION SCRIPT: DETECCIÓN DE CORRUPCIÓN EN CSPS MDM Y ERRORES SYNCML 404 (COMPLIANCE FIX)

.DESCRIPTION
    Este script detecta anomalías e inaccesibilidad en los Configuration Service Providers (CSPs)
    de Windows MDM que provocan fallos de cumplimiento (Not-Compliant) en Intune con el error:
    "Error Code: 0x87d10194 - Syncml(404): The requested target was not found".
    
    Verificaciones realizadas:
    1. Accesibilidad del CSP de Device Health Attestation (MDM_HealthAttestation en WMI).
    2. Accesibilidad del CSP de BitLocker (MDM_BitLocker en WMI).
    3. Integridad del repositorio WMI (winmgmt /verifyrepository).
    4. Búsqueda de eventos recientes de error SyncML 404 / 454 en el log de diagnóstico MDM
       (Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin).

    Si se detecta corrupción o inaccesibilidad de los CSPs/WMI: Finaliza con Exit 1 (activa remediación).
    Si el subsistema MDM y los CSPs responden correctamente: Finaliza con Exit 0.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - MDM SyncML 404 Fix - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-11-10
    Context: System
#>

# Forzar codificación UTF-8 segura
$OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Asegurar entorno de ejecución de 64 bits para evitar redirecciones de registro o WMI
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

$issuesFound = [System.Collections.Generic.List[string]]::new()

Write-Host "=== INICIANDO DETECCIÓN DE ESTADO CSP MDM Y ERRORES SYNCML 404 ==="

# ---------------------------------------------------------------------------
# BLOQUE 1: Verificación de accesibilidad del CSP Device Health Attestation
# ---------------------------------------------------------------------------
try {
    $null = Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_HealthAttestation" -ErrorAction Stop
    Write-Host "[OK] CSP Device Health Attestation (MDM_HealthAttestation) accesible y operativo."
}
catch {
    $msg = "CSP HealthAttestation inaccesible en WMI: $($_.Exception.Message)"
    $issuesFound.Add($msg)
    Write-Warning "[FALLO] $msg"
}

# ---------------------------------------------------------------------------
# BLOQUE 2: Verificación de accesibilidad del CSP BitLocker
# ---------------------------------------------------------------------------
try {
    $null = Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_BitLocker" -ErrorAction Stop
    Write-Host "[OK] CSP BitLocker (MDM_BitLocker) accesible y operativo."
}
catch {
    $msg = "CSP BitLocker inaccesible en WMI: $($_.Exception.Message)"
    $issuesFound.Add($msg)
    Write-Warning "[FALLO] $msg"
}

# ---------------------------------------------------------------------------
# BLOQUE 3: Integridad del Repositorio WMI
# ---------------------------------------------------------------------------
try {
    $wmiCheck = & "$env:SystemRoot\System32\wbem\winmgmt.exe" /verifyrepository 2>&1
    if ($LASTEXITCODE -ne 0 -or $wmiCheck -match "inconsistent|inconsistente") {
        $msg = "Repositorio WMI inconsistente o corrupto ($wmiCheck)"
        $issuesFound.Add($msg)
        Write-Warning "[FALLO] $msg"
    } else {
        Write-Host "[OK] Repositorio WMI íntegro."
    }
}
catch {
    $msg = "Error al verificar repositorio WMI: $($_.Exception.Message)"
    $issuesFound.Add($msg)
    Write-Warning "[FALLO] $msg"
}

# ---------------------------------------------------------------------------
# BLOQUE 4: Comprobación de errores SyncML 404 / 454 recientes en visor de eventos
# ---------------------------------------------------------------------------
try {
    $recentErrors = Get-WinEvent -FilterHashtable @{
        LogName   = 'Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin'
        Id        = 404, 454
        StartTime = (Get-Date).AddHours(-48)
    } -MaxEvents 5 -ErrorAction SilentlyContinue

    if ($recentErrors -and $recentErrors.Count -gt 0) {
        $msg = "Detectados $($recentErrors.Count) evento(s) de error SyncML (404/454) en las últimas 48 horas."
        $issuesFound.Add($msg)
        Write-Warning "[FALLO] $msg"
    } else {
        Write-Host "[OK] Sin eventos recientes de SyncML 404 en el log de diagnóstico MDM."
    }
}
catch {
    # Continuar si el registro no tiene eventos o está inaccesible
}

# ---------------------------------------------------------------------------
# EVALUACIÓN FINAL
# ---------------------------------------------------------------------------
if ($issuesFound.Count -gt 0) {
    Write-Output "DISPOSITIVO NO CONFORME: Se detectaron $($issuesFound.Count) anomalía(s) en los CSPs/MDM que provocan fallos de Compliance:"
    foreach ($issue in $issuesFound) {
        Write-Output " - $issue"
    }
    exit 1
} else {
    Write-Output "DISPOSITIVO CONFORME: Todos los CSPs de Compliance (DHA, BitLocker), WMI y canales SyncML responden correctamente."
    exit 0
}

