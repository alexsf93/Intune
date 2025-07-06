<#
===============================================================================================
    REGLA DE DETECCIÓN (DETECTION RULE) - POWERSHELL
-----------------------------------------------------------------------------------------------
Este script está diseñado para usarse como una Detection Rule en Intune Remediations u otros
sistemas de compliance. Su único propósito es devolver el código de salida `1`, lo que indica
que la condición de detección **NO se cumple** (estado "no conforme").

Útil para pruebas, validación de flujos, comprobación de lógica o para forzar la ejecución de
acciones de remediación en los dispositivos objetivo.

-----------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------
- Devuelve inmediatamente el código de salida `1` al ejecutarse.
- No realiza comprobaciones ni acciones adicionales.

-----------------------------------------------------------------------------------------------
INSTRUCCIONES DE USO
-----------------------------------------------------------------------------------------------
- Usa este script como Detection Rule en Intune o cualquier sistema que interprete exit codes.
- Un exit code `1` significa que la condición de detección NO está cumplida.
- Para marcar como "cumplido", utiliza `exit 0` en su lugar.

-----------------------------------------------------------------------------------------------
===============================================================================================
#>
exit 1