<#
=====================================================================================================
    REMEDIATION SCRIPT: CREAR O AJUSTAR LA TAREA "ScheduledTask-Inkoova-WingetUpgradeSoftware"
-----------------------------------------------------------------------------------------------------
Este script crea o corrige la tarea programada **ScheduledTask-Inkoova-WingetUpgradeSoftware**
para ejecutar la actualización silenciosa de aplicaciones mediante **winget** en el equipo.

Pensado para Intune Proactive Remediations en dispositivos gestionados.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Ejecución con privilegios SYSTEM o administrador local.
- Winget instalado (Desktop App Installer).
- Permisos de escritura en `C:\ProgramData\Inkoova\`.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Opción `-RunUpgrade`: ejecuta `winget upgrade --all --silent --accept-source-agreements
  --accept-package-agreements --disable-interactivity` y registra salida en un log.
- Sin parámetros: copia este script a `C:\ProgramData\Inkoova\WingetUpgradeSoftware.ps1`
  y crea/actualiza la tarea programada que lo ejecuta con `-RunUpgrade`.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Actualización ejecutada correctamente o tarea registrada/actualizada con éxito.
- "NOK" (exit code 1) → Error al crear/actualizar la tarea o al resolver/ejecutar winget.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar manualmente con `-RunUpgrade` para actualizar en el momento.
- Ejecutar sin parámetros para registrar/actualizar la tarea programada.
- La tarea se ejecuta los viernes a las 12:00 (intervalo semanal).
-----------------------------------------------------------------------------------------------------
AUTOR ORIGINAL: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$RunUpgrade
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Parámetros/constantes ---
$TaskName      = 'ScheduledTask-Inkoova-WingetUpgradeSoftware'
$CompanyFolder = Join-Path $env:ProgramData 'Inkoova'
$ScriptTarget  = Join-Path $CompanyFolder 'WingetUpgradeSoftware.ps1'
$LogPath       = 'C:\Winget_Upgrade.log'

function Write-Log([string]$Message) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line
    try { Add-Content -Path $LogPath -Value $line -Encoding UTF8 } catch {}
}

function Resolve-WingetPath {
    # 1) Si está en PATH (alias de App Execution o instalación clásica)
    $cmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($cmd -and (Test-Path $cmd.Path)) {
        return $cmd.Path
    }

    # 2) Búsqueda en WindowsApps (escenarios SYSTEM)
    $waRoot = 'C:\Program Files\WindowsApps'
    if (Test-Path $waRoot) {
        $candidates = Get-ChildItem $waRoot -Directory -Filter 'Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe' -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending
        foreach ($dir in $candidates) {
            $wingetExe = Join-Path $dir.FullName 'winget.exe'
            if (Test-Path $wingetExe) { return $wingetExe }
        }
        # Intento x86 si aplica
        $candidatesX86 = Get-ChildItem $waRoot -Directory -Filter 'Microsoft.DesktopAppInstaller_*_x86__8wekyb3d8bbwe' -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending
        foreach ($dir in $candidatesX86) {
            $wingetExe = Join-Path $dir.FullName 'winget.exe'
            if (Test-Path $wingetExe) { return $wingetExe }
        }
    }

    return $null
}

function Run-Winget-Upgrade {
    $winget = Resolve-WingetPath
    if (-not $winget) {
        Write-Log "No se encontró winget. Asegura que 'Desktop App Installer' esté instalado para el contexto SYSTEM."
        exit 1
    }

    Write-Log "Usando winget: $winget"

    # Actualiza las fuentes primero (no crítico si falla)
    try {
        Start-Process -FilePath $winget -ArgumentList @('source','update') -Wait -NoNewWindow -WindowStyle Hidden | Out-Null
        Write-Log "Fuentes de winget actualizadas."
    } catch {
        Write-Log "Aviso: No se pudieron actualizar las fuentes: $($_.Exception.Message)"
    }

    $args = @(
        'upgrade','--all',
        '--silent',
        '--accept-source-agreements',
        '--accept-package-agreements',
        '--disable-interactivity'
    )

    try {
        $proc = Start-Process -FilePath $winget -ArgumentList $args -Wait -PassThru -NoNewWindow -WindowStyle Hidden
        Write-Log "winget upgrade finalizado. ExitCode=$($proc.ExitCode)"
    } catch {
        Write-Log "ERROR ejecutando winget upgrade: $($_.Exception.Message)"
        exit 1
    }

    Write-Log "Actualización de software con winget completada."
}

# --- Flujo principal ---
if ($RunUpgrade) {
    Run-Winget-Upgrade
    exit 0
}

# Copiar el script actual a C:\ProgramData\Inkoova\WingetUpgradeSoftware.ps1
if (-not (Test-Path $CompanyFolder)) {
    New-Item -ItemType Directory -Path $CompanyFolder -Force | Out-Null
}
$currentPath = $MyInvocation.MyCommand.Path
if ($currentPath -and $currentPath -ne $ScriptTarget) {
    Copy-Item -Path $currentPath -Destination $ScriptTarget -Force
} elseif (-not (Test-Path $ScriptTarget) -and $currentPath) {
    Copy-Item -Path $currentPath -Destination $ScriptTarget -Force
}

# Definir acción, trigger, settings y principal para la tarea
$action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptTarget`" -RunUpgrade"
$trigger   = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At "12:00"   # Viernes 12:00, semanal
$settings  = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 6)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

# Registrar/actualizar la tarea
try {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
    }
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
    Write-Log "Tarea '$TaskName' creada o actualizada correctamente."
} catch {
    Write-Log "ERROR creando/actualizando la tarea: $($_.Exception.Message)"
    exit 1
}

exit 0
