<#
===============================================================================================
     REMEDIACIÓN: CREAR/AJUSTAR LA TAREA "ScheduledTask-Inkoova-CleanUpdates"
-----------------------------------------------------------------------------------------------
Este script crea o corrige la tarea programada "ScheduledTask-Inkoova-CleanUpdates"
para ejecutar la limpieza de actualizaciones en modo silencioso cada viernes a las 11:00.

-----------------------------------------------------------------------------------------------
AUTOR
-----------------------------------------------------------------------------------------------
- Alejandro Suárez (@alexsf93)
===============================================================================================
#>

[CmdletBinding()]
param(
    [switch]$RunCleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TaskName      = 'ScheduledTask-Inkoova-CleanUpdates'
$CompanyFolder = Join-Path $env:ProgramData 'Inkoova'
$ScriptTarget  = Join-Path $CompanyFolder 'CleanUpdates.ps1'
$Preset        = 9999

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
        } catch {}
    }
}

# 1. Parámetros y configuración
$ExpectedDay  = 'Friday'
$ExpectedHour = 11
$ExpectedMin  = 0

# 2. Ejecutar limpieza si viene -RunCleanup
if ($RunCleanup) {
    Run-CleanMgr-AllFixed
    exit 0
}

# 3. Asegurar ruta persistente del script en %ProgramData%
if (-not (Test-Path $CompanyFolder)) { New-Item -ItemType Directory -Path $CompanyFolder -Force | Out-Null }
$currentPath = $MyInvocation.MyCommand.Path
if ($currentPath -and $currentPath -ne $ScriptTarget) {
    Copy-Item -Path $currentPath -Destination $ScriptTarget -Force
} elseif (-not (Test-Path $ScriptTarget) -and $currentPath) {
    Copy-Item -Path $currentPath -Destination $ScriptTarget -Force
}

# 4. Crear o actualizar la tarea programada (viernes 11:00, SYSTEM)
$action   = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptTarget`" -RunCleanup"
$trigger  = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $ExpectedDay -At ([TimeSpan]::FromHours($ExpectedHour) + [TimeSpan]::FromMinutes($ExpectedMin))
$settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 6)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

try {
    $exists = $false
    try { $null = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop; $exists = $true } catch {}

    if ($exists) {
        Set-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
        Enable-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue | Out-Null
    } else {
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
    }
} catch {
    Write-Host "Error creando/actualizando la tarea '$TaskName': $($_.Exception.Message)"
    exit 1
}

# 5. Salida
Write-Host "OK: Tarea '$TaskName' creada/actualizada (viernes 11:00, SYSTEM, -RunCleanup)."
exit 0
