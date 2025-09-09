<#
===============================================================================================
     REMEDIACIÓN: CREAR O AJUSTAR LA TAREA "ScheduledTask-Inkoova-CleanUpdates"
-----------------------------------------------------------------------------------------------
Este script crea o corrige la tarea programada "ScheduledTask-Inkoova-CleanUpdates"
para que ejecute la limpieza de actualizaciones con cleanmgr en todas las unidades.
Pensado para Intune Proactive Remediations en dispositivos gestionados.

-----------------------------------------------------------------------------------------------
AUTOR
-----------------------------------------------------------------------------------------------
- Alejandro Suárez (@alexsf93)
===============================================================================================
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
