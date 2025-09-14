<#
===============================================================
        Script: Script - Full cleanup (para updates) (Windows)
---
Autor: Alejandro Suárez (@alexsf93)
===============================================================

.DESCRIPCIÓN
    Ejecuta el Liberador de espacio en disco (cleanmgr) en todas
    las unidades fijas del sistema de forma 100% silenciosa
    mediante tareas programadas temporales ejecutadas como SYSTEM.

.INSTRUCCIONES DE USO
    1. Guarda este script como .ps1 en el equipo (ej: Script - Full cleanup (para updates).ps1).
    2. Ejecuta PowerShell como Administrador.
    3. Lanza el script con:
         .\Script - Full cleanup (para updates).ps1
    4. El proceso puede tardar varios minutos, según el tamaño
       y la cantidad de archivos temporales acumulados.

.NOTAS
    - Limpia todas las categorías de cleanmgr (preset 9999).
    - Se ejecuta en todas las unidades fijas (C:, D:, etc).
    - No se muestra ninguna ventana durante la ejecución.
    - Cada tarea temporal se nombra como:
        Inkoova-Limpieza-<letra>-<GUID>
      y se elimina al finalizar.
    - Se genera un log en:
        C:\Limpieza_cleanmgr.log
===============================================================
#>

# Ejecutar como Administrador
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# LOG 
$LogPath = "C:\Limpieza_cleanmgr.log"
function Write-Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
    Write-Host $line
    try { Add-Content -Path $LogPath -Value $line -Encoding UTF8 } catch { }
}

# Comprobación de admin 
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Este script debe ejecutarse como Administrador." -ForegroundColor Red
    exit 1
}

# Configurar preset de cleanmgr
$Preset = 9999
$vcKey  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
Write-Log "Activando todas las categorías de cleanmgr (StateFlags$Preset = 2)..."
Get-ChildItem $vcKey | ForEach-Object {
    try {
        New-ItemProperty -Path $_.PSPath -Name ("StateFlags{0}" -f $Preset) -Value 2 -PropertyType DWord -Force | Out-Null
    } catch {
        Write-Log "Aviso: no se pudo marcar $($_.PSChildName): $($_.Exception.Message)"
    }
}

# Unidades fijas 
$fixed = Get-PSDrive -PSProvider FileSystem |
         Where-Object { $_.DisplayRoot -eq $null -and $_.Root -match '^[A-Z]:\\$' }

if (-not $fixed) {
    Write-Log "No se detectaron unidades de archivo."
    exit 0
}

# Ejecutar vía Programador de tareas, oculto, como SYSTEM 
foreach ($d in $fixed) {
    $letter = $d.Root.Substring(0,1)
    $guid = [guid]::NewGuid().ToString("N")
    $taskName = "Inkoova-Limpieza-${letter}-$guid"
    Write-Log "Creando tarea oculta $taskName ..."

    $action    = New-ScheduledTaskAction -Execute "cleanmgr.exe" -Argument "/d ${letter} /sagerun:$Preset"
    $trigger   = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddSeconds(10))
    $stgs      = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 6)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $stgs -Principal $principal | Out-Null
        Start-ScheduledTask -TaskName $taskName
        Write-Log "Limpieza iniciada en ${letter}: (tarea: $taskName)."

        # Esperar hasta 6 horas a que termine
        $timeout = (Get-Date).AddHours(6)
        do {
            Start-Sleep -Seconds 5
            $state = (Get-ScheduledTask -TaskName $taskName).State
        } while ($state -in @('Queued','Running') -and (Get-Date) -lt $timeout)

        if ($state -in @('Queued','Running')) {
            Write-Log "Tiempo agotado esperando la tarea $taskName (estado actual: $state)."
        } else {
            Write-Log "Limpieza finalizada en ${letter}: (estado final: $state)."
        }
    } catch {
        Write-Log "Error al ejecutar en ${letter}:: $($_.Exception.Message)"
    } finally {
        try { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false | Out-Null } catch { }
    }
}

Write-Log "Liberador de espacio en disco completado en todas las unidades"
