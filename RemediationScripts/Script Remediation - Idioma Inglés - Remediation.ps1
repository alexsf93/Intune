<#
.SYNOPSIS
    REMEDIATION SCRIPT: CONFIGURAR IDIOMA INGLÉS (en-US) Y TECLADO ESPAÑOL (ES)

.DESCRIPTION
    Este script instala y configura el idioma **en-US** como UI de Windows, mantiene formatos regionales
    en **es-ES**, y ajusta el teclado a Español (España). Está orientado a Intune Proactive Remediations.

.PARAMETER
    Ninguno.

.EXAMPLE
    Executes as Intune Remediation Script.

.NOTES
    Name: Script Remediation - Idioma Inglés - Remediation.ps1
    Author: Alejandro Suárez (@alexsf93)
    Version: 1.0.0
    Date: 2026-01-21
    Context: User
#>

$want = "en-US"

# 1) Instalar paquete de idioma desde Windows Update
try {
    Install-Language -Language $want -ErrorAction Stop
}
catch {
    Write-Error "Error instalando el paquete de idioma $want $_"
    exit 1
}

# 2) Instalar capacidades adicionales
$caps = @(
    "Language.Basic~~~en-US~0.0.1.0",
    "Language.Handwriting~~~en-US~0.0.1.0",
    "Language.OCR~~~en-US~0.0.1.0",
    "Language.Speech~~~en-US~0.0.1.0",
    "Language.TextToSpeech~~~en-US~0.0.1.0"
)
foreach ($c in $caps) {
    try { Add-WindowsCapability -Online -Name $c -ErrorAction SilentlyContinue | Out-Null } catch {}
}

# 3) Configuración de idioma y región
Set-WinSystemLocale en-US
Set-WinUILanguageOverride en-US
Set-Culture es-ES
Set-WinHomeLocation -GeoId 217

# 4) Teclado: solo Español (España - Tradicional)
$ll = New-WinUserLanguageList en-US
$ll[0].InputMethodTips.Clear()
$ll[0].InputMethodTips.Add("040a:0000040a")
Set-WinUserLanguageList $ll -Force

# 5) Copiar ajustes a pantalla de bienvenida y nuevas cuentas
try { Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true 2>$null } catch {}

exit 0
