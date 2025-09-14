<#
=====================================================================================================
    REMEDIATION SCRIPT: AÑADIR “PRIMARY USER” AL GRUPO DE ADMINISTRADORES LOCALES
-----------------------------------------------------------------------------------------------------
Este script añade el "primary user" (usuario más frecuente o último logueado) al grupo de 
administradores locales si aún no lo está. Está pensado para usarse en conjunto con reglas 
de detección y remediación en entornos gestionados con Intune u otras plataformas MDM.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- Debe ejecutarse con permisos SYSTEM o con privilegios de administrador local.
- Compatible con PowerShell 5.1 o superior.
- El cmdlet `Add-LocalGroupMember` debe estar disponible.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Obtiene el "primary user" del dispositivo (usuario con más sesiones o último logueado).
- Verifica si el usuario ya pertenece al grupo de administradores locales.
- Si no pertenece, lo añade al grupo "Administradores" (o "Administrators" en sistemas en inglés).

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0 implícito) → El usuario se añade correctamente o ya pertenece al grupo.
- "NOK" (mensajes en salida estándar) → No se pudo añadir al grupo de administradores.

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Ejecutar como parte de una Remediation Script en Intune.
- Asegurarse de combinarlo con el script de detección correspondiente.
- Revisar la salida del script para confirmar si la acción se aplicó.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

# 1. Obtener el primary user como en el detection
$users = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
if (-not $users) {
    $reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
    $primaryUser = (Get-ItemProperty -Path $reg -Name LastLoggedOnUser -ErrorAction SilentlyContinue).LastLoggedOnUser
    if ($primaryUser) {
        $primaryUser = $primaryUser -replace "^.+\\", ""
    }
} else {
    $primaryUser = $users -replace "^.+\\", ""
}

if ($primaryUser) {
    # 2. Añadirlo como administrador local (soporta dominio/local/AAD)
    try {
        Add-LocalGroupMember -Group "Administradores" -Member $primaryUser -ErrorAction Stop
    } catch {
        try {
            Add-LocalGroupMember -Group "Administrators" -Member $primaryUser -ErrorAction Stop
        } catch {
            Write-Host "No se pudo añadir a $primaryUser al grupo de administradores locales."
        }
    }
}
