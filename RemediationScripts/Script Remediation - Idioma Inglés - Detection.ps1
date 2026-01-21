<#
.SYNOPSIS
    DETECTION SCRIPT: IDIOMA INGLÉS (en-US) NO CONFIGURADO

.DESCRIPTION
    Este script detecta si el idioma de Windows está configurado en **en-US** y si el paquete de idioma 
    en-US está instalado. Está orientado a Intune Proactive Remediations en dispositivos gestionados.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Detection Script.

.NOTES
    Name: Script Remediation - Idioma Inglés - Detection.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
#>

$want = "en-US"
$lpKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\LanguagePack\InstalledLanguages\$want"
$ui = (Get-WinUILanguageOverride) 2>$null

if ((Test-Path $lpKey) -and ($ui -eq $want)) {
    exit 0
}
else {
    exit 1
}
