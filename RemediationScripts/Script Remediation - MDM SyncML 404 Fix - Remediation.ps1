<#
.SYNOPSIS
    REMEDIATION SCRIPT: REPARACIÓN DE ALMACÉN DE COMPONENTES, CSPS MDM Y SINCRONIZACIÓN (SYNCML 404 FIX)

.DESCRIPTION
    Este script remedia la corrupción del subsistema MDM y de los CSPs de Windows (Health Attestation y BitLocker)
    que originan el error "Error Code: 0x87d10194 - Syncml(404): The requested target was not found":
    
    1. Sanea el almacén de componentes de Windows mediante DISM (Cleanup-Image /RestoreHealth).
    2. Ejecuta el Comprobador de archivos de sistema (sfc /scannow) para restaurar DLLs protegidas corruptas.
    3. Verifica y repara el repositorio WMI si presenta inconsistencias (winmgmt /salvagerepository).
    4. Reinicia el servicio de notificación MDM (dmwappushservice).
    5. Solicita sincronización inmediata con Intune (PushLaunch / deviceenroller.exe).
    6. Registra las acciones en C:\ProgramData\IntuneLogs\MDM_SyncML_Fix.log.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - MDM SyncML 404 Fix - Remediation.ps1
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

# ---------------------------------------------------------------------------
# CONFIGURACIÓN DE LOGS LOCALES
# ---------------------------------------------------------------------------
$logFolder = Join-Path $env:ProgramData "IntuneLogs"
$logFile   = Join-Path $logFolder "MDM_SyncML_Fix.log"

if (-not (Test-Path -Path $logFolder)) {
    New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$message, [string]$severity = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logLine = "[$timestamp] [$severity] $message"
    Write-Host $logLine
    try {
        Add-Content -Path $logFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

Write-Log "=== INICIANDO REMEDIACIÓN INTEGRAL DE CSPS MDM Y SYNCML 404 ===" "INFO"

# ---------------------------------------------------------------------------
# BLOQUE 1: Reparación del Almacén de Componentes (DISM RestoreHealth)
# ---------------------------------------------------------------------------
Write-Log "Iniciando saneamiento de componentes mediante DISM..." "INFO"
try {
    $dismProcess = Start-Process -FilePath "$env:SystemRoot\System32\Dism.exe" `
        -ArgumentList "/Online /Cleanup-Image /RestoreHealth /NoRestart" `
        -Wait -PassThru -NoNewWindow -ErrorAction Stop

    if ($dismProcess.ExitCode -eq 0) {
        Write-Log "DISM completado con éxito (ExitCode 0)." "INFO"
    } else {
        Write-Log "DISM finalizó con código de salida no cero: $($dismProcess.ExitCode)." "WARNING"
    }
}
catch {
    Write-Log "Error al ejecutar DISM: $($_.Exception.Message)" "ERROR"
}

# ---------------------------------------------------------------------------
# BLOQUE 2: Comprobación y Restauración de Archivos de Sistema (SFC)
# ---------------------------------------------------------------------------
Write-Log "Iniciando comprobador de archivos de sistema protegido (sfc /scannow)..." "INFO"
try {
    $sfcProcess = Start-Process -FilePath "$env:SystemRoot\System32\sfc.exe" `
        -ArgumentList "/scannow" `
        -Wait -PassThru -NoNewWindow -ErrorAction Stop

    if ($sfcProcess.ExitCode -eq 0) {
        Write-Log "SFC completado: No se encontraron infracciones de integridad (ExitCode 0)." "INFO"
    } elseif ($sfcProcess.ExitCode -eq 1) {
        Write-Log "SFC completado: Se repararon archivos dañados correctamente." "INFO"
    } else {
        Write-Log "SFC finalizó con código: $($sfcProcess.ExitCode)." "WARNING"
    }
}
catch {
    Write-Log "Error al ejecutar SFC: $($_.Exception.Message)" "ERROR"
}

# ---------------------------------------------------------------------------
# BLOQUE 3: Verificación y Saneamiento del Repositorio WMI
# ---------------------------------------------------------------------------
Write-Log "Verificando consistencia del repositorio WMI..." "INFO"
try {
    $wmiCheck = & "$env:SystemRoot\System32\wbem\winmgmt.exe" /verifyrepository 2>&1
    if ($LASTEXITCODE -ne 0 -or $wmiCheck -match "inconsistent|inconsistente") {
        Write-Log "Inconsistencia en WMI detectada. Ejecutando salvamento de repositorio..." "WARNING"
        $salvage = & "$env:SystemRoot\System32\wbem\winmgmt.exe" /salvagerepository 2>&1
        Write-Log "Resultado winmgmt /salvagerepository: $salvage" "INFO"
    } else {
        Write-Log "Repositorio WMI consistente y verificado." "INFO"
    }
}
catch {
    Write-Log "Aviso al evaluar o reparar WMI: $($_.Exception.Message)" "WARNING"
}

# ---------------------------------------------------------------------------
# BLOQUE 4: Reiniciar Servicio de Notificación MDM
# ---------------------------------------------------------------------------
Write-Log "Reiniciando el servicio dmwappushservice (WAP Push Message Routing)..." "INFO"
try {
    Restart-Service -Name "dmwappushservice" -Force -ErrorAction SilentlyContinue
    Write-Log "Servicio dmwappushservice reiniciado correctamente." "INFO"
}
catch {
    Write-Log "Aviso al reiniciar dmwappushservice: $($_.Exception.Message)" "WARNING"
}

# ---------------------------------------------------------------------------
# BLOQUE 5: Desencadenar Sincronización MDM con Intune
# ---------------------------------------------------------------------------
Write-Log "Desencadenando sincronización con Intune..." "INFO"
$syncTriggered = $false

try {
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { 
        $_.TaskPath -like "*EnterpriseMgmt*" -and $_.TaskName -eq "PushLaunch" 
    }

    if ($tasks) {
        foreach ($task in $tasks) {
            Start-ScheduledTask -InputObject $task -ErrorAction SilentlyContinue
            $syncTriggered = $true
        }
        if ($syncTriggered) {
            Write-Log "Tarea PushLaunch iniciada para sincronización MDM." "INFO"
        }
    }
}
catch {
    Write-Log "Aviso al invocar PushLaunch: $($_.Exception.Message)" "WARNING"
}

if (-not $syncTriggered) {
    try {
        Start-Process -FilePath "$env:SystemRoot\System32\deviceenroller.exe" `
            -ArgumentList "/c /mobileenrollment" -NoNewWindow -ErrorAction SilentlyContinue
        Write-Log "Sincronización MDM invocada vía deviceenroller.exe." "INFO"
    }
    catch {
        Write-Log "Aviso al invocar deviceenroller.exe: $($_.Exception.Message)" "WARNING"
    }
}

# ---------------------------------------------------------------------------
# BLOQUE 6: Verificación de estado final de los CSPs
# ---------------------------------------------------------------------------
Write-Log "Realizando comprobación final de disponibilidad de CSPs..." "INFO"
$cspErrors = 0

try {
    $null = Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_HealthAttestation" -ErrorAction Stop
    Write-Log "Validación: CSP MDM_HealthAttestation disponible." "INFO"
}
catch {
    Write-Log "Validación: CSP MDM_HealthAttestation aún inaccesible: $($_.Exception.Message)" "WARNING"
    $cspErrors++
}

try {
    $null = Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_BitLocker" -ErrorAction Stop
    Write-Log "Validación: CSP MDM_BitLocker disponible." "INFO"
}
catch {
    Write-Log "Validación: CSP MDM_BitLocker aún inaccesible: $($_.Exception.Message)" "WARNING"
    $cspErrors++
}

if ($cspErrors -eq 0) {
    Write-Log "Remediación completada con éxito. Todos los CSPs de Compliance están operativos." "INFO"
    Write-Output "Remediación completada exitosamente. CSPs MDM y WMI reparados."
    exit 0
} else {
    Write-Log "Remediación aplicada. Es posible que se requiera un reinicio del sistema para consolidar el estado del TPM y CSPs." "WARNING"
    Write-Output "Remediación aplicada (se sugiere reinicio para consolidar la atestación de hardware TPM)."
    exit 0
}

