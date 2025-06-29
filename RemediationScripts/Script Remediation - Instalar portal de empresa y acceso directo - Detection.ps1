<#
===============================================================================================
     DETECCIÓN: ¿ESTÁ INSTALADO EL COMPANY PORTAL (PORTAL DE EMPRESA)?
-----------------------------------------------------------------------------------------------
Este script detecta si el "Company Portal" de Microsoft está instalado (modo AppX/MSIX)
en el equipo. Pensado para remediaciones y compliance en Microsoft Intune.

-----------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------
- Busca el paquete "Microsoft.CompanyPortal" en las apps instaladas.
- Devuelve Exit 0 si está instalado, Exit 1 si NO está (requiere remediation).

-----------------------------------------------------------------------------------------------
AUTOR
-----------------------------------------------------------------------------------------------
- Alejandro Suárez (@alexsf93)
===============================================================================================
#>

$cp = Get-AppxPackage -Name "Microsoft.CompanyPortal"
if ($cp) {
    Exit 0  # Está instalado
} else {
    Exit 1  # NO está instalado (necesita remediation)
}
