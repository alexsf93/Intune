<#
.SYNOPSIS
    DETECTION SCRIPT: DEVOLVER EXIT CODE 1 (REGLA DE PRUEBA/NO CONFORME)

.DESCRIPTION
    Este script está diseñado para usarse como Detection Rule en Intune Remediations u otros sistemas de
    compliance. Su único propósito es devolver el código de salida `1`, indicando que la condición de
    detección NO se cumple (estado "no conforme"). Útil para pruebas y validación de flujos.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Notificacion Toast - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
#>
exit 1
