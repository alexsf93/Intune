<#
.SYNOPSIS
    REMEDIATION SCRIPT: RESTRINGIR ACCESO A LOCALIZACION EN APP (LENOVO POWER MANAGER)

.DESCRIPTION
    Este script deniega el acceso a los servicios de localizacion (establece 'Value' = 'Deny')
    especificamente para la aplicacion Lenovo Vantage / Lenovo Power Manager en el almacen de consentimiento
    de Windows (ConsentStore).
    
    Esto previene que Lenovo Power Manager consulte la ubicacion en segundo plano, evitando
    notificaciones e iconos recurrentes de ubicacion en la barra de tareas de Windows 11.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Lenovo Restringir Localizacion App Power Manager - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-09-03
    Context: User
#>

$rutas = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\E046963F.LenovoSettingsforEnterprise_k1h2ywk1493x8",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\nonPackaged\C:#Windows#SysWOW64#Lenovo#PowerMgr#PowerMgr.exe"
)

try {
    # 1. Aplicar la restriccion en el registro
    foreach ($ruta in $rutas) {
        if (-not (Test-Path $ruta)) {
            New-Item -Path $ruta -Force | Out-Null
        }
        Set-ItemProperty -Path $ruta -Name "Value" -Value "Deny" -Type String -Force
        Write-Host "Restriccion aplicada en: $ruta"
    }

    # 2. Notificacion no bloqueante opcional (se auto-cierra en 5 segundos para evitar bloquear Intune)
    $titulo = "Configuracion de Privacidad"
    $mensaje = "Se ha optimizado la privacidad de localizacion para Lenovo Power Manager."
    $wshell = New-Object -ComObject WScript.Shell
    $wshell.Popup($mensaje, 5, $titulo, 64) | Out-Null

    Write-Host "Remediacion finalizada con exito."
    Exit 0
} catch {
    Write-Error "Error durante la remediacion: $_"
    Exit 1
}
