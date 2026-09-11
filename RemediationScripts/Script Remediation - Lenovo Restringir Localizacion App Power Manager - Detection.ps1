<#
.SYNOPSIS
    DETECTION SCRIPT: RESTRINGIR ACCESO A LOCALIZACION EN APP (LENOVO POWER MANAGER)

.DESCRIPTION
    Este script detecta si el acceso a los servicios de localizacion esta restringido (valor 'Deny')
    especificamente para la aplicacion Lenovo Vantage / Lenovo Power Manager en el almacen de consentimiento
    de Windows (ConsentStore).
    
    Evita que el proceso de la aplicacion consulte continuamente la ubicacion geografica y genere notificaciones
    e iconos recurrentes en la barra de tareas de Windows 11.
    
    Si el valor 'Value' no esta establecido en 'Deny' o la clave no existe, el script finaliza con Exit 1 para remediar.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Lenovo Restringir Localizacion App Power Manager - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-09-03
    Context: User
#>

$rutas = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\E046963F.LenovoSettingsforEnterprise_k1h2ywk1493x8",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\nonPackaged\C:#Windows#SysWOW64#Lenovo#PowerMgr#PowerMgr.exe"
)

$requiereRemediacion = $false

foreach ($ruta in $rutas) {
    if (Test-Path $ruta) {
        $valor = (Get-ItemProperty -Path $ruta -Name "Value" -ErrorAction SilentlyContinue).Value
        if ($valor -ne "Deny") {
            Write-Host "No conforme: $ruta tiene el valor '$valor' (se requiere 'Deny')."
            $requiereRemediacion = $true
        }
    } else {
        # Si no existe la clave, no esta restringido -> Requiere remediacion preventiva
        Write-Host "No conforme: $ruta no existe (permiso no restringido)."
        $requiereRemediacion = $true
    }
}

if ($requiereRemediacion) {
    Write-Host "Estado: NO CONFORME. Se requiere aplicar la remediacion."
    Exit 1
} else {
    Write-Host "Estado: CONFORME. Acceso a localizacion denegado correctamente."
    Exit 0
}
