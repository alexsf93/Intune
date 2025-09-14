<#
=====================================================================================================
    DETECTION SCRIPT: DEVOLVER EXIT CODE 1 (REGLA DE PRUEBA/NO CONFORME)
-----------------------------------------------------------------------------------------------------
Este script está diseñado para usarse como Detection Rule en Intune Remediations u otros sistemas de
compliance. Su único propósito es devolver el código de salida `1`, indicando que la condición de
detección NO se cumple (estado "no conforme"). Útil para pruebas y validación de flujos.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Ninguno adicional.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Finaliza inmediatamente con `exit 1`.
- No realiza comprobaciones ni acciones adicionales.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "NOK" (exit code 1) → Condición de detección no cumplida.
- (Para marcar cumplimiento usar `exit 0` en su lugar.)

-----------------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------------
- Usar como Detection Rule en Intune o cualquier sistema que interprete exit codes.
- Emplear para forzar la ejecución de remediaciones o validar flujos de trabajo.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>
exit 1
