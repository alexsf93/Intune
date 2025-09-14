<#
=====================================================================================================
    DETECTION SCRIPT: ¿ESTÁ INSTALADO EL COMPANY PORTAL (PORTAL DE EMPRESA)?
-----------------------------------------------------------------------------------------------------
Este script detecta si la aplicación **Company Portal** de Microsoft está instalada en el equipo
en formato AppX/MSIX. Está orientado a escenarios de remediación y compliance con Microsoft Intune.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- Compatible con PowerShell 5.1 y 7.x.
- No requiere privilegios de administrador.
- Acceso al cmdlet `Get-AppxPackage`.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Busca el paquete instalado con nombre `Microsoft.CompanyPortal`.
- Devuelve:
  * Exit code 0 → Company Portal está instalado.
  * Exit code 1 → Company Portal NO está instalado.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → Company Portal presente.
- "NOK" (exit code 1) → Company Portal ausente (aplicar remediación).

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Usar como Detection Rule en Intune u otros flujos de compliance.
- Interpretar el exit code para decidir acciones de remediación (instalación del Company Portal).

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

$cp = Get-AppxPackage -Name "Microsoft.CompanyPortal" -ErrorAction SilentlyContinue
if ($cp) {
    Exit 0  # Está instalado
} else {
    Exit 1  # NO está instalado (necesita remediación)
}
