<#
===============================================================================================
     REMEDIACIÓN: AÑADIR “PRIMARY USER” AL GRUPO DE ADMINISTRADORES LOCALES
-----------------------------------------------------------------------------------------------
Este script añade el “primary user” (usuario más frecuente o último logueado)
al grupo de administradores locales si aún no lo está.

-----------------------------------------------------------------------------------------------
AUTOR
-----------------------------------------------------------------------------------------------
- Alejandro Suárez (@alexsf93)
===============================================================================================
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
