<#
=====================================================================================================
    REMEDIATION SCRIPT: CREAR O AJUSTAR LA TAREA "ScheduledTask-Inkoova-CleanUpdates"
-----------------------------------------------------------------------------------------------------
Este script crea o corrige la tarea programada **ScheduledTask-Inkoova-CleanUpdates** para ejecutar
la limpieza de actualizaciones con **cleanmgr** en todas las unidades del equipo. Está orientado a
Intune Proactive Remediations en dispositivos gestionados.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Ejecución con privilegios SYSTEM o administrador local.
- Herramienta `cleanmgr.exe` disponible (Windows).
- Permisos de escritura en `C:\ProgramData\Inkoova\` y en `C:\`.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Establece un preset de `cleanmgr` (StateFlags).
- Recorre todas las unidades fijas y ejecuta `cleanmgr /sagerun:<Preset>`.
- Registra la acción y resultado en un log local.
- Copia el propio script a `C:\ProgramData\Inkoova\CleanUpdates.ps1`.
- Crea/actualiza la tarea programada que ejecuta el script con `-RunCleanup`.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Limpieza ejecutada correctamente o tarea registrada/actualizada con éxito.
- "NOK" (exit code 1) → Error al crear/actualizar la tarea programada.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar manualmente con `-RunCleanup` para limpiar en el momento.
- Ejecutar sin parámetros para registrar/actualizar la tarea programada.
- Ajustar la hora/frecuencia del trigger según la política de la organización.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$RunCleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TaskName      = 'ScheduledTask-Inkoova-CleanUpdates'
$CompanyFolder = Join-Path $env:ProgramData 'Inkoova'
$ScriptTarget  = Join-Path $CompanyFolder 'CleanUpdates.ps1'
$LogPath       = 'C:\Limpieza_cleanmgr.log'
$Preset        = 9999

function Write-Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Write-Host $line
    try { Add-Content -Path $LogPath -Value $line -Encoding UTF8 } catch {}
}

function Ensure-Preset {
    $vcKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    Get-ChildItem $vcKey | ForEach-Object {
        try {
            New-ItemProperty -Path $_.PSPath -Name ("StateFlags{0}" -f $Preset) -Value 2 -PropertyType DWord -Force | Out-Null
        } catch {}
    }
}

function Run-CleanMgr-AllFixed {
    Ensure-Preset
    $fixed = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -eq $null -and $_.Root -match '^[A-Z]:\\$' }
    foreach ($d in $fixed) {
        $letter = $d.Root.Substring(0,1)
        try {
            Start-Process -FilePath 'cleanmgr.exe' -ArgumentList "/d $letter /sagerun:$Preset" -WindowStyle Hidden -Wait
            Write-Log "Finalizado cleanmgr en ${letter}:"
        } catch {
            Write-Log "Error en ${letter}: $($_.Exception.Message)"
        }
    }
    Write-Log "Liberador de espacio en disco completado en todas las unidades."
}

# 1. Si se ejecuta con -RunCleanup, lanzar limpieza directamente
if ($RunCleanup) {
    Run-CleanMgr-AllFixed
    exit 0
}

# 2. Copiar el script actual a C:\ProgramData\Inkoova\CleanUpdates.ps1
if (-not (Test-Path $CompanyFolder)) { New-Item -ItemType Directory -Path $CompanyFolder -Force | Out-Null }
$currentPath = $MyInvocation.MyCommand.Path
if ($currentPath -and $currentPath -ne $ScriptTarget) {
    Copy-Item -Path $currentPath -Destination $ScriptTarget -Force
} elseif (-not (Test-Path $ScriptTarget) -and $currentPath) {
    Copy-Item -Path $currentPath -Destination $ScriptTarget -Force
}

# 3. Definir acción, trigger, settings y principal para la tarea
$action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptTarget`" -RunCleanup"
$trigger   = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At "11:00"
$settings  = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 6)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

# 4. Registrar la tarea (si existe, eliminar primero)
try {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
    }
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
    Write-Log "Tarea '$TaskName' creada o actualizada correctamente."
} catch {
    Write-Log "ERROR creando la tarea: $($_.Exception.Message)"
    exit 1
}

# 5. Salida final
exit 0
