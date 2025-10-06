<#
=====================================================================================================
    DETECTION SCRIPT: CREAR O AJUSTAR LA TAREA "ScheduledTask-Inkoova-CleanUpdates"
-----------------------------------------------------------------------------------------------------
Este script detecta si el idioma de Windows está configurado en **en-US** y si el paquete de idioma 
en-US está instalado. Está orientado a Intune Proactive Remediations en dispositivos gestionados.

-----------------------------------------------------------------------------------------------------
REQUISITOS
-----------------------------------------------------------------------------------------------------
- PowerShell 5.1 o 7.x.
- Ejecución con privilegios SYSTEM o administrador local.

-----------------------------------------------------------------------------------------------------
¿CÓMO FUNCIONA?
-----------------------------------------------------------------------------------------------------
- Comprueba en el registro si está instalado el paquete de idioma en-US.
- Comprueba si la UI actual está configurada en en-US.
- Devuelve exit code 0 si todo está conforme, 1 si requiere remediación.

-----------------------------------------------------------------------------------------------------
RESULTADOS
-----------------------------------------------------------------------------------------------------
- "OK" (exit code 0) → LP instalado y UI en inglés (en-US).
- "NOK" (exit code 1) → Falta LP o UI no está en inglés.

-----------------------------------------------------------------------------------------------------
AUTOR: Alejandro Suárez (@alexsf93)
=====================================================================================================
#>

$want = "en-US"
$lpKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\LanguagePack\InstalledLanguages\$want"
$ui = (Get-WinUILanguageOverride) 2>$null

if ((Test-Path $lpKey) -and ($ui -eq $want)) {
    exit 0
} else {
    exit 1
}
