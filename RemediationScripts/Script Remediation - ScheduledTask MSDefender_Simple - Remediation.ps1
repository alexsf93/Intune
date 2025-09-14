<#
=====================================================================================================
    REMEDIATION SCRIPT: CREAR O AJUSTAR LA TAREA "ScheduledTask-Inkoova-MSDefender-Simple"
-----------------------------------------------------------------------------------------------------
Este script crea o corrige la tarea programada **ScheduledTask-Inkoova-MSDefender-Simple** para
ejecutar un escaneo simple de Microsoft Defender (CustomScan) en todas las unidades del equipo.
Incluye logging local y registro de resultados de detecciones.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Ejecución con privilegios SYSTEM o administrador local.
- Microsoft Defender activo y accesible (cmdlets `Start-MpScan` / binario `MpCmdRun.exe`).
- Permisos de escritura en `C:\ProgramData\Inkoova\` y en `C:\` para el log.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Detecta unidades fijas y ejecuta un CustomScan por unidad.
- Prefiere `Start-MpScan`; si no está disponible, usa `MpCmdRun.exe`.
- Registra inicio/fin por unidad y, al final, resume detecciones (remediadas/no remediadas).
- Copia el propio script a `C:\ProgramData\Inkoova\MSDefenderSimple.ps1`.
- Crea/actualiza la tarea programada para ejecutarse el **2º y 4º viernes a las 13:00**.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Escaneo ejecutado o tarea registrada/actualizada correctamente.
- "NOK" (exit code 1) → Error al crear/actualizar la tarea programada.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar con `-RunScan` para lanzar el escaneo inmediatamente.
- Ejecutar sin parámetros para registrar/actualizar la tarea programada.
- Revisar `C:\MSDefender_Simple.log` para trazabilidad del escaneo y detecciones.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$RunScan
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TaskName      = 'ScheduledTask-Inkoova-MSDefender-Simple'
$CompanyFolder = Join-Path $env:ProgramData 'Inkoova'
$ScriptTarget  = Join-Path $CompanyFolder 'MSDefenderSimple.ps1'
$LogPath       = 'C:\MSDefender_Simple.log'

function Write-Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Write-Host $line
    try { Add-Content -Path $LogPath -Value $line -Encoding UTF8 } catch {}
}

function Get-FixedDrives {
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -eq $null -and $_.Root -match '^[A-Z]:\\$' }
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
    } catch {}
    $fallback = Join-Path ${env:ProgramFiles} 'Windows Defender\MpCmdRun.exe'
    if (Test-Path $fallback) { return $fallback }
    return $null
}

function Run-DefenderScan-AllFixed {
    $scanStart = Get-Date
    $drives = Get-FixedDrives
    if (-not $drives) {
        Write-Log "No se han detectado unidades para escanear."
        return
    }

    $mpcmd = Get-MpCmdRunPath

    foreach ($d in $drives) {
        $letter = $d.Root.Substring(0,1)
        $path   = "$letter`:\"
        $scanned = $false
        try {
            if (Get-Command -Name Start-MpScan -ErrorAction SilentlyContinue) {
                Write-Log "Iniciando escaneo Defender (CustomScan) en ${letter}:\ con Start-MpScan..."
                Start-MpScan -ScanType CustomScan -ScanPath $path
                Write-Log "Finalizado escaneo en ${letter}:\ (Start-MpScan)."
                $scanned = $true
            }
        } catch {
            Write-Log "Error en ${letter}:\ con Start-MpScan: $($_.Exception.Message)"
        }

        if (-not $scanned -and $mpcmd) {
            try {
                Write-Log "Iniciando escaneo Defender (CustomScan) en ${letter}:\ con MpCmdRun.exe..."
                Start-Process -FilePath $mpcmd -ArgumentList "-Scan","-ScanType","3","-File",$path -WindowStyle Hidden -Wait
                Write-Log "Finalizado escaneo en ${letter}:\ (MpCmdRun.exe)."
                $scanned = $true
            } catch {
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
            } catch {
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
        } else {
            Write-Log "No se detectaron amenazas durante este escaneo."
        }
    } catch {
        Write-Log "No se pudieron obtener resultados del escaneo: $($_.Exception.Message)"
    }
}

# 1. Si se ejecuta con -RunScan, lanzar escaneo directamente
if ($RunScan) {
    Run-DefenderScan-AllFixed
    exit 0
}

# 2. Copiar el script actual a C:\ProgramData\Inkoova\MSDefenderSimple.ps1
if (-not (Test-Path $CompanyFolder)) { New-Item -ItemType Directory -Path $CompanyFolder -Force | Out-Null }
$currentPath = $MyInvocation.MyCommand.Path
if ($currentPath -and $currentPath -ne $ScriptTarget) {
    Copy-Item -Path $currentPath -Destination $ScriptTarget -Force
} elseif (-not (Test-Path $ScriptTarget) -and $currentPath) {
    Copy-Item -Path $currentPath -Destination $ScriptTarget -Force
}

# 3. Definir acción, trigger, settings y principal para la tarea
$action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptTarget`" -RunScan"
$trigger   = New-ScheduledTaskTrigger -MonthlyDOW -WeeksOfMonth Second, Fourth -DaysOfWeek Friday -At "13:00"
$settings  = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 6)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

# 4. Registrar la tarea (si existe, eliminar primero)
try {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
    }
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
    Write-Log "Tarea '$TaskName' creada o actualizada correctamente (2º y 4º viernes a las 13:00)."
} catch {
    Write-Log "ERROR creando la tarea: $($_.Exception.Message)"
    exit 1
}

# 5. Salida final
exit 0
