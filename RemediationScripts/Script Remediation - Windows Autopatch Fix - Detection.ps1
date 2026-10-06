<#
.SYNOPSIS
    DETECTION SCRIPT: VALIDACION INTEGRAL DE WINDOWS AUTOPATCH (MASTER FIX)

.DESCRIPTION
    Script integral de deteccion para Windows Autopatch que detecta directivas en conflicto
    que impiden la gestion de actualizaciones de Windows, controladores y firmware:
    
    1. Directivas de Registro Conflictivas (GPO / Politicas heredadas):
       - HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate (Debe NO existir)
       - HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\AUOptions (No debe ser 1, 2, 3 o 7; solo 4, 5 o no configurado)
       - HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\DoNotConnectToWindowsUpdateInternetLocations (No debe bloquear acceso)
       - HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\DisableWindowsUpdateAccess (No debe bloquear acceso)
    
    2. Integridad de PolicyManager (si existe):
       - HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update (Verifica accesibilidad y ausencia de corrupcion)

    Si se detecta cualquier conflicto, finaliza con Exit 1 para activar la remediacion.
    Si el dispositivo esta limpio y conforme, finaliza con Exit 0.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Windows Autopatch Fix - Detection.ps1
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

$issuesFound = [System.Collections.Generic.List[string]]::new()

Write-Host "=== INICIANDO DETECCION INTEGRAL DE WINDOWS AUTOPATCH ==="

# ---------------------------------------------------------------------------
# BLOQUE 1: Verificacion de Directivas Conflictivas (WindowsUpdate y AU)
# ---------------------------------------------------------------------------
$regAU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
$regWU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

# 1.1 NoAutoUpdate (Autopatch requiere que NO exista)
if (Test-Path $regAU) {
    try {
        $auKey = Get-Item -Path $regAU -ErrorAction Stop
        if ($auKey.GetValueNames() -contains "NoAutoUpdate") {
            $valNoAuto = $auKey.GetValue("NoAutoUpdate")
            $msg = "Conflicto detectado: 'NoAutoUpdate' existe en '$regAU' con valor '$valNoAuto'. Windows Autopatch requiere su eliminacion."
            Write-Host " [!] $msg"
            $issuesFound.Add($msg)
        }

        # 1.2 AUOptions (Incompatible si es distinto de 4 o 5)
        if ($auKey.GetValueNames() -contains "AUOptions") {
            $valAUOpt = [int]$auKey.GetValue("AUOptions")
            if ($valAUOpt -ne 4 -and $valAUOpt -ne 5) {
                $msg = "Conflicto detectado: 'AUOptions' tiene valor '$valAUOpt' en '$regAU' (Valores compatibles: 4, 5 o no configurado)."
                Write-Host " [!] $msg"
                $issuesFound.Add($msg)
            }
        }
    }
    catch {
        Write-Warning "Aviso leyendo $($regAU): $($_.Exception.Message)"
    }
}

# 1.3 Bloqueos de conectividad o acceso general a Windows Update
if (Test-Path $regWU) {
    try {
        $wuKey = Get-Item -Path $regWU -ErrorAction Stop
        if ($wuKey.GetValueNames() -contains "DoNotConnectToWindowsUpdateInternetLocations") {
            $valDoNotConnect = [int]$wuKey.GetValue("DoNotConnectToWindowsUpdateInternetLocations")
            if ($valDoNotConnect -ne 0) {
                $msg = "Conflicto detectado: 'DoNotConnectToWindowsUpdateInternetLocations' activo con valor '$valDoNotConnect' en '$regWU'."
                Write-Host " [!] $msg"
                $issuesFound.Add($msg)
            }
        }

        if ($wuKey.GetValueNames() -contains "DisableWindowsUpdateAccess") {
            $valDisableWU = [int]$wuKey.GetValue("DisableWindowsUpdateAccess")
            if ($valDisableWU -ne 0) {
                $msg = "Conflicto detectado: 'DisableWindowsUpdateAccess' activo con valor '$valDisableWU' en '$regWU'."
                Write-Host " [!] $msg"
                $issuesFound.Add($msg)
            }
        }
    }
    catch {
        Write-Warning "Aviso leyendo $($regWU): $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# BLOQUE 2: Integridad de PolicyManager (si la clave existe en el equipo)
# ---------------------------------------------------------------------------
$policyManagerPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update"
if (Test-Path -Path $policyManagerPath -ErrorAction SilentlyContinue) {
    try {
        $pmKey = Get-Item -Path $policyManagerPath -ErrorAction Stop
        # Si la clave existe, validar que es accesible y legible
        $null = $pmKey.GetValueNames()
    }
    catch {
        $msg = "PolicyManager: Clave corrupta o inaccesible en '$policyManagerPath' ($($_.Exception.Message))."
        Write-Host " [!] $msg"
        $issuesFound.Add($msg)
    }
}

# ---------------------------------------------------------------------------
# EVALUACION FINAL
# ---------------------------------------------------------------------------
Write-Host "--------------------------------------------------------"
if ($issuesFound.Count -gt 0) {
    Write-Host "ESTADO: NO CONFORME. Se encontraron $($issuesFound.Count) problema(s) para Windows Autopatch:"
    foreach ($issue in $issuesFound) {
        Write-Host " - $issue"
    }
    Write-Host "Iniciando proceso de remediacion..."
    exit 1
} else {
    Write-Host "ESTADO: CONFORME. Directivas de registro limpias y sin conflictos. Windows Autopatch listo."
    exit 0
}
