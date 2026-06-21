<#
.SYNOPSIS
    REMEDIATION SCRIPT: CREAR O AJUSTAR LA TAREA "ScheduledTask-Inkoova-MSDefender-Simple"

.DESCRIPTION
    Este script crea o corrige la tarea programada **ScheduledTask-Inkoova-MSDefender-Simple** para
    ejecutar un escaneo simple de Microsoft Defender (CustomScan) en todas las unidades del equipo.
    Incluye logging local y registro de resultados de detecciones.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - ScheduledTask MSDefender_Simple - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: System
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$RunScan
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TaskName = 'ScheduledTask-Inkoova-MSDefender-Simple'
$CompanyFolder = Join-Path $env:ProgramData 'Inkoova'
$ScriptTarget = Join-Path $CompanyFolder 'MSDefenderSimple.ps1'
$LogPath = 'C:\MSDefender_Simple.log'

function Write-Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Write-Host $line
    try { Add-Content -Path $LogPath -Value $line -Encoding UTF8 } catch {}
}

function Get-FixedDrives {
    Get-PSDrive -PSProvider FileSystem | Where-Object { $null -eq $_.DisplayRoot -and $_.Root -match '^[A-Z]:\\$' }
}

function Get-MpCmdRunPath {
    $platformRoot = Join-Path $env:ProgramData 'Microsoft\Windows Defender\Platform'
    try {
        if (Test-Path $platformRoot) {
            $latest = Get-ChildItem -Path $platformRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
            if ($latest) {
                $candidate = Join-Path $latest.FullName 'MpCmdRun.exe'
                if (Test-Path $candidate) { return $candidate }
            }
        }
    }
    catch {}
    $fallback = Join-Path ${env:ProgramFiles} 'Windows Defender\MpCmdRun.exe'
    if (Test-Path $fallback) { return $fallback }
    return $null
}

function Invoke-DefenderScanAllFixed {
    $scanStart = Get-Date
    $drives = Get-FixedDrives
    if (-not $drives) {
        Write-Log "No se han detectado unidades para escanear."
        return
    }

    $mpcmd = Get-MpCmdRunPath

    foreach ($d in $drives) {
        $letter = $d.Root.Substring(0, 1)
        $path = "$letter`:\"
        $scanned = $false
        try {
            if (Get-Command -Name Start-MpScan -ErrorAction SilentlyContinue) {
                Write-Log "Iniciando escaneo Defender (CustomScan) en ${letter}:\ con Start-MpScan..."
                Start-MpScan -ScanType CustomScan -ScanPath $path
                Write-Log "Finalizado escaneo en ${letter}:\ (Start-MpScan)."
                $scanned = $true
            }
        }
        catch {
            Write-Log "Error en ${letter}:\ con Start-MpScan: $($_.Exception.Message)"
        }

        if (-not $scanned -and $mpcmd) {
            try {
                Write-Log "Iniciando escaneo Defender (CustomScan) en ${letter}:\ con MpCmdRun.exe..."
                Start-Process -FilePath $mpcmd -ArgumentList "-Scan", "-ScanType", "3", "-File", $path -WindowStyle Hidden -Wait
                Write-Log "Finalizado escaneo en ${letter}:\ (MpCmdRun.exe)."
                $scanned = $true
            }
            catch {
                Write-Log "Error en ${letter}:\ con MpCmdRun.exe: $($_.Exception.Message)"
            }
        }

        if (-not $scanned) {
            Write-Log "No fue posible escanear ${letter}:\ con Microsoft Defender."
        }
    }

    Write-Log "Escaneo de Microsoft Defender completado en todas las unidades."

    # ---- RESULTADOS DEL ESCANEO (detecciones desde el inicio de esta ejecución) ----
    try {
        $detections = Get-MpThreatDetection | Where-Object { $_.InitialDetectionTime -ge $scanStart }

        if ($detections -and $detections.Count -gt 0) {
            Write-Log "Se detectaron $($detections.Count) amenazas durante este escaneo."
            # Intentar severidad desde catálogo (si disponible)
            $sevMap = @{}
            try {
                $catalog = Get-MpThreat
                foreach ($t in $catalog) { $sevMap[$t.ThreatID] = $t.Severity }
            }
            catch {
                Write-Log "No se pudo obtener la severidad desde el catálogo de amenazas: $($_.Exception.Message)"
            }

            $remediadas = 0
            $noRemediadas = 0

            foreach ($det in $detections) {
                $sev = if ($sevMap.ContainsKey($det.ThreatID)) { $sevMap[$det.ThreatID] } else { 'N/A' }
                $res = $det.Resources
                if ($res -is [array]) { $res = ($res -join ', ') }

                $estado = if ($det.ActionSuccess -eq $true) { 'Remediada' }
                elseif ($det.ActionSuccess -eq $false) { 'No remediada' }
                else { 'Desconocido' }

                if ($det.ActionSuccess -eq $true) { $remediadas++ }
                elseif ($det.ActionSuccess -eq $false) { $noRemediadas++ }

                Write-Log ("Detección -> ID:{0} | Amenaza:{1} | Severidad:{2} | Estado:{3} | Hora:{4} | Rutas:{5}" -f `
                        $det.ThreatID, $det.ThreatName, $sev, $estado, $det.InitialDetectionTime, $res)
            }

            Write-Log ("Resumen detecciones: Remediadas={0}; NoRemediadas={1}" -f $remediadas, $noRemediadas)
        }
        else {
            Write-Log "No se detectaron amenazas durante este escaneo."
        }
    }
    catch {
        Write-Log "No se pudieron obtener resultados del escaneo: $($_.Exception.Message)"
    }
}

# 1. Si se ejecuta con -RunScan, lanzar escaneo directamente
if ($RunScan) {
    Invoke-DefenderScanAllFixed
    exit 0
}

# 2. Copiar el script actual a C:\ProgramData\Inkoova\MSDefenderSimple.ps1
if (-not (Test-Path $CompanyFolder)) { New-Item -ItemType Directory -Path $CompanyFolder -Force | Out-Null }
$currentPath = $MyInvocation.MyCommand.Path
if ($currentPath -and $currentPath -ne $ScriptTarget) {
    Copy-Item -Path $currentPath -Destination $ScriptTarget -Force
}
elseif (-not (Test-Path $ScriptTarget) -and $currentPath) {
    Copy-Item -Path $currentPath -Destination $ScriptTarget -Force
}

# 3. Definir acción, trigger, settings y principal para la tarea
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptTarget`" -RunScan"
$trigger = New-ScheduledTaskTrigger -MonthlyDOW -WeeksOfMonth Second, Fourth -DaysOfWeek Friday -At "13:00"
$settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 6)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

# 4. Registrar la tarea (si existe, eliminar primero)
try {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
    }
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
    Write-Log "Tarea '$TaskName' creada o actualizada correctamente (2Âº y 4Âº viernes a las 13:00)."
}
catch {
    Write-Log "ERROR creando la tarea: $($_.Exception.Message)"
    exit 1
}

# 5. Salida final
exit 0
